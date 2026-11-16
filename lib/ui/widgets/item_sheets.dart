import 'package:material_ui/material_ui.dart';

import 'common.dart';

import '../../data/open_food_facts.dart';
import '../../data/picture_finder.dart';
import '../../data/store_scope.dart';
import '../../logic/amounts.dart';
import '../../logic/usage.dart';
import '../../models/models.dart';
import 'capture.dart';
import 'picture_search.dart';
import 'pictures.dart';
import 'use_some_sheet.dart';

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

  // Measured items: pack size, unopened packs, what is left in the open one.
  late bool _measured;
  late final TextEditingController _packSize;
  late final TextEditingController _packs;
  late final TextEditingController _left;
  late final TextEditingController _targetPacks;
  late String _mUnit;

  String? _barcode;
  String? _photoPath;
  String? _imageUrl;
  bool _byName = false;
  bool _looking = false;

  /// What the scan found, shown under the buttons.
  String? _found;

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
    _barcode = e?.barcode;
    _photoPath = e?.photoPath;
    _imageUrl = e?.imageUrl;
    _byName = e?.pictureByName ?? false;

    _measured = e?.isMeasured ?? false;
    _mUnit = _keptUnit(e?.unit ?? 'ml');
    final size = e != null && e.isMeasured ? e.packSize : 0.0;
    var packs = 0.0;
    var left = 0.0;
    if (size > 0) {
      packs = ((e!.quantity - 1e-9) / size).floorToDouble().clamp(0, double.infinity).toDouble();
      left = double.parse((e.quantity - packs * size).toStringAsFixed(2));
    }
    _packSize = TextEditingController(text: size > 0 ? formatQty(size) : '');
    _packs = TextEditingController(text: formatQty(packs));
    _left = TextEditingController(text: size > 0 ? formatQty(left) : '');
    _targetPacks = TextEditingController(
      text: size > 0 && e!.hasTarget ? formatQty(double.parse((e.target / size).toStringAsFixed(2))) : '',
    );
  }

  /// One of the dropdown's units: ml, L, g, kg (ml when it is none of them).
  static String _keptUnit(String unit) {
    final n = normaliseUnit(unit);
    for (final u in keptMeasures) {
      if (normaliseUnit(u) == n) return u;
    }
    return 'ml';
  }

  @override
  void dispose() {
    for (final c in [_name, _qty, _target, _packSize, _packs, _left, _targetPacks]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setMeasured(bool on) {
    setState(() {
      _measured = on;
      if (on) {
        if (isMeasureUnit(_unit)) _mUnit = _keptUnit(_unit);
        if (_left.text.trim().isEmpty) _left.text = _packSize.text;
      } else {
        // Back to counting: the amount stays, in the measure it was kept in.
        final total = (_parse(_packs.text) ?? 0) * (_parse(_packSize.text) ?? 0) + (_parse(_left.text) ?? 0);
        _qty.text = formatQty(double.parse(total.toStringAsFixed(2)));
        _unit = _mUnit;
      }
    });
  }

  Future<void> _scan() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    final store = StoreScope.read(context);
    final known = store.itemByBarcode(code);
    if (known != null && known.id != widget.existing?.id) {
      final add = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('You already have ${known.name}'),
          content: Text(
            known.isMeasured
                ? 'Add a ${known.packLabel} pack to it?'
                : 'Add one to it? You have ${formatQty(known.quantity)} now.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No, add it here')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Add to it')),
          ],
        ),
      );
      if (!mounted) return;
      if (add == true) {
        await store.addPack(known.id);
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(SnackBar(content: Text('Added to ${known.name}')));
        return;
      }
    }
    setState(() {
      _barcode = code;
      _looking = true;
      _found = null;
    });
    try {
      final info = await OpenFoodFacts.instance.lookup(code);
      if (!mounted) return;
      setState(() {
        if (info == null) {
          _found = 'Not on Open Food Facts yet. Type the name; the barcode is kept for next time.';
          return;
        }
        final name = info.displayName;
        if (name.isNotEmpty && (widget.existing == null || _name.text.trim().isEmpty)) _name.text = name;
        if (info.imageUrl != null) {
          _imageUrl = info.imageUrl;
          _byName = false;
        }
        if (info.hasPackSize) {
          _measured = true;
          _mUnit = _keptUnit(info.unit);
          _packSize.text = formatQty(info.packSize);
          if (widget.existing == null) {
            _packs.text = '0';
            _left.text = formatQty(info.packSize);
          }
        }
        _found = [
          'Found: ${name.isEmpty ? 'a product with no name' : name}',
          if (info.hasPackSize) formatMeasure(info.packSize, info.unit),
        ].join('  ·  ');
      });
    } on LookupFailed catch (e) {
      if (mounted) setState(() => _found = '$e. The barcode is kept; type the name.');
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  Future<void> _findPicture() async {
    final picked = await showPictureSearch(context, initial: _name.text.trim());
    if (picked == null || !mounted) return;
    setState(() {
      if (picked.imageUrl != null) {
        _imageUrl = picked.imageUrl;
        _byName = false;
      }
      if (_name.text.trim().isEmpty) _name.text = picked.displayName;
      _found = [
        'Picture: ${picked.displayName}',
        if (picked.quantityText.isNotEmpty) picked.quantityText,
      ].join('  ·  ');
    });
  }

  void _removePicture() => setState(() {
    if (_photoPath != null) {
      _photoPath = null;
    } else {
      _imageUrl = null;
      _byName = false;
    }
  });

  Future<void> _photo() async {
    try {
      final path = await takeItemPhoto();
      if (path != null && mounted) setState(() => _photoPath = path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('The camera could not open. Check camera access in Settings.')));
      }
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final store = StoreScope.read(context);
    final double qty;
    final double target;
    final String unit;
    final double packSize;
    if (_measured) {
      packSize = _parse(_packSize.text)!;
      qty = (_parse(_packs.text) ?? 0) * packSize + _parse(_left.text)!;
      target = (_parse(_targetPacks.text) ?? 0) * packSize;
      unit = _mUnit;
    } else {
      packSize = 0;
      qty = _parse(_qty.text)!;
      target = _parse(_target.text)!;
      unit = _unit;
    }
    final e = widget.existing;
    if (e == null) {
      await store.addItem(
        name: _name.text,
        locationId: _locationId,
        quantity: qty,
        unit: unit,
        target: target,
        useBy: _useBy,
        packSize: packSize,
        barcode: _barcode,
        photoPath: _photoPath,
        imageUrl: _imageUrl,
      );
      PictureFinder.instance?.nudge();
    } else {
      await store.updateItem(
        e.copyWith(
          name: _name.text.trim(),
          locationId: _locationId,
          quantity: qty,
          unit: unit,
          target: target,
          useBy: _useBy,
          clearUseBy: _useBy == null,
          packSize: packSize,
          barcode: _barcode,
          clearBarcode: _barcode == null,
          photoPath: _photoPath,
          clearPhoto: _photoPath == null,
          imageUrl: _imageUrl,
          clearImage: _imageUrl == null,
          pictureByName: _imageUrl != null && _byName,
          // A new name is worth a fresh look for a picture.
          pictureTried: e.pictureTried && _name.text.trim() == e.name,
        ),
      );
      PictureFinder.instance?.nudge();
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

  String? _number(String? v) => _parse(v ?? '') == null ? 'A number' : null;

  List<Widget> _countedFields() => [
    Row(
      children: [
        Expanded(
          child: TextFormField(
            key: const ValueKey('field-qty'),
            controller: _qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Have'),
            validator: _number,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _unit,
            decoration: const InputDecoration(labelText: 'Unit'),
            items: [
              for (final u in {...commonUnits, _unit}) DropdownMenuItem(value: u, child: Text(u.isEmpty ? '—' : u)),
            ],
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
      validator: _number,
    ),
  ];

  List<Widget> _measuredFields(BuildContext context) {
    final size = _parse(_packSize.text) ?? 0;
    final unitLabel = _mUnit;
    return [
      Row(
        children: [
          Expanded(
            child: TextFormField(
              key: const ValueKey('field-pack-size'),
              controller: _packSize,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'One pack holds', hintText: 'e.g. 500'),
              onChanged: (_) => setState(() {}),
              validator: (v) => (_parse(v ?? '') ?? 0) <= 0 ? 'How much is in one pack' : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              key: const ValueKey('field-measure-unit'),
              initialValue: _mUnit,
              decoration: const InputDecoration(labelText: 'Measured in'),
              items: [for (final u in keptMeasures) DropdownMenuItem(value: u, child: Text(u))],
              onChanged: (v) => setState(() => _mUnit = v ?? _mUnit),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              key: const ValueKey('field-left'),
              controller: _left,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Left in the open one', suffixText: unitLabel),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final left = _parse(v ?? '');
                if (left == null) return 'A number';
                if (size > 0 && left > size) return 'More than a pack holds';
                return null;
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              key: const ValueKey('field-packs'),
              controller: _packs,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Unopened packs'),
              validator: _number,
            ),
          ),
        ],
      ),
      if (size > 0) ...[
        const SizedBox(height: 8),
        Text('Roughly how much is left?', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, part) in const [('Full', 1.0), ('¾', 0.75), ('½', 0.5), ('¼', 0.25), ('Empty', 0.0)])
              ChoiceChip(
                key: ValueKey('left-$label'),
                label: Text(label),
                selected: _parse(_left.text) == double.parse((size * part).toStringAsFixed(2)),
                onSelected: (_) =>
                    setState(() => _left.text = formatQty(double.parse((size * part).toStringAsFixed(2)))),
              ),
          ],
        ),
      ],
      const SizedBox(height: 12),
      TextFormField(
        key: const ValueKey('field-target-packs'),
        controller: _targetPacks,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Keep at least (packs)',
          helperText: 'Below this it goes on the running-low list. Leave empty for no target.',
        ),
        validator: _number,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final kind = widget.existing == null
        ? widget.kind
        : (store.location(widget.existing!.locationId)?.kind ?? widget.kind);
    final locations = [
      ...store.locationsOf(kind),
      ...store.locationsOf(kind == LocationKind.pantry ? LocationKind.storage : LocationKind.pantry),
    ];
    if (_locationId.isEmpty || store.location(_locationId) == null) _locationId = locations.first.id;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, sheetBottom(context)),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ProductPicture(
                    key: const ValueKey('editor-picture'),
                    name: _name.text.isEmpty ? '?' : _name.text,
                    photoPath: _photoPath,
                    imageUrl: _imageUrl,
                    size: 80,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.existing == null ? 'Add item' : 'Edit item', style: text.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          _photoPath != null
                              ? 'Your photo'
                              : _imageUrl != null && _byName
                              ? 'Found by name. Check it is your pack; Find picture to change it.'
                              : _imageUrl != null
                              ? 'Picture: Open Food Facts'
                              : 'No picture yet',
                          style: text.bodySmall,
                        ),
                        if (_photoPath != null || _imageUrl != null)
                          TextButton(
                            key: const ValueKey('remove-picture'),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                            onPressed: _removePicture,
                            child: const Text('Remove picture'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('scan-barcode'),
                    onPressed: _looking ? null : _scan,
                    icon: _looking
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.qr_code_scanner),
                    label: Text(_looking ? 'Looking up' : 'Scan barcode'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('find-picture'),
                    onPressed: _findPicture,
                    icon: const Icon(Icons.image_search),
                    label: const Text('Find picture'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('take-photo'),
                    onPressed: _photo,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(_photoPath == null ? 'Take photo' : 'New photo'),
                  ),
                ],
              ),
              if (_found != null || _barcode != null) ...[
                const SizedBox(height: 8),
                Text(
                  _found ?? 'Barcode $_barcode',
                  key: const ValueKey('scan-result'),
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('field-name'),
                controller: _name,
                autofocus: widget.existing == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Tinned tomatoes'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Give it a name' : null,
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                key: const ValueKey('field-measured'),
                contentPadding: EdgeInsets.zero,
                value: _measured,
                onChanged: _setMeasured,
                title: const Text('Measure how much is left'),
                subtitle: const Text('For bottles and bags you use bit by bit, e.g. 300 ml of a 500 ml soy sauce'),
              ),
              const SizedBox(height: 4),
              ...(_measured ? _measuredFields(context) : _countedFields()),
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
                  if (widget.existing != null && !widget.existing!.isOut)
                    TextButton(
                      key: const ValueKey('editor-use-some'),
                      onPressed: () {
                        final item = widget.existing!;
                        final nav = Navigator.of(context)..pop();
                        showUseSomeSheet(nav.context, item);
                      },
                      child: const Text('Use some…'),
                    ),
                  const SizedBox(width: 8),
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
      padding: EdgeInsets.fromLTRB(16, 0, 16, sheetBottom(context)),
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
                          '${formatMoney(prices[n].unitPrice)} / ${prices[n].perLabel}',
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
