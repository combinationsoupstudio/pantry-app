import 'package:material_ui/material_ui.dart';

import '../../data/store_scope.dart';
import '../../logic/amounts.dart';
import '../../models/models.dart';
import 'capture.dart';
import 'common.dart';
import 'item_sheets.dart';
import 'pictures.dart';
import 'use_some_sheet.dart';

/// Scan to use: scan the barcode of something being used or binned. If it is
/// in stock: used it all, use some, or use one. If not: add it.
Future<void> scanToUse(BuildContext context, {LocationKind kind = LocationKind.pantry}) async {
  final code = await scanBarcode(context);
  if (code == null || !context.mounted) return;
  final item = StoreScope.read(context).itemByBarcode(code);
  if (item == null) {
    final add = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Not in stock yet'),
        content: Text('Nothing in the house has barcode $code. Add it?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Add it')),
        ],
      ),
    );
    if (add == true && context.mounted) await showItemEditor(context, kind: kind, barcode: code);
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      final text = Theme.of(sheet).textTheme;
      final store = StoreScope.read(sheet);
      Future<void> done(Future<void> Function() act, String said) async {
        final messenger = ScaffoldMessenger.of(sheet);
        Navigator.of(sheet).pop();
        await act();
        messenger.showSnackBar(SnackBar(content: Text(said)));
      }

      return Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, sheetBottom(sheet)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ProductPicture.of(item, size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: text.titleLarge),
                      Text('Have ${formatMeasure(item.quantity, item.unit)}', style: text.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!item.isMeasured && item.quantity >= 1)
              FilledButton.icon(
                key: const ValueKey('scan-use-one'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () => done(() => store.adjust(item.id, -1), 'One ${item.name} used'),
                icon: const Icon(Icons.remove),
                label: const Text('Used one'),
              ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              key: const ValueKey('scan-use-some'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () {
                final nav = Navigator.of(sheet)..pop();
                showUseSomeSheet(nav.context, item);
              },
              icon: const Icon(Icons.water_drop_outlined),
              label: const Text('Used some…'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('scan-use-all'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => done(
                () => store.adjust(item.id, -openPack(item)),
                item.isMeasured ? 'Open ${item.name} finished' : '${item.name} used up',
              ),
              icon: const Icon(Icons.delete_sweep_outlined),
              label: Text(item.isMeasured ? 'Finished the open pack' : 'Used it all'),
            ),
          ],
        ),
      );
    },
  );
}

/// What a finished pack takes off: for a measured item, only what is in the
/// open pack (1150 ml of 750 ml bottles is a full one plus 400 ml open, so
/// 400 ml); for anything else, all of it.
double openPack(StockItem item) {
  if (!item.isMeasured || item.quantity <= 0) return item.quantity;
  final rest = item.quantity % item.packSize;
  return rest < 1e-9 ? item.packSize : rest;
}
