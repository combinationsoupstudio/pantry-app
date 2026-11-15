/// A small, strict CSV reader for stock lists. Columns, in order:
/// name, location, quantity, unit, target. A header row is optional.
library;

class StockCsvRow {
  const StockCsvRow({
    required this.name,
    required this.location,
    required this.quantity,
    required this.unit,
    required this.target,
  });

  final String name;
  final String location;
  final double quantity;
  final String unit;
  final double target;
}

class ParsedStockCsv {
  const ParsedStockCsv(this.rows, this.skipped);
  final List<StockCsvRow> rows;

  /// Lines that had content but could not be read.
  final int skipped;
}

ParsedStockCsv parseStockCsv(String text) {
  final rows = <StockCsvRow>[];
  var skipped = 0;
  var first = true;
  for (final rawLine in text.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final cells = splitCsvLine(line).map((c) => c.trim()).toList();
    if (first) {
      first = false;
      if (cells.isNotEmpty && cells.first.toLowerCase() == 'name') continue;
    }
    if (cells.length < 2 || cells[0].isEmpty) {
      skipped++;
      continue;
    }
    final quantity = cells.length > 2 ? _number(cells[2]) : 0.0;
    final target = cells.length > 4 ? _number(cells[4]) : 0.0;
    if (quantity == null || target == null) {
      skipped++;
      continue;
    }
    rows.add(
      StockCsvRow(
        name: cells[0],
        location: cells[1].isEmpty ? 'Pantry' : cells[1],
        quantity: quantity,
        unit: cells.length > 3 ? cells[3] : '',
        target: target,
      ),
    );
  }
  return ParsedStockCsv(rows, skipped);
}

double? _number(String cell) {
  if (cell.isEmpty) return 0;
  final value = double.tryParse(cell);
  if (value == null || value < 0) return null;
  return value;
}

/// Splits one CSV line, honouring double-quoted cells ("a, b" and "" escapes).
List<String> splitCsvLine(String line) {
  final cells = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == ',') {
      cells.add(cell.toString());
      cell.clear();
    } else {
      cell.write(ch);
    }
  }
  cells.add(cell.toString());
  return cells;
}

String csvEscape(String value) {
  if (value.contains(RegExp(r'[",\n]'))) return '"${value.replaceAll('"', '""')}"';
  return value;
}
