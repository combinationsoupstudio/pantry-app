import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_app/data/csv_import.dart';
import 'package:pantry_app/logic/insights.dart';
import 'package:pantry_app/logic/recipes.dart';
import 'package:pantry_app/models/models.dart';
import 'package:pantry_app/ui/pages/recipe_detail_page.dart';

StockItem item(String name, double qty, {double target = 0, String loc = 'pantry', DateTime? useBy}) => StockItem(
  id: name,
  name: name,
  locationId: loc,
  quantity: qty,
  unit: '',
  target: target,
  useBy: useBy,
  updatedAt: DateTime(2026),
  updatedBy: 'Chris',
);

void main() {
  group('csv', () {
    test('splits quoted cells and escaped quotes', () {
      expect(splitCsvLine('a,"b, c","say ""hi""",'), ['a', 'b, c', 'say "hi"', '']);
    });

    test('header is optional and blank location means Pantry', () {
      final parsed = parseStockCsv('Salt,,1,kg\n\n  \nFlour,Pantry,,kg,2');
      expect(parsed.rows.map((r) => r.name), ['Salt', 'Flour']);
      expect(parsed.rows.first.location, 'Pantry');
      expect(parsed.rows.last.quantity, 0);
      expect(parsed.rows.last.target, 2);
    });

    test('negative or non-numeric amounts are skipped', () {
      expect(parseStockCsv('A,Pantry,-1\nB,Pantry,x\nC,Pantry,1').rows.single.name, 'C');
    });

    test('escape quotes cells that need it', () {
      expect(csvEscape('plain'), 'plain');
      expect(csvEscape('a, b'), '"a, b"');
      expect(csvEscape('a "b"'), '"a ""b"""');
    });
  });

  group('recipes', () {
    test('matches whole words and plurals through aliases', () {
      final stock = [
        item('Spaghetti 500g', 2),
        item('Beef mince', 1),
        item('Diced tomatoes', 3),
        item('Brown onions', 4),
        item('Garlic', 1),
      ];
      final bolognese = matchRecipes(stock).firstWhere((m) => m.recipe.name == 'Spaghetti bolognese');
      expect(bolognese.ready, isTrue);
    });

    test('items with nothing left do not count', () {
      final stock = [item('Bread', 0), item('Baked beans', 2)];
      final beans = matchRecipes(stock).firstWhere((m) => m.recipe.name == 'Beans on toast');
      expect(beans.missing.map((i) => i.label), ['bread']);
    });

    test('does not match inside other words', () {
      expect(hasIngredient(const Ingredient('ham'), [item('Shampoo', 1)]), isFalse);
      expect(hasIngredient(const Ingredient('rice'), [item('Price list', 1)]), isFalse);
      expect(hasIngredient(const Ingredient('rice'), [item('Jasmine rice', 1)]), isTrue);
    });

    test('a missing ingredient still finds the stock item that ran out', () {
      const pasta = Ingredient('pasta', ['spaghetti']);
      final stock = [item('Spaghetti', 0)];
      expect(hasIngredient(pasta, stock), isFalse);
      expect(stockItemFor(pasta, stock)!.name, 'Spaghetti');
      expect(stockItemFor(pasta, stock, inStockOnly: true), isNull);
    });

    test('saved-recipe ingredients match stock both ways round', () {
      final saved = SavedRecipe(
        id: 'r',
        name: 'Garlic rice',
        ingredients: const ['garlic cloves', 'rice', 'rice wine'],
        addedBy: 'Chris',
        createdAt: DateTime(2026),
      );
      final m = matchRecipes([item('Garlic', 1), item('Jasmine rice', 2)], recipes: [Recipe.fromSaved(saved)]).single;
      expect(m.recipe.savedId, 'r');
      expect(m.have.map((i) => i.label), ['garlic cloves', 'rice']);
      expect(m.missing.map((i) => i.label), ['rice wine'], reason: 'rice wine is not rice');
    });

    test('sentence case', () {
      expect(sentenceCase('tinned tomatoes'), 'Tinned tomatoes');
      expect(sentenceCase(''), '');
    });

    test('ready recipes come first', () {
      final matches = matchRecipes([item('Bread', 1), item('Baked beans', 1)]);
      expect(matches.first.recipe.name, 'Beans on toast');
    });
  });

  group('insights', () {
    final now = DateTime(2026, 11, 15);
    const locations = [
      StockLocation(id: 'pantry', name: 'Pantry', kind: LocationKind.pantry),
      StockLocation(id: 'garage', name: 'Garage', kind: LocationKind.storage),
      StockLocation(id: 'empty', name: 'Empty', kind: LocationKind.storage),
    ];

    test('readiness, low and out counts', () {
      final ins = computeInsights(
        items: [item('A', 5, target: 5), item('B', 1, target: 4), item('C', 0, target: 2), item('D', 3)],
        locations: locations,
        activity: const [],
        now: now,
      );
      expect(ins.totalItems, 4);
      expect(ins.targeted, 3);
      expect(ins.readiness, closeTo(1 / 3, 1e-9));
      expect(ins.low, 2);
      expect(ins.out, 1);
      expect(ins.byLocation.map((s) => s.location.name), ['Pantry']);
    });

    test('no targets means no readiness score', () {
      final ins = computeInsights(items: [item('A', 1)], locations: locations, activity: const [], now: now);
      expect(ins.readiness, isNull);
    });

    test('use-by soon is within 14 days, skips empty items, soonest first', () {
      final ins = computeInsights(
        items: [
          item('Late', 1, useBy: now.add(const Duration(days: 30))),
          item('Soon', 1, useBy: now.add(const Duration(days: 3))),
          item('Past', 1, useBy: now.subtract(const Duration(days: 1))),
          item('Gone', 0, useBy: now),
        ],
        locations: locations,
        activity: const [],
        now: now,
      );
      expect(ins.useBySoon.map((i) => i.name), ['Past', 'Soon']);
    });

    test('most used counts only uses in the last 30 days', () {
      final ins = computeInsights(
        items: const [],
        locations: locations,
        activity: [
          ActivityEntry(at: now, who: 'Chris', itemName: 'Milk', action: 'used', delta: -2, unit: 'L'),
          ActivityEntry(at: now, who: 'Emily', itemName: 'Milk', action: 'used', delta: -1, unit: 'L'),
          ActivityEntry(at: now, who: 'Emily', itemName: 'Bread', action: 'used', delta: -1),
          ActivityEntry(at: now, who: 'Emily', itemName: 'Bread', action: 'topped up', delta: 5),
          ActivityEntry(
            at: now.subtract(const Duration(days: 40)),
            who: 'Chris',
            itemName: 'Rice',
            action: 'used',
            delta: -9,
          ),
        ],
        now: now,
      );
      expect(ins.mostUsed.map((u) => '${u.itemName} ${formatQty(u.used)}'), ['Milk 3', 'Bread 1']);
    });
  });

  test('formatQty drops trailing zeros', () {
    expect(formatQty(2), '2');
    expect(formatQty(1.5), '1.5');
    expect(formatQty(0.25), '0.25');
  });

  test('model JSON round-trips', () {
    final i = item('Rice', 2.5, target: 5, useBy: DateTime(2027, 1, 2));
    final back = StockItem.fromJson(i.toJson());
    expect(back.toJson(), i.toJson());
    const s = ShoppingItem(id: 's', name: 'Bread', quantity: 1, unit: '', store: Store.coles, addedBy: 'Emily');
    expect(ShoppingItem.fromJson(s.toJson()).toJson(), s.toJson());
  });

  test('method steps: one per line, typed numbering taken off', () {
    expect(methodSteps('1. Boil water\n\nStep 2: Add pasta\n3) Drain\nServe'), [
      'Boil water',
      'Add pasta',
      'Drain',
      'Serve',
    ]);
    expect(methodSteps(''), isEmpty);
  });
}
