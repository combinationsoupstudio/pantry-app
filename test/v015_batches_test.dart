import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/data/storage_backend.dart';
import 'package:pantry_app/data/store_scope.dart';
import 'package:pantry_app/logic/supplies.dart';
import 'package:pantry_app/models/models.dart';
import 'package:pantry_app/ui/pages/dates_page.dart';
import 'package:pantry_app/ui/theme.dart';
import 'package:pantry_app/ui/widgets/item_sheets.dart';

// v0.15: use-by batches. Some of an item can carry one date and some
// another; using stock always takes the soonest first ("eat me first"); a
// top-up of something that has kept before gets a guessed date for free.

final today = DateTime(2026, 11, 18, 9); // a Wednesday

Future<HouseholdStore> newStore() async {
  final s = HouseholdStore(MemoryBackend(), clock: () => today);
  await s.load();
  return s;
}

StockBatch b(double amount, int day, {bool guessed = false}) =>
    StockBatch(amount: amount, useBy: DateTime(2026, 11, day), guessed: guessed);

void main() {
  group('the batches themselves', () {
    test('tidied: soonest first, one per date, nothing empty, never more than there is', () {
      final n = normaliseBatches([b(1, 25), b(2, 20), b(0, 21), b(1, 20, guessed: true)], 10);
      expect(n, [b(3, 20), b(1, 25)], reason: 'a guess merged with a checked date is checked');
      expect(normaliseBatches([b(2, 20), b(2, 25)], 3), [b(1, 20), b(2, 25)], reason: 'the soonest went first');
      expect(normaliseBatches([b(2, 20)], 0), isEmpty);
    });

    test('taking stock takes the soonest first, splitting a batch when it must', () {
      final (left, taken) = takeSoonest([b(2, 20), b(3, 25)], 3);
      expect(left, [b(2, 25)]);
      expect(taken, [b(2, 20), b(1, 25)]);
      expect(takeSoonest([b(1, 20)], 5).$1, isEmpty);
    });

    test('an old one-date item reads as one batch of all of it, and writes the soonest date back', () {
      final old = StockItem.fromJson({
        'id': 'x',
        'name': 'Milk',
        'locationId': 'fridge',
        'quantity': 2,
        'useBy': DateTime(2026, 11, 20).toIso8601String(),
        'updatedAt': today.toIso8601String(),
      });
      expect(old.batches, [b(2, 20)]);
      final two = old.copyWith(batches: [b(1, 20), b(1, 27, guessed: true)], keepDays: 9);
      final back = StockItem.fromJson(two.toJson());
      expect(back.batches, two.batches);
      expect(back.keepDays, 9);
      expect(
        two.toJson()['useBy'],
        DateTime(2026, 11, 20).toIso8601String(),
        reason: 'an older phone sees the soonest',
      );
    });

    test('less of it takes the soonest; more of it is undated; the old single date still sets all of it', () {
      final i = StockItem.fromJson({
        'id': 'x',
        'name': 'Yoghurt',
        'locationId': 'fridge',
        'quantity': 4,
        'updatedAt': today.toIso8601String(),
      }).copyWith(batches: [b(2, 20), b(2, 27)]);
      expect(i.copyWith(quantity: 3).batches, [b(1, 20), b(2, 27)]);
      final more = i.copyWith(quantity: 6);
      expect(more.batches, i.batches);
      expect(more.undatedAmount, 2);
      expect(i.copyWith(useBy: DateTime(2026, 12, 1)).batches, [b(4, 1).copyWith(useBy: DateTime(2026, 12, 1))]);
      expect(i.copyWith(useBy: DateTime(2026, 11, 20)).batches, i.batches, reason: 'same date as showing: kept');
      expect(i.copyWith(clearUseBy: true).batches, isEmpty);
      expect(i.useBy, DateTime(2026, 11, 20));
    });
  });

  group('in the store', () {
    test('using some, cooking and counting all take the soonest first', () async {
      final s = await newStore();
      final y = await s.addItem(name: 'Yoghurt', locationId: 'fridge', quantity: 4);
      await s.setBatches(y.id, [b(2, 20), b(2, 27)]);
      await s.adjust(y.id, -1);
      expect(s.item(y.id)!.batches, [b(1, 20), b(2, 27)]);
      await s.cook('Smoothie', {y.id: 2});
      expect(s.item(y.id)!.batches, [b(1, 27)]);
      await s.countItem(y.id, 0);
      expect(s.item(y.id)!.batches, isEmpty);
    });

    test('dating some learns how long it keeps; the next top-up gets a guess', () async {
      final s = await newStore();
      final m = await s.addItem(name: 'Milk', locationId: 'fridge', quantity: 2);
      expect(m.keepDays, 0);
      await s.adjust(m.id, 1);
      expect(s.item(m.id)!.batches, isEmpty, reason: 'never dated: a top-up stays undated, no nagging');
      await s.dateStock(m.id, 2, DateTime(2026, 11, 25));
      expect(s.item(m.id)!.batches, [b(2, 25)]);
      expect(s.item(m.id)!.keepDays, 7);
      expect(s.item(m.id)!.undatedAmount, 1);
      await s.addPack(m.id);
      expect(s.item(m.id)!.batches, [b(3, 25)], reason: 'the guess lands on the same day and merges; checked wins');
    });

    test('a new item with a date learns its keep; a bought top-up from a receipt or the list is guessed', () async {
      final s = await newStore();
      final bread = await s.addItem(name: 'Bread', locationId: 'pantry', quantity: 1, useBy: DateTime(2026, 11, 23));
      expect(bread.keepDays, 5);
      await s.recordReceipt(
        store: Store.woolworths,
        at: today,
        lines: [ReceiptEntry(name: 'Bread', total: 4, stockItemId: bread.id)],
      );
      expect(s.item(bread.id)!.batches, [b(2, 23)]);
      await s.addShopping(name: 'Bread', quantity: 1, stockItemId: bread.id);
      final line = s.shopping.firstWhere((l) => l.stockItemId == bread.id);
      await s.setBought(line.id, true);
      await s.putAwayBought();
      expect(s.item(bread.id)!.quantity, 3);
      expect(s.item(bread.id)!.datedAmount, 3);
    });

    test('moving stock takes its dates with it, soonest first', () async {
      final s = await newStore();
      final mince = await s.addItem(name: 'Mince', locationId: 'fridge', quantity: 3, unit: 'kg');
      await s.setBatches(mince.id, [b(1, 19), b(2, 22)]);
      await s.move(mince.id, 'freezer', 2);
      final frozen = s.items.firstWhere((i) => i.locationId == 'freezer' && i.name == 'Mince');
      expect(frozen.batches, [b(1, 19), b(1, 22)]);
      expect(s.item(mince.id)!.batches, [b(1, 22)]);
    });

    test('the dates page lists each batch; the row hint names the soonest', () async {
      final s = await newStore();
      final y = await s.addItem(name: 'Yoghurt', locationId: 'fridge', quantity: 4);
      await s.setBatches(y.id, [b(2, 20), b(2, 30, guessed: true)]);
      final lots = lotsByUseBy(s.items, today);
      expect(lots[DateGroup.week]!.single.$2, b(2, 20));
      expect(lots.values.expand((l) => l).length, 2);
      String n(double a) => formatQty(a);
      expect(eatFirstHint(s.item(y.id)!, today, n), 'eat 2 by Fri');
      final past = s.item(y.id)!.copyWith(batches: [b(1, 17)]);
      expect(eatFirstHint(past, today, n), '1 past date');
      final far = s.item(y.id)!.copyWith(batches: [b(1, 30)]);
      expect(eatFirstHint(far, today, n), isNull);
      final soonGuess = s.item(y.id)!.copyWith(batches: [b(1, 19, guessed: true)]);
      expect(eatFirstHint(soonGuess, today, n), 'eat 1 tomorrow?');
    });
  });

  group('on the phone', () {
    Future<void> open(WidgetTester tester, HouseholdStore s, Widget child) async {
      // Wider than a phone: the test font's square letters run wider than
      // the real ones (the real-font screens are in tool/screens).
      tester.view.physicalSize = const Size(1300, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        StoreScope(
          store: s,
          child: MaterialApp(theme: buildTheme(Brightness.light), home: child),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the editor shows each batch, soonest marked, and dates the rest in two taps', (tester) async {
      final s = await newStore();
      final y = await s.addItem(name: 'Yoghurt', locationId: 'fridge', quantity: 5);
      await s.setBatches(y.id, [b(2, 20), b(1, 27, guessed: true)]);
      await open(
        tester,
        s,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showItemEditor(context, existing: s.item(y.id)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final batch0 = find.byKey(const ValueKey('batch-0'));
      await tester.scrollUntilVisible(batch0, 200, scrollable: find.byType(Scrollable).last);
      expect(find.textContaining('use by 20/11/2026'), findsOneWidget);
      expect(find.text('Use these first'), findsOneWidget);
      expect(find.textContaining('about 27/11/2026'), findsOneWidget);
      expect(find.textContaining('with no date'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('batch-date-some')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('date-some-+2 weeks')));
      await tester.pumpAndSettle();
      expect(find.textContaining('with no date'), findsNothing);
      final save = find.byKey(const ValueKey('save-item'));
      await tester.scrollUntilVisible(save, 200, scrollable: find.byType(Scrollable).last);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(s.item(y.id)!.batches.take(2), [b(2, 20), b(1, 27, guessed: true)]);
      expect(s.item(y.id)!.datedAmount, 5);
      expect(s.item(y.id)!.keepDays, 14, reason: 'two weeks, learned for next time');
    });

    testWidgets('the dates page shows one row per batch, guesses marked', (tester) async {
      final s = await newStore();
      final y = await s.addItem(name: 'Yoghurt', locationId: 'fridge', quantity: 4);
      await s.setBatches(y.id, [b(2, 20), b(2, 30, guessed: true)]);
      await open(tester, s, const DatesPage());
      expect(find.byKey(ValueKey('date-${y.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('date-${y.id}-1')), findsOneWidget);
      expect(find.textContaining('2 of 4'), findsNWidgets(2));
      expect(find.textContaining('guessed'), findsOneWidget);
    });
  });
}
