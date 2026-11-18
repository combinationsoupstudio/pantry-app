import 'package:flutter/services.dart' show rootBundle;

import '../logic/recipe_pack.dart';
import '../logic/recipes.dart';

/// The recipe packs bundled with the app (assets/recipes/).
const recipePackAssets = ['assets/recipes/pack-01.txt'];

/// Loads the packs into [starterLibrary]. A pack that will not load leaves
/// the short starter ideas in place rather than stopping the app.
Future<void> loadStarterLibrary() async {
  final packs = <RecipePack>[];
  for (final asset in recipePackAssets) {
    try {
      packs.add(parseRecipePack(await rootBundle.loadString(asset)));
    } catch (_) {
      // Carry on with what loaded.
    }
  }
  starterLibrary = buildStarterLibrary(packs);
}
