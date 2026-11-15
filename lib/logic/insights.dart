import '../models/models.dart';

class LocationSummary {
  const LocationSummary(this.location, this.itemCount, this.lowCount, this.readiness);
  final StockLocation location;
  final int itemCount;
  final int lowCount;

  /// 0..1, share of targeted items at or above target (null if none have a target).
  final double? readiness;
}

class UsageSummary {
  const UsageSummary(this.itemName, this.used, this.unit);
  final String itemName;
  final double used;
  final String unit;
}

class Insights {
  const Insights({
    required this.totalItems,
    required this.targeted,
    required this.atTarget,
    required this.low,
    required this.out,
    required this.useBySoon,
    required this.byLocation,
    required this.mostUsed,
  });

  final int totalItems;
  final int targeted;
  final int atTarget;
  final int low;
  final int out;

  /// Items with a use-by date in the next 14 days (or past it).
  final List<StockItem> useBySoon;
  final List<LocationSummary> byLocation;

  /// Most used items over the last 30 days, from the activity log.
  final List<UsageSummary> mostUsed;

  /// 0..1 household readiness: share of targeted items at or above target.
  double? get readiness => targeted == 0 ? null : atTarget / targeted;
}

Insights computeInsights({
  required List<StockItem> items,
  required List<StockLocation> locations,
  required List<ActivityEntry> activity,
  required DateTime now,
}) {
  final targeted = items.where((i) => i.hasTarget).toList();
  final atTarget = targeted.where((i) => !i.isLow).length;

  final byLocation = locations
      .map((loc) {
        final inLoc = items.where((i) => i.locationId == loc.id).toList();
        final t = inLoc.where((i) => i.hasTarget).toList();
        final ok = t.where((i) => !i.isLow).length;
        return LocationSummary(loc, inLoc.length, t.length - ok, t.isEmpty ? null : ok / t.length);
      })
      .where((s) => s.itemCount > 0)
      .toList();

  final soon = now.add(const Duration(days: 14));
  final useBySoon = items.where((i) => i.useBy != null && !i.isOut && i.useBy!.isBefore(soon)).toList()
    ..sort((a, b) => a.useBy!.compareTo(b.useBy!));

  final since = now.subtract(const Duration(days: 30));
  final used = <String, double>{};
  final units = <String, String>{};
  for (final entry in activity) {
    if (entry.action != 'used' || entry.at.isBefore(since)) continue;
    used[entry.itemName] = (used[entry.itemName] ?? 0) + entry.delta.abs();
    units[entry.itemName] = entry.unit;
  }
  final mostUsed = used.entries.map((e) => UsageSummary(e.key, e.value, units[e.key] ?? '')).toList()
    ..sort((a, b) => b.used.compareTo(a.used));

  return Insights(
    totalItems: items.length,
    targeted: targeted.length,
    atTarget: atTarget,
    low: items.where((i) => i.isLow).length,
    out: items.where((i) => i.isOut).length,
    useBySoon: useBySoon,
    byLocation: byLocation,
    mostUsed: mostUsed.take(8).toList(),
  );
}
