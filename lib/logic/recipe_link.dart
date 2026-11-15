/// Reads the recipe name, time and ingredient list from a recipe page's
/// schema.org data (the JSON-LD block that recipe sites publish for search
/// engines). The method is deliberately not read: it stays on the site, and
/// the app opens the page for it. See docs/adr/0004-saved-recipes.md.
library;

import 'dart:convert';

class RecipeDraft {
  const RecipeDraft({required this.name, required this.ingredients, this.minutes, required this.url, this.printUrl});
  final String name;

  /// Ingredient lines with their amounts, tidied, ready for the person to check.
  final List<String> ingredients;
  final int? minutes;
  final String url;

  /// The site's print view of the recipe card, if it has one: the recipe
  /// alone, without the article around it.
  final String? printUrl;
}

/// Strips the tick boxes and bullets that come along when a list is copied
/// from a web page, decodes entities and tidies spacing.
String cleanIngredientLine(String raw) => _decodeEntities(raw)
    .replaceAll(RegExp('[\u25A2\u2610\u25A1\u25FB\u25FD\u2B1C\u2022\u25AA\u25CF\u2713\u2714\u2705\u00A0\u200B]'), ' ')
    .replaceAll(RegExp(r'^[-*\s]+'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

const _notIngredients = {
  'ingredients',
  'ingredient',
  'instructions',
  'method',
  'directions',
  'steps',
  'notes',
  'recipe notes',
  'nutrition',
  'nutrition information',
  'equipment',
  'servings',
  'serves',
  'yield',
  'keywords',
  'course',
  'cuisine',
  'cook mode',
  'prevent screen from sleeping',
  'print',
  'print recipe',
  'pin',
  'pin recipe',
  'save',
  'save recipe',
  'jump to recipe',
  'rate this recipe',
  'reply',
  'comment',
  'comments',
  'leave a comment',
  'read more',
  'next post',
  'previous post',
  'video',
  'watch how to make it',
  'share',
  'prep time',
  'cook time',
  'total time',
  'author',
  'garnish',
  'to serve',
  'optional',
  'sauce',
  'marinade',
  'dressing',
  'topping',
  'filling',
  'for the sauce',
  'name',
  'email',
  'website',
};
const _months = r'(january|february|march|april|may|june|july|august|september|october|november|december)';

/// False for a line that is not an ingredient: a heading ("Ingredients",
/// "For serving:"), page furniture ("Cook mode", "Reply"), a comment, a date,
/// nutrition or a sentence. Used wherever lines become ingredients or
/// shopping items, so none of that ever reaches the list.
bool isIngredientLine(String raw) {
  final line = cleanIngredientLine(raw);
  if (line.isEmpty || line.length > 120) return false;
  final lower = line.toLowerCase();
  if (lower.endsWith(':')) return false;
  final bare = lower.replaceAll(RegExp(r'[^a-z ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (bare.isEmpty || _notIngredients.contains(bare)) return false;
  if (lower.contains('http') || lower.contains('@') || lower.contains('!') || lower.contains('?')) return false;
  if (RegExp('\\b$_months\\s+\\d{1,2},?\\s+\\d{4}').hasMatch(lower)) return false;
  if (RegExp(r'^\d[\d,]*\s+(comments?|reviews?|ratings?|stars?)\b').hasMatch(lower)) return false;
  if (RegExp(r'^(\d\s*)?stars?\b').hasMatch(lower)) return false;
  if (RegExp(r'^(calories|nutrition|keywords|serving size|carbohydrates|protein|fat|sodium)\b').hasMatch(lower)) {
    return false;
  }
  // Prose, not a list item: several sentences, or many words with no amount.
  if (RegExp(r'[.]\s+[a-z]').allMatches(lower).length >= 2) return false;
  final words = bare.split(' ').length;
  final hasAmount = RegExp(r'[\d¼½¾⅓⅔⅛]').hasMatch(lower);
  if (!hasAmount && words > 8) return false;
  return true;
}

/// The page's print-view link for its recipe card (WP Recipe Maker sites,
/// such as RecipeTin Eats), or null.
String? findPrintUrl(String html) =>
    RegExp(r'''href=["'](https?://[^"']*?/wprm_print/[^"'#?]+)''').firstMatch(html)?.group(1);

/// The recipe in [html], or null if the page has no recipe data.
RecipeDraft? parseRecipeHtml(String html, String url) {
  final scripts = RegExp(
    r'<script[^>]*type\s*=\s*"application/ld\+json"[^>]*>(.*?)</script>',
    caseSensitive: false,
    dotAll: true,
  ).allMatches(html);
  for (final m in scripts) {
    Object? data;
    try {
      data = jsonDecode(m.group(1)!.trim());
    } on FormatException {
      continue;
    }
    final recipe = _findRecipe(data);
    if (recipe == null) continue;
    final name = _text(recipe['name']);
    final raw = (recipe['recipeIngredient'] ?? recipe['ingredients']);
    final ingredients = <String>[];
    final seen = <String>{};
    if (raw is List) {
      for (final r in raw) {
        final line = cleanIngredientLine(_text(r));
        final key = simplifyIngredient(line);
        if (line.isNotEmpty && seen.add(key.isEmpty ? line.toLowerCase() : key)) ingredients.add(line);
      }
    }
    if (name.isEmpty && ingredients.isEmpty) continue;
    final minutes =
        parseIsoMinutes(_text(recipe['totalTime'])) ??
        _sum(parseIsoMinutes(_text(recipe['prepTime'])), parseIsoMinutes(_text(recipe['cookTime'])));
    return RecipeDraft(
      name: _decodeEntities(name),
      ingredients: ingredients,
      minutes: minutes,
      url: url,
      printUrl: findPrintUrl(html),
    );
  }
  return null;
}

int? _sum(int? a, int? b) => (a == null && b == null) ? null : (a ?? 0) + (b ?? 0);

Map<String, Object?>? _findRecipe(Object? node) {
  if (node is List) {
    for (final n in node) {
      final r = _findRecipe(n);
      if (r != null) return r;
    }
  } else if (node is Map) {
    final map = node.cast<String, Object?>();
    final type = map['@type'];
    final isRecipe = type == 'Recipe' || (type is List && type.contains('Recipe'));
    if (isRecipe) return map;
    if (map['@graph'] != null) return _findRecipe(map['@graph']);
  }
  return null;
}

String _text(Object? v) {
  if (v == null) return '';
  if (v is String) return v.trim();
  if (v is List && v.isNotEmpty) return _text(v.first);
  return v.toString().trim();
}

String _decodeEntities(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&#39;', "'")
    .replaceAll('&#039;', "'")
    .replaceAll('&quot;', '"')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&#8217;', "'");

/// "PT1H30M" -> 90. Null if it is not an ISO 8601 duration.
int? parseIsoMinutes(String iso) {
  final m = RegExp(r'^P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?', caseSensitive: false).firstMatch(iso.trim());
  if (m == null || iso.trim().isEmpty) return null;
  final d = int.tryParse(m.group(1) ?? '') ?? 0;
  final h = int.tryParse(m.group(2) ?? '') ?? 0;
  final min = int.tryParse(m.group(3) ?? '') ?? 0;
  final total = d * 1440 + h * 60 + min;
  return total == 0 ? null : total;
}

const _units =
    r'(?:kg|g|grams?|ml|millilitres?|milliliters?|l|litres?|liters?|lbs?|oz|ounces?|cups?|c|tbsp|tbs|tablespoons?|tsp|teaspoons?|cm|inch(?:es)?|in|pinch(?:es)?|cans?|tins?|packets?|pkts?|bunch(?:es)?|handfuls?|sprigs?|slices?|pieces?|stalks?|sticks?)';
const _descriptors = {
  'large',
  'small',
  'medium',
  'fresh',
  'finely',
  'roughly',
  'thinly',
  'chopped',
  'minced',
  'sliced',
  'grated',
  'peeled',
  'heaped',
  'level',
  'about',
  'approx',
  'approximately',
  'optional',
  'extra',
  'good',
  'quality',
  'plus',
  'x',
};

/// "500g / 1 lb chicken thighs, skinless" -> "chicken thighs".
/// Drops amounts, units, bracketed notes, preparation after a comma and
/// words like "finely" or "large". Keeps what you would look for in a shop.
String simplifyIngredient(String raw) {
  var s = cleanIngredientLine(raw).toLowerCase();
  s = s.replaceAll(RegExp(r'\([^)]*\)'), ' ');
  s = s.split(RegExp(r'[,;]|\bfor serving\b|\bto serve\b|\bto taste\b')).first;
  const numbers = r'[\d¼½¾⅓⅔⅛⅜⅝⅞.,/–-]+';
  s = s.replaceAll(RegExp('$numbers\\s*$_units\\b\\.?'), ' ');
  s = s.replaceAll(RegExp(numbers), ' ');
  s = s.replaceAll(RegExp('(^|\\s)$_units(?=\\s|\$)'), ' ');
  s = s.replaceAll(RegExp(r"[^a-z' ]"), ' ');
  final words = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty && !_descriptors.contains(w)).toList();
  while (words.isNotEmpty && const {'of', 'and', 'or', 'a', 'an'}.contains(words.first)) {
    words.removeAt(0);
  }
  return words.join(' ').trim();
}
