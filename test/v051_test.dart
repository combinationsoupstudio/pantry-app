import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pantry_app/app.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/data/open_food_facts.dart';
import 'package:pantry_app/data/picture_finder.dart';
import 'package:pantry_app/data/storage_backend.dart';
import 'package:pantry_app/logic/picture_match.dart';

const pic = 'https://images.openfoodfacts.org/images/products/930/000/000/0001/front_en.1.200.jpg';

ProductInfo p(String name, {bool picture = true}) =>
    ProductInfo(barcode: '1', name: name, imageUrl: picture ? pic : null);

Future<HouseholdStore> newStore() async {
  final s = HouseholdStore(MemoryBackend());
  await s.load();
  return s;
}

void main() {
  group('pictures by name', () {
    test('queries strip labels, brackets, amounts and container words', () {
      expect(pictureQueries('Flour (plain and self-raising)'), ['flour']);
      expect(pictureQueries('Hydralyte sachets'), ['hydralyte sachets', 'hydralyte']);
      expect(pictureQueries('Tins: veg and tomatoes'), ['veg tomatoes', 'veg', 'tomatoes']);
      expect(pictureQueries('Cask water 10 L'), ['cask water']);
      expect(pictureQueries('Tea bags'), ['tea bags', 'tea']);
      expect(pictureQueries('Flavour kit (stock cubes, soy)'), ['flavour kit'], reason: 'a kit is not flavouring');
    });

    test('a match holds every word and is about the same thing', () {
      expect(bestPictureMatch('sugar', [p('Sugar free V'), p('White Sugar')])!.name, 'White Sugar');
      expect(bestPictureMatch('fish', [p('Fish fingers')]), isNull);
      expect(bestPictureMatch('sleeping bag', [p('My sleeping tea')]), isNull);
      expect(bestPictureMatch('uht milk', [p('Pauls uht milk 200 ml')])!.name, 'Pauls uht milk 200 ml');
      expect(bestPictureMatch('tea bags', [p('Ice Tea'), p('Tea Bags')])!.name, 'Tea Bags');
      expect(
        bestPictureMatch('rolled oats', [p('Rolled Oats with Honey and Almond Oats'), p('Rolled Oats')])!.name,
        'Rolled Oats',
        reason: 'the plainest name wins',
      );
      expect(bestPictureMatch('rolled oats', [p('Rolled Oats', picture: false)]), isNull, reason: 'needs a picture');
    });
  });

  group('picture finder', () {
    test('barcode first, then name; nothing trusted is marked and not searched again', () async {
      final s = await newStore();
      final oats = await s.addItem(name: 'Rolled oats', locationId: 'pantry', quantity: 3, unit: 'kg');
      final soy = await s.addItem(name: 'Soy sauce', locationId: 'pantry', barcode: '4901515118586');
      final torch = await s.addItem(name: 'LED torch', locationId: 'prep');
      final calls = <String>[];
      final off = OpenFoodFacts(
        client: MockClient((req) async {
          calls.add(req.url.host);
          if (req.url.path.startsWith('/api/v2/product/')) {
            return http.Response(
              jsonEncode({
                'status': 1,
                'product': {'product_name': 'Soy Sauce', 'image_front_small_url': pic},
              }),
              200,
            );
          }
          final q = req.url.queryParameters['q']!;
          final hits = q.startsWith('rolled oats')
              ? [
                  {'code': '2', 'product_name': 'Rolled Oats', 'image_front_small_url': pic},
                ]
              : [];
          return http.Response(jsonEncode({'hits': hits}), 200);
        }),
      );
      final finder = PictureFinder(s, off: off, wait: (_) async {});
      await finder.run();
      expect((s.item(oats.id)!.imageUrl, s.item(oats.id)!.pictureByName), (pic, true));
      expect((s.item(soy.id)!.imageUrl, s.item(soy.id)!.pictureByName), (pic, false));
      expect((s.item(torch.id)!.imageUrl, s.item(torch.id)!.pictureTried), (null, true));

      final before = calls.length;
      await finder.run();
      expect(calls.length, before, reason: 'nothing left to look for');

      expect(await s.retryPictures(), 1);
      await finder.run();
      expect(calls.length, greaterThan(before));
    });

    test('no connection leaves items to try next time', () async {
      final s = await newStore();
      final oats = await s.addItem(name: 'Rolled oats', locationId: 'pantry');
      final finder = PictureFinder(
        s,
        off: OpenFoodFacts(client: MockClient((_) async => throw const LookupFailed('offline'))),
        wait: (_) async {},
      );
      await finder.run();
      expect(s.item(oats.id)!.pictureTried, isFalse);
      expect(s.item(oats.id)!.wantsPicture, isTrue);
    });
  });

  testWidgets('I cooked this: type the amount used, in any measure', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final store = await newStore();
    await store.addItem(name: 'Bread', locationId: 'pantry', quantity: 4, unit: 'loaves');
    final beans = await store.addItem(name: 'Baked beans', locationId: 'prep', quantity: 1200, unit: 'g');

    await tester.pumpWidget(PantryApp(store: store));
    await tester.tap(find.byKey(const ValueKey('nav-recipes')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beans on toast'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cooked')));
    await tester.pumpAndSettle();
    expect(find.text('250 g'), findsOneWidget, reason: 'a line with no amount starts at 250 g, not 1 g');

    await tester.tap(find.byKey(ValueKey('cook-amount-${beans.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('cook-amount-field')), '0.42');
    await tester.tap(find.byKey(const ValueKey('cook-unit-kg')));
    await tester.pumpAndSettle();
    expect(find.text('= 420 g of 1200 g'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cook-amount-ok')));
    await tester.pumpAndSettle();
    expect(find.text('420 g'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-cook')));
    await tester.pumpAndSettle();
    expect(store.item(beans.id)!.quantity, 780);
  });
}
