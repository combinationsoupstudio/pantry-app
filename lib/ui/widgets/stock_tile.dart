import 'package:material_ui/material_ui.dart';

import '../../data/store_scope.dart';
import '../../models/models.dart';
import '../../logic/usage.dart';
import '../theme.dart';
import 'capture.dart';
import 'item_sheets.dart';
import 'use_some_sheet.dart';

/// One stock item as its own card: a coloured edge for its state (green fine,
/// amber low, red out), the name, a bold amount against its target, a bar,
/// and solid - and + buttons.
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
    final unit = item.unit.isEmpty ? '' : ' ${item.unit}';
    // A measured item reads "300 / 500 ml" (what is left of one pack), or
    // "1300 ml · 2 full + 300" when there is more than one pack.
    final String amountTail;
    if (item.isMeasured) {
      if (item.quantity <= item.packSize + 1e-9) {
        amountTail = ' / ${item.packLabel}';
      } else {
        final full = (item.quantity / item.packSize).floor();
        final rest = item.quantity - full * item.packSize;
        amountTail =
            '$unit  ·  $full full${rest > 0.5 ? ' + ${formatQty(double.parse(rest.toStringAsFixed(1)))}' : ''}';
      }
    } else {
      amountTail = item.hasTarget ? ' / ${formatQty(item.target)}$unit' : unit;
    }
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
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: item.hasTarget || item.isOut ? colour : scheme.outlineVariant),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    child: Row(
                      children: [
                        if (item.photoPath != null) ...[ItemPhoto(path: item.photoPath), const SizedBox(width: 10)],
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
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: item.isOut ? status.outContainer : status.lowContainer,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        state,
                                        style: text.labelSmall?.copyWith(color: colour, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: formatQty(item.quantity),
                                      style: text.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: item.hasTarget || item.isOut ? colour : scheme.onSurface,
                                      ),
                                    ),
                                    TextSpan(
                                      text: amountTail,
                                      style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                                    ),
                                    if (left != null)
                                      TextSpan(
                                        text: '   ~${describeDays(left)} left',
                                        style: text.bodySmall?.copyWith(
                                          color: left <= 7 ? status.low : scheme.onSurfaceVariant,
                                          fontWeight: left <= 7 ? FontWeight.w700 : null,
                                        ),
                                      ),
                                    if (showLocation && location.isNotEmpty)
                                      TextSpan(
                                        text: '   $location',
                                        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                      ),
                                  ],
                                ),
                              ),
                              if (item.hasTarget) ...[
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: item.fill,
                                    minHeight: 6,
                                    color: colour,
                                    backgroundColor: scheme.surfaceContainerHighest,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          key: ValueKey('minus-${item.id}'),
                          tooltip: item.isMeasured ? 'Use some' : 'Use one',
                          onPressed: item.isOut
                              ? null
                              : item.isMeasured
                              ? () => showUseSomeSheet(context, item)
                              : () => store.adjust(item.id, -1),
                          icon: const Icon(Icons.remove),
                        ),
                        IconButton.filled(
                          key: ValueKey('plus-${item.id}'),
                          tooltip: item.isMeasured ? 'Add a ${item.packLabel} pack' : 'Add one',
                          onPressed: () => store.addPack(item.id),
                          icon: const Icon(Icons.add),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
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
