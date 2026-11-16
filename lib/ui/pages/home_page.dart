import 'package:material_ui/material_ui.dart';

import 'dates_page.dart';
import '../../logic/supplies.dart';
import '../../app.dart';
import '../../data/store_scope.dart';
import '../../models/models.dart';
import '../../logic/insights.dart';
import '../../logic/recipes.dart';
import '../widgets/common.dart';
import '../widgets/stock_tile.dart';
import '../theme.dart';
import 'settings_page.dart';

/// The dashboard: how the house is going at a glance, and what needs doing.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onGo});
  final void Function(AppTab tab) onGo;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final ins = computeInsights(items: store.items, locations: store.locations, activity: store.activity, now: now);
    final low = store.runningLow;
    final ready = matchRecipes(store.items).where((m) => m.ready).length;
    final toBuy = store.shopping.where((s) => !s.bought).length;
    final people = store.setting<int>('people', 3);
    final water = waterDays(store.items, people: people);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            title: Text('G\'day ${store.user}'),
            actions: [
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 84,
                        height: 84,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: ins.readiness ?? 0,
                              strokeWidth: 8,
                              backgroundColor: scheme.surface.withValues(alpha: 0.5),
                            ),
                            Center(
                              child: Text(
                                ins.readiness == null ? '—' : '${(ins.readiness! * 100).round()}%',
                                style: text.titleLarge?.copyWith(color: scheme.onPrimaryContainer),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('House stock', style: text.titleMedium?.copyWith(color: scheme.onPrimaryContainer)),
                            const SizedBox(height: 4),
                            Text(_assessment(ins), style: text.bodyMedium?.copyWith(color: scheme.onPrimaryContainer)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 140 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.6),
              ),
              delegate: SliverChildListDelegate([
                StatTile(
                  label: 'on the list',
                  value: '$toBuy',
                  icon: Icons.shopping_cart_outlined,
                  onTap: () => onGo(AppTab.shopping),
                ),
                StatTile(
                  label: 'meals ready',
                  value: '$ready',
                  icon: Icons.restaurant_menu_outlined,
                  onTap: () => onGo(AppTab.recipes),
                ),
                StatTile(
                  label: 'use by soon',
                  value: '${ins.useBySoon.length}',
                  icon: Icons.event_outlined,
                  tone: ins.useBySoon.isEmpty
                      ? null
                      : (StatusColors.of(context).low, StatusColors.of(context).lowContainer),
                  key: const ValueKey('home-dates'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DatesPage())),
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _WaterCard(water: water, people: people),
            ),
          ),
          if (store.runningOutWithin(7).isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionHeader('Runs out within a week')),
            SliverList.list(
              children: [for (final i in store.runningOutWithin(7).take(5)) StockTile(item: i, showLocation: true)],
            ),
          ],
          SliverToBoxAdapter(
            child: SectionHeader(
              'Running low',
              trailing: low.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () async {
                        final n = await store.addRunningLowToShopping();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(n == 0 ? 'Already on the list' : '$n added to the shopping list')),
                          );
                        }
                      },
                      child: const Text('Add to list'),
                    ),
            ),
          ),
          if (store.items.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.kitchen_outlined,
                title: 'No stock yet',
                body: 'Add items on the Pantry and Storage pages, or import your stock list in Settings.',
                action: FilledButton.tonal(onPressed: () => onGo(AppTab.pantry), child: const Text('Go to Pantry')),
              ),
            )
          else if (low.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Everything with a target is at or above it.'),
              ),
            )
          else
            SliverList.list(children: [for (final i in low.take(6)) StockTile(item: i, showLocation: true)]),
          if (low.length > 6)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('and ${low.length - 6} more on the Insights page', style: text.bodySmall),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  String _assessment(Insights ins) {
    if (ins.totalItems == 0) return 'Add your first items to see how the house is tracking.';
    if (ins.targeted == 0) return '${ins.totalItems} items tracked. Set a "keep at least" on items to score them.';
    final parts = <String>['${ins.atTarget} of ${ins.targeted} targets met'];
    if (ins.out > 0) parts.add('${ins.out} out');
    if (ins.low > 0) parts.add('${ins.low} running low');
    return '${parts.join(', ')}.';
  }
}

/// Water days: drinking water in stock against 3 L per person a day.
class _WaterCard extends StatelessWidget {
  const _WaterCard({required this.water, required this.people});
  final WaterDays water;
  final int people;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final store = StoreScope.read(context);
    return Card(
      key: const ValueKey('home-water'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.water_drop_outlined, color: scheme.primary),
                const SizedBox(width: 6),
                Text('Water', style: text.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              water.counted.isEmpty ? 'None counted' : '${water.days} day${water.days == 1 ? '' : 's'}',
              key: const ValueKey('water-days'),
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text('${formatQty(double.parse(water.litres.toStringAsFixed(1)))} L for', style: text.bodySmall),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                InkWell(
                  key: const ValueKey('people-less'),
                  onTap: people <= 1 ? null : () => store.setSetting('people', people - 1),
                  child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.remove, size: 18)),
                ),
                Text('$people people', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                InkWell(
                  key: const ValueKey('people-more'),
                  onTap: () => store.setSetting('people', people + 1),
                  child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.add, size: 18)),
                ),
              ],
            ),
            Text(
              water.notCounted.isEmpty
                  ? '3 L each a day (NSW Health, RFS)'
                  : '3 L each a day. ${water.notCounted.length} not counted: put litres in the name or unit',
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
