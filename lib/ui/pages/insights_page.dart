import 'package:material_ui/material_ui.dart';

import '../../data/store_scope.dart';
import '../../logic/insights.dart';
import '../../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final ins = computeInsights(items: store.items, locations: store.locations, activity: store.activity, now: now);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.medium(title: Text('Insights')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 136 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.6),
              ),
              delegate: SliverChildListDelegate([
                StatTile(
                  label: 'of targets met',
                  value: ins.readiness == null ? '—' : '${(ins.readiness! * 100).round()}%',
                  icon: Icons.verified_outlined,
                ),
                StatTile(label: 'items tracked', value: '${ins.totalItems}', icon: Icons.inventory_2_outlined),
                StatTile(
                  label: 'running low',
                  value: '${ins.low}',
                  icon: Icons.trending_down,
                  tone: ins.low > 0 ? (StatusColors.of(context).low, StatusColors.of(context).lowContainer) : null,
                ),
                StatTile(
                  label: 'out of stock',
                  value: '${ins.out}',
                  icon: Icons.remove_shopping_cart_outlined,
                  tone: ins.out > 0 ? (StatusColors.of(context).out, StatusColors.of(context).outContainer) : null,
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(child: _SpendCard(spend: store.spendThisWeek(now))),
          const SliverToBoxAdapter(child: SectionHeader('By location')),
          if (ins.byLocation.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('No stock yet.')),
            ),
          SliverList.list(
            children: [
              for (final s in ins.byLocation)
                ListTile(
                  title: Text(s.location.name),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: s.readiness == null
                        ? Text('${s.itemCount} items, no targets set')
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: s.readiness,
                              color: s.readiness! >= 0.8 ? StatusColors.of(context).ok : StatusColors.of(context).low,
                              minHeight: 6,
                              backgroundColor: scheme.surfaceContainerHighest,
                            ),
                          ),
                  ),
                  trailing: Text(
                    s.readiness == null ? '${s.itemCount}' : '${(s.readiness! * 100).round()}%',
                    style: text.titleSmall,
                  ),
                ),
            ],
          ),
          const SliverToBoxAdapter(child: SectionHeader('Use by soon')),
          SliverList.list(
            children: [
              if (ins.useBySoon.isEmpty) const ListTile(title: Text('Nothing due in the next fortnight.')),
              for (final i in ins.useBySoon)
                ListTile(
                  leading: Icon(Icons.event_outlined, color: i.useBy!.isBefore(now) ? scheme.error : null),
                  title: Text(i.name),
                  trailing: Text(friendlyDate(i.useBy!, now)),
                ),
            ],
          ),
          const SliverToBoxAdapter(child: SectionHeader('Most used, last 30 days')),
          SliverList.list(
            children: [
              if (ins.mostUsed.isEmpty)
                const ListTile(title: Text('Tap minus on an item when you use it and this fills in.')),
              for (final u in ins.mostUsed)
                ListTile(title: Text(u.itemName), trailing: Text('${formatQty(u.used)} ${u.unit}'.trim())),
            ],
          ),
          const SliverToBoxAdapter(child: SectionHeader('Recent changes')),
          SliverList.list(
            children: [
              if (store.activity.isEmpty) const ListTile(title: Text('No changes yet.')),
              for (final a in store.activity.take(20))
                ListTile(
                  dense: true,
                  title: Text('${a.who} ${a.action} ${a.itemName}'),
                  subtitle: Text(friendlyTime(a.at, now)),
                  trailing: a.delta == 0
                      ? null
                      : Text('${a.delta > 0 ? '+' : ''}${formatQty(a.delta)} ${a.unit}'.trim()),
                ),
            ],
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

/// What was paid this week (since Monday), per shop, from prices entered at
/// Put away.
class _SpendCard extends StatelessWidget {
  const _SpendCard({required this.spend});
  final Map<Store, double> spend;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final total = spend.values.fold<double>(0, (a, b) => a + b);
    final rows = spend.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Spent this week'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: total == 0
                  ? const Text('Enter prices when you put a shop away and the week adds up here.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(formatMoney(total), style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        for (final e in rows)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                SizedBox(width: 96, child: Text(e.key.label)),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: e.value / total,
                                      minHeight: 8,
                                      backgroundColor: scheme.surfaceContainerHighest,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 72,
                                  child: Text(formatMoney(e.value), textAlign: TextAlign.right, style: text.labelLarge),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
