// Renders each screen at phone size with real fonts and made-up demo data.
// Not part of CI. Run: flutter test --update-goldens tool/screens/screens_test.dart
// Images land in tool/screens/goldens/ and docs/screens/ for the README.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pantry_app/data/sync_service.dart';
import 'package:pantry_app/ui/pages/household_page.dart';
import 'package:pantry_app/app.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/logic/receipt_parse.dart';
import 'package:pantry_app/ui/pages/receipt_page.dart';
import 'package:pantry_app/ui/theme.dart';
import 'package:pantry_app/data/store_scope.dart';
import 'package:pantry_app/ui/pages/stocktake_page.dart';
import 'package:pantry_app/data/open_food_facts.dart';
import 'package:pantry_app/data/picture_cache.dart';
import 'package:pantry_app/data/storage_backend.dart';
import 'package:pantry_app/models/models.dart';

Future<void> loadFonts() async {
  final dir =
      '${Platform.environment['FLUTTER_ROOT'] ?? '/home/claude/sdk/flutter'}/bin/cache/artifacts/material_fonts';
  Future<ByteData> f(String name) async => ByteData.sublistView(File('$dir/$name').readAsBytesSync());
  final roboto = FontLoader('Roboto')
    ..addFont(f('Roboto-Regular.ttf'))
    ..addFont(f('Roboto-Medium.ttf'))
    ..addFont(f('Roboto-Bold.ttf'));
  await roboto.load();
  Future<ByteData> a(String name) async => ByteData.sublistView(File('assets/fonts/$name').readAsBytesSync());
  await (FontLoader('Fraunces')
        ..addFont(a('Fraunces-SemiBold.ttf'))
        ..addFont(a('Fraunces-Bold.ttf')))
      .load();
  await (FontLoader('Nunito Sans')
        ..addFont(a('NunitoSans-Regular.ttf'))
        ..addFont(a('NunitoSans-SemiBold.ttf'))
        ..addFont(a('NunitoSans-Bold.ttf'))
        ..addFont(a('NunitoSans-ExtraBold.ttf')))
      .load();
  final icons = FontLoader('MaterialIcons')..addFont(f('MaterialIcons-Regular.otf'));
  await icons.load();
}

/// Real Open Food Facts pictures fetched by tool/screens/fetch_pictures.py.
final Map<String, Object?> pictures = File('tool/screens/pictures.json').existsSync()
    ? (jsonDecode(File('tool/screens/pictures.json').readAsStringSync()) as Map).cast<String, Object?>()
    : {};

Future<HouseholdStore> demoStore() async {
  final s = HouseholdStore(MemoryBackend(), clock: () => DateTime(2026, 11, 16, 12));
  await s.load();
  final now = DateTime(2026, 11, 16);
  Future<void> add(String n, String loc, double q, String u, double t, {DateTime? useBy}) =>
      s.addItem(name: n, locationId: loc, quantity: q, unit: u, target: t, useBy: useBy);
  await add('White rice', 'prep', 10, 'kg', 10);
  await add('Pasta', 'pantry', 2, 'kg', 5);
  await add('Rolled oats', 'pantry', 3, 'kg', 5);
  await add('Tins: tomatoes', 'pantry', 9, 'tins', 20);
  await add('Tins: fish', 'prep', 4, 'tins', 20);
  await add('UHT milk', 'prep', 3, 'L', 20);
  await add('Eggs', 'fridge', 8, 'items', 12, useBy: now.add(const Duration(days: 9)));
  await add('Cheese', 'fridge', 1, 'blocks', 1, useBy: now.add(const Duration(days: 4)));
  await add('Bread', 'pantry', 1, 'loaves', 1);
  await add('Garlic', 'pantry', 1, 'bulbs', 2);
  await add('Onions', 'pantry', 0, 'items', 4);
  await add('Frozen peas', 'freezer', 1, 'kg', 1);
  await add('Toilet paper', 'hygiene', 90, 'rolls', 30);
  await add('Hydralyte sachets', 'medical', 40, 'sachets', 40);
  await add('Panadol', 'medical', 1, 'packs', 1, useBy: now.subtract(const Duration(days: 12)));
  await add('Bandages', 'medical', 2, 'packs', 2, useBy: now.add(const Duration(days: 200)));
  await add('Water jerry cans', 'garage', 40, 'L', 40);
  await add('Cask water 10 L', 'garage', 2, 'casks', 2);
  await add('LED torch', 'garage', 2, 'items', 4);
  await add('Batteries AAA', 'garage', 48, 'items', 10);
  final soy = await s.addItem(
    name: 'Soy sauce',
    locationId: 'pantry',
    quantity: 30,
    unit: 'ml',
    target: 500,
    packSize: 500,
    barcode: '9300000000001',
  );
  await s.addItem(name: 'Olive oil', locationId: 'pantry', quantity: 1150, unit: 'ml', target: 750, packSize: 750);
  final soyLine = await s.addShopping(name: 'Soy sauce', store: Store.coles);
  await s.setBought(soyLine.id, true);
  await s.putAwayBought(paid: {soyLine.id: 4.5});
  await s.adjust(soy.id, -500);
  await s.addItem(name: 'Washed potatoes', locationId: 'pantry', quantity: 4, unit: 'items', target: 6);
  for (final i in s.items) {
    final url = pictures[i.name];
    if (url is String) await s.setPicture(i.id, url);
  }
  final pasta = s.items.firstWhere((i) => i.name == 'Pasta');
  await s.adjust(pasta.id, -1);
  await s.adjust(pasta.id, 1);
  await s.addRunningLowToShopping();
  await s.addShopping(name: 'Butter', store: Store.aldi);
  final bread = await s.addShopping(name: 'Bread', store: Store.iga);
  await s.setBought(bread.id, true);
  await s.putAwayBought(paid: {bread.id: 4.2});
  final eggs = s.items.firstWhere((i) => i.name == 'Eggs');
  await s.adjust(eggs.id, -6);
  await s.addRecipe(
    name: 'Weeknight fried rice',
    minutes: 25,
    ingredients: ['3 cups cooked white rice', '2 eggs', '1 cup frozen peas', '2 tbsp soy sauce', '2 garlic cloves'],
    method:
        'Scramble the eggs in a hot wok and set aside.\nFry the garlic, then the rice until hot.\n'
        'Add the peas and soy sauce.\nFold the egg back through and serve.',
  );
  await s.addRecipe(
    name: 'Tomato pasta bake',
    minutes: 40,
    url: 'https://example.com/tomato-pasta-bake/',
    ingredients: ['500 g pasta', '2 tins tomatoes', '1 onion', '200 g cheese'],
  );
  return s;
}

void main() {
  setUpAll(() async {
    await loadFonts();
    PictureCache.instance = PictureCache(root: () async => Directory('tool/screens'));
    final hits = (pictures['_search'] as List?) ?? const [];
    OpenFoodFacts.instance = OpenFoodFacts(
      client: MockClient((req) async => http.Response(jsonEncode({'hits': hits, 'status': 0}), 200)),
    );
  });

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    // Pictures load from files: let the real file reads and decodes finish.
    for (var round = 0; round < 3; round++) {
      await tester.runAsync(() async {
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e).timeout(const Duration(seconds: 5), onTimeout: () {});
        }
      });
      await tester.pumpAndSettle();
    }
    await expectLater(find.byType(MaterialApp).first, matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('screens', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final store = await demoStore();
    await tester.pumpWidget(PantryApp(store: store));
    await shot(tester, '1-home');
    for (final (key, name) in [
      ('nav-pantry', '2-pantry'),
      ('nav-shopping', '4-shopping'),
      ('nav-recipes', '5-recipes'),
    ]) {
      await tester.tap(find.byKey(ValueKey(key)));
      await shot(tester, name);
      if (name == '2-pantry') {
        final soy = store.items.firstWhere((i) => i.name == 'Soy sauce');
        final oil = store.items.firstWhere((i) => i.name == 'Olive oil');
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('stock-${oil.id}')),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await shot(tester, '9-pantry-measured');
        await tester.tap(find.byKey(ValueKey('minus-${oil.id}')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('use-amount')), '3');
        await tester.tap(find.byKey(const ValueKey('use-unit-tbsp')));
        await shot(tester, '10-use-some');
        Navigator.of(tester.element(find.byKey(const ValueKey('use-amount')))).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('stock-${soy.id}')));
        await shot(tester, '11-edit-measured');
        Navigator.of(tester.element(find.byKey(const ValueKey('save-item')))).pop();
        await tester.pumpAndSettle();
        final spuds = store.items.firstWhere((i) => i.name == 'Washed potatoes');
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('stock-${spuds.id}')),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.byKey(ValueKey('stock-${spuds.id}')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('find-picture')));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await shot(tester, '12-find-picture');
        Navigator.of(tester.element(find.byKey(const ValueKey('picture-query')))).pop();
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byKey(const ValueKey('save-item')))).pop();
        await tester.pumpAndSettle();
        // The extra stock, stored away, further down the same page.
        await tester.scrollUntilVisible(find.text('STORED AWAY'), 300, scrollable: find.byType(Scrollable).last);
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
        await shot(tester, '3-pantry-stored');
      }
      if (name == '5-recipes') {
        await tester.tap(find.text('Weeknight fried rice'));
        await shot(tester, '6-recipe-ingredients');
        await tester.tap(find.byKey(const ValueKey('tab-method')));
        await shot(tester, '7-recipe-method');
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    }
    // Insights now opens from the House stock card on Home.
    await tester.tap(find.byKey(const ValueKey('nav-home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-stock')));
    await shot(tester, '8-insights');
  });

  testWidgets('v0.6 screens', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final store = await demoStore();
    final prep = store.itemsOf(LocationKind.storage, locationId: 'prep');
    await tester.pumpWidget(PantryApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-dates')));
    await shot(tester, '13-use-by-dates');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          debugShowCheckedModeBanner: false,
          home: StocktakePage(title: 'Prep pantry', itemIds: [for (final i in prep) i.id]),
        ),
      ),
    );
    await shot(tester, '14-stocktake');
  });

  testWidgets('v0.8 receipt', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final store = await demoStore();
    final receipt = parseReceipt(const [
      'Woolworths',
      '16/11/26 10:42',
      'WW FREE RANGE EGGS 12PK 700G   6.50',
      'KIKKOMAN SOY SAUCE 600ML   5.20',
      'WW DICED TOMATOES 400G',
      'QTY 3 @ \$1.10 EACH   3.30',
      'POTATOES WASHED LOOSE',
      '1.250 kg NET @ \$3.50/kg   4.38',
      'CADBURY DAIRY MILK 180G   6.00',
      'Promotional Price   -1.50',
      'TOTAL   \$23.88',
    ]);
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          debugShowCheckedModeBanner: false,
          home: ReceiptPage(receipt: receipt),
        ),
      ),
    );
    await shot(tester, '15-receipt');
  });

  testWidgets('v0.9 household', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final store = await demoStore();
    final sync = SyncService.instance = SyncService(
      store,
      backend: MemoryBackend(),
      server: 'https://x',
      client: MockClient((req) async {
        if (req.url.path == '/households') {
          return http.Response(jsonEncode({'household': 'K7QM4RXT', 'token': 't', 'code': 'K7QM4RXT-482913'}), 200);
        }
        return http.Response(jsonEncode({'cursor': 1, 'records': [], 'refused': []}), 200);
      }),
    );
    addTearDown(() => SyncService.instance = null);
    await tester.runAsync(sync.start);
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          debugShowCheckedModeBanner: false,
          home: const HouseholdPage(),
        ),
      ),
    );
    await shot(tester, '16-household');
  });
}
