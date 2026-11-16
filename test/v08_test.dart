import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/data/storage_backend.dart';
import 'package:pantry_app/data/store_scope.dart';
import 'package:pantry_app/ui/pages/receipt_page.dart';
import 'package:pantry_app/ui/theme.dart';
import 'package:pantry_app/logic/receipt_parse.dart';
import 'package:pantry_app/models/models.dart';

/// A Woolworths-style receipt, as rows the reader joins up.
const woolies = [
  'Woolworths',
  'Batemans Bay',
  'ABN 88 000 014 675',
  'TAX INVOICE',
  '16/11/26 10:42',
  'WW FREE RANGE EGGS 12PK 700G   6.50',
  'KIKKOMAN SOY SAUCE 600ML   5.20',
  'WW DICED TOMATOES 400G',
  'QTY 3 @ \$1.10 EACH   3.30',
  'POTATOES WASHED LOOSE',
  '1.250 kg NET @ \$3.50/kg   4.38',
  'CADBURY DAIRY MILK 180G   6.00',
  'Promotional Price   -1.50',
  '5 SUBTOTAL   23.88',
  'TOTAL   \$23.88',
  'EFTPOS   23.88',
  'GST included in total   0.64',
];

void main() {
  group('reading a receipt', () {
    test('shop, date, lines with quantities and discounts, and a total that adds up', () {
      final r = parseReceipt(woolies);
      expect(r.store, Store.woolworths);
      expect(r.date, DateTime(2026, 11, 16));
      expect(r.total, 23.88);
      expect(r.lines.map((l) => l.toString()), [
        'WW FREE RANGE EGGS 12PK 700G x1 = 6.50',
        'KIKKOMAN SOY SAUCE 600ML x1 = 5.20',
        'WW DICED TOMATOES 400G x3 = 3.30',
        'POTATOES WASHED LOOSE x1.25kg = 4.38',
        'CADBURY DAIRY MILK 180G x1 = 4.50',
      ]);
      expect(r.linesTotal, closeTo(23.88, 0.001));
      expect(r.addsUp, isTrue);
    });

    test('description and price in separate pieces are joined by row', () {
      final rows = rowsOf(const [
        TextBox('Coles', top: 0, bottom: 20, left: 100, right: 200),
        TextBox('MILK 2L', top: 100, bottom: 120, left: 10, right: 120),
        TextBox('3.10', top: 102, bottom: 121, left: 400, right: 460),
        TextBox('BREAD WHITE', top: 130, bottom: 150, left: 10, right: 160),
        TextBox('3.50', top: 131, bottom: 149, left: 400, right: 460),
        TextBox('TOTAL', top: 200, bottom: 220, left: 10, right: 80),
        TextBox('6.60', top: 201, bottom: 220, left: 400, right: 460),
      ]);
      expect(rows, ['Coles', 'MILK 2L 3.10', 'BREAD WHITE 3.50', 'TOTAL 6.60']);
      final r = parseReceipt(rows);
      expect((r.store, r.lines.length, r.total, r.addsUp), (Store.coles, 2, 6.6, true));
    });

    test('a misread line shows as not adding up', () {
      final r = parseReceipt(['ALDI', 'MILK 3.10', 'TOTAL 9.99']);
      expect(r.store, Store.aldi);
      expect(r.addsUp, isFalse);
    });

    test('names are tidied for matching and showing', () {
      expect(tidyName('WW FREE RANGE EGGS 12PK 700G'), 'Free range eggs 12pk 700g');
      expect(tidyName('KIKKOMAN SOY SAUCE 600ML'), 'Kikkoman soy sauce 600ml');
      expect(
        [packCount('WW FREE RANGE EGGS 12PK 700G'), packCount('YOGHURT 6 PACK'), packCount('TUNA 4X95G')],
        [12, 6, 4],
      );
      expect(packCount('KIKKOMAN SOY SAUCE 600ML'), isNull);
    });
  });

  Future<HouseholdStore> newStore() async {
    final s = HouseholdStore(MemoryBackend(), clock: () => DateTime(2026, 11, 16, 17));
    await s.load();
    return s;
  }

  group('saving a receipt', () {
    test('receipt lines find their stock items', () async {
      final s = await newStore();
      final soy = await s.addItem(name: 'Soy sauce', locationId: 'pantry');
      final eggs = await s.addItem(name: 'Eggs', locationId: 'fridge');
      final toms = await s.addItem(name: 'Tins: tomatoes', locationId: 'prep');
      await s.addItem(name: 'Sauce', locationId: 'pantry');
      expect(matchStock('KIKKOMAN SOY SAUCE 600ML', s.items)?.id, soy.id, reason: 'the fuller name wins');
      expect(matchStock('WW FREE RANGE EGGS 12PK', s.items)?.id, eggs.id);
      expect(matchStock('WW DICED TOMATOES 400G', s.items)?.id, toms.id);
      expect(matchStock('CADBURY DAIRY MILK', s.items), isNull);
    });

    test('prices for every line, stock for ticked lines, list lines come off', () async {
      final s = await newStore();
      final soy = await s.addItem(name: 'Soy sauce', locationId: 'pantry', quantity: 100, unit: 'ml', packSize: 600);
      final spuds = await s.addItem(name: 'Potatoes', locationId: 'pantry', quantity: 1, unit: 'kg');
      final toms = await s.addItem(name: 'Tomatoes', locationId: 'prep', quantity: 2, unit: 'tins');
      await s.addShopping(name: 'Soy sauce');
      await s.addShopping(name: 'Bread');
      final n = await s.recordReceipt(
        store: Store.woolworths,
        at: DateTime(2026, 11, 16, 10),
        lines: [
          ReceiptEntry(name: 'Kikkoman soy sauce 600ml', total: 5.2, stockItemId: soy.id),
          ReceiptEntry(name: 'Potatoes washed loose', total: 4.38, quantity: 1.25, unit: 'kg', stockItemId: spuds.id),
          ReceiptEntry(name: 'Diced tomatoes', total: 3.3, quantity: 3, stockItemId: toms.id, toStock: false),
          const ReceiptEntry(name: 'Cadbury dairy milk', total: 4.5),
        ],
      );
      expect(n, 2);
      expect(s.item(soy.id)!.quantity, 700, reason: 'one 600 ml pack');
      expect(s.item(spuds.id)!.quantity, 2.25);
      expect(s.item(toms.id)!.quantity, 2, reason: 'not ticked for stock');
      expect(s.prices.length, 4);
      expect(s.prices.firstWhere((p) => p.stockItemId == toms.id).unitPrice, closeTo(1.1, 1e-9));
      expect(s.shopping.map((l) => l.name), ['Bread'], reason: 'soy sauce was bought');
      expect(s.spendThisWeek(DateTime(2026, 11, 16, 17)).values.fold(0.0, (a, b) => a + b), closeTo(17.38, 1e-9));
    });
  });

  testWidgets('the review page shows the check and saves', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final s = await newStore();
    final eggs = await s.addItem(name: 'Eggs', locationId: 'fridge', quantity: 2, unit: 'items');
    final soy = await s.addItem(name: 'Soy sauce', locationId: 'pantry', quantity: 100, unit: 'ml', packSize: 500);
    final spuds = await s.addItem(name: 'Potatoes', locationId: 'pantry', quantity: 4, unit: 'items');
    await tester.pumpWidget(
      StoreScope(
        store: s,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: ReceiptPage(receipt: parseReceipt(woolies)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lines add to \$23.88: matches the receipt total.'), findsOneWidget);
    expect(find.text('Eggs'), findsOneWidget, reason: 'the eggs line found the stock item');
    await tester.tap(find.byKey(const ValueKey('receipt-save')));
    await tester.pumpAndSettle();
    expect(s.prices.length, 5);
    expect(s.item(eggs.id)!.quantity, 14, reason: '2 + a 12 pack');
    expect(s.item(soy.id)!.quantity, 700, reason: 'the receipt says 600 ml, not the saved 500 ml pack');
    expect(s.item(spuds.id)!.quantity, 4, reason: '1.25 kg cannot become a count; left for a hand count');
  });
}
