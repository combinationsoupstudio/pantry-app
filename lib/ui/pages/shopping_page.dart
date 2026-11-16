import 'package:image_picker/image_picker.dart';

import 'receipt_page.dart';

import 'package:material_ui/material_ui.dart';

import '../widgets/voice_add.dart';
import '../../data/store_scope.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/name_match.dart';
import '../widgets/pictures.dart';
import '../widgets/put_away_sheet.dart';

class ShoppingPage extends StatelessWidget {
  const ShoppingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.shopping;
    final boughtCount = list.where((s) => s.bought).length;
    final byStore = <Store, List<ShoppingItem>>{};
    for (final s in list) {
      byStore.putIfAbsent(s.store, () => []).add(s);
    }
    final lowNotOnList = store.runningLow.where((i) => !list.any((s) => s.stockItemId == i.id)).length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            title: const Text('Shopping list'),
            actions: [
              PopupMenuButton<ImageSource>(
                key: const ValueKey('scan-receipt'),
                tooltip: 'Scan a receipt',
                icon: const Icon(Icons.receipt_long_outlined),
                onSelected: (src) => scanReceipt(context, source: src),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: ImageSource.camera, child: Text('Scan a receipt')),
                  PopupMenuItem(value: ImageSource.gallery, child: Text('Receipt from photos')),
                ],
              ),
              IconButton(
                key: const ValueKey('voice-shopping'),
                tooltip: 'Say it to add it',
                icon: const Icon(Icons.mic_none),
                onPressed: () => showVoiceAdd(context),
              ),
              if (boughtCount > 0)
                TextButton.icon(
                  key: const ValueKey('put-away'),
                  onPressed: () async {
                    final n = await showPutAwaySheet(context);
                    if (n == null) return;
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$n put away and added to stock')));
                    }
                  },
                  icon: const Icon(Icons.move_to_inbox_outlined),
                  label: Text('Put away $boughtCount'),
                ),
              if (list.isNotEmpty)
                PopupMenuButton<String>(
                  key: const ValueKey('shopping-menu'),
                  onSelected: (_) => _confirmClear(context, list.length),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'clear', key: ValueKey('clear-list'), child: Text('Clear list')),
                  ],
                ),
            ],
          ),
          if (lowNotOnList > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.trending_down),
                    title: Text('$lowNotOnList running low, not on the list'),
                    trailing: FilledButton.tonal(
                      key: const ValueKey('add-low'),
                      onPressed: () => store.addRunningLowToShopping(),
                      child: const Text('Add all'),
                    ),
                  ),
                ),
              ),
            ),
          if (list.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: 'The list is empty',
                  body: 'Add things yourself, or pull in everything that is running low.',
                ),
              ),
            )
          else
            for (final entry in byStore.entries) ...[
              SliverToBoxAdapter(
                child: _ShopHeader(shop: entry.key, lines: entry.value),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Still to get first; what is in the trolley sinks to the bottom.
                        for (final (n, line) in [
                          ...entry.value.where((l) => !l.bought),
                          ...entry.value.where((l) => l.bought),
                        ].indexed) ...[if (n > 0) const Divider(height: 1, indent: 60), _ShoppingRow(item: line)],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-shopping',
        onPressed: () => _addDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Clear all $count items?'),
        content: const Text('The list empties. Your stock does not change.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
          FilledButton(
            key: const ValueKey('confirm-clear'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) await StoreScope.read(context).clearShopping();
  }

  Future<void> _addDialog(BuildContext context) async {
    final name = TextEditingController();
    final qty = TextEditingController(text: '1');
    var store = Store.any;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Add to the list'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('shop-name'),
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'What'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qty,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'How many'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Store>(
                initialValue: store,
                decoration: const InputDecoration(labelText: 'Shop'),
                items: [for (final s in Store.values) DropdownMenuItem(value: s, child: Text(s.label))],
                onChanged: (v) => set(() => store = v ?? Store.any),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty && context.mounted) {
      final household = StoreScope.read(context);
      var typed = name.text.trim();
      // A close spelling of something kept is asked about, never guessed.
      final m = household.matchFor(typed);
      if (m != null && !m.sure) {
        final yes = await askSameThing(context, typed, m.item);
        if (yes == true) typed = m.item.name;
      }
      // The store stacks it onto a matching line and links it to stock.
      await household.addShopping(name: typed, quantity: double.tryParse(qty.text.trim()) ?? 1, store: store);
    }
    name.dispose();
    qty.dispose();
  }
}

/// A shop's heading: its name, how many still to get, and how many are in
/// the trolley.
class _ShopHeader extends StatelessWidget {
  const _ShopHeader({required this.shop, required this.lines});
  final Store shop;
  final List<ShoppingItem> lines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final got = lines.where((l) => l.bought).length;
    final left = lines.length - got;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        children: [
          Icon(Icons.storefront_outlined, size: 20, color: scheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              shop == Store.any ? 'Any shop' : shop.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleLarge?.copyWith(fontSize: 19),
            ),
          ),
          const SizedBox(width: 12),
          const Spacer(),
          Flexible(
            flex: 2,
            child: Text(
              got == 0 ? '$left to get' : '$left to get · $got in trolley',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// One line on the list (v0.10): tap anywhere to tick it into the trolley,
/// the picture pile, the name, and a small − amount + on the right. Hold for
/// the shop; swipe left to remove. Who added it shows only when it was
/// someone else.
class _ShoppingRow extends StatelessWidget {
  const _ShoppingRow({required this.item});
  final ShoppingItem item;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final amount = item.unit.isEmpty || item.unit == 'items'
        ? formatQty(item.quantity)
        : '${formatQty(item.quantity)} ${item.unit}';
    final stock = item.stockItemId == null ? null : store.item(item.stockItemId!);
    final count = item.quantity < 1 ? 1 : item.quantity.round();
    final pile = stock != null
        ? ItemPile(key: ValueKey('shop-pile-${item.id}'), item: stock, count: stock.pileFor(item.quantity), size: 40)
        : PicturePile(
            key: ValueKey('shop-pile-${item.id}'),
            count: count,
            size: 40,
            picture: () => ProductPicture(name: item.name, size: 40),
          );
    final someoneElse = item.addedBy.isNotEmpty && item.addedBy != store.user;
    return Dismissible(
      key: ValueKey('shop-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: scheme.errorContainer,
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) => store.removeShopping(item.id),
      child: InkWell(
        key: ValueKey('shop-tick-${item.id}'),
        onTap: () => store.setBought(item.id, !item.bought),
        onLongPress: () => _chooseShop(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              _Tick(ticked: item.bought),
              const SizedBox(width: 10),
              SizedBox(
                width: PicturePile.slotWidth(40),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Opacity(opacity: item.bought ? 0.45 : 1, child: pile),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        decoration: item.bought ? TextDecoration.lineThrough : null,
                        color: item.bought ? scheme.onSurfaceVariant : null,
                      ),
                    ),
                    if (someoneElse)
                      Text('from ${item.addedBy}', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (item.bought)
                Text(amount, style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant))
              else ...[
                _Step(
                  key: ValueKey('shop-less-${item.id}'),
                  icon: Icons.remove,
                  tooltip: 'One less',
                  onPressed: item.quantity <= 1 ? null : () => store.setShoppingQuantity(item.id, item.quantity - 1),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 34, maxWidth: 76),
                  child: Text(
                    amount,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                _Step(
                  key: ValueKey('shop-more-${item.id}'),
                  icon: Icons.add,
                  tooltip: 'One more',
                  filled: true,
                  onPressed: () => store.setShoppingQuantity(item.id, item.quantity + 1),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseShop(BuildContext context) async {
    final store = StoreScope.read(context);
    final pick = await showModalBottomSheet<Store>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Where to get ${item.name}', style: Theme.of(c).textTheme.titleLarge),
            ),
            for (final s in Store.values)
              ListTile(
                leading: Icon(s == item.store ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                title: Text(s.label),
                onTap: () => Navigator.pop(c, s),
              ),
          ],
        ),
      ),
    );
    if (pick != null) await store.setStore(item.id, pick);
  }
}

/// The round tick: empty ring to get, olive with a tick once in the trolley.
class _Tick extends StatelessWidget {
  const _Tick({required this.ticked});
  final bool ticked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ticked ? scheme.primary : Colors.transparent,
        border: Border.all(color: ticked ? scheme.primary : scheme.outline, width: 2),
      ),
      child: ticked ? Icon(Icons.check, size: 18, color: scheme.onPrimary) : null,
    );
  }
}

/// A small round - or + for a shopping line's amount.
class _Step extends StatelessWidget {
  const _Step({super.key, required this.icon, required this.tooltip, this.onPressed, this.filled = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: !on ? Colors.transparent : (filled ? scheme.primaryContainer : Colors.transparent),
        shape: CircleBorder(side: filled && on ? BorderSide.none : BorderSide(color: scheme.outlineVariant)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 32,
            child: Icon(
              icon,
              size: 18,
              color: !on ? scheme.outlineVariant : (filled ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }
}
