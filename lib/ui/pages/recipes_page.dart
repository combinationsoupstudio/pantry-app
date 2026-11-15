import 'package:material_ui/material_ui.dart';

import '../../data/household_store.dart';
import '../../data/store_scope.dart';
import '../../logic/recipes.dart';
import '../widgets/common.dart';
import 'recipe_detail_page.dart';
import 'recipe_editor_page.dart';

/// A list of recipe banners. Everything about a recipe is one tap away, on
/// its own page; nothing here needs reading past the banner.
class RecipesPage extends StatelessWidget {
  const RecipesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final saved = matchRecipes(store.items, recipes: [for (final r in store.recipes) Recipe.fromSaved(r)]);
    final starters = matchRecipes(store.items).where((m) => m.missing.length <= 2).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.medium(title: Text('Recipes')),
          SliverToBoxAdapter(child: SectionHeader('Your recipes (${saved.length})')),
          if (saved.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Paste a link to a recipe you love, or write your own.'),
              ),
            ),
          SliverList.list(children: [for (final m in saved) RecipeBanner(match: m)]),
          SliverToBoxAdapter(child: SectionHeader('Starter ideas you can nearly make (${starters.length})')),
          SliverList.list(children: [for (final m in starters) RecipeBanner(match: m)]),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add-recipe'),
        heroTag: 'add-recipe',
        onPressed: () => _chooseAdd(context),
        icon: const Icon(Icons.add),
        label: const Text('Add recipe'),
      ),
    );
  }

  Future<void> _chooseAdd(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('add-from-link'),
              leading: const Icon(Icons.link),
              title: const Text('From a link'),
              subtitle: const Text('Paste a recipe page link. Ingredients are read for you.'),
              onTap: () => Navigator.pop(c, 'link'),
            ),
            ListTile(
              key: const ValueKey('add-own'),
              leading: const Icon(Icons.edit_note),
              title: const Text('Write my own'),
              subtitle: const Text('One ingredient per line, then the method'),
              onTap: () => Navigator.pop(c, 'own'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => RecipeEditorPage(startFromLink: choice == 'link')));
  }
}

/// One recipe as a banner: name, time, how many ingredients, and a badge
/// saying ready or how many to buy. Tap to open the recipe.
class RecipeBanner extends StatelessWidget {
  const RecipeBanner({super.key, required this.match});
  final RecipeMatch match;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final store = StoreScope.read(context);
    final savedId = match.recipe.savedId;
    final saved = savedId == null ? null : store.recipe(savedId);
    final pasted = saved != null && saved.ingredients.length > RecipeEditorPage.maxIngredients;
    final details = [
      if (match.recipe.minutes > 0) '${match.recipe.minutes} min',
      '${match.recipe.ingredients.length} ingredients',
      if (saved?.siteName != null) saved!.siteName!,
      if (saved == null) 'starter',
    ].join('  ·  ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('recipe-${match.recipe.name}'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  saved != null ? RecipeDetailPage(recipeId: saved.id) : RecipeDetailPage.starter(recipe: match.recipe),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: match.ready ? scheme.primaryContainer : scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    saved?.isLinked == true ? Icons.menu_book_outlined : Icons.restaurant_menu,
                    color: match.ready ? scheme.onPrimaryContainer : scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(match.recipe.name, style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        pasted ? 'Looks like a pasted web page. Tap, then edit to fix.' : details,
                        style: text.bodySmall?.copyWith(color: pasted ? scheme.error : null),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(missing: match.missing.length),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.missing});
  final int missing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ready = missing == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ready ? scheme.primaryContainer : scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        ready ? 'Ready' : '$missing to buy',
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: ready ? scheme.onPrimaryContainer : scheme.onTertiaryContainer),
      ),
    );
  }
}

/// Puts a recipe's missing ingredients on the list, linked to stock where the
/// household tracks them. Ingredients already on the list are skipped, so a
/// second press adds nothing twice. Returns how many were added.
Future<int> addMissingToShopping(HouseholdStore store, RecipeMatch match) async {
  var added = 0;
  for (final i in match.missing) {
    final stock = stockItemFor(i, store.items);
    final name = stock?.name ?? sentenceCase(i.label);
    if (store.isOnShoppingList(name, stockItemId: stock?.id)) continue;
    await store.addShopping(name: name, unit: stock?.unit ?? '', stockItemId: stock?.id);
    added++;
  }
  return added;
}

/// How many of a recipe's missing ingredients are not yet on the list.
int missingNotOnList(HouseholdStore store, RecipeMatch match) => match.missing.where((i) {
  final stock = stockItemFor(i, store.items);
  return !store.isOnShoppingList(stock?.name ?? sentenceCase(i.label), stockItemId: stock?.id);
}).length;
