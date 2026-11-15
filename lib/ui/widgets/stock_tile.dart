import 'package:material_ui/material_ui.dart';

import '../../data/store_scope.dart';
import '../../models/models.dart';
import 'item_sheets.dart';

/// One stock item: name, amount against target, and one-tap - / +.
class StockTile extends StatelessWidget {
  const StockTile({super.key, required this.item, this.showLocation = false});
  final StockItem item;
  final bool showLocation;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final location = store.location(item.locationId)?.name ?? '';
    final amount = '${formatQty(item.quantity)}${item.unit.isEmpty ? '' : ' ${item.unit}'}';
    final targetText = item.hasTarget ? ' of ${formatQty(item.target)}' : '';
    final barColor = item.isOut
        ? scheme.error
        : item.isLow
        ? scheme.tertiary
        : scheme.primary;

    return InkWell(
      key: ValueKey('stock-${item.id}'),
      onTap: () => showItemEditor(context, existing: item),
      onLongPress: () => showMoveSheet(context, item),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    ['$amount$targetText', if (showLocation && location.isNotEmpty) location].join('  ·  '),
                    style: text.bodySmall?.copyWith(color: item.isLow ? scheme.tertiary : null),
                  ),
                  if (item.hasTarget) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: item.fill,
                        minHeight: 4,
                        color: barColor,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              key: ValueKey('minus-${item.id}'),
              tooltip: 'Use one',
              onPressed: item.isOut ? null : () => store.adjust(item.id, -1),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            IconButton(
              key: ValueKey('plus-${item.id}'),
              tooltip: 'Add one',
              onPressed: () => store.adjust(item.id, 1),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}
