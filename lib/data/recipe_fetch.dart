import 'package:http/http.dart' as http;

import '../logic/recipe_link.dart';

/// Fetches a recipe page and reads its name, time and ingredients.
/// Throws [RecipeFetchException] with a message fit to show the person.
Future<RecipeDraft> fetchRecipeFromLink(String link, {http.Client? client}) async {
  final uri = Uri.tryParse(link.trim());
  if (uri == null || !(uri.isScheme('https') || uri.isScheme('http')) || uri.host.isEmpty) {
    throw const RecipeFetchException('That does not look like a web link.');
  }
  final c = client ?? http.Client();
  try {
    final response = await c
        .get(uri, headers: {'User-Agent': 'Mozilla/5.0 (Linux; Android 14) Pantry/0.2', 'Accept': 'text/html'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw RecipeFetchException('The page answered ${response.statusCode}.');
    }
    final draft = parseRecipeHtml(response.body, uri.toString());
    if (draft == null) throw const RecipeFetchException('No recipe details found on that page.');
    return draft;
  } on RecipeFetchException {
    rethrow;
  } on Exception {
    throw const RecipeFetchException('Could not reach that page. Check the connection.');
  } finally {
    if (client == null) c.close();
  }
}

class RecipeFetchException implements Exception {
  const RecipeFetchException(this.message);
  final String message;
  @override
  String toString() => message;
}
