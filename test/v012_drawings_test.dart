import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/data/storage_backend.dart';
import 'package:pantry_app/data/store_scope.dart';
import 'package:pantry_app/ui/theme.dart';
import 'package:pantry_app/ui/widgets/item_look.dart';
import 'package:pantry_app/ui/widgets/pictures.dart';

void main() {
  test('names get the right drawing, however they are typed', () {
    final cases = <String, String?>{
      'Bread': 'bread',
      'Eggs': 'eggs',
      'UHT milk': 'milk',
      'Tins: tomatoes': 'tinned-tomatoes',
      'Diced tomatoes': 'tinned-tomatoes',
      'Tins: fish': 'tuna',
      'Baked beans': 'baked-beans',
      'White rice': 'rice',
      'Rolled oats': 'oats',
      'Frozen peas': 'frozen-peas',
      'Olive oil': 'olive-oil',
      'Soy sauce': 'soy-sauce',
      'Beef mince': 'mince',
      'Chicken thighs': 'chicken',
      'Tea bags': 'tea',
      'Honey': 'honey',
      // Names of their own: no drawing rather than the wrong one.
      'Coconut milk': null,
      'Peanut butter': null,
      'Chicken stock': null,
      'Sweet potato': null,
      'Canola oil': null,
      'Batteries AAA': null,
    };
    for (final MapEntry(key: name, value: art) in cases.entries) {
      expect(artFor(name), art == null ? isNull : 'assets/food/$art.png', reason: name);
    }
  });

  test('every drawing named in the map is in the app', () {
    for (final name in ['Bread', 'Tins: fish', 'Rolled oats', 'Honey', 'Frozen peas']) {
      expect(File(artFor(name)!).existsSync(), isTrue, reason: name);
    }
    expect(Directory('assets/food').listSync().where((f) => f.path.endsWith('.png')), hasLength(22));
  });

  testWidgets('a drawing shows where there is no photo; Drawings puts it first', (tester) async {
    final store = HouseholdStore(MemoryBackend());
    await store.load();
    Widget pic(String name, {String? url}) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Center(
          child: ProductPicture(name: name, imageUrl: url),
        ),
      ),
    );
    await tester.pumpWidget(pic('Shallots'));
    expect(find.byKey(const ValueKey('picture-drawing')), findsOneWidget);
    await tester.pumpWidget(pic('Batteries AAA'));
    expect(find.byKey(const ValueKey('picture-icon')), findsOneWidget);
    // A product photo wins by default; with Drawings the drawing does.
    await tester.pumpWidget(pic('Bread', url: 'https://images.openfoodfacts.org/x.jpg'));
    expect(find.byKey(const ValueKey('picture-drawing')), findsNothing);
    await store.setSetting('pictures', 'drawings');
    await tester.pump();
    expect(find.byKey(const ValueKey('picture-drawing')), findsOneWidget);
  });
}
