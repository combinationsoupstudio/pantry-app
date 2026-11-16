import 'package:material_ui/material_ui.dart';

import '../widgets/stock_list_view.dart';

/// Everything the household keeps (v0.10, Chris 16 Nov): the kitchen first
/// (pantry, fridge, freezer), then the extra stock stored away (prep pantry,
/// spare cupboard, garage, medical, hygiene) further down, as you would find
/// it going into the pantry.
class PantryPage extends StatelessWidget {
  const PantryPage({super.key});

  @override
  Widget build(BuildContext context) => const StockListView(
    title: 'Pantry',
    emptyHint: 'Everything you keep: the kitchen first, then the stock stored away. Tap Add item to start.',
  );
}
