import 'package:material_ui/material_ui.dart';

import '../../data/store_scope.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

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
              if (boughtCount > 0)
                TextButton.icon(
                  key: const ValueKey('put-away'),
                  onPressed: () async {
                    final n = await store.putAwayBought();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$n put away and added to stock')));
                    }
                  },
                  icon: const Icon(Icons.move_to_inbox_outlined),
                  label: Text('Put away $boughtCount'),
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
              SliverToBoxAdapter(child: SectionHeader(entry.key.label)),
              SliverList.list(children: [for (final s in entry.value) _ShoppingRow(item: s)]),
            ],
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 96),
              child: Text(
                'Prices and specials for Batemans Bay stores arrive in a later release.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
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
      // Link to a stock item of the same name so "put away" tops it up.
      final s = StoreScope.read(context);
      final match = s.items.where((i) => i.name.toLowerCase() == name.text.trim().toLowerCase()).firstOrNull;
      await s.addShopping(
        name: name.text,
        quantity: double.tryParse(qty.text.trim()) ?? 1,
        unit: match?.unit ?? '',
        store: store,
        stockItemId: match?.id,
      );
    }
    name.dispose();
    qty.dispose();
  }
}

class _ShoppingRow extends StatelessWidget {
  const _ShoppingRow({required this.item});
  final ShoppingItem item;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final amount = '${formatQty(item.quantity)}${item.unit.isEmpty ? '' : ' ${item.unit}'}';
    return Dismissible(
      key: ValueKey('shop-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Theme.of(context).colorScheme.errorContainer,
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) => store.removeShopping(item.id),
      child: CheckboxListTile(
        value: item.bought,
        onChanged: (v) => store.setBought(item.id, v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(item.name, style: item.bought ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
        subtitle: Text('$amount  ·  added by ${item.addedBy}'),
        secondary: PopupMenuButton<Store>(
          tooltip: 'Choose shop',
          icon: const Icon(Icons.storefront_outlined),
          onSelected: (s) => store.setStore(item.id, s),
          itemBuilder: (_) => [for (final s in Store.values) PopupMenuItem(value: s, child: Text(s.label))],
        ),
      ),
    );
  }
}
