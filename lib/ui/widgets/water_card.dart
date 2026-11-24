import 'package:material_ui/material_ui.dart';

import '../../data/store_scope.dart';
import '../../logic/supplies.dart';
import '../../models/models.dart';

/// Moved off Home to the stored-away side of Pantry (v0.18, #42; Chris 24
/// Nov: most people "wont care to know how much water they have on hand").
/// Water days: drinking water in stock against 3 L per person a day.
class WaterCard extends StatelessWidget {
  const WaterCard({super.key, required this.water, required this.people});
  final WaterDays water;
  final int people;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final store = StoreScope.read(context);
    return Card(
      key: const ValueKey('home-water'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.water_drop_outlined, color: scheme.primary),
                const SizedBox(width: 6),
                Text('Water', style: text.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              water.counted.isEmpty ? 'None counted' : '${water.days} day${water.days == 1 ? '' : 's'}',
              key: const ValueKey('water-days'),
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text('${formatQty(double.parse(water.litres.toStringAsFixed(1)))} L for', style: text.bodySmall),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                InkWell(
                  key: const ValueKey('people-less'),
                  onTap: people <= 1 ? null : () => store.setSetting('people', people - 1),
                  child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.remove, size: 18)),
                ),
                Text('$people people', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                InkWell(
                  key: const ValueKey('people-more'),
                  onTap: () => store.setSetting('people', people + 1),
                  child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.add, size: 18)),
                ),
              ],
            ),
            Text(
              water.notCounted.isEmpty
                  ? '3 L each a day (NSW Health, RFS)'
                  : '3 L each a day. ${water.notCounted.length} not counted: put litres in the name or unit',
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
