import 'package:material_ui/material_ui.dart';

import '../../data/store_scope.dart';
import '../../logic/usage.dart';
import '../../models/models.dart';

const commonUnits = ['', 'items', 'cans', 'packs', 'bottles', 'jars', 'boxes', 'rolls', 'kg', 'g', 'L', 'mL'];

double? _parse(String text) {
  final t = text.trim();
  if (t.isEmpty) return 0;
  final v = double.tryParse(t);
  return (v == null || v < 0) ? null : v;
}

/// Add a new item (when [existing] is null) or edit one.
Future<void> showItemEditor(
  BuildContext context, {
  StockItem? existing,
  LocationKind kind = LocationKind.pantry,
  String? locationId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ItemEditor(existing: existing, kind: kind, locationId: locationId),
  );
}

class _ItemEditor extends StatefulWidget {
  const _ItemEditor({this.existing, required this.kind, this.locationId});
  final StockItem? existing;
  final LocationKind kind;
  final String? locationId;

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _qty;
  late final TextEditingController _target;
  late String _unit;
  late String _locationId;
  DateTime? _useBy;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _qty = TextEditingController(text: e == null ? '1' : formatQty(e.quantity));
    _target = TextEditingController(text: e == null || !e.hasTarget ? '' : formatQty(e.target));
    _unit = e?.unit ?? '';
    _useBy = e?.useBy;
    _locationId = e?.locationId ?? widget.locationId ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final store = StoreScope.read(context);
    final qty = _parse(_qty.text)!;
    final target = _parse(_target.text)!;
    final e = widget.existing;
    if (e == null) {
      await store.addItem(
        name: _name.text,
        locationId: _locationId,
        quantity: qty,
        unit: _unit,
        target: target,
        useBy: _useBy,
      );
    } else {
      await store.updateItem(
        e.copyWith(
          name: _name.text.trim(),
          locationId: _locationId,
          quantity: qty,
          unit: _unit,
          target: target,
          useBy: _useBy,
          clearUseBy: _useBy == null,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final e = widget.existing!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remove ${e.name}?'),
        content: const Text('It comes off the stock list. The history keeps a note of it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await StoreScope.read(context).removeItem(e.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final kind = widget.existing == null
        ? widget.kind
        : (store.location(widget.existing!.locationId)?.kind ?? widget.kind);
    final locations = [
      ...store.locationsOf(kind),
      ...store.locationsOf(kind == LocationKind.pantry ? LocationKind.storage : LocationKind.pantry),
    ];
    if (_locationId.isEmpty || store.location(_locationId) == null) _locationId = locations.first.id;
    final units = {...commonUnits, _unit}.toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.existing == null ? 'Add item' : 'Edit item', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('field-name'),
                controller: _name,
                autofocus: widget.existing == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Tinned tomatoes'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Give it a name' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('field-qty'),
                      controller: _qty,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Have'),
                      validator: (v) => _parse(v ?? '') == null ? 'A number' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: [for (final u in units) DropdownMenuItem(value: u, child: Text(u.isEmpty ? '—' : u))],
                      onChanged: (v) => setState(() => _unit = v ?? ''),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('field-target'),
                controller: _target,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Keep at least',
                  helperText: 'Below this it goes on the running-low list. Leave empty for no target.',
                ),
                validator: (v) => _parse(v ?? '') == null ? 'A number' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _locationId,
                decoration: const InputDecoration(labelText: 'Kept in'),
                items: [for (final l in locations) DropdownMenuItem(value: l.id, child: Text(l.name))],
                onChanged: (v) => setState(() => _locationId = v ?? _locationId),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(
                  _useBy == null ? 'No use-by date' : 'Use by ${_useBy!.day}/${_useBy!.month}/${_useBy!.year}',
                ),
                trailing: _useBy == null
                    ? null
                    : IconButton(
                        tooltip: 'Clear date',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _useBy = null),
                      ),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 10),
                    initialDate: _useBy ?? now,
                  );
                  if (picked != null) setState(() => _useBy = picked);
                },
              ),
              if (widget.existing != null) _ItemFacts(item: widget.existing!),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (widget.existing != null)
                    TextButton.icon(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove'),
                    ),
                  const Spacer(),
                  FilledButton(key: const ValueKey('save-item'), onPressed: _save, child: const Text('Save')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Move some of an item to another location (e.g. prep pantry -> pantry).
Future<void> showMoveSheet(BuildContext context, StockItem item) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _MoveSheet(item: item),
  );
}

class _MoveSheet extends StatefulWidget {
  const _MoveSheet({required this.item});
  final StockItem item;

  @override
  State<_MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends State<_MoveSheet> {
  late double _amount = widget.item.quantity >= 1 ? 1 : widget.item.quantity;
  String? _to;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final item = widget.item;
    final others = store.locations.where((l) => l.id != item.locationId).toList();
    _to ??= others.isEmpty ? null : others.first.id;
    final max = item.quantity;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Move ${item.name}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('From ${store.location(item.locationId)?.name ?? ''}, ${formatQty(max)} ${item.unit} there now.'),
          const SizedBox(height: 16),
          if (max <= 0)
            const Text('Nothing left here to move.')
          else ...[
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _amount > 1 ? () => setState(() => _amount -= 1) : null,
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Text(
                    '${formatQty(_amount)} ${item.unit}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _amount + 1 <= max ? () => setState(() => _amount += 1) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _to,
              decoration: const InputDecoration(labelText: 'Move to'),
              items: [for (final l in others) DropdownMenuItem(value: l.id, child: Text(l.name))],
              onChanged: (v) => setState(() => _to = v),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _to == null
                  ? null
                  : () async {
                      await store.move(item.id, _to!, _amount);
                      if (context.mounted) Navigator.of(context).pop();
                    },
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Move'),
            ),
          ],
        ],
      ),
    );
  }
}

/// What the app knows about an existing item: how long it lasts at the
/// current rate, and what it cost at each shop (cheapest first).
class _ItemFacts extends StatelessWidget {
  const _ItemFacts({required this.item});
  final StockItem item;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final current = store.item(item.id) ?? item;
    final left = store.daysLeftFor(current);
    final prices = store.latestByStore(current);
    if (left == null && prices.isEmpty) return const SizedBox.shrink();
    final unit = current.unit.isEmpty ? 'each' : current.unit;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (left != null)
                Text('Runs out in about ${describeDays(left)} at the current rate', style: text.bodyMedium),
              if (prices.isNotEmpty) ...[
                if (left != null) const SizedBox(height: 8),
                Text('Last paid', style: text.labelLarge),
                const SizedBox(height: 4),
                for (var n = 0; n < prices.length; n++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(child: Text(prices[n].store.label)),
                        Text(
                          '${formatMoney(prices[n].unitPrice)} / ${prices[n].unit.isEmpty ? 'each' : prices[n].unit}',
                          style: text.bodyMedium?.copyWith(
                            fontWeight: n == 0 && prices.length > 1 ? FontWeight.w800 : null,
                            color: n == 0 && prices.length > 1 ? scheme.primary : null,
                          ),
                        ),
                        if (n == 0 && prices.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text('cheapest', style: text.labelSmall?.copyWith(color: scheme.primary)),
                          ),
                      ],
                    ),
                  ),
                if (prices.first.unit.isNotEmpty && prices.first.unit != unit)
                  Text('Shown per unit as bought.', style: text.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
