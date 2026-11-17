import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'sync_service.dart';

/// How a barcode was set up by a household (or taken from Open Food Facts).
class CatalogueProduct {
  const CatalogueProduct({
    required this.barcode,
    required this.name,
    this.brand = '',
    this.packSize = 0,
    this.unit = '',
    this.countAs = 'count',
    this.countUnit = '',
    this.locationKind = 'pantry',
    this.hasPhoto = false,
    this.updatedAt = 0,
  });

  final String barcode;
  final String name;
  final String brand;
  final double packSize;
  final String unit;

  /// "count" (2 jars) or "measure" (300 g of a 500 g bag).
  final String countAs;

  /// What it is counted in when counted: "jars", "tins".
  final String countUnit;

  /// "pantry" (the kitchen) or "storage" (stored away).
  final String locationKind;
  final bool hasPhoto;
  final int updatedAt;

  bool get measured => countAs == 'measure';

  factory CatalogueProduct.fromJson(Map<String, Object?> j) => CatalogueProduct(
    barcode: j['barcode'] as String? ?? '',
    name: j['name'] as String? ?? '',
    brand: j['brand'] as String? ?? '',
    packSize: (j['packSize'] as num?)?.toDouble() ?? 0,
    unit: j['unit'] as String? ?? '',
    countAs: j['countAs'] == 'measure' ? 'measure' : 'count',
    countUnit: j['countUnit'] as String? ?? '',
    locationKind: j['locationKind'] == 'storage' ? 'storage' : 'pantry',
    hasPhoto: j['hasPhoto'] == true,
    updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
  );

  Map<String, Object?> toJson({String source = 'household'}) => {
    'name': name,
    'brand': brand,
    'packSize': packSize,
    'unit': unit,
    'countAs': countAs,
    'countUnit': countUnit,
    'locationKind': locationKind,
    'source': source,
  };
}

/// The product library (v0.13): one for everyone, by barcode, on the studio's
/// household server. A scan asks here first (a fraction of a second); Open
/// Food Facts only when a barcode is new, and then the answer is kept here
/// so nobody waits on it for that barcode again. What a household sets a
/// product up as, and its photo, is shared so the next scan gets it.
///
/// Chris, 17 Nov 2026: "a database the users add to when uploading for their
/// products ... the next person who ... scans the same Barcode gets that
/// product photo."
class Catalogue {
  Catalogue({http.Client? client, this.server = syncServer, this.auth}) : _client = client ?? http.Client();

  static Catalogue instance = Catalogue(auth: () => SyncService.instance?.authHeaders);

  final http.Client _client;
  final String server;

  /// The household's token headers, or null when this phone is not in one
  /// (then nothing is shared, only read).
  final Map<String, String>? Function()? auth;

  /// Where a product's shared photo is; the version makes a new photo a new
  /// picture on every phone.
  String photoUrl(String barcode, int version) => '$server/catalogue/$barcode/photo?v=$version';

  static bool isBarcode(String s) => RegExp(r'^\d{6,14}$').hasMatch(s.trim());

  /// What the library knows about [barcode]; null when nothing, or no answer
  /// in [timeout].
  Future<CatalogueProduct?> lookup(String barcode, {Duration timeout = const Duration(seconds: 3)}) async {
    if (!isBarcode(barcode)) return null;
    try {
      final res = await _client.get(Uri.parse('$server/catalogue/${barcode.trim()}')).timeout(timeout);
      if (res.statusCode != 200) return null;
      final body = (jsonDecode(utf8.decode(res.bodyBytes)) as Map).cast<String, Object?>();
      final p = (body['product'] as Map?)?.cast<String, Object?>();
      if (p == null || (p['name'] as String? ?? '').isEmpty) return null;
      return CatalogueProduct.fromJson(p);
    } catch (_) {
      return null;
    }
  }

  /// Shares how this household set [p] up. Quietly does nothing when this
  /// phone is not in a household or has no signal.
  Future<bool> share(CatalogueProduct p, {String source = 'household'}) async {
    final headers = auth?.call();
    if (headers == null || !isBarcode(p.barcode) || p.name.trim().isEmpty) return false;
    try {
      final res = await _client
          .post(
            Uri.parse('$server/catalogue/${p.barcode.trim()}'),
            headers: {...headers, 'content-type': 'application/json'},
            body: jsonEncode(p.toJson(source: source)),
          )
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Shares a product photo (a small JPEG) for [barcode].
  Future<bool> sharePhoto(String barcode, Uint8List jpeg) async {
    final headers = auth?.call();
    if (headers == null || !isBarcode(barcode)) return false;
    try {
      final res = await _client
          .put(
            Uri.parse('$server/catalogue/${barcode.trim()}/photo'),
            headers: {...headers, 'content-type': 'image/jpeg'},
            body: jpeg,
          )
          .timeout(const Duration(seconds: 20));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
