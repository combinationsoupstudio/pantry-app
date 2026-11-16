import 'package:material_ui/material_ui.dart';

import 'common.dart';

import '../../data/store_scope.dart';
import '../../logic/amounts.dart';
import '../../logic/recipes.dart';
import '../../models/models.dart';

/// "I cooked this": shows what comes out of stock for each ingredient you
/// have, worked out from the recipe's amounts where they convert, ready to
/// adjust or untick before it is taken.
Future<bool?> showCookSheet(BuildContext context, RecipeMatch match) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _CookSheet(match: match),
);

class _Use {
  _Use(this.item, this.line, this.amount);
  final StockItem item;
  final String line;
  double amount;
  bool on = true;
}

class _CookSheet extends StatefulWidget {
  const _CookSheet({required this.match});
  final RecipeMatch match;

  @override
  State<_CookSheet> createState() => _CookSheetState();
}

class _CookSheetState extends State<_CookSheet> {
  late final List<_Use> _uses;

  @override
  void initState() {
    super.initState();
    final store = StoreScope.read(context);
    final seen = <String>{};
    _uses = [];
    for (final i in widget.match.have) {
      final stock = stockItemFor(i, store.items, inStockOnly: true);
      if (stock == null || !seen.add(stock.id)) continue;
      // A measured item with no amount on the line starts at one step
      // (e.g. 25 ml of a 500 ml bottle), not "1 ml".
      final need = amountNeeded(i.line, stock);
      final want = need ?? _startAmount(stock);
      _uses.add(_Use(stock, i.line, want > stock.quantity ? stock.quantity : want));
    }
    // What we were short of gets used up.
    for (final s in widget.match.short) {
      if (!seen.add(s.item.id)) continue;
      _uses.add(_Use(s.item, s.ingredient.line, s.item.quantity));
    }
  }

  static double _measuredStep(StockItem item) => item.packSize <= 100
      ? 5
      : item.packSize <= 1000
      ? 25
      : 100;

  /// What a recipe line with no amount starts at: one step of a measured
  /// item, a quarter kilo or litre, 250 g or ml, or one of a counted thing.
  static double _startAmount(StockItem item) {
    if (item.isMeasured) return _measuredStep(item);
    switch (normaliseUnit(item.unit)) {
      case 'kg' || 'l':
        return 0.25;
      case 'g' || 'ml':
        return 250;
      default:
        return 1;
    }
  }

  double _step(_Use u) {
    if (u.item.isMeasured) return _measuredStep(u.item);
    switch (normaliseUnit(u.item.unit)) {
      case 'kg' || 'l':
        return 0.1;
      case 'g' || 'ml':
        return 50;
      default:
        return 1;
    }
  }

  /// Type the amount used, in any measure that converts to the item's.
  Future<void> _typeAmount(_Use u) async {
    final typed = await showDialog<double>(
      context: context,
      builder: (_) => _AmountDialog(item: u.item, start: u.amount),
    );
    if (typed == null || !mounted) return;
    setState(() {
      u.amount = _round(typed > u.item.quantity ? u.item.quantity : typed);
      u.on = u.amount > 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      // Clear of the phone's own buttons at the bottom of the screen.
      padding: EdgeInsets.fromLTRB(16, 0, 16, sheetBottom(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('I cooked ${widget.match.recipe.name}', style: text.titleLarge),
          const SizedBox(height: 4),
          const Text('This comes out of stock. Tap an amount to type what you used, or untick what you did not use.'),
          const SizedBox(height: 8),
          if (_uses.isEmpty) const Text('None of the ingredients are tracked in stock.'),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final u in _uses)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Checkbox(value: u.on, onChanged: (v) => setState(() => u.on = v ?? false)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.item.name, style: text.titleSmall),
                              Text(
                                'Recipe: ${sentenceCase(u.line)}',
                                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Less',
                          onPressed: !u.on || u.amount <= 0
                              ? null
                              : () => setState(() => u.amount = _round(u.amount - _step(u))),
                          icon: const Icon(Icons.remove),
                        ),
                        InkWell(
                          key: ValueKey('cook-amount-${u.item.id}'),
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _typeAmount(u),
                          child: Container(
                            width: 76,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            child: Text(
                              formatMeasure(u.amount, u.item.unit),
                              textAlign: TextAlign.center,
                              style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'More',
                          onPressed: !u.on || u.amount >= u.item.quantity
                              ? null
                              : () => setState(() => u.amount = _round(u.amount + _step(u))),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('confirm-cook'),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await StoreScope.read(context).cook(widget.match.recipe.name, {
                for (final u in _uses)
                  if (u.on && u.amount > 0) u.item.id: u.amount,
              });
              navigator.pop(true);
            },
            icon: const Icon(Icons.restaurant),
            label: const Text('Take it out of stock'),
          ),
        ],
      ),
    );
  }

  static double _round(double v) => v < 0 ? 0 : double.parse(v.toStringAsFixed(2));
}

/// Type an amount used: a number and a measure (cups, tbsp, g ...) that
/// converts to the item's own unit, with the result shown before it is set.
class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.item, required this.start});
  final StockItem item;
  final double start;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final _field = TextEditingController(text: formatQty(widget.start));
  late final List<String> _units = useUnitsFor(widget.item.unit.isEmpty ? 'each' : widget.item.unit);
  late String _unit = _units.firstWhere(
    (u) => normaliseUnit(u) == normaliseUnit(widget.item.unit),
    orElse: () => _units.first,
  );

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  /// The typed amount in the item's own unit; null when it is not a number.
  double? get _value {
    final v = double.tryParse(_field.text.trim().replaceAll(',', '.'));
    if (v == null || v < 0) return null;
    if (widget.item.unit.isEmpty) return v;
    return convertUnits(v, _unit, widget.item.unit);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final v = _value;
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text('How much ${item.name}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('cook-amount-field'),
            controller: _field,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount used'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => v == null ? null : Navigator.pop(context, v),
          ),
          if (_units.length > 1) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final u in _units)
                  ChoiceChip(
                    key: ValueKey('cook-unit-$u'),
                    label: Text(u),
                    selected: _unit == u,
                    onSelected: (_) => setState(() => _unit = u),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            v == null
                ? 'Type a number'
                : v > item.quantity + 1e-9
                ? 'More than you have (${formatMeasure(item.quantity, item.unit)}): all of it comes out'
                : '= ${formatMeasure(double.parse(v.toStringAsFixed(3)), item.unit)} of ${formatMeasure(item.quantity, item.unit)}',
            key: const ValueKey('cook-amount-result'),
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          key: const ValueKey('cook-amount-ok'),
          onPressed: v == null ? null : () => Navigator.pop(context, v),
          child: const Text('Set'),
        ),
      ],
    );
  }
}
