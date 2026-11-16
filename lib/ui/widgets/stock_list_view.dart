import 'package:material_ui/material_ui.dart';

import 'voice_add.dart';
import 'scan_to_use.dart';
import '../pages/stocktake_page.dart';
import '../../data/store_scope.dart';
import '../../models/models.dart';
import 'common.dart';
import 'item_sheets.dart';
import 'stock_tile.dart';

/// The Pantry page's body (v0.10: one page for everything kept): a search
/// box, location chips (kitchen first, then the places extra stock is stored
/// away), and the stock with - / +. With no place picked, kitchen stock comes
/// first and the stored-away stock follows under its own heading.
class StockListView extends StatefulWidget {
  const StockListView({super.key, this.kind, required this.title, required this.emptyHint});

  /// Only one kind of place (null: every place).
  final LocationKind? kind;
  final String title;
  final String emptyHint;

  @override
  State<StockListView> createState() => _StockListViewState();
}

class _StockListViewState extends State<StockListView> {
  String? _locationId;
  String _query = '';
  bool _lowOnly = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final kinds = widget.kind == null ? LocationKind.values : [widget.kind!];
    if (_locationId != null && store.location(_locationId!) == null) _locationId = null;
    final picked = _locationId == null ? null : store.location(_locationId!);
    List<StockItem> itemsIn(LocationKind k) {
      var list = store.itemsOf(k, locationId: _locationId);
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        list = list.where((i) => i.name.toLowerCase().contains(q)).toList();
      }
      if (_lowOnly) list = list.where((i) => i.isLow).toList();
      return list;
    }

    final groups = <(LocationKind, List<StockItem>)>[
      for (final k in kinds)
        if (picked == null || picked.kind == k) (k, itemsIn(k)),
    ].where((g) => g.$2.isNotEmpty).toList();
    final items = [for (final g in groups) ...g.$2];
    final headed = picked == null && kinds.length > 1;
    final addKind = picked?.kind ?? widget.kind ?? LocationKind.pantry;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            title: Text(widget.title),
            floating: true,
            actions: [
              IconButton(
                key: ValueKey('voice-${widget.kind?.name ?? 'all'}'),
                tooltip: 'Say it to add it',
                icon: const Icon(Icons.mic_none),
                onPressed: () => showVoiceAdd(
                  context,
                  target: VoiceTarget.stock,
                  locationId: _locationId ?? (widget.kind == LocationKind.storage ? 'prep' : 'pantry'),
                ),
              ),
              IconButton(
                key: ValueKey('scan-use-${widget.kind?.name ?? 'all'}'),
                tooltip: 'Scan to use',
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () => scanToUse(context, kind: addKind),
              ),
              IconButton(
                key: ValueKey('stocktake-${widget.kind?.name ?? 'all'}'),
                tooltip: 'Stocktake',
                icon: const Icon(Icons.fact_check_outlined),
                onPressed: () {
                  final place = picked?.name;
                  final list = [
                    for (final k in kinds)
                      if (picked == null || picked.kind == k) ...store.itemsOf(k, locationId: _locationId),
                  ];
                  if (list.isEmpty) return;
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          StocktakePage(title: place ?? widget.title, itemIds: [for (final i in list) i.id]),
                    ),
                  );
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SearchBar(
                hintText: 'Search ${widget.title.toLowerCase()}',
                leading: const Icon(Icons.search),
                elevation: const WidgetStatePropertyAll(0),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _chip('All', _locationId == null, () => setState(() => _locationId = null)),
                  for (final (n, k) in kinds.indexed) ...[
                    if (n > 0)
                      Container(
                        width: 1,
                        height: 24,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    for (final l in store.locationsOf(k))
                      _chip(l.name, _locationId == l.id, () => setState(() => _locationId = l.id)),
                  ],
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Running low'),
                    selected: _lowOnly,
                    onSelected: (v) => setState(() => _lowOnly = v),
                  ),
                ],
              ),
            ),
          ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: EmptyState(
                  icon: Icons.inventory_outlined,
                  title: _query.isNotEmpty || _lowOnly ? 'Nothing matches' : 'Nothing here yet',
                  body: _query.isNotEmpty || _lowOnly ? 'Try another search or filter.' : widget.emptyHint,
                ),
              ),
            )
          else
            for (final (k, list) in groups) ...[
              if (headed)
                SliverToBoxAdapter(
                  child: SectionHeader(
                    k == LocationKind.pantry ? 'In the kitchen' : 'Stored away',
                    trailing: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        '${list.length}',
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                )
              else
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverList.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => StockTile(item: list[i], showLocation: _locationId == null),
              ),
            ],
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-${widget.kind?.name ?? 'all'}',
        onPressed: () => showItemEditor(context, kind: addKind, locationId: _locationId),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
  );
}
