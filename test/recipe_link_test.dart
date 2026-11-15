import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_app/logic/recipe_link.dart';

/// A made-up page in the shape recipe sites publish (schema.org JSON-LD).
String page(Object jsonLd) =>
    '<html><head><script type="application/ld+json">${jsonEncode(jsonLd)}</script></head>'
    '<body><h1>Test</h1></body></html>';

void main() {
  group('simplifyIngredient keeps what you would look for in a shop', () {
    const cases = {
      '500g / 1 lb chicken thighs, skinless': 'chicken thighs',
      '2 tbsp soy sauce (light or all purpose)': 'soy sauce',
      '1 1/2 cups (300g) jasmine rice': 'jasmine rice',
      '3 garlic cloves, finely minced': 'garlic cloves',
      '1 large onion, diced': 'onion',
      'Salt and pepper': 'salt and pepper',
      '400g/14oz can crushed tomatoes': 'crushed tomatoes',
      '½ cup grated parmesan, plus extra to serve': 'parmesan',
      '2 x 400g tins chickpeas, drained': 'chickpeas',
      'Fresh coriander, to serve': 'coriander',
      '1 tsp ground cumin': 'ground cumin',
      'Oil spray': 'oil spray',
    };
    cases.forEach((raw, expected) {
      test(raw, () => expect(simplifyIngredient(raw), expected));
    });
  });

  test('ISO durations become minutes', () {
    expect(parseIsoMinutes('PT1H30M'), 90);
    expect(parseIsoMinutes('PT45M'), 45);
    expect(parseIsoMinutes('P0DT2H'), 120);
    expect(parseIsoMinutes(''), isNull);
    expect(parseIsoMinutes('soon'), isNull);
  });

  test('reads a recipe inside a @graph, with total time', () {
    final draft = parseRecipeHtml(
      page({
        '@context': 'https://schema.org',
        '@graph': [
          {'@type': 'WebPage', 'name': 'Not this'},
          {
            '@type': ['Recipe'],
            'name': 'Test Lemon Chicken &amp; Rice',
            'totalTime': 'PT40M',
            'recipeIngredient': ['600g chicken thighs', '1 cup rice', '1 lemon, juiced', '2 cups rice'],
            'recipeInstructions': [
              {'@type': 'HowToStep', 'text': 'Instructions are never read.'},
            ],
          },
        ],
      }),
      'https://example.com/lemon-chicken',
    )!;
    expect(draft.name, 'Test Lemon Chicken & Rice');
    expect(draft.minutes, 40);
    expect(draft.ingredients, ['600g chicken thighs', '1 cup rice', '1 lemon, juiced']);
    expect(draft.url, 'https://example.com/lemon-chicken');
    expect(draft.printUrl, isNull);
  });

  test('adds prep and cook time when there is no total', () {
    final draft = parseRecipeHtml(
      page({
        '@type': 'Recipe',
        'name': 'Soup',
        'prepTime': 'PT10M',
        'cookTime': 'PT20M',
        'recipeIngredient': ['1 carrot'],
      }),
      'https://example.com/soup',
    )!;
    expect(draft.minutes, 30);
  });

  test('a page with no recipe data gives null, and bad JSON is skipped', () {
    expect(parseRecipeHtml('<html><body>Hello</body></html>', 'https://example.com'), isNull);
    const broken = '<script type="application/ld+json">{not json</script>';
    expect(parseRecipeHtml(broken + page({'@type': 'Recipe', 'name': 'Ok'}), 'https://example.com')!.name, 'Ok');
  });

  test('finds the print view of the recipe card', () {
    final html =
        '<a href="https://example.com/wprm_print/soup" class="print">Print</a>${page({
          '@type': 'Recipe',
          'name': 'Soup',
          'recipeIngredient': ['1 carrot'],
        })}';
    expect(parseRecipeHtml(html, 'https://example.com/soup')!.printUrl, 'https://example.com/wprm_print/soup');
  });

  test('tick boxes and bullets copied from a page are stripped', () {
    expect(cleanIngredientLine('\u25A21 tsp salt'), '1 tsp salt');
    expect(cleanIngredientLine(' \u2022  2 eggs '), '2 eggs');
    expect(cleanIngredientLine('- 1 cup  rice'), '1 cup rice');
  });

  group('isIngredientLine keeps ingredients and drops page clutter', () {
    const keep = [
      '1 kg pork belly, skin on',
      'Salt and pepper',
      'apple sauce',
      '2 x 400g tins chickpeas, drained',
      '1/2 tsp fennel powder / ground fennel seeds',
      'Fresh coriander',
    ];
    const drop = [
      'Ingredients',
      'INSTRUCTIONS',
      'Method:',
      'For serving (as pictured):',
      'Recipe notes:',
      'Cook mode',
      'Prevent screen from sleeping',
      'Reply',
      'Next post',
      'Hi, I am the cook!',
      'Did you make this recipe?',
      'October 6, 2026 at 6:02 pm',
      '1,027 comments',
      '5 stars Great recipe, will make again',
      'Calories: 500kcal (25%)',
      'Keywords: pork, roast',
      'This is how they start off every single morning in the kitchen at our place',
      'Preheat the oven. Dry the skin well. Rub with oil and salt.',
      'Visit https://example.com for more',
    ];
    for (final line in keep) {
      test('keeps "$line"', () => expect(isIngredientLine(line), isTrue));
    }
    for (final line in drop) {
      test('drops "$line"', () => expect(isIngredientLine(line), isFalse));
    }
  });
}
