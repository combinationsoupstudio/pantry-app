import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pantry_app/app.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/data/open_food_facts.dart';
import 'package:pantry_app/data/storage_backend.dart';
import 'package:pantry_app/logic/amounts.dart';
import 'package:pantry_app/logic/recipes.dart';
import 'package:pantry_app/models/models.dart';
import 'package:pantry_app/ui/pages/recipes_page.dart';

Future<HouseholdStore> newStore() async {
  final s = HouseholdStore(MemoryBackend());
  await s.load();
  return s;
}

/// A 500 ml bottle of soy sauce with about 300 ml left.
Future<StockItem> soySauce(HouseholdStore s, {double left = 300, double target = 0}) => s.addItem(
  name: 'Soy sauce',
  locationId: 'pantry',
  quantity: left,
  unit: 'ml',
  target: target,
  packSize: 500,
  barcode: '9300000000001',
);

void main() {
  group('measures', () {
    test('Australian cups and spoons convert into ml and L', () {
      expect(convertUnits(2, 'tbsp', 'ml'), 40);
      expect(convertUnits(1, 'cup', 'ml'), 250);
      expect(convertUnits(4, 'tsp', 'L'), 0.02);
      expect(convertUnits(300, 'mL', 'l'), 0.3);
      expect(convertUnits(1.5, 'kg', 'g'), 1500);
      expect(convertUnits(100, 'g', 'ml'), isNull, reason: 'weight is never turned into volume');
      expect(convertUnits(1, 'cup', 'kg'), isNull);
    });

    test('recipe lines read spoons and cups', () {
      final a = parseAmount('2 tablespoons soy sauce')!;
      expect((a.quantity, a.unit), (2.0, 'tbsp'));
      expect(parseAmount('1 tsp salt')!.unit, 'tsp');
      expect(parseAmount('½ cup milk')!.unit, 'cup');
      expect(amountToUse('2 tbsp soy sauce', 'ml'), 40);
      expect(amountToUse('1 cup milk', 'L'), 0.25);
    });

    test('use units follow what the item is measured in', () {
      expect(useUnitsFor('ml'), ['ml', 'L', 'cup', 'tbsp', 'tsp']);
      expect(useUnitsFor('kg'), ['g', 'kg']);
      expect(useUnitsFor('tins'), ['tins']);
      expect(formatMeasure(300, 'ml'), '300 ml');
      expect(formatMeasure(1.5, 'l'), '1.5 L');
    });
  });

  group('measured stock items', () {
    test('a part-used bottle knows its pack, and buys in whole packs', () async {
      final s = await newStore();
      final soy = await soySauce(s, left: 300, target: 500);
      expect(soy.isMeasured, isTrue);
      expect(soy.packLabel, '500 ml');
      expect(soy.shoppingUnit, '× 500 ml');
      expect(soy.shortfall, 200);
      expect(soy.restock, 1, reason: '200 ml short is one 500 ml bottle');
      expect(soy.packsFor(501), 2);
    });

    test('a counted item is not measured, even in ml', () async {
      final s = await newStore();
      final milk = await s.addItem(name: 'UHT milk', locationId: 'prep', quantity: 3, unit: 'L');
      expect(milk.isMeasured, isFalse);
      expect(milk.shoppingUnit, 'L');
    });

    test('pack size, barcode and photo survive a save; old saves still load', () async {
      final s = await newStore();
      final soy = await soySauce(s);
      final withPhoto = soy.copyWith(photoPath: '/photos/soy.jpg');
      final back = StockItem.fromJson(jsonDecode(jsonEncode(withPhoto.toJson())) as Map<String, Object?>);
      expect((back.packSize, back.barcode, back.photoPath), (500.0, '9300000000001', '/photos/soy.jpg'));
      final old = Map<String, Object?>.of(soy.toJson())
        ..remove('packSize')
        ..remove('barcode');
      final legacy = StockItem.fromJson(old);
      expect((legacy.packSize, legacy.barcode, legacy.isMeasured), (0.0, null, false));
      expect(back.copyWith(clearPhoto: true, clearBarcode: true).photoPath, isNull);
    });

    test('running low goes on the list as packs, and packs put away as ml', () async {
      final s = await newStore();
      final soy = await soySauce(s, left: 300, target: 1000);
      await s.addRunningLowToShopping();
      final line = s.shopping.single;
      expect((line.quantity, line.unit, line.stockItemId), (2.0, '× 500 ml', soy.id));
      await s.setBought(line.id, true);
      await s.putAwayBought(paid: {line.id: 9.0});
      expect(s.item(soy.id)!.quantity, 1300);
      expect(s.prices.single.unitPrice, 4.5);
      expect(s.prices.single.perLabel, '500 ml');
      expect(s.activity.first.delta, 1000, reason: 'the log keeps ml');
    });

    test('a typed line for a measured item links up and is bought in packs', () async {
      final s = await newStore();
      final soy = await soySauce(s);
      final line = await s.addShopping(name: 'soy sauce');
      expect((line.unit, line.stockItemId), ('× 500 ml', soy.id));
    });

    test('+ adds a whole pack; a barcode finds its item; moving keeps the pack', () async {
      final s = await newStore();
      final soy = await soySauce(s);
      await s.addPack(soy.id);
      expect(s.item(soy.id)!.quantity, 800);
      expect(s.itemByBarcode(' 9300000000001 ')!.id, soy.id);
      expect(s.itemByBarcode('123'), isNull);
      await s.move(soy.id, 'prep', 500);
      final moved = s.items.firstWhere((i) => i.locationId == 'prep');
      expect((moved.quantity, moved.packSize, moved.barcode), (500.0, 500.0, '9300000000001'));
    });
  });

  group('recipe needs against what is left', () {
    Recipe recipe(List<String> lines) => Recipe.fromSaved(
      SavedRecipe(id: 'r', name: 'Stir fry', ingredients: lines, addedBy: 'Chris', createdAt: DateTime(2026)),
    );

    test('needs 100 ml, have 20 ml: short 80 ml, one bottle to buy', () async {
      final s = await newStore();
      await soySauce(s, left: 20);
      final m = matchRecipes(
        s.items,
        recipes: [
          recipe(['100 ml soy sauce']),
        ],
      ).single;
      expect(m.ready, isFalse);
      expect(m.have, isEmpty);
      final short = m.short.single;
      expect((short.need, short.have, short.short), (100.0, 20.0, 80.0));
      expect(short.label, 'short 80 ml');
      expect(short.toBuy, 1);

      expect(await addMissingToShopping(s, m), 1);
      final line = s.shopping.single;
      expect((line.quantity, line.unit), (1.0, '× 500 ml'));
      expect(await addMissingToShopping(s, m), 0, reason: 'not added twice');
    });

    test('spoons count against ml; enough left means it is had', () async {
      final s = await newStore();
      await soySauce(s, left: 50);
      final m = matchRecipes(
        s.items,
        recipes: [
          recipe(['2 tbsp soy sauce']),
        ],
      ).single;
      expect(m.ready, isTrue, reason: '40 ml needed, 50 ml left');
    });

    test('counted things are checked too; lines without amounts are not', () async {
      final s = await newStore();
      await s.addItem(name: 'Eggs', locationId: 'fridge', quantity: 2, unit: 'items');
      await s.addItem(name: 'Rice', locationId: 'pantry', quantity: 1, unit: 'kg');
      final m = matchRecipes(
        s.items,
        recipes: [
          recipe(['3 eggs', '1 cup rice', 'Rice']),
        ],
      ).single;
      expect(m.short.single.item.name, 'Eggs');
      expect(m.short.single.label, 'short 1');
      expect(m.have.length, 2, reason: 'cups do not convert to kg, so rice is had');
      expect(m.toBuy, 1);
    });

    test('a count in other words is not compared: cloves against bulbs', () async {
      final s = await newStore();
      await s.addItem(name: 'Garlic', locationId: 'pantry', quantity: 1, unit: 'bulbs');
      await s.addItem(name: 'Tinned tomatoes', locationId: 'pantry', quantity: 1, unit: 'tins');
      final m = matchRecipes(
        s.items,
        recipes: [
          recipe(['2 garlic cloves', '2 tins tomatoes']),
        ],
      ).single;
      expect(m.have.single.label, 'garlic cloves');
      expect(m.short.single.label, 'short 1 tins');
    });
  });

  group('Open Food Facts', () {
    test('reads the pack size from the product, or from its quantity text', () {
      final a = productFromJson('1', {
        'product_name': 'Soy Sauce',
        'brands': 'Kikkoman',
        'product_quantity': '500',
        'product_quantity_unit': 'ml',
      });
      expect((a.displayName, a.packSize, a.unit), ('Kikkoman Soy Sauce', 500.0, 'ml'));

      final b = productFromJson('2', {'product_name': 'Kikkoman soy sauce', 'brands': 'Kikkoman', 'quantity': '1 L'});
      expect((b.displayName, b.packSize, b.unit), ('Kikkoman soy sauce', 1.0, 'L'));

      expect(parsePackSize('2 x 375 ml'), (750.0, 'ml'));
      expect(parsePackSize('33 cl'), (330.0, 'ml'));
      expect(parsePackSize('1,5 kg'), (1.5, 'kg'));
      expect(parsePackSize('6 rolls'), isNull);
      expect(productFromJson('3', {'product_name': 'Tissues'}).hasPackSize, isFalse);
    });

    test('lookup names the app, and handles found, unknown and failure', () async {
      late http.Request seen;
      OpenFoodFacts off(int status, Object body) => OpenFoodFacts(
        client: MockClient((req) async {
          seen = req;
          return http.Response(jsonEncode(body), status);
        }),
      );

      final found = await off(200, {
        'status': 1,
        'product': {'product_name': 'Rolled Oats', 'brands': 'Uncle Tobys', 'quantity': '750 g'},
      }).lookup('9300617000000');
      expect((found!.displayName, found.packSize, found.unit), ('Uncle Tobys Rolled Oats', 750.0, 'g'));
      expect(seen.url.host, 'world.openfoodfacts.org');
      expect(seen.url.path, '/api/v2/product/9300617000000');
      expect(seen.headers['User-Agent'], contains('PantryApp'));

      expect(await off(200, {'status': 0}).lookup('9300617000000'), isNull);
      expect(await off(404, {'status': 0}).lookup('9300617000000'), isNull);
      expect(await off(200, {}).lookup('not-a-barcode'), isNull);
      expect(off(503, {}).lookup('9300617000000'), throwsA(isA<LookupFailed>()));
    });
  });

  testWidgets('a part-used bottle reads 300 / 500 ml, and Use some takes 2 tbsp', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final s = await newStore();
    final soy = await soySauce(s);

    await tester.pumpWidget(PantryApp(store: s));
    await tester.tap(find.byKey(const ValueKey('nav-pantry')));
    await tester.pumpAndSettle();
    expect(find.textContaining('/ 500 ml', findRichText: true), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('minus-${soy.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Use some Soy sauce'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('use-amount')), '2');
    await tester.tap(find.byKey(const ValueKey('use-unit-tbsp')));
    await tester.pumpAndSettle();
    expect(find.text('Takes 40 ml, leaves 260 ml'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('use-confirm')));
    await tester.pumpAndSettle();
    expect(s.item(soy.id)!.quantity, 260);

    await tester.tap(find.byKey(ValueKey('plus-${soy.id}')));
    await tester.pumpAndSettle();
    expect(s.item(soy.id)!.quantity, 760);
  });

  testWidgets('the editor saves a measured item from pack size and what is left', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final s = await newStore();

    await tester.pumpWidget(PantryApp(store: s));
    await tester.tap(find.byKey(const ValueKey('nav-pantry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('scan-barcode')), findsOneWidget);
    expect(find.byKey(const ValueKey('take-photo')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('field-name')), 'Olive oil');
    await tester.tap(find.byKey(const ValueKey('field-measured')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('field-pack-size')), '750');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('left-½')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('field-packs')), '1');
    await tester.enterText(find.byKey(const ValueKey('field-target-packs')), '1');
    await tester.ensureVisible(find.byKey(const ValueKey('save-item')));
    await tester.tap(find.byKey(const ValueKey('save-item')));
    await tester.pumpAndSettle();

    final oil = s.items.single;
    expect((oil.name, oil.unit, oil.packSize, oil.quantity, oil.target), ('Olive oil', 'ml', 750.0, 1125.0, 750.0));
    expect(oil.isLow, isFalse);
  });
}
