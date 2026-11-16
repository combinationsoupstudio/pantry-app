import 'package:material_ui/material_ui.dart';

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
      final want = amountToUse(i.line, stock.unit);
      _uses.add(_Use(stock, i.line, want > stock.quantity ? stock.quantity : want));
    }
  }

  double _step(_Use u) => u.amount < 1 || u.item.quantity < 1 ? 0.1 : 1;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('I cooked ${widget.match.recipe.name}', style: text.titleLarge),
          const SizedBox(height: 4),
          const Text('This comes out of stock. Change any amount, or untick what you did not use.'),
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
                        SizedBox(
                          width: 64,
                          child: Text(
                            '${formatQty(u.amount)}${u.item.unit.isEmpty ? '' : ' ${u.item.unit}'}',
                            textAlign: TextAlign.center,
                            style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
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
