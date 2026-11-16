/// Reads a supermarket receipt from the text the phone's on-device reader
/// found (Google ML Kit): which shop, the date, each bought line with its
/// price and quantity, and the total. Plain logic: the camera and the text
/// reader live in ui/widgets/receipt_scan.dart. ADR 0009.
library;

import '../models/models.dart';
import 'names.dart';

/// One piece of text the reader found, with where it sits on the photo.
class TextBox {
  const TextBox(this.text, {this.left = 0, this.top = 0, this.right = 0, this.bottom = 0});
  final String text;
  final double left, top, right, bottom;
  double get middle => (top + bottom) / 2;
  double get height => (bottom - top).abs();
}

/// A bought line: what it was, how many, what it cost in total.
class ReceiptLine {
  const ReceiptLine({required this.name, required this.total, this.quantity = 1, this.unit = ''});
  final String name;
  final double total;
  final double quantity;

  /// 'kg' for weighed produce ("1.234 kg @ $3.50/kg"), else ''.
  final String unit;

  @override
  String toString() => '$name x${quantity % 1 == 0 ? quantity.toInt() : quantity}$unit = ${total.toStringAsFixed(2)}';
}

class Receipt {
  const Receipt({required this.store, required this.lines, this.date, this.total});
  final Store store;
  final DateTime? date;

  /// What the receipt says was paid, if it could be read.
  final double? total;
  final List<ReceiptLine> lines;

  /// The lines added up.
  double get linesTotal => lines.fold(0.0, (a, l) => a + l.total);

  /// True when the lines add up to the receipt's total (within a cent or
  /// two of rounding), so nothing was missed or misread.
  bool get addsUp => total != null && (linesTotal - total!).abs() < 0.06;
}

final _price = RegExp(r'-?\$?\s?(\d{1,4}[.,]\d{2})\s*-?\s*[A-Z*#^]{0,2}$');
final _date = RegExp(r'\b(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})\b');
final _qtyAt = RegExp(r'^(?:qty\s*)?(\d+)\s*(?:@|x|at)\s*\$?(\d+[.,]\d{2})', caseSensitive: false);
final _kgAt = RegExp(r'(\d+[.,]\d{1,3})\s*kg\s*(?:net)?\s*@\s*\$?(\d+[.,]\d{2})\s*/\s*kg', caseSensitive: false);
final _skip = RegExp(
  r'\b(sub\s*total|subtotal|total|balance|gst|tax|change|cash|eftpos|visa|mastercard|debit|credit|card|tend|'
  r'rounding|savings?|you saved|promotional|discount|points|rewards|flybuys|everyday|member|abn|tel|phone|'
  r'store|thank|receipt|invoice|items?\s*sold|qty|purchase|approved|auth|ref|account|terminal|surcharge|'
  r'paypass|contactless|ph:)\b',
  caseSensitive: false,
);
final _total = RegExp(r'^(total|balance due|amount due|total payable|total amount)\b', caseSensitive: false);

double _money(String s) => double.parse(s.replaceAll(',', '.'));

/// The shop, from words on the receipt.
Store storeFrom(String text) {
  final t = text.toLowerCase();
  if (t.contains('woolworths') || t.contains('woolies')) return Store.woolworths;
  if (t.contains('coles')) return Store.coles;
  if (t.contains('aldi')) return Store.aldi;
  if (t.contains('iga') || t.contains('supa iga') || t.contains('foodworks')) return Store.iga;
  return Store.any;
}

/// Joins boxes that sit on the same line of the receipt (the reader often
/// returns the description and the price as separate pieces), top to bottom,
/// left to right.
List<String> rowsOf(List<TextBox> boxes) {
  final sorted = [...boxes]..sort((a, b) => a.middle.compareTo(b.middle));
  final rows = <List<TextBox>>[];
  for (final b in sorted) {
    final tol = (b.height <= 0 ? 10 : b.height) * 0.6;
    final row = rows.isEmpty ? null : rows.last;
    if (row != null && (row.first.middle - b.middle).abs() <= tol) {
      row.add(b);
    } else {
      rows.add([b]);
    }
  }
  return [
    for (final r in rows) (r..sort((a, b) => a.left.compareTo(b.left))).map((b) => b.text.trim()).join(' ').trim(),
  ];
}

String _clean(String name) => name
    .replaceAll(RegExp(r'^[\^*#\s]+'), '')
    .replaceAll(RegExp(r'\s{2,}'), ' ')
    .replaceAll(RegExp(r'\s*\$\s*$'), '')
    .trim();

/// Reads a receipt from its rows of text (see [rowsOf]).
Receipt parseReceipt(List<String> rows) {
  final all = rows.join('\n');
  final store = storeFrom(all);

  DateTime? date;
  for (final r in rows) {
    final m = _date.firstMatch(r);
    if (m == null) continue;
    var y = int.parse(m.group(3)!);
    if (y < 100) y += 2000;
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(1)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31 || y < 2020 || y > 2100) continue;
    date = DateTime(y, mo, d);
    break;
  }

  double? total;
  final lines = <ReceiptLine>[];
  String? pending; // a description whose price is on the next row
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i].trim();
    if (row.isEmpty) continue;
    final priceMatch = _price.firstMatch(row);

    if (_total.hasMatch(row) && priceMatch != null) {
      total ??= _money(priceMatch.group(1)!);
      pending = null;
      continue;
    }

    // "2 @ $1.50" or "1.234 kg @ $3.50/kg" under a description: sets its quantity.
    final qty = _qtyAt.firstMatch(row);
    final kg = _kgAt.firstMatch(row);
    if ((qty != null || kg != null) && (lines.isNotEmpty || pending != null)) {
      final q = kg != null ? _money(kg.group(1)!) : double.parse(qty!.group(1)!);
      final unit = kg != null ? 'kg' : '';
      final t = priceMatch != null ? _money(priceMatch.group(1)!) : null;
      if (pending != null && t != null) {
        lines.add(ReceiptLine(name: _clean(pending), total: t, quantity: q, unit: unit));
        pending = null;
      } else if (lines.isNotEmpty) {
        final last = lines.removeLast();
        lines.add(ReceiptLine(name: last.name, total: t ?? last.total, quantity: q, unit: unit));
      }
      continue;
    }

    // A discount ("Promotional Price -1.50") takes money off the line above.
    if (priceMatch != null && RegExp(r'-\s*\$?\s?\d+[.,]\d{2}|\d+[.,]\d{2}\s*-').hasMatch(row)) {
      if (lines.isNotEmpty) {
        final value = _money(priceMatch.group(1)!);
        final last = lines.removeLast();
        lines.add(ReceiptLine(name: last.name, total: last.total - value, quantity: last.quantity, unit: last.unit));
      }
      continue;
    }

    if (_skip.hasMatch(row)) {
      pending = null;
      continue;
    }

    if (priceMatch != null) {
      final name = _clean(row.substring(0, priceMatch.start));
      final value = _money(priceMatch.group(1)!);
      if (name.length >= 2 && RegExp(r'[A-Za-z]{2,}').hasMatch(name)) {
        lines.add(ReceiptLine(name: name, total: value));
      } else if (pending != null) {
        lines.add(ReceiptLine(name: _clean(pending), total: value));
      }
      pending = null;
      continue;
    }

    // Text with no price: maybe a description whose price sits on the next row.
    if (total == null && RegExp(r'[A-Za-z]{3,}').hasMatch(row)) pending = row;
  }

  return Receipt(store: store, date: date, total: total, lines: lines);
}

/// "WW FREE RANGE EGGS 12PK 700G" -> "Free range eggs 12pk 700g": drops shop
/// brand codes and shouting, for matching to stock and showing.
String tidyName(String receiptName) {
  var n = receiptName.replaceAll(RegExp(r'^(ww|woolworths|coles|cs|aldi|iga|macro)\s+', caseSensitive: false), '');
  n = n.toLowerCase().replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  return n.isEmpty ? receiptName : n[0].toUpperCase() + n.substring(1);
}

String _stem(String w) {
  if (w.length > 3 && w.endsWith('ies')) return '${w.substring(0, w.length - 3)}y';
  if (w.length > 3 && w.endsWith('es') && !w.endsWith('ses')) return w.substring(0, w.length - 2);
  if (w.length > 2 && w.endsWith('s') && !w.endsWith('ss')) return w.substring(0, w.length - 1);
  return w;
}

const _filler = {'tin', 'tins', 'can', 'cans', 'pack', 'packs', 'and', 'of', 'the', 'loose', 'fresh', 'x'};

Set<String> _nameWords(String s) {
  var t = s.toLowerCase().replaceAll(RegExp(r'\(.*?(\)|$)'), ' ');
  final colon = t.indexOf(':');
  if (colon >= 0) t = t.substring(colon + 1);
  // Folded as names.dart folds them: "SPRING ONIONS" and Shallots agree.
  return RegExp(r'[a-z]+')
      .allMatches(canonicalName(t))
      .map((m) => m.group(0)!)
      .where((w) => w.length > 1 && !_filler.contains(w))
      .map(_stem)
      .toSet();
}

/// The stock item a receipt line is: every word of the item's name appears in
/// the line ("Soy sauce" in "KIKKOMAN SOY SAUCE 600ML"), the item with the
/// most such words winning. Null when none fits.
StockItem? matchStock(String receiptName, Iterable<StockItem> items) {
  final have = _nameWords(receiptName);
  StockItem? best;
  var bestWords = 0;
  final key = canonicalName(receiptName);
  for (final i in items) {
    if (i.notAliases.any((a) => canonicalName(a) == key)) continue;
    for (final name in [i.name, ...i.aliases]) {
      final want = _nameWords(name);
      if (want.isEmpty || !have.containsAll(want)) continue;
      if (want.length > bestWords) {
        best = i;
        bestWords = want.length;
      }
    }
  }
  return best;
}

/// How many are in one pack, from the name: "EGGS 12PK" -> 12,
/// "YOGHURT 6 PACK" -> 6, "TUNA 4X95G" -> 4. Null when it does not say.
int? packCount(String receiptName) {
  final t = receiptName.toLowerCase();
  final m = RegExp(r'\b(\d{1,3})\s*(?:pk|pack|pce|pcs|x\s*\d)').firstMatch(t);
  if (m == null) return null;
  final n = int.parse(m.group(1)!);
  return n > 1 ? n : null;
}

/// How a tall receipt image (a saved e-receipt is often 1 wide by 6 or more
/// high) is cut into overlapping sections the text reader can read at full
/// size. Each span is (top, height) in pixels; [overlap] pixels are shared
/// with the next span so no line is cut in half everywhere.
List<(int, int)> receiptSpans(int width, int height, {double ratio = 1.6, int? overlap}) {
  final h = (width * ratio).round();
  if (height <= h * 1.25) return [(0, height)];
  final o = overlap ?? (width * 0.15).round();
  final spans = <(int, int)>[];
  var top = 0;
  while (true) {
    if (top + h >= height) {
      spans.add((top, height - top));
      break;
    }
    spans.add((top, h));
    top += h - o;
  }
  return spans;
}

/// Whether a line found in span [i] (its middle at [middle], in whole-image
/// pixels) is kept: each overlap is split down the middle, so a line in both
/// spans is counted once.
bool keepInSpan(double middle, int i, List<(int, int)> spans) {
  final (top, height) = spans[i];
  final lo = i == 0 ? double.negativeInfinity : (top + (spans[i - 1].$1 + spans[i - 1].$2)) / 2;
  final hi = i == spans.length - 1 ? double.infinity : (spans[i + 1].$1 + top + height) / 2;
  return middle >= lo && middle < hi;
}
