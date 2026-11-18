import 'recipe_link.dart';
import 'recipes.dart';

/// A recipe pack: the app's own starter recipes with full methods, kept as
/// plain text in assets/recipes/ so they can be read and edited without code.
/// The format is in docs/recipe-pack-format.md.
class RecipePack {
  const RecipePack(this.recipes, this.credits, this.errors);
  final List<Recipe> recipes;
  final Map<String, RecipeCredit> credits;

  /// Lines that could not be read, with their line numbers. A pack with
  /// errors still loads what it could; the tests insist on none.
  final List<String> errors;
}

/// Words that are a heading, never an ingredient (they must never reach the
/// shopping list).
const _headingWords = {'ingredients', 'method', 'to serve', 'for the sauce', 'sauce', 'notes', 'garnish'};

RecipePack parseRecipePack(String text) {
  final credits = <String, RecipeCredit>{};
  final recipes = <Recipe>[];
  final errors = <String>[];
  final ids = <String>{};

  _Draft? draft;
  void finish() {
    final d = draft;
    if (d == null) return;
    draft = null;
    final where = '"${d.name}" (line ${d.line})';
    if (d.id == null || d.id!.isEmpty) errors.add('$where has no id');
    if (d.id != null && !ids.add(d.id!)) errors.add('$where repeats the id ${d.id}');
    if (d.serves <= 0) errors.add('$where has no serves');
    if (d.minutes <= 0) errors.add('$where has no minutes');
    if (d.ingredients.isEmpty) errors.add('$where has no ingredients');
    if (d.steps.isEmpty) errors.add('$where has no method');
    final credit = credits[d.creditKey];
    if (credit == null) errors.add('$where has an unknown credit "${d.creditKey}"');
    recipes.add(
      Recipe(
        name: d.name,
        id: d.id,
        minutes: d.minutes,
        serves: d.serves,
        ingredients: List.unmodifiable(d.ingredients),
        steps: List.unmodifiable(d.steps),
        tags: List.unmodifiable(d.tags),
        notes: List.unmodifiable(d.notes),
        credit: credit,
        untested: true,
      ),
    );
  }

  final lines = text.split('\n');
  for (var n = 0; n < lines.length; n++) {
    final raw = lines[n].trimRight();
    final line = raw.trim();
    final at = n + 1;
    if (line.isEmpty || line.startsWith('#')) continue;

    if (line.startsWith('@credit ')) {
      final m = RegExp(r'^@credit\s+([\w-]+):\s*(.+)$').firstMatch(line);
      if (m == null) {
        errors.add('line $at: a credit needs "@credit key: text"');
        continue;
      }
      final parts = m.group(2)!.split('|');
      final url = parts.length > 1 ? parts[1].trim() : null;
      credits[m.group(1)!] = RecipeCredit(parts[0].trim(), url == null || url.isEmpty ? null : url);
      continue;
    }

    if (line.startsWith('=== ')) {
      finish();
      draft = _Draft(line.substring(4).trim(), at);
      continue;
    }

    final d = draft;
    if (d == null) {
      errors.add('line $at: "$line" is outside a recipe');
      continue;
    }

    if (line.startsWith('-- ')) {
      d.group = line.substring(3).trim();
    } else if (line.startsWith('- ') || line.startsWith('~ ')) {
      final ing = _ingredient(line.substring(2), group: d.group, basic: line.startsWith('~'));
      if (ing == null) {
        errors.add('line $at: "$line" is a heading or has no name; use "-- Heading" for headings');
      } else {
        d.ingredients.add(ing);
      }
    } else if (line.startsWith('> ')) {
      d.steps.add(line.substring(2).trim());
    } else {
      final m = RegExp(r'^(id|serves|minutes|tags|credit|note):\s*(.*)$').firstMatch(line);
      if (m == null) {
        errors.add('line $at: "$line" is not part of the format');
        continue;
      }
      final value = m.group(2)!.trim();
      switch (m.group(1)) {
        case 'id':
          d.id = value;
        case 'serves':
          d.serves = int.tryParse(value) ?? 0;
        case 'minutes':
          d.minutes = int.tryParse(value) ?? 0;
        case 'tags':
          d.tags.addAll(value.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty));
        case 'credit':
          d.creditKey = value;
        case 'note':
          d.notes.add(value);
      }
    }
  }
  finish();
  return RecipePack(recipes, credits, errors);
}

/// "1 onion, sliced" or "3 garlic cloves | garlic; garlic cloves". The part
/// after "|" is the name it is shopped by, then other names it may be kept
/// under; without it the name is worked out from the line.
Ingredient? _ingredient(String text, {String? group, bool basic = false}) {
  final parts = text.split('|');
  final line = parts.first.trim();
  final names = parts.length > 1
      ? parts[1].split(';').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toList()
      : <String>[];
  final label = names.isNotEmpty ? names.first : (basic ? line.toLowerCase() : simplifyIngredient(line));
  final bare = line.toLowerCase().replaceAll(RegExp(r':$'), '');
  if (label.isEmpty || line.endsWith(':') || _headingWords.contains(bare)) return null;
  return Ingredient.pack(label, names.skip(1).toList(), line, group: group, basic: basic);
}

class _Draft {
  _Draft(this.name, this.line);
  final String name;
  final int line;
  String? id;
  int serves = 0;
  int minutes = 0;
  String creditKey = '';
  String? group;
  final ingredients = <Ingredient>[];
  final steps = <String>[];
  final tags = <String>[];
  final notes = <String>[];
}

/// The starter library: every pack recipe, then the short ideas whose names
/// no pack recipe already has.
List<Recipe> buildStarterLibrary(List<RecipePack> packs) {
  final fromPacks = [for (final p in packs) ...p.recipes];
  final names = {for (final r in fromPacks) r.name.toLowerCase()};
  return [...fromPacks, ...starterRecipes.where((r) => !names.contains(r.name.toLowerCase()))];
}
