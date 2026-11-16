import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/data/storage_backend.dart';
import 'package:pantry_app/data/store_scope.dart';
import 'package:pantry_app/logic/names.dart';
import 'package:pantry_app/logic/receipt_parse.dart';
import 'package:pantry_app/logic/recipes.dart';
import 'package:pantry_app/models/models.dart';
import 'package:pantry_app/ui/pages/recipe_detail_page.dart';
import 'package:pantry_app/ui/theme.dart';

StockItem item(String name, {double qty = 1, List<String> aliases = const [], List<String> not = const []}) =>
    StockItem(
      id: name,
      name: name,
      locationId: 'pantry',
      quantity: qty,
      unit: '',
      target: 0,
      updatedAt: DateTime(2026),
      updatedBy: 'Chris',
      aliases: aliases,
      notAliases: not,
    );

void main() {
  group('canonical names', () {
    test('case, plurals and punctuation do not matter', () {
      expect(canonicalName('Spring Onions!'), 'spring onion');
      expect(canonicalName('POTATOES'), 'potato');
      expect(canonicalName('Berries'), 'berry');
      expect(canonicalName('Loaves'), 'loaf');
      expect(canonicalName("Kellogg's Corn Flakes"), canonicalName('kelloggs corn flakes'));
      expect(canonicalName('Tins: tomatoes'), 'tin tomato');
      expect(canonicalName('canned tomatoes'), 'tin tomato');
    });

    test('Australian names and the names that mean the same fold together', () {
      for (final same in [
        ['Shallots', 'spring onions', 'scallions', 'green onions'],
        ['Capsicum', 'bell peppers'],
        ['Coriander', 'cilantro'],
        ['Cornflour', 'cornstarch'],
        ['Bicarb soda', 'baking soda', 'bicarbonate of soda'],
        ['Panadol', 'paracetamol'],
        ['Glad wrap', 'cling wrap', 'plastic wrap'],
        ['Zucchini', 'courgettes'],
        ['Yoghurt', 'yogurt'],
      ]) {
        final keys = same.map(canonicalName).toSet();
        expect(keys, hasLength(1), reason: '$same -> $keys');
      }
      // Eschalots (french shallots) are their own thing.
      expect(canonicalName('french shallots'), isNot(canonicalName('shallots')));
    });

    test('edit distance counts a swap as one', () {
      expect(editDistance('onoin', 'onion'), 1);
      expect(editDistance('spagetti', 'spaghetti'), 1);
      expect(editDistance('rice', 'mice'), 1);
    });
  });

  group('matching what is typed to what is kept', () {
    final stock = [
      item('Shallots'),
      item('Jasmine rice'),
      item('Spaghetti 500g'),
      item('Garlic'),
      item('Milk'),
      item('Onions'),
      item('Chicken'),
      item('Torch'),
    ];

    NameMatch? m(String q) => matchName(q, stock);

    test('the same thing under another name is sure', () {
      expect(m('spring onions')!.item.name, 'Shallots');
      expect(m('spring onions')!.sure, isTrue);
      expect(m('SCALLIONS')!.item.name, 'Shallots');
      expect(m('rice')!.item.name, 'Jasmine rice', reason: 'a kind of rice');
      expect(m('rice')!.sure, isTrue);
      expect(m('spaghetti')!.item.name, 'Spaghetti 500g');
      expect(m('garlic cloves')!.item.name, 'Garlic');
      expect(m('garlic cloves')!.sure, isTrue);
    });

    test('a spelling slip is close, never sure', () {
      final slip = m('spring onoins')!;
      expect(slip.item.name, 'Shallots');
      expect(slip.sure, isFalse);
      expect(m('spagetti')!.item.name, 'Spaghetti 500g');
      expect(m('spagetti')!.sure, isFalse);
      expect(m('garlik')!.sure, isFalse);
    });

    test('a different thing is not matched, or only asked about', () {
      expect(m('rice wine'), isNull);
      expect(m('chicken stock'), isNull, reason: 'stock is not chicken');
      expect(m('torch batteries'), isNull);
      // Same last word but its own thing: asked, never sure.
      expect(m('coconut milk')?.sure, isNot(isTrue));
      // Short words must match exactly: rice is not mice, ham is not jam.
      expect(matchName('mice', [item('Rice')]), isNull);
      expect(matchName('jam', [item('Ham')]), isNull);
      // Spring onions are not onions.
      expect(matchName('spring onions', [item('Onions')])?.sure, isNot(isTrue));
    });

    test('a taught name is sure; a rejected one is never guessed again', () {
      expect(
        matchName('scallys', [
          item('Shallots', aliases: ['scallys']),
        ])!.sure,
        isTrue,
      );
      expect(
        matchName('spring onoins', [
          item('Shallots', not: ['spring onoins']),
        ]),
        isNull,
      );
    });

    test('recipes count only sure matches; close ones are asked about', () {
      const ing = Ingredient('spring onoins');
      expect(stockItemFor(ing, stock), isNull);
      expect(closeStockFor(ing, stock)!.item.name, 'Shallots');
      expect(stockItemFor(const Ingredient('spring onions'), stock)!.name, 'Shallots');
    });

    test('receipts use the same names', () {
      expect(matchStock('WW SPRING ONIONS BUNCH', [item('Shallots')])?.name, 'Shallots');
      expect(
        matchStock('KIKKOMAN TAMARI 250ML', [
          item('Gluten free soy', aliases: ['tamari']),
        ])?.name,
        'Gluten free soy',
      );
    });
  });

  group('the household learns', () {
    test('yes teaches the name, no rejects it, and both sync as item data', () async {
      final store = HouseholdStore(MemoryBackend());
      await store.load();
      final s = await store.addItem(name: 'Shallots', locationId: 'pantry', quantity: 2);
      expect(store.matchFor('spring onoins')!.sure, isFalse);
      await store.teachName(s.id, 'spring onoins');
      expect(store.itemByName('spring onoins')!.id, s.id);
      expect(store.item(s.id)!.toJson()['aliases'], ['spring onoins']);

      await store.rejectName(s.id, 'spring onoins');
      expect(store.itemByName('spring onoins'), isNull);
      expect(store.matchFor('spring onoins'), isNull);
      expect(store.item(s.id)!.aliases, isEmpty);
      expect(store.item(s.id)!.notAliases, ['spring onoins']);
    });

    test('a shopping line typed another way joins the same stock', () async {
      final store = HouseholdStore(MemoryBackend());
      await store.load();
      final s = await store.addItem(name: 'Shallots', locationId: 'pantry', quantity: 0, target: 2);
      final line = await store.addShopping(name: 'spring onions');
      expect(line.stockItemId, s.id);
      await store.addShopping(name: 'Shallots');
      expect(store.shopping, hasLength(1), reason: 'stacked onto the same line');
    });
  });

  testWidgets('a recipe line asks "Is it your …?" and remembers the answer', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final store = HouseholdStore(MemoryBackend());
    await store.load();
    final s = await store.addItem(name: 'Shallots', locationId: 'pantry', quantity: 2);
    final r = await store.addRecipe(name: 'Fried rice', ingredients: ['2 spring onoins', '1 cup rice']);
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: RecipeDetailPage(recipeId: r.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Is it your Shallots?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('close-yes-spring onoins')));
    await tester.pumpAndSettle();
    expect(find.text('Is it your Shallots?'), findsNothing);
    expect(find.text('You have: Shallots'), findsOneWidget);
    expect(store.item(s.id)!.aliases, ['spring onoins']);
  });
}
