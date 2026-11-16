/// Reading the amount at the start of a recipe line, and converting it to
/// the unit a stock item is kept in.
library;

class Amount {
  const Amount(this.quantity, this.unit);
  final double quantity;

  /// Normalised: g, kg, ml, l, or '' for a count.
  final String unit;
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
  final unit =
      _unitWords[word] ?? (word.length <= 5 && const {'cup', 'cups', 'tbsp', 'tsp'}.contains(word) ? word : '');
  return Amount(qty, unit);
}

/// [amount] in the stock item's [stockUnit], or null if they do not convert
/// (e.g. cups into kg, or grams into "tins").
double? convertTo(Amount amount, String stockUnit) {
  final to = _unitWords[stockUnit.trim().toLowerCase()] ?? stockUnit.trim().toLowerCase();
  final from = amount.unit;
  const counts = {'', 'items', 'item', 'each', 'eggs', 'pcs', 'pieces'};
  if (from.isEmpty) return counts.contains(to) || !_unitWords.containsValue(to) ? amount.quantity : null;
  if (from == to) return amount.quantity;
  const factor = {'g>kg': 0.001, 'kg>g': 1000.0, 'ml>l': 0.001, 'l>ml': 1000.0};
  final f = factor['$from>$to'];
  return f == null ? null : amount.quantity * f;
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
