import 'package:material_ui/material_ui.dart';

import '../../data/store_scope.dart';
import '../../models/models.dart';
import '../../logic/usage.dart';
import '../theme.dart';
import 'pictures.dart';
import '../../logic/amounts.dart';
import '../../logic/supplies.dart';
import 'item_sheets.dart';
import 'use_some_sheet.dart';

/// How an amount reads: "2 loaves", "1 loaf", "12" (items need no word),
/// "500 ml".
String amountText(double qty, String unit) {
  final u = unit.trim();
  final n = formatQty(qty);
  if (u.isEmpty || u == 'items' || u == 'item') return n;
  if (qty == 1) {
    const one = {'loaves': 'loaf', 'boxes': 'box', 'packs': 'pack', 'tins': 'tin', 'bottles': 'bottle'};
    final single = one[u] ?? (u.length > 3 && u.endsWith('s') && !u.endsWith('ss') ? u.substring(0, u.length - 1) : u);
    return '$n $single';
  }
  return '$n $u';
}

/// One stock item as a card (v0.10): its picture or icon, the name with Low
/// or Out, the amount in plain words ("2 loaves · need 1"), a thin bar, and
/// light − / + buttons so the row reads before the buttons do.
class StockTile extends StatelessWidget {
  const StockTile({super.key, required this.item, this.showLocation = false});
  final StockItem item;
  final bool showLocation;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final status = StatusColors.of(context);
    final colour = stockColor(context, out: item.isOut, low: item.isLow);
    final location = store.location(item.locationId)?.name ?? '';
    final left = store.daysLeftFor(item);

    // "300 ml of 500 ml", "1150 ml · 2 full + 150", "2 loaves", then "need 1".
    final String main;
    final List<String> tail = [];
    if (item.isMeasured) {
      main = '${formatQty(item.quantity)} ${item.unit}';
      if (item.quantity <= item.packSize + 1e-9) {
        tail.add('of ${item.packLabel}');
      } else {
        final full = (item.quantity / item.packSize).floor();
        final rest = item.quantity - full * item.packSize;
        tail.add('$full full${rest > 0.5 ? ' + ${formatQty(double.parse(rest.toStringAsFixed(1)))}' : ''}');
      }
    } else {
      main = amountText(item.quantity, item.unit);
      if (item.hasTarget) tail.add('need ${formatQty(item.target)}');
    }
    // Second line: where it is (when the list mixes places) and how long it lasts.
    final under = [
      if (showLocation && location.isNotEmpty) location,
      ?eatFirstHint(item, DateTime.now(), (a) => item.isMeasured ? formatMeasure(a, item.unit) : formatQty(a)),
      if (left != null && left <= 14) 'about ${describeDays(left)} left',
    ];
    final state = item.isOut
        ? 'Out'
        : item.isLow
        ? 'Low'
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('stock-${item.id}'),
          onTap: () => showItemEditor(context, existing: item),
          onLongPress: () => showMoveSheet(context, item),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                SizedBox(
                  width: PicturePile.slotWidth(44),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ItemPile(key: ValueKey('pile-${item.id}'), item: item),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.name,
                              style: text.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (state != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                              decoration: BoxDecoration(
                                color: item.isOut ? status.outContainer : status.lowContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                state,
                                style: text.labelSmall?.copyWith(color: colour, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: main,
                              style: text.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: item.isOut || item.isLow ? colour : scheme.onSurface,
                              ),
                            ),
                            if (tail.isNotEmpty)
                              TextSpan(
                                text: '  ·  ${tail.join('  ·  ')}',
                                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (under.isNotEmpty)
                        Text.rich(
                          TextSpan(
                            children: [
                              for (final (n, part) in under.indexed)
                                TextSpan(
                                  text: n == 0 ? part : '  ·  $part',
                                  style: part.startsWith('about') && left != null && left <= 7
                                      ? TextStyle(color: status.low, fontWeight: FontWeight.w700)
                                      : null,
                                ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      if (item.hasTarget) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: item.fill,
                            minHeight: 4,
                            color: colour,
                            backgroundColor: scheme.surfaceContainerHigh,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _Step(
                  key: ValueKey('minus-${item.id}'),
                  icon: Icons.remove,
                  tooltip: item.isMeasured ? 'Use some' : 'Use one',
                  onPressed: item.isOut
                      ? null
                      : item.isMeasured
                      ? () => showUseSomeSheet(context, item)
                      : () => store.adjust(item.id, -1),
                ),
                const SizedBox(width: 6),
                _Step(
                  key: ValueKey('plus-${item.id}'),
                  icon: Icons.add,
                  strong: true,
                  tooltip: item.isMeasured ? 'Add a ${item.packLabel} pack' : 'Add one',
                  onPressed: () => store.addPack(item.id),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A light round − or + (the + a touch stronger). 40 dp, 48 dp to tap.
class _Step extends StatelessWidget {
  const _Step({super.key, required this.icon, required this.tooltip, this.onPressed, this.strong = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        fixedSize: const Size(40, 40),
        minimumSize: const Size(40, 40),
        backgroundColor: strong ? scheme.primaryContainer : Colors.transparent,
        foregroundColor: strong ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        disabledForegroundColor: scheme.outlineVariant,
        side: strong ? null : BorderSide(color: scheme.outlineVariant),
      ),
    );
  }
}
