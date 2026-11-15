import 'package:material_ui/material_ui.dart';

import '../../data/household_store.dart';
import '../../data/store_scope.dart';
import '../../logic/recipes.dart';
import '../widgets/common.dart';
import 'recipe_detail_page.dart';
import 'recipe_editor_page.dart';

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
                child: Text(
                  'Paste a link to a recipe you love, or write your own. '
                  'They are matched against what is in stock.',
                ),
              ),
            ),
          SliverList.list(children: [for (final m in saved) RecipeCard(match: m)]),
          SliverToBoxAdapter(child: SectionHeader('Starter ideas you can nearly make (${starters.length})')),
          SliverList.list(children: [for (final m in starters) RecipeCard(match: m)]),
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
              subtitle: const Text('RecipeTin Eats or any recipe site. The method stays on their page.'),
              onTap: () => Navigator.pop(c, 'link'),
            ),
            ListTile(
              key: const ValueKey('add-own'),
              leading: const Icon(Icons.edit_note),
              title: const Text('Write my own'),
              subtitle: const Text('Ingredients and method in your own words'),
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

/// One recipe with what we have and what is missing.
class RecipeCard extends StatelessWidget {
  const RecipeCard({super.key, required this.match});
  final RecipeMatch match;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final store = StoreScope.read(context);
    final savedId = match.recipe.savedId;
    final saved = savedId == null ? null : store.recipe(savedId);
    final status = match.ready ? 'Ready to cook' : '${match.missing.length} missing';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: saved == null
              ? null
              : () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => RecipeDetailPage(recipeId: saved.id))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(match.recipe.name, style: text.titleMedium)),
                    if (match.recipe.minutes > 0) Text('${match.recipe.minutes} min', style: text.bodySmall),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [status, if (saved?.siteName != null) saved!.siteName!].join('  ·  '),
                  style: text.bodySmall?.copyWith(color: match.ready ? scheme.primary : scheme.tertiary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final i in match.have)
                      Chip(
                        avatar: Icon(Icons.check, size: 16, color: scheme.primary),
                        label: Text(i.label),
                        visualDensity: VisualDensity.compact,
                      ),
                    for (final i in match.missing)
                      Chip(
                        avatar: Icon(Icons.close, size: 16, color: scheme.tertiary),
                        label: Text(i.label),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: scheme.tertiaryContainer,
                      ),
                  ],
                ),
                if (match.missing.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AddMissingButton(match: match),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AddMissingButton extends StatelessWidget {
  const AddMissingButton({super.key, required this.match});
  final RecipeMatch match;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () async {
        final store = StoreScope.read(context);
        await addMissingToShopping(store, match);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('${match.missing.length} added to the shopping list')));
        }
      },
      icon: const Icon(Icons.add_shopping_cart),
      label: const Text('Add missing to list'),
    );
  }
}

/// Puts a recipe's missing ingredients on the list, linked to stock where the
/// household tracks them. Repeat presses stack onto the same lines.
Future<void> addMissingToShopping(HouseholdStore store, RecipeMatch match) async {
  for (final i in match.missing) {
    final stock = stockItemFor(i, store.items);
    await store.addShopping(
      name: stock?.name ?? sentenceCase(i.label),
      unit: stock?.unit ?? '',
      stockItemId: stock?.id,
    );
  }
}
