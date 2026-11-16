import 'package:material_ui/material_ui.dart';

import '../../data/store_scope.dart';
import '../../models/models.dart';

/// Puts away what was ticked, asking (optionally) what each line cost, so the
/// app can remember prices per shop.
Future<int?> showPutAwaySheet(BuildContext context) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _PutAwaySheet(),
);

class _PutAwaySheet extends StatefulWidget {
  const _PutAwaySheet();

  @override
  State<_PutAwaySheet> createState() => _PutAwaySheetState();
}

class _PutAwaySheetState extends State<_PutAwaySheet> {
  final _controllers = <String, TextEditingController>{};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final bought = store.shopping.where((s) => s.bought).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Put away ${bought.length}', style: text.titleLarge),
          const SizedBox(height: 4),
          const Text('What did each cost? Optional: prices are remembered per shop.'),
          const SizedBox(height: 12),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final s in bought)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name, style: text.titleSmall),
                              Text(
                                '${formatQty(s.quantity)}${s.unit.isEmpty ? '' : ' ${s.unit}'}  ·  ${s.store.label}',
                                style: text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: TextField(
                            key: ValueKey('price-${s.id}'),
                            controller: _controllers.putIfAbsent(s.id, TextEditingController.new),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(prefixText: '\$ ', hintText: '0.00', isDense: true),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('confirm-put-away'),
            onPressed: () async {
              final paid = <String, double>{};
              _controllers.forEach((id, c) {
                final v = double.tryParse(c.text.trim().replaceAll('\$', ''));
                if (v != null && v > 0) paid[id] = v;
              });
              final navigator = Navigator.of(context);
              final n = await store.putAwayBought(paid: paid);
              navigator.pop(n);
            },
            icon: const Icon(Icons.move_to_inbox_outlined),
            label: const Text('Put away into stock'),
          ),
        ],
      ),
    );
  }
}
