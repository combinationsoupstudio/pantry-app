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
    expect(draft.ingredients, ['chicken thighs', 'rice', 'lemon']);
    expect(draft.url, 'https://example.com/lemon-chicken');
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
}
