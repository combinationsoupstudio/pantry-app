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
}
