import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pantry_app/app.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/data/storage_backend.dart';
import 'package:pantry_app/logic/amounts.dart';
import 'package:pantry_app/logic/usage.dart';
import 'package:pantry_app/models/models.dart';

void main() {
  group('amounts', () {
    test('parses counts, weights, fractions and unicode fractions', () {
      Amount a(String s) => parseAmount(s)!;
      expect((a('2 eggs').quantity, a('2 eggs').unit), (2.0, ''));
      expect((a('500 g pasta').quantity, a('500 g pasta').unit), (500.0, 'g'));
      expect(a('500g pasta').unit, 'g');
      expect(a('1 1/2 kg potatoes').quantity, 1.5);
      expect(a('½ cup rice').quantity, 0.5);
      expect(a('½ cup rice').unit, 'cup');
      expect(parseAmount('Salt and pepper'), isNull);
    });

    test('converts to the stock unit where it can, else one', () {
      expect(amountToUse('500 g pasta', 'kg'), 0.5);
      expect(amountToUse('2 eggs', 'items'), 2);
      expect(amountToUse('2 eggs', ''), 2);
      expect(amountToUse('250 ml milk', 'L'), 0.25);
      expect(amountToUse('1 cup rice', 'kg'), 1, reason: 'cups do not convert to kg');
      expect(amountToUse('200 g cheese', 'blocks'), 1);
      expect(amountToUse('Salt', 'kg'), 1);
    });
  });

  group('usage', () {
    final now = DateTime(2026, 11, 30);
    ActivityEntry used(String name, double amount, int daysAgo) => ActivityEntry(
      at: now.subtract(Duration(days: daysAgo)),
      who: 'Chris',
      itemName: name,
      action: 'used',
      delta: -amount,
    );
    StockItem item(String name, double qty) => StockItem(
      id: name,
      name: name,
      locationId: 'pantry',
      quantity: qty,
      unit: 'L',
      target: 0,
      updatedAt: now,
      updatedBy: 'Chris',
    );

    test('rate over the window, matched by name', () {
      final rates = usePerDay([used('Milk', 6, 2), used('milk ', 6, 20), used('Milk', 99, 45)], now);
      // First seen 45 days ago, so the whole 30-day window counts: 12 L / 30 days.
      expect(rates['milk'], closeTo(12 / 30, 0.01));
      expect(daysLeft(item('Milk', 6), rates), closeTo(15, 0.2));
      // Seen for only 20 days: the span is 20 days.
      expect(usePerDay([used('Oats', 6, 2), used('Oats', 6, 20)], now)['oats'], closeTo(12 / 20, 0.01));
    });

    test('a single early burst is spread over at least three days', () {
      final rates = usePerDay([used('Rice', 3, 0)], now);
      expect(rates['rice'], closeTo(1, 0.01));
    });

    test('not used, or already out: no estimate', () {
      final rates = usePerDay([used('Milk', 2, 1)], now);
      expect(daysLeft(item('Bread', 3), rates), isNull);
      expect(daysLeft(item('Milk', 0), rates), isNull);
    });

    test('describes days plainly', () {
      expect(describeDays(0.5), 'today');
      expect(describeDays(1.2), '1 day');
      expect(describeDays(6.8), '6 days');
      expect(describeDays(21), '3 weeks');
      expect(describeDays(90), '3 months');
    });
  });

  group('store: prices, spend, cooking, runs out', () {
    var clock = DateTime(2026, 11, 18, 10); // a Wednesday
    late HouseholdStore store;
    setUp(() async {
      clock = DateTime(2026, 11, 18, 10);
      store = HouseholdStore(MemoryBackend(), clock: () => clock);
      await store.load();
    });

    test('prices are kept per shop when a shop is put away; cheapest per unit first', () async {
      final milk = await store.addItem(name: 'UHT milk', locationId: 'prep', quantity: 1, unit: 'L', target: 6);
      await store.addRunningLowToShopping();
      var line = store.shopping.single;
      await store.setStore(line.id, Store.coles);
      await store.setBought(line.id, true);
      await store.putAwayBought(paid: {line.id: 10.0}); // 5 L for $10 = $2/L

      await store.addShopping(name: 'UHT milk', quantity: 2, store: Store.aldi);
      line = store.shopping.single;
      await store.setBought(line.id, true);
      await store.putAwayBought(paid: {line.id: 3.0}); // $1.50/L

      final latest = store.latestByStore(store.item(milk.id)!);
      expect(latest.map((p) => '${p.store.label} ${formatMoney(p.unitPrice)}'), ['Aldi \$1.50', 'Coles \$2.00']);
      expect(store.item(milk.id)!.quantity, 8);
    });

    test('a line with no price records none', () async {
      await store.addShopping(name: 'Bread');
      final line = store.shopping.single;
      await store.setBought(line.id, true);
      await store.putAwayBought();
      expect(store.prices, isEmpty);
    });

    test('spend this week counts from Monday', () async {
      Future<void> buy(String name, Store shop, double paid) async {
        final line = await store.addShopping(name: name, store: shop);
        await store.setBought(line.id, true);
        await store.putAwayBought(paid: {line.id: paid});
      }

      clock = DateTime(2026, 11, 15, 9); // the Sunday before
      await buy('Eggs', Store.iga, 7);
      clock = DateTime(2026, 11, 16, 9); // Monday
      await buy('Bread', Store.woolworths, 4.5);
      clock = DateTime(2026, 11, 18, 9);
      await buy('Milk', Store.woolworths, 3);
      await buy('Cheese', Store.aldi, 6);
      final spend = store.spendThisWeek(DateTime(2026, 11, 18, 12));
      expect(spend[Store.woolworths], 7.5);
      expect(spend[Store.aldi], 6);
      expect(spend.containsKey(Store.iga), isFalse);
    });

    test('cooking takes amounts out, never below zero, and logs uses', () async {
      final pasta = await store.addItem(name: 'Pasta', locationId: 'pantry', quantity: 2, unit: 'kg');
      final eggs = await store.addItem(name: 'Eggs', locationId: 'fridge', quantity: 1, unit: 'items');
      await store.cook('Pasta bake', {pasta.id: 0.5, eggs.id: 3});
      expect(store.item(pasta.id)!.quantity, 1.5);
      expect(store.item(eggs.id)!.quantity, 0);
      expect(store.activity.first.action, 'cooked');
      expect(store.activity.where((a) => a.action == 'used'), hasLength(2));
    });

    test('runs out within a week, from the history', () async {
      final milk = await store.addItem(name: 'Milk', locationId: 'fridge', quantity: 10, unit: 'L');
      await store.addItem(name: 'Salt', locationId: 'pantry', quantity: 1, unit: 'kg');
      clock = DateTime(2026, 11, 8, 10);
      await store.adjust(milk.id, -4);
      clock = DateTime(2026, 11, 18, 10);
      await store.adjust(milk.id, -4); // 8 L over 10 days -> 0.8 L/day; 2 L left -> 2.5 days
      expect(store.runningOutWithin(7).map((i) => i.name), ['Milk']);
      expect(store.daysLeftFor(store.item(milk.id)!), closeTo(2.5, 0.3));
    });
  });

  testWidgets('put away asks for prices; I cooked this takes stock out', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final store = HouseholdStore(MemoryBackend());
    await store.load();
    await store.addItem(name: 'Bread', locationId: 'pantry', quantity: 2, unit: 'loaves');
    await store.addItem(name: 'Baked beans', locationId: 'prep', quantity: 4, unit: 'tins');
    final line = await store.addShopping(name: 'Bread', store: Store.iga);
    await store.setBought(line.id, true);

    await tester.pumpWidget(PantryApp(store: store));
    await tester.tap(find.byKey(const ValueKey('nav-shopping')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('put-away')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(ValueKey('price-${line.id}')), '4.20');
    await tester.tap(find.byKey(const ValueKey('confirm-put-away')));
    await tester.pumpAndSettle();
    expect(store.prices.single.total, 4.2);
    expect(store.prices.single.store, Store.iga);

    await tester.tap(find.byKey(const ValueKey('nav-recipes')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beans on toast'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cooked')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-cook')));
    await tester.pumpAndSettle();
    expect(store.items.firstWhere((i) => i.name == 'Bread').quantity, 2, reason: '3 loaves less 1');
    expect(store.items.firstWhere((i) => i.name == 'Baked beans').quantity, 3);
  });
}
