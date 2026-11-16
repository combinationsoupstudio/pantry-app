import '../models/models.dart';
import 'amounts.dart';
import 'names.dart';
import 'recipe_link.dart';

/// One ingredient, with the words a stock item might be called.
class Ingredient {
  const Ingredient(this.label, [this.aliases = const [], String? line]) : _line = line;

  /// The name it is matched and shopped by, e.g. "pork belly".
  final String label;
  final List<String> aliases;
  final String? _line;

  /// The line as written, with its amount, e.g. "1 kg pork belly, skin on".
  String get line => _line ?? label;

  Iterable<String> get keywords => [label, ...aliases].map((k) => k.toLowerCase());
}

class Recipe {
  const Recipe({required this.name, required this.minutes, required this.ingredients, this.savedId});
  final String name;

  /// 0 when not known.
  final int minutes;
  final List<Ingredient> ingredients;

  /// The household's saved recipe this came from; null for a starter.
  final String? savedId;

  /// A saved recipe as something [matchRecipes] can match.
  factory Recipe.fromSaved(SavedRecipe saved) => Recipe(
    name: saved.name,
    minutes: saved.minutes ?? 0,
    ingredients: [
      for (final line in saved.ingredients)
        if (isIngredientLine(line)) Ingredient(_matchName(line), const [], cleanIngredientLine(line)),
    ],
    savedId: saved.id,
  );
}

/// An ingredient the household has some of, but not as much as the recipe
/// line asks for: "needs 100 ml, have 20 ml".
class Shortfall {
  const Shortfall(this.ingredient, this.item, this.need);
  final Ingredient ingredient;
  final StockItem item;

  /// What the line needs, in the item's unit.
  final double need;
  double get have => item.quantity;

  /// How much more is needed, in the item's unit.
  double get short => need - have;

  /// What goes on the list: whole packs for a measured item.
  double get toBuy => item.packsFor(short);

  /// "short 80 ml".
  String get label {
    final unit = const {'', 'items', 'item', 'each'}.contains(item.unit.trim().toLowerCase()) ? '' : item.unit;
    return 'short ${formatMeasure(double.parse(short.toStringAsFixed(2)), unit)}';
  }
}

class RecipeMatch {
  const RecipeMatch(this.recipe, this.have, this.missing, [this.short = const []]);
  final Recipe recipe;

  /// In stock, and enough of it where the line says how much.
  final List<Ingredient> have;

  /// Not in stock at all.
  final List<Ingredient> missing;

  /// In stock, but less than the line asks for.
  final List<Shortfall> short;

  /// How many things to buy before cooking it.
  int get toBuy => missing.length + short.length;

  bool get ready => toBuy == 0;
}

/// How much of [item] the ingredient [line] asks for, in the item's unit,
/// or null when the line gives no amount that converts ("1 cup rice"
/// against rice kept in kg, or "salt").
double? amountNeeded(String line, StockItem item) {
  final a = parseAmount(line);
  if (a == null) return null;
  if (a.unit.isEmpty && !isMeasureUnit(item.unit)) {
    // A plain count only compares when it counts the same thing: "3 eggs"
    // against eggs kept as items, "2 tins tomatoes" against tins; never
    // "2 garlic cloves" against garlic kept in bulbs.
    final unit = item.unit.trim().toLowerCase();
    if (!const {'', 'items', 'item', 'each', 'pcs', 'pieces'}.contains(unit)) {
      final word = RegExp(r'^[\d\s./¼½¾⅓⅔⅛]*([a-zA-Z]+)').firstMatch(line)?.group(1)?.toLowerCase() ?? '';
      String stem(String w) => w.endsWith('s') ? w.substring(0, w.length - 1) : w;
      if (stem(word) != stem(unit)) return null;
    }
  }
  return convertTo(a, item.unit);
}

String _matchName(String line) {
  final simple = simplifyIngredient(line);
  return simple.isEmpty ? line.toLowerCase() : simple;
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

/// The stock item an ingredient surely refers to, if the household tracks
/// one (names.dart: the same name, a name the household taught it, or one
/// inside the other with nothing that changes the thing). With [inStockOnly]
/// false it also finds items that have run out, which is what a shopping
/// line should be linked to. A close spelling is never used here; see
/// [closeStockFor].
StockItem? stockItemFor(Ingredient ingredient, List<StockItem> stock, {bool inStockOnly = false}) {
  NameMatch? best;
  for (final k in ingredient.keywords) {
    final m = matchName(k, stock, inStockOnly: inStockOnly, allowClose: false);
    if (m != null && (best == null || m.rank < best.rank)) best = m;
  }
  return best?.item;
}

/// A stock item the ingredient is close to but not surely ("spring onoins"
/// and Spring onions, "rice" and White rice): the app asks "Is this your …?".
/// Null when there is a sure match or nothing close.
NameMatch? closeStockFor(Ingredient ingredient, List<StockItem> stock) {
  if (stockItemFor(ingredient, stock) != null) return null;
  NameMatch? best;
  for (final k in ingredient.keywords) {
    final m = matchName(k, stock);
    if (m != null && !m.sure && (best == null || m.rank < best.rank)) best = m;
  }
  return best;
}

/// "tinned tomatoes" -> "Tinned tomatoes".
String sentenceCase(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// Every recipe with what we have and what is missing, best first.
List<RecipeMatch> matchRecipes(List<StockItem> stock, {List<Recipe> recipes = starterRecipes}) {
  final matches =
      recipes.map((r) {
        final have = <Ingredient>[];
        final missing = <Ingredient>[];
        final short = <Shortfall>[];
        for (final ing in r.ingredients) {
          final item = stockItemFor(ing, stock, inStockOnly: true);
          if (item == null) {
            missing.add(ing);
            continue;
          }
          final need = amountNeeded(ing.line, item);
          if (need != null && need > item.quantity + 1e-6) {
            short.add(Shortfall(ing, item, need));
          } else {
            have.add(ing);
          }
        }
        return RecipeMatch(r, have, missing, short);
      }).toList()..sort((a, b) {
        final byMissing = a.toBuy.compareTo(b.toBuy);
        return byMissing != 0 ? byMissing : a.recipe.name.compareTo(b.recipe.name);
      });
  return matches;
}
