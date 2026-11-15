import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/store_scope.dart';
import '../../logic/recipes.dart';
import '../../models/models.dart';
import 'recipe_editor_page.dart';
import 'recipes_page.dart';

/// One recipe, laid out for a phone in a kitchen. The header (name, what you
/// have) and the Ingredients | Method tabs stay put; only the list under them
/// scrolls; the add-to-list button is always at the bottom. No jumping back
/// up to the ingredients or down to the method.
class RecipeDetailPage extends StatelessWidget {
  const RecipeDetailPage({super.key, required String this.recipeId}) : starterRecipe = null;
  const RecipeDetailPage.starter({super.key, required Recipe recipe}) : recipeId = null, starterRecipe = recipe;

  final String? recipeId;
  final Recipe? starterRecipe;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final saved = recipeId == null ? null : store.recipe(recipeId!);
    if (recipeId != null && saved == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This recipe was removed.')),
      );
    }
    final recipe = saved != null ? Recipe.fromSaved(saved) : starterRecipe!;
    final match = matchRecipes(store.items, recipes: [recipe]).single;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final total = recipe.ingredients.length;
    final have = match.have.length;
    final toAdd = missingNotOnList(store, match);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          title: Text(recipe.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          actions: [
            if (saved != null)
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => RecipeEditorPage(existing: saved))),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(104),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              match.ready ? 'Everything is in stock' : '$have of $total in stock',
                              style: text.titleSmall,
                            ),
                          ),
                          Text(
                            [
                              if (recipe.minutes > 0) '${recipe.minutes} min',
                              if (saved?.siteName != null) saved!.siteName!,
                            ].join('  ·  '),
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : have / total,
                          minHeight: 6,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  tabs: [
                    Tab(key: const ValueKey('tab-ingredients'), text: 'Ingredients ($total)'),
                    const Tab(key: ValueKey('tab-method'), text: 'Method'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _IngredientsTab(match: match),
            _MethodTab(saved: saved),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: match.ready
                ? const FilledButton.tonal(onPressed: null, child: Text('Everything is in stock'))
                : toAdd == 0
                ? const FilledButton.tonal(onPressed: null, child: Text('Missing items are on your shopping list'))
                : FilledButton.icon(
                    key: const ValueKey('add-missing'),
                    onPressed: () async {
                      final n = await addMissingToShopping(StoreScope.read(context), match);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('$n added to the shopping list')));
                      }
                    },
                    icon: const Icon(Icons.add_shopping_cart),
                    label: Text('Add $toAdd missing to shopping list'),
                  ),
          ),
        ),
      ),
    );
  }
}

class _IngredientsTab extends StatelessWidget {
  const _IngredientsTab({required this.match});
  final RecipeMatch match;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget row(Ingredient i, {required bool have}) {
      final stock = have ? stockItemFor(i, store.items, inStockOnly: true) : null;
      return ListTile(
        visualDensity: VisualDensity.compact,
        leading: Icon(
          have ? Icons.check_circle : Icons.radio_button_unchecked,
          color: have ? scheme.primary : scheme.tertiary,
        ),
        title: Text(sentenceCase(i.line), style: text.bodyLarge),
        subtitle: stock == null ? null : Text('You have: ${stock.name}'),
      );
    }

    Widget heading(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(label, style: text.labelLarge?.copyWith(color: scheme.primary)),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (match.missing.isNotEmpty) ...[
          heading('To buy (${match.missing.length})'),
          for (final i in match.missing) row(i, have: false),
        ],
        if (match.have.isNotEmpty) ...[
          heading('You have (${match.have.length})'),
          for (final i in match.have) row(i, have: true),
        ],
      ],
    );
  }
}

class _MethodTab extends StatelessWidget {
  const _MethodTab({required this.saved});
  final SavedRecipe? saved;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = saved;
    final children = <Widget>[];

    if (s != null && s.isLinked) {
      children.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('The method is on ${s.siteName ?? 'the recipe page'}', style: text.titleMedium),
                const SizedBox(height: 6),
                const Text('This opens the recipe card on its own: ingredients and steps, nothing else.'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('open-recipe'),
                  onPressed: () async {
                    final ok = await launchUrl(Uri.parse(s.openUrl!), mode: LaunchMode.externalApplication);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Could not open the page')));
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open recipe card'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final steps = s == null ? const <String>[] : methodSteps(s.method);
    if (steps.isNotEmpty) {
      if (s!.isLinked) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text('Your notes', style: text.titleSmall),
          ),
        );
      }
      for (var n = 0; n < steps.length; n++) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text.rich(
              TextSpan(
                children: [
                  if (steps.length > 1)
                    TextSpan(
                      text: '${n + 1}.  ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  TextSpan(text: steps[n]),
                ],
              ),
              style: text.bodyLarge?.copyWith(height: 1.45),
            ),
          ),
        );
      }
    } else if (s == null || !s.isLinked) {
      children.add(
        Text(
          s == null
              ? 'A starter idea: ingredients only. Save your own version to add a method.'
              : 'No method written yet. Tap the pencil to add one.',
          style: text.bodyLarge,
        ),
      );
    }

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: children);
  }
}

/// Splits a written method into steps: one per line (blank lines ignored),
/// with any numbering people typed ("1.", "Step 2:") taken off, since the
/// page numbers them itself.
List<String> methodSteps(String method) => method
    .split(RegExp(r'\n+'))
    .map((l) => l.trim().replaceFirst(RegExp(r'^(step\s*)?\d+\s*[.):-]?\s*', caseSensitive: false), ''))
    .where((l) => l.isNotEmpty)
    .toList();
