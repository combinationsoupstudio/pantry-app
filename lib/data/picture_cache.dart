/// Product pictures, downloaded once and kept on the phone.
///
/// Nothing is bundled with the app: a picture is fetched the first time an
/// item needs it (small, 200 px, around 10-25 KB) and read from the phone
/// after that, so the app stays the same size however many products a
/// household has. ADR 0006.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'open_food_facts.dart';

class PictureCache {
  PictureCache({required this.root, http.Client? client}) : _client = client ?? http.Client();

  /// The app's cache, in its own folder on the phone.
  static PictureCache instance = PictureCache(root: getApplicationDocumentsDirectory);

  /// Where the app keeps its files; pictures go in a "pictures" folder in it.
  final Future<Directory> Function() root;
  final http.Client _client;
  final _pending = <String, Future<File?>>{};
  Directory? _dir;

  Future<Directory> _folder() async {
    final d = _dir ??= Directory('${(await root()).path}/pictures');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  /// The file name a picture URL is kept under: its path on the image server
  /// ("/images/products/490/151/511/8586/front.5.200.jpg" ->
  /// "490_151_511_8586_front.5.200.jpg"), which is unique per product and
  /// per picture version.
  static String fileNameFor(String url) {
    final uri = Uri.tryParse(url);
    final segments = (uri?.pathSegments ?? const <String>[]).where((s) => s.isNotEmpty).toList();
    final start = segments.indexOf('products');
    final parts = start >= 0 ? segments.sublist(start + 1) : segments;
    final name = parts.join('_').replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return name.isEmpty ? 'picture.jpg' : name;
  }

  /// Only Open Food Facts' image server is fetched from.
  static bool isAllowed(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'https' && uri.host == 'images.openfoodfacts.org';
  }

  /// Recently shown pictures, kept in memory (a few hundred small JPEGs).
  final _memory = <String, Uint8List>{};
  static const memoryLimit = 300;

  /// The picture's bytes: from memory, else from the phone, else downloaded
  /// once. Null when it cannot be had.
  Future<Uint8List?> bytesFor(String url) async {
    final hit = _memory.remove(url);
    if (hit != null) return _memory[url] = hit;
    final f = await fileFor(url);
    if (f == null) return null;
    final bytes = f.readAsBytesSync();
    _memory[url] = bytes;
    if (_memory.length > memoryLimit) _memory.remove(_memory.keys.first);
    return bytes;
  }

  /// The file for [url] if it is already on the phone, without fetching.
  Future<File?> cached(String url) async {
    if (!isAllowed(url)) return null;
    final f = File('${(await _folder()).path}/${fileNameFor(url)}');
    return f.existsSync() && f.lengthSync() > 0 ? f : null;
  }

  /// The picture's file on the phone, downloading it the first time. Null when
  /// it cannot be had (no signal, gone from the server, not an image).
  Future<File?> fileFor(String url) => _pending.putIfAbsent(url, () async {
    try {
      final have = await cached(url);
      if (have != null || !isAllowed(url)) return have;
      final res = await _client
          .get(Uri.parse(url), headers: {'User-Agent': OpenFoodFacts.userAgent})
          .timeout(const Duration(seconds: 15));
      final type = res.headers['content-type'] ?? '';
      if (res.statusCode != 200 || res.bodyBytes.isEmpty || !type.startsWith('image/')) return null;
      final f = File('${(await _folder()).path}/${fileNameFor(url)}');
      final part = File('${f.path}.part');
      await part.writeAsBytes(res.bodyBytes, flush: true);
      await part.rename(f.path);
      return f;
    } catch (_) {
      return null;
    } finally {
      // A failed fetch can be tried again later; a good one is on disk now.
      _pending.remove(url)?.ignore();
    }
  });
}
