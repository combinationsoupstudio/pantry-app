import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pantry_app/app.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/data/open_food_facts.dart';
import 'package:pantry_app/data/picture_cache.dart';
import 'package:pantry_app/data/storage_backend.dart';
import 'package:pantry_app/models/models.dart';

const potatoPic = 'https://images.openfoodfacts.org/images/products/932/085/800/1310/front_en.3.200.jpg';

Future<HouseholdStore> newStore() async {
  final s = HouseholdStore(MemoryBackend());
  await s.load();
  return s;
}

void main() {
  group('product pictures from Open Food Facts', () {
    test('the small front picture is read, and only over https', () {
      final p = productFromJson('9320858001310', {
        'product_name': 'Washed potatoes',
        'brands': ['Woolworths'],
        'quantity': '2 kg',
        'image_front_small_url': potatoPic,
      });
      expect((p.imageUrl, p.brand, p.quantityText, p.packSize, p.unit), (potatoPic, 'Woolworths', '2 kg', 2.0, 'kg'));
      expect(
        productFromJson('1', {'product_name': 'X', 'image_front_small_url': 'http://evil.example/x.jpg'}).imageUrl,
        isNull,
      );
    });

    test('name search asks for Australian products and reads the hits', () async {
      late Uri asked;
      final off = OpenFoodFacts(
        client: MockClient((req) async {
          asked = req.url;
          return http.Response(
            jsonEncode({
              'hits': [
                {'code': '9320858001310', 'product_name': 'Washed potatoes', 'image_front_small_url': potatoPic},
                {'code': '9330798001820', 'product_name': 'White washed potatoes', 'quantity': '1 kg'},
                {'code': '0000'},
              ],
            }),
            200,
          );
        }),
      );
      final found = await off.search('washed potatoes');
      expect(asked.host, 'search.openfoodfacts.org');
      expect(asked.queryParameters['q'], 'washed potatoes countries_tags:"en:australia"');
      expect(found.map((p) => p.name), ['Washed potatoes', 'White washed potatoes']);
      expect(found.first.imageUrl, potatoPic);
      expect(await off.search('a'), isEmpty, reason: 'too short to search');
    });

    test('names that hold the words come first, pictures break ties', () {
      ProductInfo p(String name, {bool pic = false}) =>
          ProductInfo(barcode: '1', name: name, imageUrl: pic ? potatoPic : null);
      final ranked = rankByName('washed potatoes', [
        p('Refreshing Facial Wash', pic: true),
        p('Potato Bites', pic: true),
        p('Washed white potatoes'),
        p('Washed potatoes', pic: true),
      ]);
      expect(ranked.map((r) => r.name), [
        'Washed potatoes',
        'Washed white potatoes',
        'Potato Bites',
        'Refreshing Facial Wash',
      ]);
    });
  });

  group('picture cache', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('pictures'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('downloads a picture once, then reads it from the phone', () async {
      var calls = 0;
      final cache = PictureCache(
        root: () async => dir,
        client: MockClient((req) async {
          calls++;
          return http.Response.bytes([1, 2, 3, 4], 200, headers: {'content-type': 'image/jpeg'});
        }),
      );
      final first = await cache.fileFor(potatoPic);
      final again = await cache.fileFor(potatoPic);
      expect(first!.path, again!.path);
      expect(first.readAsBytesSync(), [1, 2, 3, 4]);
      expect(calls, 1);
      expect(PictureCache.fileNameFor(potatoPic), '932_085_800_1310_front_en.3.200.jpg');
    });

    test('never fetches from anywhere but the Open Food Facts image server; failures give none', () async {
      var calls = 0;
      final cache = PictureCache(
        root: () async => dir,
        client: MockClient((req) async {
          calls++;
          return http.Response('missing', 404);
        }),
      );
      expect(await cache.fileFor('https://example.com/pic.jpg'), isNull);
      expect(calls, 0);
      expect(await cache.fileFor(potatoPic), isNull);
      expect(calls, 1);
      expect(await cache.fileFor(potatoPic), isNull, reason: 'a failure can be tried again');
      expect(calls, 2);
    });
  });

  group('pictures on stock and the list', () {
    test('a pile counts items, or packs for a measured item', () async {
      final s = await newStore();
      final spuds = await s.addItem(name: 'Washed potatoes', locationId: 'pantry', quantity: 4, unit: 'items');
      final half = await s.addItem(name: 'Lemon', locationId: 'fridge', quantity: 0.5);
      final none = await s.addItem(name: 'Onions', locationId: 'pantry');
      final oil = await s.addItem(name: 'Olive oil', locationId: 'pantry', quantity: 1150, unit: 'ml', packSize: 750);
      final pasta = await s.addItem(name: 'Pasta', locationId: 'pantry', quantity: 3, unit: 'kg');
      expect([spuds.pileCount, half.pileCount, none.pileCount, oil.pileCount, pasta.pileCount], [4, 1, 0, 2, 1]);
      expect([pasta.pileFor(3), spuds.pileFor(5), oil.pileFor(2)], [1, 5, 2]);
    });

    test('setting a picture is not logged as an edit, survives a save, and moves with the stock', () async {
      final s = await newStore();
      final spuds = await s.addItem(name: 'Washed potatoes', locationId: 'pantry', quantity: 4);
      final logged = s.activity.length;
      await s.setPicture(spuds.id, potatoPic);
      expect(s.activity.length, logged);
      final back = StockItem.fromJson(jsonDecode(jsonEncode(s.item(spuds.id)!.toJson())) as Map<String, Object?>);
      expect(back.imageUrl, potatoPic);
      await s.move(spuds.id, 'prep', 2);
      expect(s.items.firstWhere((i) => i.locationId == 'prep').imageUrl, potatoPic);
      await s.setPicture(spuds.id, null);
      expect(s.item(spuds.id)!.imageUrl, isNull);
    });

    test('a shopping line amount goes up and down, never below one', () async {
      final s = await newStore();
      final line = await s.addShopping(name: 'Washed potatoes', quantity: 2);
      await s.setShoppingQuantity(line.id, 5);
      expect(s.shopping.single.quantity, 5);
      await s.setShoppingQuantity(line.id, 0);
      expect(s.shopping.single.quantity, 1);
    });
  });

  testWidgets('picking more tins on the list grows the pile (produce shows its heap instead, v0.14)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final s = await newStore();
    final spuds = await s.addItem(name: 'Baked beans', locationId: 'pantry', quantity: 4, unit: 'items');
    final line = await s.addShopping(name: 'Baked beans', quantity: 2);

    await tester.pumpWidget(PantryApp(store: s));
    await tester.tap(find.byKey(const ValueKey('nav-pantry')));
    await tester.pumpAndSettle();
    final tilePile = find.byKey(ValueKey('pile-${spuds.id}'));
    expect(find.descendant(of: tilePile, matching: find.text('×4')), findsOneWidget);
    expect(find.descendant(of: tilePile, matching: find.byKey(const ValueKey('pile-copy-3'))), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-shopping')));
    await tester.pumpAndSettle();
    final linePile = find.byKey(ValueKey('shop-pile-${line.id}'));
    expect(find.descendant(of: linePile, matching: find.text('×2')), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(ValueKey('shop-more-${line.id}')));
      await tester.pumpAndSettle();
    }
    expect(s.shopping.single.quantity, 5);
    expect(find.descendant(of: linePile, matching: find.text('×5')), findsOneWidget);
    expect(find.descendant(of: linePile, matching: find.byKey(const ValueKey('pile-copy-4'))), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('shop-less-${line.id}')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: linePile, matching: find.text('×4')), findsOneWidget);
  });
}
