import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/data/storage_backend.dart';
import 'package:pantry_app/data/store_scope.dart';
import 'package:pantry_app/models/models.dart';
import 'package:pantry_app/ui/theme.dart';
import 'package:pantry_app/ui/widgets/pictures.dart';
import 'package:pantry_app/ui/widgets/produce.dart';

StockItem item(String name, double qty, {String unit = 'items'}) => StockItem(
  id: name,
  name: name,
  locationId: 'pantry',
  quantity: qty,
  unit: unit,
  target: 0,
  updatedAt: DateTime(2026),
  updatedBy: 'Chris',
);

void main() {
  test('names find their produce, however they are typed', () {
    final cases = <String, String?>{
      'Washed potatoes': 'potato',
      'Sweet potato': 'sweet-potato',
      'Kumara': 'sweet-potato',
      'Shallots': 'spring-onion',
      'Spring onions': 'spring-onion',
      'Eschalots': 'shallot',
      'Brown onions': 'onion',
      'Red onion': 'red-onion',
      'Granny Smith apples': 'green-apple',
      'Pink Lady': 'apple',
      'Custard apple': 'custard-apple',
      'Pineapple': 'pineapple',
      'Cherry tomatoes': 'cherry-tomato',
      'Tomatoes': 'tomato',
      'Bell pepper': 'red-capsicum',
      'Green capsicum': 'green-capsicum',
      'Chili': 'chilli',
      'Cantaloupe': 'rockmelon',
      'Baby spinach': 'spinach',
      'English spinach': 'english-spinach',
      'Snow pea shoots': 'snow-pea-sprouts',
      'Snow peas': 'snow-pea',
      'Coriander': 'coriander',
      'Cilantro': 'coriander',
      'Flat leaf parsley': 'parsley',
      'Lettuce': 'iceberg-lettuce',
      'Cos lettuce': 'cos-lettuce',
      'Salad mix': 'salad-leaves',
      'Grapes': 'red-grapes',
      'Grapefruit': 'grapefruit',
      'Butternut pumpkin': 'butternut',
      'Pumpkin': 'pumpkin',
      'Jerusalem artichokes': 'jerusalem-artichoke',
      'Kipflers': 'kipfler-potato',
      // Made from the produce, or a name of its own: never the fresh drawing.
      'Tinned tomatoes': null,
      'Diced tomatoes tin': null,
      'Orange juice': null,
      'Dried oregano': null,
      'Garlic powder': null,
      'Crushed garlic': null,
      'Banana bread': null,
      'Frozen peas': null,
      'Peas': null,
      'Coconut milk': null,
      'Potato chips': null,
      'Potato salad': null,
      'Baked beans': null,
      'Ginger beer': null,
      'Tomato sauce': null,
      'Apple pie': null,
      'Bread': null,
    };
    for (final MapEntry(key: name, value: slug) in cases.entries) {
      expect(produceOf(name)?.$1, slug, reason: name);
    }
  });

  test('one of it for 1, the heap or bunch for more, the cut piece for part', () {
    expect(produceArt('Potatoes'), 'assets/food/produce/potato-1.png');
    expect(produceArt('Potatoes', count: 4), 'assets/food/produce/potato-many.png');
    expect(produceArt('Bananas'), 'assets/food/produce/banana-1.png');
    expect(produceArt('Bananas', count: 6), 'assets/food/produce/banana-bunch.png');
    expect(produceArt('Pumpkin'), 'assets/food/produce/pumpkin-whole.png');
    expect(produceArt('Pumpkin', part: true), 'assets/food/produce/pumpkin-cut.png');
    expect(produceArt('Pumpkin', count: 2), 'assets/food/produce/pumpkin-whole.png');
    expect(produceArt('Strawberries', count: 3), 'assets/food/produce/strawberry-punnet.png');
    expect(produceArt('Basil'), 'assets/food/produce/basil-bunch.png');
    expect(produceArt('Ginger', count: 3), 'assets/food/produce/ginger-1.png');
    expect(produceArt('Batteries AAA'), isNull);
  });

  test('every produce picture is in the app, and every file is used', () {
    final named = <String>{};
    for (final (slug, variants, _) in produceTable) {
      for (final v in variants) {
        final path = 'assets/food/produce/$slug-$v.png';
        expect(File(path).existsSync(), isTrue, reason: path);
        named.add(path);
      }
    }
    expect(produceTable, hasLength(141));
    expect(named, hasLength(228));
    final files = Directory('assets/food/produce').listSync().map((f) => f.path).where((p) => p.endsWith('.png'));
    expect(files.toSet(), named);
  });

  test('loose produce by weight shows the heap; half a pumpkin the cut piece', () {
    final spuds = ProductPicture.of(item('Potatoes', 1.5, unit: 'kg'));
    expect(spuds.count, 2);
    final half = ProductPicture.of(item('Pumpkin', 0.5));
    expect(half.part, isTrue);
    final one = ProductPicture.of(item('Pumpkin', 1));
    expect(one.part, isFalse);
  });

  testWidgets('4 potatoes are one heap drawing with ×4; 4 tins still fan out', (tester) async {
    final store = HouseholdStore(MemoryBackend());
    await store.load();
    Widget pile(StockItem i) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Center(child: ItemPile(item: i)),
      ),
    );
    await tester.pumpWidget(pile(item('Washed potatoes', 4)));
    expect(find.byKey(const ValueKey('pile-copy-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('pile-copy-1')), findsNothing);
    expect(find.text('×4'), findsOneWidget);
    final img = tester.widget<Image>(
      find.descendant(of: find.byKey(const ValueKey('picture-drawing')), matching: find.byType(Image)),
    );
    expect(
      (img.image as ResizeImage).imageProvider,
      isA<AssetImage>().having((a) => a.assetName, 'asset', 'assets/food/produce/potato-many.png'),
    );

    await tester.pumpWidget(pile(item('Washed potatoes', 1)));
    final one = tester.widget<Image>(
      find.descendant(of: find.byKey(const ValueKey('picture-drawing')), matching: find.byType(Image)),
    );
    expect(
      (one.image as ResizeImage).imageProvider,
      isA<AssetImage>().having((a) => a.assetName, 'asset', 'assets/food/produce/potato-1.png'),
    );
    expect(find.text('×1'), findsNothing);

    await tester.pumpWidget(pile(item('Baked beans', 4)));
    expect(find.byKey(const ValueKey('pile-copy-3')), findsOneWidget);
  });
}
