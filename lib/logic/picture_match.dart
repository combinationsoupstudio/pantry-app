/// Finding a product picture from an item's own name ("Tins: beans and baked
/// beans", "Flour (plain and self-raising)"), for items that were typed or
/// imported rather than scanned. ADR 0006.
library;

import '../data/open_food_facts.dart';

/// Container and filler words that say nothing about the product itself.
const _drop = {
  'tin', 'tins', 'can', 'cans', 'packet', 'packets', 'pack', 'packs', 'jar', 'jars', 'bottle', 'bottles', //
  'bag', 'bags', 'box', 'boxes', 'sachet', 'sachets', 'and', 'or', 'of', 'for', 'with', 'the', 'x',
};

String _stem(String w) {
  if (w.length > 3 && w.endsWith('ies')) return '${w.substring(0, w.length - 3)}y';
  if (w.length > 3 && w.endsWith('es') && !w.endsWith('ses')) return w.substring(0, w.length - 2);
  if (w.length > 2 && w.endsWith('s') && !w.endsWith('ss')) return w.substring(0, w.length - 1);
  return w;
}

Set<String> _words(String text) =>
    RegExp(r'[a-z]+')
        .allMatches(text.toLowerCase())
        .map((m) => m.group(0)!)
        .where((w) => w.length > 1)
        .map(_stem)
        .toSet();

String _clean(String s) =>
    RegExp(r'[a-z]+').allMatches(s).map((m) => m.group(0)!).where((w) => w.length > 1 && !_drop.contains(w)).join(' ');

/// What to search for, best first: the whole name without brackets, a
/// "Tins:"-style label or amounts ("tea bags"); then without container words
/// ("hydralyte" for "Hydralyte sachets"); then each part of it ("veg and
/// tomatoes" -> "veg", "tomatoes"). At most [limit].
List<String> pictureQueries(String name, {int limit = 3}) {
  var n = name.toLowerCase().replaceAll(RegExp(r'\(.*?(\)|$)'), ' ');
  final colon = n.indexOf(':');
  if (colon >= 0) n = n.substring(colon + 1);
  n = n.replaceAll(RegExp(r'\b\d+(\.\d+)?\s*(kg|g|l|ml|m|cm|mm)?\b'), ' ');
  final out = <String>[];
  final whole = RegExp(r'[a-z]+')
      .allMatches(n)
      .map((m) => m.group(0)!)
      .where((w) => w.length > 1 && !const {'and', 'or', 'of', 'for', 'with', 'the'}.contains(w))
      .join(' ');
  if (whole.isNotEmpty) out.add(whole);
  final full = _clean(n);
  if (full.isNotEmpty && !out.contains(full)) out.add(full);
  for (final part in n.split(RegExp(r'\band\b|/|,|\+'))) {
    final c = _clean(part);
    if (c.isNotEmpty && !out.contains(c)) out.add(c);
  }
  return out.take(limit).toList();
}

/// Words in product names that are amounts or packaging, not the product.
const _notHead = {'ml', 'kg', 'gm', 'ltr', 'pack', 'pk', 'tin', 'can', 'bottle', 'jar', 'bag', 'box', 'value'};

/// The word a name is about: its last real word ("Sugar free V" is about
/// "v", not sugar; "Pauls UHT milk 200 ml" is about milk).
String? _head(String text) {
  final ws = RegExp(r'[a-z]+')
      .allMatches(text.toLowerCase())
      .map((m) => m.group(0)!)
      .where((w) => w.length > 1 && !_notHead.contains(w))
      .toList();
  return ws.isEmpty ? null : _stem(ws.last);
}

/// The product to take a picture from: one with a picture whose name holds
/// every word searched for AND is about the same thing (the same last word:
/// "fish" does not take "Fish fingers"), the shortest such name winning
/// ("Rolled Oats" over "Rolled Oats with Honey"). Null when none can be
/// trusted.
ProductInfo? bestPictureMatch(String query, List<ProductInfo> found) {
  final want = _words(query);
  final head = _head(query);
  if (want.isEmpty || head == null) return null;
  ProductInfo? best;
  var bestLen = 1 << 30;
  for (final p in found) {
    if (p.imageUrl == null) continue;
    final name = p.name.isEmpty ? p.displayName : p.name;
    final have = _words(name);
    if (!have.containsAll(want) || _head(name) != head) continue;
    if (have.length < bestLen) {
      best = p;
      bestLen = have.length;
    }
  }
  return best;
}
