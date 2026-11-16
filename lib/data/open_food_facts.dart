/// Looks products up on Open Food Facts (openfoodfacts.org), the free, open
/// product database: by barcode, or by name among Australian products. Only
/// the name, brand, pack size and the small front picture are read. Data is
/// ODbL; pictures are CC BY-SA 3.0; the app credits both. ADRs 0005, 0006.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// What Open Food Facts knows about one product.
class ProductInfo {
  const ProductInfo({
    required this.barcode,
    required this.name,
    this.brand = '',
    this.packSize = 0,
    this.unit = '',
    this.quantityText = '',
    this.imageUrl,
  });

  final String barcode;

  /// The product's own name, e.g. "Soy Sauce".
  final String name;
  final String brand;

  /// How much one pack holds, in [unit] (g, kg, ml or L); 0 when not known.
  final double packSize;
  final String unit;

  /// The pack size as Open Food Facts writes it ("600ml", "2 kg"); '' if none.
  final String quantityText;

  /// The small (200 px) front picture, when it has one.
  final String? imageUrl;

  /// "Kikkoman Soy Sauce": the brand in front, unless the name already has it.
  String get displayName {
    final b = brand.split(',').first.trim();
    if (b.isEmpty || name.toLowerCase().contains(b.toLowerCase())) return name;
    return name.isEmpty ? b : '$b $name';
  }

  bool get hasPackSize => packSize > 0 && unit.isNotEmpty;
}

/// Reads a pack size: "500 ml", "1L", "1,5 kg", "2 x 375 ml" (750 ml),
/// "33 cl" (330 ml). Returns (size, unit) with unit one of g, kg, ml, L, or
/// null when there is no amount in it.
(double, String)? parsePackSize(String text) {
  final t = text.toLowerCase().replaceAll(',', '.');
  final m = RegExp(r'(?:(\d+)\s*[x×]\s*)?(\d+(?:\.\d+)?)\s*(kg|g|ml|cl|l)\b').firstMatch(t);
  if (m == null) return null;
  final count = m.group(1) == null ? 1 : int.parse(m.group(1)!);
  var size = double.parse(m.group(2)!) * count;
  var unit = m.group(3)!;
  if (unit == 'cl') {
    size *= 10;
    unit = 'ml';
  }
  if (size <= 0) return null;
  return (size, unit == 'l' ? 'L' : unit);
}

/// Thrown when the lookup could not be made (no signal, the service is down).
class LookupFailed implements Exception {
  const LookupFailed(this.reason);
  final String reason;
  @override
  String toString() => reason;
}

class OpenFoodFacts {
  OpenFoodFacts({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// The one the app uses; tests swap in one with a fake client.
  static OpenFoodFacts instance = OpenFoodFacts();

  /// Open Food Facts asks every app to name itself and give a contact.
  static const userAgent = 'PantryApp/0.5 (chris@combinationsoupstudio.com.au)';

  /// The product for [barcode], or null if Open Food Facts does not have it.
  Future<ProductInfo?> lookup(String barcode) async {
    final code = barcode.trim();
    if (!RegExp(r'^\d{6,14}$').hasMatch(code)) return null;
    final uri = Uri.https('world.openfoodfacts.org', '/api/v2/product/$code', {
      'fields':
          'product_name,product_name_en,brands,quantity,product_quantity,product_quantity_unit,image_front_small_url',
    });
    final http.Response res;
    try {
      res = await _client.get(uri, headers: {'User-Agent': userAgent}).timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const LookupFailed('No connection to Open Food Facts');
    }
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw LookupFailed('Open Food Facts answered ${res.statusCode}');
    final Object? body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      throw const LookupFailed('Open Food Facts sent something unreadable');
    }
    if (body is! Map || body['status'] != 1 || body['product'] is! Map) return null;
    return productFromJson(code, (body['product'] as Map).cast<String, Object?>());
  }

  /// Products sold in Australia whose name, brand or category matches
  /// [query], best match first, at most [limit]. Empty when nothing matches.
  Future<List<ProductInfo>> search(String query, {int limit = 24}) async {
    final q = query.trim().replaceAll('"', '');
    if (q.length < 2) return const [];
    final uri = Uri.https('search.openfoodfacts.org', '/search', {
      'q': '$q countries_tags:"en:australia"',
      'page_size': '$limit',
      'fields': 'code,product_name,product_name_en,brands,quantity,product_quantity,product_quantity_unit,image_front_small_url',
    });
    final http.Response res;
    try {
      res = await _client.get(uri, headers: {'User-Agent': userAgent}).timeout(const Duration(seconds: 12));
    } catch (_) {
      throw const LookupFailed('No connection to Open Food Facts');
    }
    if (res.statusCode != 200) throw LookupFailed('Open Food Facts search answered ${res.statusCode}');
    final Object? body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      throw const LookupFailed('Open Food Facts sent something unreadable');
    }
    final hits = body is Map && body['hits'] is List ? body['hits'] as List : const [];
    return [
      for (final h in hits)
        if (h is Map) productFromJson('${h['code'] ?? ''}', h.cast<String, Object?>()),
    ].where((p) => p.name.isNotEmpty || p.brand.isNotEmpty).toList();
  }
}

/// The parts of an Open Food Facts product record the app uses.
ProductInfo productFromJson(String barcode, Map<String, Object?> p) {
  String str(String key) {
    final v = p[key];
    if (v is List) return v.whereType<String>().join(', ').trim();
    return v is String ? v.trim() : '';
  }

  final name = str('product_name_en').isNotEmpty ? str('product_name_en') : str('product_name');

  var size = 0.0;
  var unit = '';
  final pq = p['product_quantity'];
  final pqValue = pq is num ? pq.toDouble() : double.tryParse('$pq'.replaceAll(',', '.'));
  final pqUnit = str('product_quantity_unit').toLowerCase();
  if (pqValue != null && pqValue > 0 && const {'g', 'ml'}.contains(pqUnit)) {
    size = pqValue;
    unit = pqUnit;
  } else {
    final parsed = parsePackSize(str('quantity'));
    if (parsed != null) (size, unit) = parsed;
  }
  final image = str('image_front_small_url');
  return ProductInfo(
    barcode: barcode,
    name: name,
    brand: str('brands'),
    packSize: size,
    unit: unit,
    quantityText: str('quantity'),
    imageUrl: image.startsWith('https://') ? image : null,
  );
}

/// Puts the products whose names hold the most of [query]'s words first
/// ("washed potatoes" before "Refreshing Facial Wash"), then those with a
/// picture; otherwise keeps the search's own order.
List<ProductInfo> rankByName(String query, List<ProductInfo> found) {
  String stem(String w) => w.length > 3 && w.endsWith('es')
      ? w.substring(0, w.length - 2)
      : w.length > 2 && w.endsWith('s')
      ? w.substring(0, w.length - 1)
      : w;
  List<String> words(String t) =>
      t.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((w) => w.length > 1).map(stem).toList();
  final want = words(query).toSet();
  int score(ProductInfo p) {
    final have = words(p.displayName).toSet();
    return want.where(have.contains).length * 2 + (p.imageUrl != null ? 1 : 0);
  }

  final indexed = [for (var i = 0; i < found.length; i++) (i, found[i], score(found[i]))];
  indexed.sort((a, b) => b.$3 != a.$3 ? b.$3.compareTo(a.$3) : a.$1.compareTo(b.$1));
  return [for (final e in indexed) e.$2];
}
