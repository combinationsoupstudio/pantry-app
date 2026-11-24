import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'dates_page.dart';
import '../../app.dart';
import '../../data/store_scope.dart';
import '../../logic/insights.dart';
import '../../logic/recipes.dart';
import '../widgets/common.dart';
import '../widgets/stock_tile.dart';
import '../theme.dart';
import 'household_page.dart';
import 'insights_page.dart';
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
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _HomeHeader(
              ins: ins,
              now: now,
              assessment: _assessment(ins),
              toBuy: toBuy,
              ready: ready,
              datesSoon: ins.useBySoon.length,
              onStock: () => _openInsights(context),
              onList: () => onGo(AppTab.shopping),
              onMeals: () => onGo(AppTab.recipes),
              onDates: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DatesPage())),
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
                body: 'Add items on the Pantry page, or import your stock list in Settings.',
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OutlinedButton.icon(
                key: const ValueKey('home-insights'),
                onPressed: () => _openInsights(context),
                icon: const Icon(Icons.insights_outlined),
                label: Text(
                  low.length > 6 ? 'All ${low.length} running low, spending and more' : 'Spending, places and more',
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  void _openInsights(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const InsightsPage()));

  String _assessment(Insights ins) {
    if (ins.totalItems == 0) return 'Add your first items to see how the house is tracking.';
    if (ins.targeted == 0) return '${ins.totalItems} items tracked. Set a "keep at least" on items to score them.';
    final parts = <String>['${ins.atTarget} of ${ins.targeted} targets met'];
    if (ins.out > 0) parts.add('${ins.out} out');
    if (ins.low > 0) parts.add('${ins.low} running low');
    return '${parts.join(', ')}.';
  }
}

/// The top of Home (v0.18, #42; Chris picked "Bold: teal header" 24 Nov):
/// a deep band in the look's bar colour with the date, how stocked the house
/// is and a bar split into good, low and out; three bright tiles sit half
/// over its edge. No greeting (Chris: "I dont like the G'day").
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.ins,
    required this.now,
    required this.assessment,
    required this.toBuy,
    required this.ready,
    required this.datesSoon,
    required this.onStock,
    required this.onList,
    required this.onMeals,
    required this.onDates,
  });

  final Insights ins;
  final DateTime now;
  final String assessment;
  final int toBuy, ready, datesSoon;
  final VoidCallback onStock, onList, onMeals, onDates;

  static const _days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
  static const _months = [
    'JANUARY',
    'FEBRUARY',
    'MARCH',
    'APRIL',
    'MAY',
    'JUNE',
    'JULY',
    'AUGUST',
    'SEPTEMBER',
    'OCTOBER',
    'NOVEMBER',
    'DECEMBER',
  ];

  @override
  Widget build(BuildContext context) {
    final p = LookColors.of(context);
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final tileH = 124.0 * scale;
    const overlap = 44.0;
    final top = MediaQuery.paddingOf(context).top;
    final pct = ins.readiness == null ? null : (ins.readiness! * 100).round();
    // Insights' low counts the outs too; the bar shows each once.
    final good = ins.atTarget, out = ins.out, low = ins.low - ins.out < 0 ? 0 : ins.low - ins.out;
    final total = good + low + out;

    final header = Container(
      decoration: BoxDecoration(
        color: p.bar,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(20, top + 6, 8, overlap + 16),
      child: IconButtonTheme(
        data: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: p.onBar)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_days[now.weekday - 1]} ${now.day} ${_months[now.month - 1]}',
                    key: const ValueKey('home-date'),
                    style: text.labelLarge?.copyWith(color: p.barSoft, fontWeight: FontWeight.w800, letterSpacing: 1),
                  ),
                ),
                const SyncButton(),
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('home-stock'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: onStock,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              pct == null ? '—' : '$pct%',
                              style: text.displayLarge?.copyWith(
                                fontFamily: headingFont,
                                fontSize: 72,
                                height: 0.95,
                                fontWeight: FontWeight.w600,
                                color: p.onBar,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  'of the house\nstocked',
                                  style: text.titleMedium?.copyWith(
                                    color: p.onBar,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Icon(Icons.chevron_right, color: p.barSoft),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // The bar says it; the sentence is only for a house
                        // with nothing to score yet.
                        if (total > 0)
                          _StockBar(good: good, low: low, out: out, palette: p)
                        else
                          Text(assessment, style: text.bodyMedium?.copyWith(color: p.onBar)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              header,
              SizedBox(height: tileH - overlap),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            height: tileH,
            child: Row(
              children: [
                _HeroTile(
                  key: const ValueKey('home-list'),
                  value: '$toBuy',
                  label: 'on the list',
                  icon: Icons.shopping_cart_outlined,
                  bg: p.accent,
                  fg: p.onAccent,
                  onTap: onList,
                ),
                const SizedBox(width: 10),
                _HeroTile(
                  key: const ValueKey('home-meals'),
                  value: '$ready',
                  label: 'meals ready',
                  icon: Icons.restaurant_menu_outlined,
                  bg: p.meals,
                  fg: p.onMeals,
                  onTap: onMeals,
                ),
                const SizedBox(width: 10),
                _HeroTile(
                  key: const ValueKey('home-dates'),
                  value: '$datesSoon',
                  label: 'dates soon',
                  icon: Icons.event_outlined,
                  bg: p.dates,
                  fg: p.onDates,
                  onTap: onDates,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Good, low and out as one bar, each part as wide as its share.
class _StockBar extends StatelessWidget {
  const _StockBar({required this.good, required this.low, required this.out, required this.palette});
  final int good, low, out;
  final Palette palette;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final parts = [(good, palette.meals, 'good'), (low, palette.accent, 'low'), (out, palette.dates, 'out')];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, (n, c, _)) in parts.where((x) => x.$1 > 0).indexed) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    flex: n,
                    child: ColoredBox(color: c),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          children: [
            for (final (n, c, label) in parts)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$n $label',
                    style: text.labelLarge?.copyWith(color: palette.onBar, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// A bright tile on Home: a big number, what it counts, and where it goes.
class _HeroTile extends StatelessWidget {
  const _HeroTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final String value, label;
  final IconData icon;
  final Color bg, fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Material(
        color: bg,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: fg, size: 20),
                ),
                const Spacer(),
                Text(
                  value,
                  style: text.headlineMedium?.copyWith(
                    fontFamily: headingFont,
                    fontWeight: FontWeight.w600,
                    color: fg,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
