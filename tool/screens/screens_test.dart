// Renders each screen at phone size with real fonts and made-up demo data.
// Not part of CI. Run: flutter test --update-goldens tool/screens/screens_test.dart
// Images land in tool/screens/goldens/ and docs/screens/ for the README.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pantry_app/app.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/data/storage_backend.dart';
import 'package:pantry_app/models/models.dart';

Future<void> loadFonts() async {
  final dir = '${Platform.environment['FLUTTER_ROOT'] ?? '/home/claude/sdk/flutter'}/bin/cache/artifacts/material_fonts';
  Future<ByteData> f(String name) async => ByteData.sublistView(File('$dir/$name').readAsBytesSync());
  final roboto = FontLoader('Roboto')
    ..addFont(f('Roboto-Regular.ttf'))
    ..addFont(f('Roboto-Medium.ttf'))
    ..addFont(f('Roboto-Bold.ttf'));
  await roboto.load();
  final icons = FontLoader('MaterialIcons')..addFont(f('MaterialIcons-Regular.otf'));
  await icons.load();
}

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
  await add('LED torch', 'garage', 2, 'items', 4);
  await add('Batteries AAA', 'garage', 48, 'items', 10);
  final pasta = s.items.firstWhere((i) => i.name == 'Pasta');
  await s.adjust(pasta.id, -1);
  await s.adjust(pasta.id, 1);
  await s.addRunningLowToShopping();
  await s.addShopping(name: 'Butter', store: Store.aldi);
  await s.addRecipe(
    name: 'Weeknight fried rice',
    minutes: 25,
    ingredients: ['3 cups cooked white rice', '2 eggs', '1 cup frozen peas', '2 tbsp soy sauce', '2 garlic cloves'],
    method: 'Scramble the eggs in a hot wok and set aside.\nFry the garlic, then the rice until hot.\n'
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
  setUpAll(loadFonts);

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
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
      ('nav-storage', '3-storage'),
      ('nav-shopping', '4-shopping'),
      ('nav-recipes', '5-recipes'),
      ('nav-insights', '8-insights'),
    ]) {
      await tester.tap(find.byKey(ValueKey(key)));
      await shot(tester, name);
      if (name == '5-recipes') {
        await tester.tap(find.text('Weeknight fried rice'));
        await shot(tester, '6-recipe-ingredients');
        await tester.tap(find.byKey(const ValueKey('tab-method')));
        await shot(tester, '7-recipe-method');
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    }
  });
}
