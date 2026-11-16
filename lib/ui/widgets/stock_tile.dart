import 'package:material_ui/material_ui.dart';

import '../../data/store_scope.dart';
import '../../models/models.dart';
import '../theme.dart';
import 'item_sheets.dart';

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
    final unit = item.unit.isEmpty ? '' : ' ${item.unit}';
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
                                      text: item.hasTarget ? ' / ${formatQty(item.target)}$unit' : unit,
                                      style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
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
                          tooltip: 'Use one',
                          onPressed: item.isOut ? null : () => store.adjust(item.id, -1),
                          icon: const Icon(Icons.remove),
                        ),
                        IconButton.filled(
                          key: ValueKey('plus-${item.id}'),
                          tooltip: 'Add one',
                          onPressed: () => store.adjust(item.id, 1),
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
