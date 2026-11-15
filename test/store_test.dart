import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/data/storage_backend.dart';
import 'package:pantry_app/models/models.dart';

void main() {
  late MemoryBackend backend;
  late HouseholdStore store;
  final clock = DateTime(2026, 11, 15, 9);

  setUp(() async {
    backend = MemoryBackend();
    store = HouseholdStore(backend, clock: () => clock);
    await store.load();
  });

  test('a new household starts with the default locations', () {
    expect(store.locationsOf(LocationKind.pantry).map((l) => l.name), ['Pantry', 'Fridge', 'Freezer']);
    expect(store.locationsOf(LocationKind.storage), hasLength(5));
  });

  test('add, use and top up stock, never below zero, and every change is logged', () async {
    final rice = await store.addItem(name: ' Rice ', locationId: 'pantry', quantity: 2, unit: 'kg', target: 5);
    expect(rice.name, 'Rice');
    expect(store.runningLow.single.id, rice.id);

    await store.adjust(rice.id, -1);
    await store.adjust(rice.id, -5);
    expect(store.item(rice.id)!.quantity, 0);

    await store.adjust(rice.id, -1); // nothing left: no change, no log line
    await store.adjust(rice.id, 6);
    expect(store.item(rice.id)!.quantity, 6);
    expect(store.runningLow, isEmpty);

    expect(store.activity.map((a) => a.action).toList(), ['topped up', 'used', 'used', 'added']);
    expect(store.activity[1].delta, -1); // the second use only took the 1 kg that was left
    expect(store.activity.first.who, 'Chris');
  });

  test('moving stock tops up the same item in the destination', () async {
    final prep = await store.addItem(name: 'Tuna', locationId: 'prep', quantity: 10, unit: 'cans');
    final pantry = await store.addItem(name: 'tuna', locationId: 'pantry', quantity: 1, unit: 'cans', target: 3);

    await store.move(prep.id, 'pantry', 2);
    expect(store.item(prep.id)!.quantity, 8);
    expect(store.item(pantry.id)!.quantity, 3);
    expect(store.items, hasLength(2));
  });

  test('moving to a location without that item creates it there, capped at what we have', () async {
    final soap = await store.addItem(name: 'Soap', locationId: 'garage', quantity: 2, unit: 'bars');
    await store.move(soap.id, 'hygiene', 5);
    expect(store.item(soap.id)!.quantity, 0);
    final moved = store.items.firstWhere((i) => i.locationId == 'hygiene');
    expect(moved.name, 'Soap');
    expect(moved.quantity, 2);
  });

  test('running-low goes on the list once, and putting it away restocks', () async {
    final milk = await store.addItem(name: 'Long life milk', locationId: 'pantry', quantity: 1, unit: 'L', target: 6);
    expect(await store.addRunningLowToShopping(), 1);
    expect(await store.addRunningLowToShopping(), 0);
    final line = store.shopping.single;
    expect(line.quantity, 5);
    expect(line.stockItemId, milk.id);

    await store.setStore(line.id, Store.aldi);
    await store.setBought(line.id, true);
    expect(await store.putAwayBought(), 1);
    expect(store.shopping, isEmpty);
    expect(store.item(milk.id)!.quantity, 6);
    expect(store.activity.first.action, 'bought');
  });

  test('removing an item unlinks it from the shopping list', () async {
    final eggs = await store.addItem(name: 'Eggs', locationId: 'fridge', quantity: 0, target: 12);
    await store.addRunningLowToShopping();
    await store.removeItem(eggs.id);
    expect(store.shopping.single.stockItemId, isNull);
  });

  test('state survives a reload, including who is using the phone', () async {
    await store.setUser('Emily');
    await store.addItem(name: 'Pasta', locationId: 'pantry', quantity: 3, unit: 'packs', target: 4);
    await store.addShopping(name: 'Bread', store: Store.iga);

    final reloaded = HouseholdStore(backend, clock: () => clock);
    await reloaded.load();
    expect(reloaded.user, 'Emily');
    expect(reloaded.items.single.name, 'Pasta');
    expect(reloaded.items.single.updatedBy, 'Emily');
    expect(reloaded.shopping.single.store, Store.iga);
    expect(reloaded.activity, isNotEmpty);
  });

  test('only household members can be chosen as the user', () async {
    await store.setUser('Someone else');
    expect(store.user, 'Chris');
  });

  test('CSV import adds new items, updates existing ones, makes unknown locations', () async {
    final first = await store.importCsv(
      'name,location,quantity,unit,target\n'
      'Rice,Pantry,2,kg,5\n'
      '"Batteries, AA",Shed,8,items,12\n'
      'broken,Pantry,lots\n',
    );
    expect(first.added, 2);
    expect(first.skipped, 1);
    expect(store.location(store.items.last.locationId)!.name, 'Shed');
    expect(store.items.last.name, 'Batteries, AA');

    final second = await store.importCsv('rice,pantry,4,kg,5');
    expect(second.added, 0);
    expect(second.updated, 1);
    expect(store.items.firstWhere((i) => i.name == 'Rice').quantity, 4);
  });

  test('CSV export round-trips through import', () async {
    await store.addItem(name: 'Olive oil, extra virgin', locationId: 'garage', quantity: 2, unit: 'L', target: 3);
    final csv = store.exportCsv();

    final other = HouseholdStore(MemoryBackend(), clock: () => clock);
    await other.load();
    final r = await other.importCsv(csv);
    expect(r.added, 1);
    expect(other.items.single.name, 'Olive oil, extra virgin');
    expect(other.location(other.items.single.locationId)!.name, 'Garage');
  });

  test('the activity log is capped', () async {
    final item = await store.addItem(name: 'Water', locationId: 'garage', quantity: 0);
    for (var i = 0; i < HouseholdStore.maxActivity + 5; i++) {
      await store.adjust(item.id, 1);
    }
    expect(store.activity, hasLength(HouseholdStore.maxActivity));
  });

  group('shopping list stacks the same thing on one line', () {
    test('same name, any case or spacing, adds to the amount', () async {
      await store.addShopping(name: 'Bread');
      await store.addShopping(name: '  bread ', quantity: 2);
      await store.addShopping(name: 'BREAD');
      expect(store.shopping, hasLength(1));
      expect(store.shopping.single.quantity, 4);
      expect(store.shopping.single.name, 'Bread');
    });

    test('different units stay apart, a missing unit stacks', () async {
      await store.addShopping(name: 'Milk', quantity: 2, unit: 'L');
      await store.addShopping(name: 'milk', unit: 'packs');
      await store.addShopping(name: 'Milk');
      expect(store.shopping, hasLength(2));
      expect(store.shopping.firstWhere((l) => l.unit == 'L').quantity, 3);
    });

    test('a ticked line is not added to; a new line starts', () async {
      final first = await store.addShopping(name: 'Eggs');
      await store.setBought(first.id, true);
      await store.addShopping(name: 'eggs');
      expect(store.shopping, hasLength(2));
    });

    test('a typed line links to the stock item of that name, so putting it away restocks', () async {
      final tuna = await store.addItem(name: 'Tuna', locationId: 'pantry', quantity: 1, unit: 'tins');
      final line = await store.addShopping(name: 'tuna', quantity: 3);
      expect(line.stockItemId, tuna.id);
      expect(line.unit, 'tins');
      await store.setBought(line.id, true);
      await store.putAwayBought();
      expect(store.item(tuna.id)!.quantity, 4);
    });

    test('running low joins a line already typed in, and raises it to the shortfall', () async {
      await store.addItem(name: 'Pasta', locationId: 'pantry', quantity: 2, unit: 'kg', target: 5);
      await store.addShopping(name: 'pasta');
      expect(await store.addRunningLowToShopping(), 1);
      expect(store.shopping, hasLength(1));
      expect(store.shopping.single.quantity, 3);
      expect(await store.addRunningLowToShopping(), 0);
    });

    test('two different stock items with the same name keep their own lines', () async {
      await store.addItem(name: 'Soap', locationId: 'garage', quantity: 0, unit: 'bars', target: 4);
      await store.addItem(name: 'Soap', locationId: 'hygiene', quantity: 1, unit: 'bars', target: 2);
      expect(await store.addRunningLowToShopping(), 2);
      expect(store.shopping, hasLength(2));
    });

    test('a list saved with duplicates is merged when it loads, and saved clean', () async {
      Map<String, Object?> line(String id, String name, {bool bought = false}) => {
        'id': id,
        'name': name,
        'quantity': 1,
        'unit': '',
        'store': 'any',
        'addedBy': 'Chris',
        'bought': bought,
      };
      final old = MemoryBackend({
        'schema': 1,
        'user': 'Chris',
        'locations': defaultLocations().map((l) => l.toJson()).toList(),
        'items': <Object?>[],
        'activity': <Object?>[],
        'shopping': [
          line('a', 'bread'),
          line('b', 'cheese'),
          line('c', 'Bread'),
          line('d', 'cheese'),
          line('e', 'bread', bought: true),
        ],
      });
      final loaded = HouseholdStore(old, clock: () => clock);
      await loaded.load();
      expect(loaded.shopping.map((l) => '${l.name} ${formatQty(l.quantity)} ${l.bought}'), [
        'bread 2 false',
        'cheese 2 false',
        'bread 1 true',
      ]);
      expect(old.saves, 1);
      expect((old.data!['shopping']! as List).length, 3);
    });
  });
}
