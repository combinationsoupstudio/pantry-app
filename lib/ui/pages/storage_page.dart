import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import '../widgets/stock_list_view.dart';

class StoragePage extends StatelessWidget {
  const StoragePage({super.key});

  @override
  Widget build(BuildContext context) => const StockListView(
    kind: LocationKind.storage,
    title: 'Storage',
    emptyHint: 'Prep pantry, spare cupboard, garage, medical and hygiene. Long-press an item to move it.',
  );
}
