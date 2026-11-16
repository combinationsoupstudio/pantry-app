import 'package:material_ui/material_ui.dart';

import '../../data/store_scope.dart';
import '../../models/models.dart';
import 'common.dart';
import 'item_sheets.dart';
import 'stock_tile.dart';

/// The shared body of the Pantry and Storage pages: location chips,
/// a search box, and a scrolling list of stock with - / +.
class StockListView extends StatefulWidget {
  const StockListView({super.key, required this.kind, required this.title, required this.emptyHint});
  final LocationKind kind;
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
    final locations = store.locationsOf(widget.kind);
    if (_locationId != null && store.location(_locationId!) == null) _locationId = null;
    var items = store.itemsOf(widget.kind, locationId: _locationId);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      items = items.where((i) => i.name.toLowerCase().contains(q)).toList();
    }
    if (_lowOnly) items = items.where((i) => i.isLow).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(title: Text(widget.title), floating: true),
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
                  for (final l in locations)
                    _chip(l.name, _locationId == l.id, () => setState(() => _locationId = l.id)),
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
            SliverPadding(
              padding: const EdgeInsets.only(top: 8),
              sliver: SliverList.builder(
                itemCount: items.length,
                itemBuilder: (_, i) => StockTile(item: items[i], showLocation: _locationId == null),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-${widget.kind.name}',
        onPressed: () => showItemEditor(context, kind: widget.kind, locationId: _locationId),
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
