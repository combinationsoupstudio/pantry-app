/// How fast things are used, worked out from the household's history.
library;

import '../models/models.dart';

/// Amount used per day for each item name (by [nameKey]), from "used" entries
/// over the last [windowDays] days. The span counted starts at the later of
/// the window start and the first time the item appears in the history, and
/// is at least [minDays], so a burst on day one does not look like a habit.
Map<String, double> usePerDay(List<ActivityEntry> activity, DateTime now, {int windowDays = 30, int minDays = 3}) {
  final windowStart = now.subtract(Duration(days: windowDays));
  final used = <String, double>{};
  final firstSeen = <String, DateTime>{};
  for (final e in activity) {
    final key = nameKey(e.itemName);
    final seen = firstSeen[key];
    if (seen == null || e.at.isBefore(seen)) firstSeen[key] = e.at;
    if (e.action == 'used' && !e.at.isBefore(windowStart)) {
      used[key] = (used[key] ?? 0) + e.delta.abs();
    }
  }
  final rates = <String, double>{};
  used.forEach((key, total) {
    final start = firstSeen[key]!.isAfter(windowStart) ? firstSeen[key]! : windowStart;
    final days = now.difference(start).inHours / 24;
    rates[key] = total / (days < minDays ? minDays : days);
  });
  return rates;
}

/// Days until [item] runs out at the rate in [rates], or null if it is not
/// being used (or is already out).
double? daysLeft(StockItem item, Map<String, double> rates) {
  final rate = rates[nameKey(item.name)];
  if (rate == null || rate <= 0 || item.isOut) return null;
  return item.quantity / rate;
}

/// "today", "1 day", "6 days", "3 weeks", "2 months".
String describeDays(double days) {
  if (days < 1) return 'today';
  if (days < 14) return '${days.floor()} day${days.floor() == 1 ? '' : 's'}';
  if (days < 60) return '${(days / 7).floor()} weeks';
  return '${(days / 30).floor()} months';
}
