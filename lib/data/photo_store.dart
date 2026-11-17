import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'catalogue.dart';
import 'household_store.dart';

/// The household's own photos (v0.13): each one shrunk to a small JPEG,
/// named by its SHA-256 (so the same photo is one file, and a phone can name
/// it before it is uploaded), kept on the phone and sent to the household
/// server, so it shows on every phone.
///
/// Chris, 17 Nov 2026: "Photos we each take and upload to products, don't
/// carry across to each other's device."
class PhotoStore {
  PhotoStore({required this.root, this.upload, this.download});

  static PhotoStore? instance;

  /// Where the app keeps its files; photos go in "shared-photos" inside it.
  final Future<Directory> Function() root;

  /// Sends a JPEG to the household; true when it is there. Null: not shared.
  Future<bool> Function(Uint8List jpeg)? upload;

  /// Fetches a photo by its hash from the household. Null: not shared.
  Future<Uint8List?> Function(String hash)? download;

  static PhotoStore onPhone() => PhotoStore(root: getApplicationDocumentsDirectory);

  Directory? _dir;
  final _memory = <String, Uint8List>{};
  final _pending = <String, Future<Uint8List?>>{};

  Future<Directory> _folder() async {
    final d = _dir ??= Directory('${(await root()).path}/shared-photos');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  File _file(Directory d, String hash) => File('${d.path}/$hash.jpg');

  /// Shrinks a camera photo to at most 640 px across, JPEG quality 78:
  /// about 40 to 80 KB, plenty for a picture the size of a thumb.
  static Uint8List shrink(Uint8List original) {
    final decoded = img.decodeImage(original);
    if (decoded == null) throw const FormatException('not a picture');
    final oriented = img.bakeOrientation(decoded);
    final longest = oriented.width > oriented.height ? oriented.width : oriented.height;
    final small = longest <= 640
        ? oriented
        : img.copyResize(
            oriented,
            width: oriented.width >= oriented.height ? 640 : null,
            height: oriented.height > oriented.width ? 640 : null,
            interpolation: img.Interpolation.average,
          );
    return Uint8List.fromList(img.encodeJpg(small, quality: 78));
  }

  static String hashOf(Uint8List jpeg) => sha256.convert(jpeg).toString();

  /// Takes a photo file from the camera: shrinks it, keeps it, queues it to
  /// go to the household. Returns its hash, the item's photoId.
  Future<String> add(String path) async {
    final small = await compute(shrink, await File(path).readAsBytes());
    return addBytes(small);
  }

  Future<String> addBytes(Uint8List jpeg) async {
    final hash = hashOf(jpeg);
    final d = await _folder();
    final f = _file(d, hash);
    if (!f.existsSync()) await f.writeAsBytes(jpeg, flush: true);
    _memory[hash] = jpeg;
    await _queue((q) => q..add(hash));
    return hash;
  }

  /// The photo, from memory, the phone, or the household (kept once fetched).
  Future<Uint8List?> bytesFor(String hash) {
    final hit = _memory[hash];
    if (hit != null) return SynchronousFuture(hit);
    return _pending.putIfAbsent(hash, () async {
      try {
        final f = _file(await _folder(), hash);
        if (f.existsSync()) return _memory[hash] = await f.readAsBytes();
        final got = await download?.call(hash);
        if (got == null || hashOf(got) != hash) return null;
        await f.writeAsBytes(got, flush: true);
        return _memory[hash] = got;
      } catch (_) {
        return null;
      } finally {
        _pending.remove(hash)?.ignore();
      }
    });
  }

  /// Sends photos taken here that the household does not have yet.
  Future<int> sendWaiting() async {
    final send = upload;
    if (send == null) return 0;
    final d = await _folder();
    var sent = 0;
    for (final hash in await _waiting()) {
      final f = _file(d, hash);
      if (!f.existsSync() || await send(await f.readAsBytes())) {
        await _queue((q) => q..remove(hash));
        if (f.existsSync()) sent++;
      }
    }
    return sent;
  }

  Future<List<String>> _waiting() async {
    final f = File('${(await _folder()).path}/waiting.json');
    if (!f.existsSync()) return [];
    try {
      return [for (final h in jsonDecode(await f.readAsString()) as List) h as String];
    } catch (_) {
      return [];
    }
  }

  Future<void> _queue(Set<String> Function(Set<String>) change) async {
    final f = File('${(await _folder()).path}/waiting.json');
    final next = change({...await _waiting()});
    await f.writeAsString(jsonEncode(next.toList()));
  }
}

/// Photos taken before v0.13 were files on the phone that took them. Each
/// one still here is shrunk, kept and shared, and its item gets the photoId,
/// so it shows on every phone. Returns how many.
Future<int> shareOldPhotos(HouseholdStore store, PhotoStore photos) async {
  var n = 0;
  for (final i in store.items.where((i) => i.photoId == null && i.photoPath != null).toList()) {
    try {
      if (!store.photoOnThisPhone(i.photoPath!)) continue;
      final id = await photos.add(i.photoPath!);
      final now = store.item(i.id);
      if (now == null || now.photoId != null) continue;
      await store.updateItem(now.copyWith(photoId: id));
      n++;
      // A barcoded product's photo also goes to the product library.
      final code = now.barcode;
      final bytes = await photos.bytesFor(id);
      if (code != null && bytes != null) await Catalogue.instance.sharePhoto(code, bytes);
    } catch (_) {
      // Not a picture any more: leave it.
    }
  }
  if (n > 0) await photos.sendWaiting();
  return n;
}
