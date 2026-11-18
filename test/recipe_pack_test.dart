import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pantry_app/app.dart';
import 'package:pantry_app/data/recipe_library.dart';
import 'package:pantry_app/logic/recipe_pack.dart';
import 'package:pantry_app/logic/recipes.dart';
import 'package:pantry_app/ui/pages/recipe_detail_page.dart';

import 'app_test.dart' show phoneSize, seededStore;
import 'logic_test.dart' show item;

RecipePack loadPack(String asset) => parseRecipePack(File(asset).readAsStringSync());

void main() {
  group('pack 01 (the starter recipes as shipped)', () {
    final pack = loadPack('assets/recipes/pack-01.txt');

    test('reads with no errors: 55 recipes, ids unique', () {
      expect(pack.errors, isEmpty);
      expect(pack.recipes.length, 55);
      final ids = pack.recipes.map((r) => r.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(recipePackAssets, contains('assets/recipes/pack-01.txt'));
    });

    test('every recipe is whole: serves, time, method, credit, marked untested', () {
      for (final r in pack.recipes) {
        expect(r.serves, greaterThan(0), reason: r.name);
        expect(r.minutes, greaterThan(0), reason: r.name);
        expect(r.steps.length, greaterThanOrEqualTo(3), reason: r.name);
        expect(r.ingredients.length, greaterThanOrEqualTo(3), reason: r.name);
        expect(r.tags, isNotEmpty, reason: r.name);
        expect(r.credit, isNotNull, reason: r.name);
        expect(r.untested, isTrue, reason: r.name);
      }
    });

    test('borrowed recipes carry their CC BY credit and a link; the rest are our own', () {
      final credited = pack.recipes.where((r) => r.credit!.text.contains('CC BY')).toList();
      expect(credited.length, 10);
      for (final r in credited) {
        expect(r.credit!.text, contains('Healthy New Communities Cookbook'));
        expect(r.credit!.url, startsWith('https://www.metrosouth.health.qld.gov.au/'));
      }
      expect(pack.recipes.where((r) => r.credit!.text.startsWith('Written for Pantry')).length, 45);
    });

    test('Australian metric only: no ounces, pounds, Fahrenheit or US sticks', () {
      final text = File('assets/recipes/pack-01.txt').readAsStringSync().toLowerCase();
      for (final bad in [RegExp(r'\d\s*oz\b'), RegExp(r'\d\s*lbs?\b'), RegExp(r'°f\b'), RegExp(r'\bstick of butter')]) {
        expect(bad.hasMatch(text), isFalse, reason: bad.pattern);
      }
    });

    test('no heading ever becomes an ingredient (headings must never reach the list)', () {
      for (final r in pack.recipes) {
        for (final i in r.ingredients) {
          expect(
            i.label,
            isNot(anyOf('ingredients', 'method', 'sauce', 'to serve', '')),
            reason: '${r.name}: ${i.line}',
          );
          expect(i.line.endsWith(':'), isFalse, reason: '${r.name}: ${i.line}');
          expect(RegExp(r'\d').hasMatch(i.label), isFalse, reason: '${r.name}: ${i.label}');
        }
      }
    });

    test('a real cupboard matches the names the recipes shop by', () {
      final stock = [
        for (final n in ['Garlic', 'Brown onion', 'Spring onions', 'Capsicum', 'Soy sauce', 'Chicken thighs', 'Rice'])
          item(n, 2),
      ];
      final sticky = pack.recipes.firstWhere((r) => r.id == 'sticky-soy-garlic-chicken');
      final m = matchRecipes(stock, recipes: [sticky]).single;
      expect(
        m.have.map((i) => i.label),
        containsAll(['chicken thighs', 'soy sauce', 'garlic', 'spring onions', 'rice']),
      );

      final burrito = pack.recipes.firstWhere((r) => r.id == 'breakfast-burritos');
      final b = matchRecipes(stock, recipes: [burrito]).single;
      expect(b.have.map((i) => i.label), contains('red capsicum'), reason: 'a plain Capsicum in stock does for red');
    });
  });

  group('pack 02 (more starter recipes, issue #30)', () {
    final pack = loadPack('assets/recipes/pack-02.txt');

    test('reads with no errors: 50 recipes, shipped', () {
      expect(pack.errors, isEmpty);
      expect(pack.recipes.length, 50);
      expect(recipePackAssets, contains('assets/recipes/pack-02.txt'));
    });

    test('every recipe is whole: serves, time, method, credit, marked untested', () {
      for (final r in pack.recipes) {
        expect(r.serves, greaterThan(0), reason: r.name);
        expect(r.minutes, greaterThan(0), reason: r.name);
        expect(r.steps.length, greaterThanOrEqualTo(3), reason: r.name);
        expect(r.ingredients.length, greaterThanOrEqualTo(3), reason: r.name);
        expect(r.tags, isNotEmpty, reason: r.name);
        expect(r.credit, isNotNull, reason: r.name);
        expect(r.untested, isTrue, reason: r.name);
      }
    });

    test('borrowed recipes carry their CC BY credit and a link; the rest are our own', () {
      final credited = pack.recipes.where((r) => r.credit!.text.contains('CC BY')).toList();
      expect(credited.length, 15);
      for (final r in credited) {
        expect(r.credit!.text, contains('Healthy New Communities Cookbook'));
        expect(r.credit!.url, startsWith('https://www.metrosouth.health.qld.gov.au/'));
      }
      expect(pack.recipes.where((r) => r.credit!.text.startsWith('Written for Pantry')).length, 35);
    });

    test('Australian metric only: no ounces, pounds, Fahrenheit or US sticks', () {
      final text = File('assets/recipes/pack-02.txt').readAsStringSync().toLowerCase();
      for (final bad in [RegExp(r'\d\s*oz\b'), RegExp(r'\d\s*lbs?\b'), RegExp(r'°f\b'), RegExp(r'\bstick of butter')]) {
        expect(bad.hasMatch(text), isFalse, reason: bad.pattern);
      }
    });

    test('no heading ever becomes an ingredient', () {
      for (final r in pack.recipes) {
        for (final i in r.ingredients) {
          expect(
            i.label,
            isNot(anyOf('ingredients', 'method', 'sauce', 'to serve', '')),
            reason: '${r.name}: ${i.line}',
          );
          expect(i.line.endsWith(':'), isFalse, reason: '${r.name}: ${i.line}');
          expect(RegExp(r'\d').hasMatch(i.label), isFalse, reason: '${r.name}: ${i.label}');
        }
      }
    });

    test('the house recipe is in: Smoko burritos', () {
      final smoko = pack.recipes.firstWhere((r) => r.id == 'smoko-burritos');
      expect(smoko.credit!.text, startsWith('Written for Pantry'));
      expect(smoko.ingredients.map((i) => i.group).toSet(), containsAll(['Smoko sauce', 'Seasoning', 'Meat']));
    });
  });

  group('every shipped pack together', () {
    final packs = [for (final a in recipePackAssets) loadPack(a)];
    final all = [for (final p in packs) ...p.recipes];

    test('no id and no recipe name is used twice across packs', () {
      final ids = all.map((r) => r.id).toList();
      final names = all.map((r) => r.name.toLowerCase()).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate id');
      expect(names.toSet().length, names.length, reason: 'duplicate name');
    });

    test('the library holds every pack recipe', () {
      final library = buildStarterLibrary(packs);
      expect(library.where((r) => r.credit != null).length, all.length);
      expect(all.length, greaterThanOrEqualTo(105));
    });
  });

  group('the format', () {
    const sample = '''
@credit original: Written for Pantry.
=== Test fritters
id: test
serves: 2
minutes: 10
tags: lunch
credit: original
-- Fritters
- 1 cup self-raising flour | self-raising flour; flour
- 2 eggs
-- Smash
- 1 lemon
~ salt
> Mix.
> Fry.
note: Keep the heat low.
''';

    test('groups ride along with their lines; basics are marked', () {
      final p = parseRecipePack(sample);
      expect(p.errors, isEmpty);
      final r = p.recipes.single;
      expect(r.ingredients.map((i) => i.group), ['Fritters', 'Fritters', 'Smash', 'Smash']);
      expect(r.ingredients.first.label, 'self-raising flour');
      expect(r.ingredients.first.aliases, ['flour']);
      expect(r.ingredients[1].label, 'eggs');
      expect(r.ingredients.last.basic, isTrue);
      expect(r.notes, ['Keep the heat low.']);
      expect(r.steps, ['Mix.', 'Fry.']);
    });

    test('a heading written as an ingredient is refused, with its line number', () {
      final p = parseRecipePack(sample.replaceFirst('- 2 eggs', '- Ingredients:'));
      expect(p.errors.single, startsWith('line 10:'));
      expect(p.recipes.single.ingredients.map((i) => i.label), isNot(contains('ingredients')));
    });

    test('missing parts and unknown credits are reported, not hidden', () {
      final p = parseRecipePack('=== Bare\nid: bare\ncredit: nobody\n- 1 onion\n');
      expect(p.errors.join('\n'), allOf(contains('no serves'), contains('no method'), contains('unknown credit')));
    });

    test('salt nobody tracks is assumed; salt that ran out goes on the list', () {
      final r = parseRecipePack(sample).recipes.single;
      final untracked = matchRecipes(
        [item('Eggs', 6), item('Self-raising flour', 1), item('Lemon', 1)],
        recipes: [r],
      ).single;
      expect(untracked.ready, isTrue);
      expect(untracked.assumed.single.label, 'salt');

      final ranOut = matchRecipes(
        [item('Eggs', 6), item('Self-raising flour', 1), item('Lemon', 1), item('Salt', 0)],
        recipes: [r],
      ).single;
      expect(ranOut.missing.single.label, 'salt');
    });

    test('the library puts pack recipes first and drops short ideas they replace', () {
      final pack = parseRecipePack(
        sample.replaceFirst('=== Test fritters', '=== Chilli con carne').replaceFirst('id: test', 'id: ccc'),
      );
      final library = buildStarterLibrary([pack]);
      expect(library.first.id, 'ccc');
      expect(library.where((r) => r.name == 'Chilli con carne').length, 1);
      expect(library.any((r) => r.name == 'Beans on toast'), isTrue);
    });
  });

  group('on the phone', () {
    setUp(() => starterLibrary = buildStarterLibrary([loadPack('assets/recipes/pack-01.txt')]));
    tearDown(() => starterLibrary = starterRecipes);

    testWidgets('browse every starter, filter, open one: method, untested, credit', (tester) async {
      phoneSize(tester);
      final store = await seededStore();
      await tester.pumpWidget(PantryApp(store: store));
      await tester.tap(find.byKey(const ValueKey('nav-recipes')));
      await tester.pumpAndSettle();

      final browse = find.byKey(const ValueKey('browse-starters'));
      await tester.scrollUntilVisible(browse, 300, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Browse all ${starterLibrary.length} starter recipes'), findsOneWidget);
      await tester.tap(browse);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('starter-search')), 'doro');
      await tester.pumpAndSettle();
      expect(find.textContaining('1 recipe,'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('recipe-Doro wat')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-method')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('untested')), findsOneWidget);
      expect(find.textContaining('Hard-boil the eggs'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('recipe-credit')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.textContaining('CC BY 4.0'), findsOneWidget);
    });

    testWidgets('a pack recipe adds what is missing, never salt or a heading', (tester) async {
      phoneSize(tester);
      final store = await seededStore();
      final shakshuka = starterLibrary.firstWhere((r) => r.id == 'shakshuka');
      await tester.pumpWidget(PantryApp(store: store));
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(MaterialPageRoute<void>(builder: (_) => RecipeDetailPage.starter(recipe: shakshuka)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-missing')));
      await tester.pumpAndSettle();
      final names = store.shopping.map((l) => l.name.toLowerCase()).toList();
      expect(names, isNotEmpty);
      expect(names, isNot(contains('salt')));
      expect(names.any((n) => n.contains('ingredient') || n.contains('method')), isFalse);
    });
  });
}
