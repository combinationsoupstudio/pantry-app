import 'package:material_ui/material_ui.dart';

import '../../data/store_scope.dart';
import '../../logic/recipes.dart';
import '../widgets/common.dart';

class RecipesPage extends StatelessWidget {
  const RecipesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final matches = matchRecipes(store.items);
    final ready = matches.where((m) => m.ready).toList();
    final nearly = matches.where((m) => !m.ready && m.missing.length <= 2).toList();
    final rest = matches.where((m) => m.missing.length > 2).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.medium(title: Text('Recipes')),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Matched against what is in stock right now. Starter recipes for now; '
                'suggestions from your own stock come in a later release.',
              ),
            ),
          ),
          SliverToBoxAdapter(child: SectionHeader('Ready to cook (${ready.length})')),
          if (ready.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Nothing fully in stock yet.')),
            ),
          SliverList.list(children: [for (final m in ready) _RecipeCard(match: m)]),
          SliverToBoxAdapter(child: SectionHeader('One or two things short (${nearly.length})')),
          SliverList.list(children: [for (final m in nearly) _RecipeCard(match: m)]),
          if (rest.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader('Needs a shop (${rest.length})')),
            SliverList.list(children: [for (final m in rest) _RecipeCard(match: m)]),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.match});
  final RecipeMatch match;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(match.recipe.name, style: text.titleMedium)),
                  Text('${match.recipe.minutes} min', style: text.bodySmall),
                ],
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
                  child: TextButton.icon(
                    onPressed: () async {
                      final store = StoreScope.read(context);
                      for (final i in match.missing) {
                        final stock = stockItemFor(i, store.items);
                        await store.addShopping(
                          name: stock?.name ?? sentenceCase(i.label),
                          unit: stock?.unit ?? '',
                          stockItemId: stock?.id,
                        );
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('${match.missing.length} added to the shopping list')));
                      }
                    },
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Add missing to list'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
