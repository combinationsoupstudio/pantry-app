import '../models/models.dart';

/// One ingredient, with the words a stock item might be called.
class Ingredient {
  const Ingredient(this.label, [this.aliases = const []]);
  final String label;
  final List<String> aliases;

  Iterable<String> get keywords => [label, ...aliases].map((k) => k.toLowerCase());
}

class Recipe {
  const Recipe({required this.name, required this.minutes, required this.ingredients});
  final String name;
  final int minutes;
  final List<Ingredient> ingredients;
}

class RecipeMatch {
  const RecipeMatch(this.recipe, this.have, this.missing);
  final Recipe recipe;
  final List<Ingredient> have;
  final List<Ingredient> missing;

  bool get ready => missing.isEmpty;
}

/// Starter recipes until the AI phase. Kept short and pantry-friendly.
const starterRecipes = <Recipe>[
  Recipe(
    name: 'Spaghetti bolognese',
    minutes: 40,
    ingredients: [
      Ingredient('pasta', ['spaghetti', 'penne', 'fettuccine']),
      Ingredient('mince', ['beef mince']),
      Ingredient('tinned tomatoes', ['diced tomatoes', 'crushed tomatoes', 'passata', 'tomato']),
      Ingredient('onion'),
      Ingredient('garlic'),
    ],
  ),
  Recipe(
    name: 'Fried rice',
    minutes: 25,
    ingredients: [
      Ingredient('rice'),
      Ingredient('eggs', ['egg']),
      Ingredient('frozen peas', ['peas', 'mixed vegetables', 'frozen veg']),
      Ingredient('soy sauce'),
    ],
  ),
  Recipe(
    name: 'Tuna pasta bake',
    minutes: 35,
    ingredients: [
      Ingredient('pasta', ['penne', 'macaroni', 'spirals']),
      Ingredient('tuna'),
      Ingredient('cheese', ['tasty cheese', 'grated cheese']),
      Ingredient('tinned tomatoes', ['diced tomatoes', 'passata', 'tomato']),
    ],
  ),
  Recipe(
    name: 'Pancakes',
    minutes: 20,
    ingredients: [
      Ingredient('flour', ['plain flour', 'self raising flour']),
      Ingredient('milk', ['long life milk', 'powdered milk']),
      Ingredient('eggs', ['egg']),
      Ingredient('sugar'),
    ],
  ),
  Recipe(
    name: 'Chicken curry',
    minutes: 45,
    ingredients: [
      Ingredient('chicken'),
      Ingredient('curry paste', ['curry powder']),
      Ingredient('coconut milk', ['coconut cream']),
      Ingredient('rice'),
      Ingredient('onion'),
    ],
  ),
  Recipe(
    name: 'Beans on toast',
    minutes: 10,
    ingredients: [
      Ingredient('baked beans', ['beans']),
      Ingredient('bread'),
    ],
  ),
  Recipe(
    name: 'Cheese omelette',
    minutes: 10,
    ingredients: [
      Ingredient('eggs', ['egg']),
      Ingredient('cheese'),
      Ingredient('milk'),
    ],
  ),
  Recipe(
    name: 'Porridge',
    minutes: 10,
    ingredients: [
      Ingredient('oats', ['rolled oats', 'porridge']),
      Ingredient('milk', ['long life milk', 'powdered milk']),
      Ingredient('honey', ['sugar', 'golden syrup']),
    ],
  ),
  Recipe(
    name: 'Lentil soup',
    minutes: 40,
    ingredients: [
      Ingredient('lentils', ['red lentils']),
      Ingredient('onion'),
      Ingredient('carrot', ['carrots']),
      Ingredient('stock', ['stock cubes', 'broth']),
    ],
  ),
  Recipe(
    name: 'Chilli con carne',
    minutes: 45,
    ingredients: [
      Ingredient('mince', ['beef mince']),
      Ingredient('kidney beans', ['red kidney beans', 'mixed beans']),
      Ingredient('tinned tomatoes', ['diced tomatoes', 'crushed tomatoes', 'tomato']),
      Ingredient('onion'),
      Ingredient('chilli', ['chilli powder', 'taco seasoning']),
    ],
  ),
  Recipe(
    name: 'Ham and cheese toasties',
    minutes: 10,
    ingredients: [Ingredient('bread'), Ingredient('cheese'), Ingredient('ham')],
  ),
  Recipe(
    name: 'Noodle stir fry',
    minutes: 20,
    ingredients: [
      Ingredient('noodles', ['instant noodles', 'egg noodles', 'rice noodles']),
      Ingredient('soy sauce'),
      Ingredient('frozen vegetables', ['mixed vegetables', 'frozen veg', 'stir fry vegetables']),
      Ingredient('garlic'),
    ],
  ),
];

/// True when a stock item with some quantity left matches the ingredient.
bool hasIngredient(Ingredient ingredient, List<StockItem> stock) =>
    stockItemFor(ingredient, stock, inStockOnly: true) != null;

/// The stock item an ingredient refers to, if the household tracks one.
/// With [inStockOnly] false it also finds items that have run out, which is
/// what a shopping line should be linked to.
StockItem? stockItemFor(Ingredient ingredient, List<StockItem> stock, {bool inStockOnly = false}) {
  StockItem? fallback;
  for (final item in stock) {
    final name = item.name.toLowerCase();
    if (!ingredient.keywords.any((k) => _containsWord(name, k))) continue;
    if (!item.isOut) return item;
    if (!inStockOnly) fallback ??= item;
  }
  return fallback;
}

/// "tinned tomatoes" -> "Tinned tomatoes".
String sentenceCase(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

bool _containsWord(String haystack, String needle) {
  final pattern = RegExp('(^|[^a-z])${RegExp.escape(needle)}s?(\$|[^a-z])');
  return pattern.hasMatch(haystack);
}

/// Every recipe with what we have and what is missing, best first.
List<RecipeMatch> matchRecipes(List<StockItem> stock, {List<Recipe> recipes = starterRecipes}) {
  final matches =
      recipes.map((r) {
        final have = <Ingredient>[];
        final missing = <Ingredient>[];
        for (final ing in r.ingredients) {
          (hasIngredient(ing, stock) ? have : missing).add(ing);
        }
        return RecipeMatch(r, have, missing);
      }).toList()..sort((a, b) {
        final byMissing = a.missing.length.compareTo(b.missing.length);
        return byMissing != 0 ? byMissing : a.recipe.name.compareTo(b.recipe.name);
      });
  return matches;
}
