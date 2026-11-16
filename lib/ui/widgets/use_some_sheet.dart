import 'package:material_ui/material_ui.dart';

import 'common.dart';

import '../../data/store_scope.dart';
import '../../logic/amounts.dart';
import '../../models/models.dart';
import '../theme.dart';

/// "Use some...": take an amount off an item in any measure that converts
/// to it (cups, tablespoons and teaspoons for an ml item; g or kg for a
/// weighed one), with a live "leaves" line before it is taken.
Future<void> showUseSomeSheet(BuildContext context, StockItem item) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _UseSomeSheet(item: item),
);

class _UseSomeSheet extends StatefulWidget {
  const _UseSomeSheet({required this.item});
  final StockItem item;

  @override
  State<_UseSomeSheet> createState() => _UseSomeSheetState();
}

class _UseSomeSheetState extends State<_UseSomeSheet> {
  final _amount = TextEditingController();
  late final List<String> _units = useUnitsFor(widget.item.unit.isEmpty ? 'each' : widget.item.unit);
  late String _unit = _units.first;

  @override
  void initState() {
    super.initState();
    // Start on the item's own unit.
    final own = _units.where((u) => normaliseUnit(u) == normaliseUnit(widget.item.unit));
    if (own.isNotEmpty) _unit = own.first;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// The amount typed, in the item's own unit; null when none is typed.
  double? get _taken {
    final v = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    if (v == null || v <= 0) return null;
    if (widget.item.unit.isEmpty) return v;
    return convertUnits(v, _unit, widget.item.unit);
  }

  void _setOwn(double amount) {
    setState(() {
      final own = _units.where((u) => normaliseUnit(u) == normaliseUnit(widget.item.unit));
      if (own.isNotEmpty) _unit = own.first;
      _amount.text = formatQty(double.parse(amount.toStringAsFixed(2)));
    });
  }

  Future<void> _use() async {
    final t = _taken;
    if (t == null) return;
    await StoreScope.read(context).adjust(widget.item.id, -t);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final text = Theme.of(context).textTheme;
    final status = StatusColors.of(context);
    final t = _taken;
    final left = t == null ? null : (item.quantity - t).clamp(0, double.infinity).toDouble();
    final over = t != null && t > item.quantity + 1e-9;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, sheetBottom(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Use some ${item.name}', style: text.titleLarge),
          const SizedBox(height: 4),
          Text('Have ${formatMeasure(item.quantity, item.unit)}', style: text.bodyMedium),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('use-amount'),
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'How much'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _use(),
          ),
          if (_units.length > 1) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final u in _units)
                  ChoiceChip(
                    key: ValueKey('use-unit-$u'),
                    label: Text(u),
                    selected: _unit == u,
                    onSelected: (_) => setState(() => _unit = u),
                  ),
              ],
            ),
          ],
          if (item.isMeasured) ...[
            const SizedBox(height: 12),
            Text('Quick amounts', style: text.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, part) in const [('¼ pack', 0.25), ('½ pack', 0.5), ('Whole pack', 1.0)])
                  ActionChip(label: Text(label), onPressed: () => _setOwn(item.packSize * part)),
                ActionChip(label: const Text('All of it'), onPressed: () => _setOwn(item.quantity)),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (t == null && _amount.text.trim().isNotEmpty)
            Text('Type a number', style: text.bodyMedium?.copyWith(color: status.out))
          else if (left != null)
            Text(
              over
                  ? 'That is more than you have. It will go to 0.'
                  : 'Takes ${formatMeasure(t!, item.unit)}, leaves ${formatMeasure(left, item.unit)}',
              key: const ValueKey('use-leaves'),
              style: text.titleMedium?.copyWith(
                color: over || left == 0 ? status.out : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('use-confirm'),
            onPressed: t == null ? null : _use,
            child: const Text('Use'),
          ),
        ],
      ),
    );
  }
}
