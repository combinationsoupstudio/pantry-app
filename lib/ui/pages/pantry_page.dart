import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import '../widgets/stock_list_view.dart';

class PantryPage extends StatelessWidget {
  const PantryPage({super.key});

  @override
  Widget build(BuildContext context) => const StockListView(
    kind: LocationKind.pantry,
    title: 'Pantry',
    emptyHint: 'Everyday food: pantry, fridge and freezer. Tap Add item to start.',
  );
}
