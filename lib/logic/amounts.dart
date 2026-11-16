/// Reading the amount at the start of a recipe line, and converting it to
/// the unit a stock item is kept in.
library;

import '../models/models.dart';

class Amount {
  const Amount(this.quantity, this.unit);
  final double quantity;

  /// Normalised: g, kg, ml, l, cup, tbsp, tsp, or '' for a count.
  final String unit;
}

/// Australian kitchen measures in millilitres (a metric cup is 250 ml and
/// an Australian tablespoon 20 ml), and grams for weights.
const _toBase = {
  'ml': ('v', 1.0),
  'l': ('v', 1000.0),
  'cup': ('v', 250.0),
  'tbsp': ('v', 20.0),
  'tsp': ('v', 5.0),
  'g': ('w', 1.0),
  'kg': ('w', 1000.0),
};

/// The units a measured item can be kept in.
const keptMeasures = ['ml', 'L', 'g', 'kg'];

/// "mL", "Litres", "tablespoons" -> "ml", "l", "tbsp". Anything else comes
/// back lower-cased and trimmed.
String normaliseUnit(String unit) {
  final u = unit.trim().toLowerCase();
  return _unitWords[u] ?? u;
}

/// True for g, kg, ml and L: units an amount can be measured out of.
bool isMeasureUnit(String unit) => const {'g', 'kg', 'ml', 'l'}.contains(normaliseUnit(unit));

/// The units a measured item's use can be entered in: every volume measure
/// for ml/L items, every weight for g/kg items; just its own unit otherwise.
List<String> useUnitsFor(String stockUnit) {
  final kind = _toBase[normaliseUnit(stockUnit)]?.$1;
  if (kind == 'v') return const ['ml', 'L', 'cup', 'tbsp', 'tsp'];
  if (kind == 'w') return const ['g', 'kg'];
  return [stockUnit];
}

/// [quantity] of [from] in [to], or null when they do not convert
/// (weight into volume, or anything into a count).
double? convertUnits(double quantity, String from, String to) {
  final f = normaliseUnit(from);
  final t = normaliseUnit(to);
  if (f == t) return quantity;
  final a = _toBase[f];
  final b = _toBase[t];
  if (a == null || b == null || a.$1 != b.$1) return null;
  return quantity * a.$2 / b.$2;
}

const _fractions = {'¼': 0.25, '½': 0.5, '¾': 0.75, '⅓': 1 / 3, '⅔': 2 / 3, '⅛': 0.125};

const _unitWords = {
  'g': 'g',
  'gram': 'g',
  'grams': 'g',
  'gm': 'g',
  'kg': 'kg',
  'kilo': 'kg',
  'kilos': 'kg',
  'kilogram': 'kg',
  'kilograms': 'kg',
  'ml': 'ml',
  'millilitre': 'ml',
  'millilitres': 'ml',
  'milliliter': 'ml',
  'milliliters': 'ml',
  'l': 'l',
  'litre': 'l',
  'litres': 'l',
  'liter': 'l',
  'liters': 'l',
  'cup': 'cup',
  'cups': 'cup',
  'tbsp': 'tbsp',
  'tbs': 'tbsp',
  'tablespoon': 'tbsp',
  'tablespoons': 'tbsp',
  'tsp': 'tsp',
  'teaspoon': 'tsp',
  'teaspoons': 'tsp',
};

/// "2 eggs" -> 2 (count); "500 g pasta" -> 500 g; "1 1/2 kg" -> 1.5 kg;
/// "½ cup rice" -> 0.5 cup (unit "cup" is kept as written). Null if the line
/// does not start with an amount.
Amount? parseAmount(String line) {
  final m = RegExp(r'^\s*(\d+(?:\.\d+)?)?\s*(\d+\s*/\s*\d+|[¼½¾⅓⅔⅛])?\s*([a-zA-Z]+)?').firstMatch(line);
  if (m == null) return null;
  var qty = 0.0;
  if (m.group(1) != null) qty += double.parse(m.group(1)!);
  final frac = m.group(2);
  if (frac != null) {
    if (_fractions.containsKey(frac)) {
      qty += _fractions[frac]!;
    } else {
      final parts = frac.split('/').map((p) => double.parse(p.trim())).toList();
      if (parts[1] != 0) qty += parts[0] / parts[1];
    }
  }
  if (qty == 0) return null;
  final word = (m.group(3) ?? '').toLowerCase();
  return Amount(qty, _unitWords[word] ?? '');
}

/// [amount] in the stock item's [stockUnit], or null if they do not convert
/// (e.g. cups into kg, or grams into "tins"). Cups, tablespoons and
/// teaspoons convert into ml and L.
double? convertTo(Amount amount, String stockUnit) {
  final to = normaliseUnit(stockUnit);
  final from = amount.unit;
  if (from.isEmpty) return _toBase.containsKey(to) ? null : amount.quantity;
  return convertUnits(amount.quantity, from, to);
}

/// "300 ml", "1.5 kg", "2 tbsp".
String formatMeasure(double quantity, String unit) {
  final u = normaliseUnit(unit) == 'l' ? 'L' : unit.trim();
  return u.isEmpty ? formatQty(quantity) : '${formatQty(quantity)} $u';
}

/// How much of a stock item one recipe line uses: the converted amount, or
/// one of whatever the item is counted in when it cannot be worked out.
double amountToUse(String recipeLine, String stockUnit) {
  final a = parseAmount(recipeLine);
  if (a == null) return 1;
  final v = convertTo(a, stockUnit);
  if (v == null || v <= 0) return 1;
  return double.parse(v.toStringAsFixed(3));
}
