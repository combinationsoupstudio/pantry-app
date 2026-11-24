import 'package:material_ui/material_ui.dart';

import '../../data/store_scope.dart';
import '../../logic/amounts.dart';
import '../../logic/supplies.dart';
import '../../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/item_sheets.dart';
import '../widgets/pictures.dart';

/// Every use-by and expiry date in the house, soonest first, grouped: past
/// its date, within a week, within a month, later. Filter by cupboard (the
/// medical kit, say). Tap an item to change it.
class DatesPage extends StatefulWidget {
  const DatesPage({super.key, this.locationId});
  final String? locationId;

  @override
  State<DatesPage> createState() => _DatesPageState();
}

class _DatesPageState extends State<DatesPage> {
  late String? _locationId = widget.locationId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final status = StatusColors.of(context);
    final now = DateTime.now();
    final inPlace = store.items.where((i) => _locationId == null || i.locationId == _locationId).toList();
    final groups = lotsByUseBy(inPlace, now);
    final undated = inPlace.where((i) => i.useBy == null && i.quantity > 0).length;
    final withDates = store.locations.where((l) => store.items.any((i) => i.locationId == l.id)).toList();

    Color colourOf(DateGroup g) => switch (g) {
      DateGroup.expired => status.out,
      DateGroup.week => status.low,
      _ => status.ok,
    };

    String when(DateTime d) {
      final days = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
      final date = '${d.day}/${d.month}/${d.year}';
      if (days < 0) return '$date · ${-days} day${days == -1 ? '' : 's'} ago';
      if (days == 0) return '$date · today';
      if (days == 1) return '$date · tomorrow';
      return '$date · in $days days';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dates')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _locationId == null,
                    onSelected: (_) => setState(() => _locationId = null),
                  ),
                ),
                for (final l in withDates)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      key: ValueKey('dates-${l.id}'),
                      label: Text(l.name),
                      selected: _locationId == l.id,
                      onSelected: (_) => setState(() => _locationId = l.id),
                    ),
                  ),
              ],
            ),
          ),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No dates here yet. Open an item and give it a use by or best before date.',
                style: text.bodyLarge,
              ),
            ),
          for (final g in DateGroup.values)
            if (groups[g] != null) ...[
              SectionHeader('${g.label} (${groups[g]!.length})'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Column(
                    children: [
                      for (final (i, b) in groups[g]!)
                        ListTile(
                          key: ValueKey(b == i.batches.first ? 'date-${i.id}' : 'date-${i.id}-${i.batches.indexOf(b)}'),
                          leading: ProductPicture.of(i, size: 40),
                          title: Text(i.name, style: text.titleSmall),
                          subtitle: Text(
                            '${b.kind.label} · ${store.location(i.locationId)?.name ?? ''} · '
                            '${i.batches.length == 1 && i.undatedAmount == 0 ? formatMeasure(i.quantity, i.unit) : '${formatMeasure(b.amount, i.unit)} of ${formatMeasure(i.quantity, i.unit)}'}'
                            '${b.guessed ? ' · guessed' : ''}'
                            '${g == DateGroup.expired ? '\n${b.kind.pastAdvice}' : ''}',
                          ),
                          trailing: Text(
                            '${b.guessed ? '~' : ''}${when(b.useBy)}',
                            style: text.labelLarge?.copyWith(
                              // Past a best before is a check, not a bin (v0.18).
                              color: g == DateGroup.expired && b.kind == DateKind.bestBefore ? status.low : colourOf(g),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          onTap: () => showItemEditor(context, existing: i),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          if (undated > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                '$undated item${undated == 1 ? ' has' : 's have'} no date. Medicines and first-aid items are worth '
                'dating so you know when to replace them.',
                key: const ValueKey('dates-undated'),
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}
