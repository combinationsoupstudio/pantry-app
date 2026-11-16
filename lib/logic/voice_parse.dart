/// Turns what was said ("two tins of tomatoes and a dozen eggs, milk") into
/// lines to add: amount, unit and name each. Plain logic, no microphone.
library;

import 'amounts.dart';

class SpokenLine {
  const SpokenLine(this.quantity, this.unit, this.name);
  final double quantity;

  /// A measure (kg, L, tbsp ...) or a counting word said ("tins", "packets"),
  /// or '' for a plain count.
  final String unit;
  final String name;

  @override
  String toString() => '$quantity $unit $name'.replaceAll(RegExp(r'\s+'), ' ').trim();
}

const _numbers = {
  'a': 1, 'an': 1, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7, //
  'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11, 'twelve': 12, 'dozen': 12, 'a dozen': 12, //
  'half a': 0.5, 'half': 0.5, 'couple of': 2, 'a couple of': 2, 'couple': 2, 'a couple': 2,
};

/// Counting words worth keeping as the unit ("2 tins of tomatoes").
const _counters = {
  'tin', 'tins', 'can', 'cans', 'packet', 'packets', 'pack', 'packs', 'bag', 'bags', 'box', 'boxes', //
  'bottle', 'bottles', 'jar', 'jars', 'loaf', 'loaves', 'bunch', 'bunches', 'carton', 'cartons', 'dozen',
};

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// The lines in [heard]. Splits on "and", commas and "then"; reads number
/// words and digits; drops "of", "some" and "please".
List<SpokenLine> parseSpoken(String heard) {
  final t = heard.toLowerCase().replaceAll(RegExp(r'[.!?]'), ' ');
  final out = <SpokenLine>[];
  for (var part in t.split(RegExp(r',|\band then\b|\bthen\b|\band\b|\bplus\b'))) {
    part = part.replaceAll(RegExp(r'\b(please|some|add|get|we need|i need|need)\b'), ' ').trim();
    if (part.isEmpty) continue;
    var qty = 1.0;
    // Longest number phrase first ("a dozen" before "a").
    final phrases = _numbers.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final p in phrases) {
      if (part == p || part.startsWith('$p ')) {
        qty = _numbers[p]!.toDouble();
        part = part.substring(p.length).trim();
        break;
      }
    }
    final a = parseAmount(part);
    var unit = '';
    var name = part;
    if (a != null) {
      qty = a.quantity * (qty == 1 ? 1 : qty);
      unit = a.unit;
      name = part.replaceFirst(RegExp(r'^[\d.,/½¼¾⅓⅔ ]+'), '').trim();
      if (unit.isNotEmpty) name = name.replaceFirst(RegExp(r'^[a-z]+\b'), '').trim();
    } else {
      // "kilo of rice", "litre of milk" after a number word
      final m = RegExp(r'^(kilos?|kilograms?|grams?|litres?|liters?|millilitres?|cups?|tablespoons?|teaspoons?)\b')
          .firstMatch(name);
      if (m != null) {
        final w = m.group(1)!;
        unit = w.startsWith('kilo') ? 'kg' : normaliseUnit(w);
        name = name.substring(m.end).trim();
      }
    }
    final first = RegExp(r'^([a-z]+)\b').firstMatch(name)?.group(1);
    if (unit.isEmpty && first != null && _counters.contains(first)) {
      unit = first == 'dozen' ? '' : first;
      if (first == 'dozen') qty *= 12;
      name = name.substring(first.length).trim();
    }
    name = name.replaceFirst(RegExp(r'^of\b'), '').trim();
    if (name.isEmpty) continue;
    out.add(SpokenLine(double.parse(qty.toStringAsFixed(3)), unit, _cap(name)));
  }
  return out;
}
