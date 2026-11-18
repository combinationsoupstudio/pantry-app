import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/store_scope.dart';
import '../../logic/amounts.dart';
import '../../logic/recipes.dart';
import '../../models/models.dart';
import '../theme.dart';
import '../widgets/cook_sheet.dart';
import '../widgets/name_match.dart';
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
                          color: match.ready ? StatusColors.of(context).ok : StatusColors.of(context).low,
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
            _MethodTab(saved: saved, recipe: recipe),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('cooked'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: match.have.isEmpty && match.short.isEmpty
                        ? null
                        : () async {
                            final done = await showCookSheet(context, match);
                            if (done == true && context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text('Enjoy! ${recipe.name} came out of stock')));
                            }
                          },
                    icon: const Icon(Icons.restaurant),
                    label: const Text('I cooked this'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: match.ready
                      ? const FilledButton.tonal(onPressed: null, child: Text('All in stock'))
                      : toAdd == 0
                      ? const FilledButton.tonal(onPressed: null, child: Text('On your list'))
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
                          label: Text('Add $toAdd to list'),
                        ),
                ),
              ],
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

    // Each line says which of the household's things it is, and can be put
    // right with a tap (v0.11): the answer is remembered on every phone.
    Widget row(Ingredient i, {required bool have}) {
      final stock = have ? stockItemFor(i, store.items, inStockOnly: true) : stockItemFor(i, store.items);
      final close = have || stock != null ? null : closeStockFor(i, store.items);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            key: ValueKey('ingredient-${i.label}'),
            visualDensity: VisualDensity.compact,
            leading: Icon(
              have ? Icons.check_circle : Icons.add_shopping_cart,
              color: have ? StatusColors.of(context).ok : StatusColors.of(context).low,
            ),
            title: Text(sentenceCase(i.line), style: text.bodyLarge),
            subtitle: Text(
              (i.group == null ? '' : '${i.group}  ·  ') +
                  (stock != null
                      ? (have ? 'You have: ${stock.name}' : 'Your ${stock.name} has run out')
                      : close != null
                      ? 'Not sure which of yours this is'
                      : 'Not something you keep yet · tap to match'),
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            trailing: Icon(Icons.swap_horiz, size: 20, color: scheme.onSurfaceVariant),
            onTap: () => pickStockFor(context, i.label, current: stock),
          ),
          if (close != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Is it your ${close.item.name}?', style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  FilledButton.tonal(
                    key: ValueKey('close-yes-${i.label}'),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                    onPressed: () => store.teachName(close.item.id, i.label),
                    child: const Text('Yes'),
                  ),
                  OutlinedButton(
                    key: ValueKey('close-no-${i.label}'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                    onPressed: () => store.rejectName(close.item.id, i.label),
                    child: const Text('No'),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    Widget shortRow(Shortfall s) {
      final last = store.latestByStore(s.item);
      final price = last.isEmpty
          ? ''
          : '  ·  last ${formatMoney(last.first.unitPrice)} ${last.first.perLabel == 'each' ? 'each' : 'per ${last.first.perLabel}'}'
                ' at ${last.first.store.label}';
      return ListTile(
        key: ValueKey('short-${s.item.id}'),
        visualDensity: VisualDensity.compact,
        leading: Icon(Icons.add_shopping_cart, color: StatusColors.of(context).low),
        title: Text(sentenceCase(s.ingredient.line), style: text.bodyLarge),
        subtitle: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: sentenceCase(s.label),
                style: TextStyle(color: StatusColors.of(context).low, fontWeight: FontWeight.w700),
              ),
              TextSpan(text: '  ·  have ${formatMeasure(s.have, s.item.unit)} of ${s.item.name}$price'),
            ],
          ),
        ),
      );
    }

    Widget heading(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(label, style: text.labelLarge?.copyWith(color: scheme.primary)),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (!match.ready) ...[
          heading('To buy (${match.toBuy})'),
          for (final s in match.short) shortRow(s),
          for (final i in match.missing) row(i, have: false),
        ],
        if (match.have.isNotEmpty) ...[
          heading('You have (${match.have.length})'),
          for (final i in match.have) row(i, have: true),
        ],
        if (match.assumed.isNotEmpty) ...[
          heading('From the cupboard'),
          Padding(
            key: const ValueKey('assumed'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              '${sentenceCase(match.assumed.map((i) => i.line).join(', '))}. Not tracked, so never added to your list.',
              style: text.bodyMedium,
            ),
          ),
        ],
      ],
    );
  }
}

class _MethodTab extends StatelessWidget {
  const _MethodTab({required this.saved, required this.recipe});
  final SavedRecipe? saved;
  final Recipe recipe;

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

    final steps = s == null ? recipe.steps : methodSteps(s.method);
    if (s == null && steps.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (recipe.serves > 0) Chip(label: Text('Serves ${recipe.serves}')),
              if (recipe.minutes > 0) Chip(label: Text('${recipe.minutes} min')),
              if (recipe.untested)
                Chip(
                  key: const ValueKey('untested'),
                  avatar: const Icon(Icons.science_outlined, size: 18),
                  label: const Text('Untested: not cooked by us yet'),
                ),
            ],
          ),
        ),
      );
    }
    if (steps.isNotEmpty) {
      if (s != null && s.isLinked) {
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
      if (s == null) {
        for (final note in recipe.notes) {
          children.add(
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(note, style: text.bodyMedium)),
                  ],
                ),
              ),
            ),
          );
        }
        final credit = recipe.credit;
        if (credit != null) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                credit.url == null ? credit.text : '${credit.text} ${credit.url}',
                key: const ValueKey('recipe-credit'),
                style: text.bodySmall,
              ),
            ),
          );
        }
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
