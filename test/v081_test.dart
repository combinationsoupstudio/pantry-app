import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_app/logic/receipt_parse.dart';

void main() {
  test('a normal photo is read whole', () {
    expect(receiptSpans(3000, 4000), [(0, 4000)]);
  });

  test('a tall e-receipt is cut into overlapping sections that cover it all', () {
    final spans = receiptSpans(1080, 8000);
    expect(spans.length, greaterThan(3));
    expect(spans.first.$1, 0);
    expect(spans.last.$1 + spans.last.$2, 8000, reason: 'reaches the bottom');
    for (var i = 1; i < spans.length; i++) {
      final prevEnd = spans[i - 1].$1 + spans[i - 1].$2;
      expect(spans[i].$1, lessThan(prevEnd), reason: 'sections overlap');
    }
  });

  test('every line is kept exactly once, even in the overlaps', () {
    final spans = receiptSpans(1080, 8000);
    for (var y = 0.0; y < 8000; y += 7) {
      final inSpans = [
        for (var i = 0; i < spans.length; i++)
          if (y >= spans[i].$1 && y < spans[i].$1 + spans[i].$2) i,
      ];
      final kept = inSpans.where((i) => keepInSpan(y, i, spans)).length;
      expect(kept, 1, reason: 'line at $y');
    }
  });

  test('a long e-receipt read in sections parses like one read whole', () {
    // Rows as the sections would give them, with the overlap row dropped once.
    final r = parseReceipt(const [
      'Woolworths',
      'Tax Invoice 16/11/2026',
      'Bananas Cavendish',
      '0.862 kg @ \$4.90/kg   \$4.22',
      'Woolworths Full Cream Milk 3L   \$5.60',
      'Qty 2 @ \$2.80 each',
      'Total   \$9.82',
    ]);
    expect(r.lines.map((l) => l.toString()), [
      'Bananas Cavendish x0.862kg = 4.22',
      'Woolworths Full Cream Milk 3L x2 = 5.60',
    ]);
    expect(r.addsUp, isTrue);
  });
}
