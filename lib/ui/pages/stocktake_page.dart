import 'package:material_ui/material_ui.dart';

import '../../data/store_scope.dart';
import '../../logic/amounts.dart';
import '../../models/models.dart';
import '../widgets/pictures.dart';

/// Stocktake: walk a cupboard and check each item in turn. "That's right"
/// moves on; a different count is typed or stepped and saved. Faster than
/// opening every item. Changes are logged as "counted", not as use, so they
/// do not skew "runs out in".
class StocktakePage extends StatefulWidget {
  const StocktakePage({super.key, required this.title, required this.itemIds});
  final String title;
  final List<String> itemIds;

  @override
  State<StocktakePage> createState() => _StocktakePageState();
}

class _StocktakePageState extends State<StocktakePage> {
  var _index = 0;
  var _right = 0;
  var _changed = 0;
  final _count = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  StockItem? get _item {
    if (_index >= widget.itemIds.length) return null;
    return StoreScope.read(context).item(widget.itemIds[_index]);
  }

  void _load() {
    final i = _item;
    if (i != null) setState(() => _count.text = formatQty(i.quantity));
  }

  double? get _typed => double.tryParse(_count.text.trim().replaceAll(',', '.'));

  void _next() {
    setState(() => _index++);
    // An item removed meanwhile is skipped.
    while (_index < widget.itemIds.length && _item == null) {
      _index++;
    }
    _load();
  }

  Future<void> _save() async {
    final i = _item;
    final v = _typed;
    if (i == null || v == null) return;
    if ((v - i.quantity).abs() < 1e-9) {
      _right++;
    } else {
      await StoreScope.read(context).countItem(i.id, v);
      _changed++;
    }
    _next();
  }

  void _step(double by) {
    final v = (_typed ?? 0) + by;
    setState(() => _count.text = formatQty(double.parse((v < 0 ? 0 : v).toStringAsFixed(2))));
  }

  @override
  Widget build(BuildContext context) {
    StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final total = widget.itemIds.length;
    final item = _item;

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Stocktake: ${widget.title}')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.task_alt, size: 72, color: scheme.primary),
                const SizedBox(height: 16),
                Text('Stocktake done', style: text.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  '$total checked: $_right right, $_changed changed${total - _right - _changed > 0 ? ', ${total - _right - _changed} skipped' : ''}.',
                  key: const ValueKey('stocktake-summary'),
                  textAlign: TextAlign.center,
                  style: text.titleMedium,
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
              ],
            ),
          ),
        ),
      );
    }

    final store = StoreScope.read(context);
    final step = item.isMeasured
        ? item.packSize / 4
        : (isMeasureUnit(item.unit)
                  ? (normaliseUnit(item.unit) == 'g' || normaliseUnit(item.unit) == 'ml' ? 100 : 0.5)
                  : 1)
              .toDouble();
    final unit = item.unit.isEmpty ? '' : ' ${item.unit}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Stocktake: ${widget.title}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(child: LinearProgressIndicator(value: _index / total, minHeight: 8)),
                const SizedBox(width: 12),
                Text('${_index + 1} of $total', key: const ValueKey('stocktake-progress'), style: text.labelLarge),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: ProductPicture.of(item, size: 140)),
            const SizedBox(height: 16),
            Text(item.name, textAlign: TextAlign.center, style: text.headlineSmall),
            Text(
              store.location(item.locationId)?.name ?? '',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'The app says ${formatQty(item.quantity)}$unit${item.isMeasured ? ' (${item.packLabel} packs)' : ''}',
              textAlign: TextAlign.center,
              style: text.titleMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('stocktake-right'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: () {
                _right++;
                _next();
              },
              icon: const Icon(Icons.check),
              label: const Text("That's right"),
            ),
            const SizedBox(height: 24),
            Text('Or count it', style: text.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(tooltip: 'Less', onPressed: () => _step(-step), icon: const Icon(Icons.remove)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const ValueKey('stocktake-count'),
                    controller: _count,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: text.headlineSmall,
                    decoration: InputDecoration(suffixText: item.unit),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(tooltip: 'More', onPressed: () => _step(step), icon: const Icon(Icons.add)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('stocktake-skip'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: _next,
                    child: const Text('Skip'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonal(
                    key: const ValueKey('stocktake-save'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: _typed == null ? null : _save,
                    child: const Text('Save count'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
