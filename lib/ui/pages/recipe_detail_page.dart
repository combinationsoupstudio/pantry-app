import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/store_scope.dart';
import '../../logic/recipes.dart';
import '../widgets/common.dart';
import 'recipe_editor_page.dart';
import 'recipes_page.dart';

class RecipeDetailPage extends StatelessWidget {
  const RecipeDetailPage({super.key, required this.recipeId});
  final String recipeId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final saved = store.recipe(recipeId);
    if (saved == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This recipe was removed.')),
      );
    }
    final match = matchRecipes(store.items, recipes: [Recipe.fromSaved(saved)]).single;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final haveSet = match.have.toSet();

    return Scaffold(
      appBar: AppBar(
        title: Text(saved.name),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RecipeEditorPage(existing: saved))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              [
                if (saved.minutes != null) '${saved.minutes} min',
                match.ready ? 'Ready to cook' : '${match.missing.length} missing',
                'saved by ${saved.addedBy}',
              ].join('  ·  '),
              style: text.bodyMedium,
            ),
          ),
          if (saved.isLinked)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: FilledButton.icon(
                key: const ValueKey('open-recipe'),
                onPressed: () async {
                  final ok = await launchUrl(Uri.parse(saved.url!), mode: LaunchMode.externalApplication);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Could not open the page')));
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: Text('Open recipe on ${saved.siteName ?? 'the web'}'),
              ),
            ),
          SectionHeader('Ingredients', trailing: match.missing.isEmpty ? null : AddMissingButton(match: match)),
          for (final i in match.recipe.ingredients)
            ListTile(
              dense: true,
              leading: Icon(
                haveSet.contains(i) ? Icons.check_circle : Icons.radio_button_unchecked,
                color: haveSet.contains(i) ? scheme.primary : scheme.tertiary,
              ),
              title: Text(sentenceCase(i.label)),
              subtitle: () {
                final stock = stockItemFor(i, store.items, inStockOnly: true);
                return stock == null ? null : Text('${stock.name} in stock');
              }(),
            ),
          if (saved.method.isNotEmpty) ...[
            SectionHeader(saved.isLinked ? 'Notes' : 'Method'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SelectableText(saved.method, style: text.bodyLarge),
            ),
          ],
        ],
      ),
    );
  }
}
