import 'package:material_ui/material_ui.dart';

import '../../data/store_scope.dart';
import '../../logic/recipes.dart';
import 'recipes_page.dart';

/// Every starter recipe, searchable and filtered by kind, the ones you can
/// make soonest first.
class StarterLibraryPage extends StatefulWidget {
  const StarterLibraryPage({super.key});

  /// The filters, each a set of tags that count as it.
  static const filters = <String, Set<String>>{
    'Breakfast': {'breakfast'},
    'Dinner': {'dinner'},
    'Quick': {'quick'},
    'Vegetarian': {'vegetarian', 'vegan'},
    'Soup': {'soup'},
    'Baking': {'baking', 'dessert', 'sweet'},
    'Slow cook': {'slow cooker', 'winter'},
  };

  @override
  State<StarterLibraryPage> createState() => _StarterLibraryPageState();
}

class _StarterLibraryPageState extends State<StarterLibraryPage> {
  String _query = '';
  String? _filter;

  bool _shows(Recipe r) {
    final tags = r.tags.map((t) => t.toLowerCase()).toSet();
    if (_filter != null && tags.intersection(StarterLibraryPage.filters[_filter]!).isEmpty) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return r.name.toLowerCase().contains(q) ||
        tags.any((t) => t.contains(q)) ||
        r.ingredients.any((i) => i.keywords.any((k) => k.contains(q)));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final matches = matchRecipes(store.items).where((m) => _shows(m.recipe)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Starter recipes')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const ValueKey('starter-search'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by name or ingredient',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final f in StarterLibraryPage.filters.keys)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      key: ValueKey('filter-$f'),
                      label: Text(f),
                      selected: _filter == f,
                      onSelected: (on) => setState(() => _filter = on ? f : null),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              '${matches.length} recipe${matches.length == 1 ? '' : 's'}, the ones you can make soonest first. New ones are untested until you rate them.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (final m in matches) RecipeBanner(match: m),
          if (matches.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('Nothing matches. Try another word.')),
        ],
      ),
    );
  }
}
