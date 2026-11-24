import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/data/storage_backend.dart';
import 'package:pantry_app/data/store_scope.dart';
import 'package:pantry_app/models/models.dart';
import 'package:pantry_app/ui/theme.dart';
import 'package:pantry_app/ui/widgets/item_sheets.dart';

// v0.18 (#37): one product bought as several lots, each to its own place
// with its own date.

final today = DateTime(2026, 11, 24, 9);

Future<HouseholdStore> newStore() async {
  final s = HouseholdStore(MemoryBackend(), clock: () => today);
  await s.load();
  return s;
}

void main() {
  group('the store', () {
    test('two places, two dates: an item in each, the dates follow the stock', () async {
      final s = await newStore();
      final ids = await s.addLots(
        name: 'Tinned tomatoes',
        unit: 'tins',
        target: 2,
        lots: [
          StockLot(locationId: 'pantry', amount: 2, date: DateTime(2027, 5, 1), kind: DateKind.bestBefore),
          StockLot(locationId: 'prep', amount: 4, date: DateTime(2027, 8, 1), kind: DateKind.bestBefore),
        ],
      );
      expect(ids.length, 2);
      final pantry = s.item(ids[0])!;
      final prep = s.item(ids[1])!;
      expect((pantry.locationId, pantry.quantity, pantry.target), ('pantry', 2.0, 2.0));
      expect((prep.locationId, prep.quantity, prep.target), ('prep', 4.0, 0.0), reason: 'the target sits on one place');
      expect(pantry.batches.single.useBy, DateTime(2027, 5, 1));
      expect(prep.batches.single.useBy, DateTime(2027, 8, 1));
      expect(prep.batches.single.kind, DateKind.bestBefore);
      expect(s.activity.where((a) => a.itemName == 'Tinned tomatoes').length, 2, reason: 'one line per place');
    });

    test('two lots in the same place make one item with two batches', () async {
      final s = await newStore();
      final ids = await s.addLots(
        name: 'Yoghurt',
        lots: [
          StockLot(locationId: 'fridge', amount: 1, date: DateTime(2026, 11, 28)),
          StockLot(locationId: 'fridge', amount: 2, date: DateTime(2026, 12, 3)),
          const StockLot(locationId: 'fridge', amount: 1),
        ],
      );
      expect(ids.length, 1);
      final y = s.item(ids.single)!;
      expect(y.quantity, 4);
      expect(y.batches.map((b) => b.amount), [1, 2]);
      expect(y.undatedAmount, 1);
    });

    test('a place that already holds it is topped up, never a twin', () async {
      final s = await newStore();
      final had = await s.addItem(name: 'Baked beans', locationId: 'prep', quantity: 3);
      final ids = await s.addLots(
        name: 'baked beans',
        lots: [
          StockLot(locationId: 'prep', amount: 2, date: DateTime(2027, 3, 1)),
          StockLot(locationId: 'pantry', amount: 1, date: DateTime(2027, 1, 1)),
        ],
        intoItemId: had.id,
      );
      expect(ids.first, had.id);
      expect(s.item(had.id)!.quantity, 5);
      expect(s.items.where((i) => i.name == 'Baked beans').length, 2);
      expect(s.item(ids.last)!.name, 'Baked beans', reason: 'the kept name wins');
    });

    test('empty lots and unknown places are skipped', () async {
      final s = await newStore();
      final ids = await s.addLots(
        name: 'Rice',
        lots: const [
          StockLot(locationId: 'pantry', amount: 0),
          StockLot(locationId: 'nowhere', amount: 2),
        ],
      );
      expect(ids, isEmpty);
      expect(s.items.where((i) => i.name == 'Rice'), isEmpty);
    });
  });

  testWidgets('on the phone: split into lots, each to its place', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final s = await newStore();
    await tester.pumpWidget(
      StoreScope(
        store: s,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showItemEditor(context, locationId: 'pantry'),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('field-name')), 'Coconut milk');
    await tester.enterText(find.byKey(const ValueKey('field-qty')), '3');
    final split = find.byKey(const ValueKey('split-lots'));
    await tester.scrollUntilVisible(split, 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(split);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lot-amount-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('lot-amount-1')), findsOneWidget);
    expect(find.text('3'), findsOneWidget, reason: 'the lots (2 + 1) add up to what was typed');
    final save = find.byKey(const ValueKey('save-item'));
    await tester.scrollUntilVisible(save, 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final kept = s.items.where((i) => i.name == 'Coconut milk').toList();
    expect(kept.map((i) => (i.locationId, i.quantity)).toSet(), {('pantry', 2.0), ('prep', 1.0)});
  });
}
