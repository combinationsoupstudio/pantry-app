/// How long the household's water lasts, and what is coming up to its
/// use-by date. Food days need calories per item, which the app does not
/// have yet; it says so rather than guess.
library;

import '../models/models.dart';
import 'amounts.dart';

/// Litres a person needs each day: NSW Health's emergency pantry list and the
/// NSW RFS survival kit both say at least 3 L per person per day.
const litresPerPersonPerDay = 3.0;

/// Where that figure comes from, shown under the water card.
const waterSource = 'NSW Health and NSW RFS: at least 3 L per person a day';

/// Things with "water" in the name that are not drinking water.
final _notDrinking = RegExp(r'hot water bottle|water filter|water heater|waterproof|water resistant|moisture|toilet');

/// The litres of drinking water an item holds, or null if it is not water or
/// its litres cannot be told: "Water jerry cans" kept in L, "Cask water 10 L"
/// kept as casks (10 L each), "Spring water" kept as 600 ml bottles measured.
double? waterLitres(StockItem item) {
  final name = item.name.toLowerCase();
  if (!RegExp(r'\bwater\b').hasMatch(name)) return null;
  if (_notDrinking.hasMatch(name)) return null;
  final inLitres = convertUnits(item.quantity, item.unit, 'l');
  if (inLitres != null) return inLitres;
  final each = RegExp(r'(\d+(?:\.\d+)?)\s*(l|litres?|liters?|ml)\b').firstMatch(name);
  if (each == null) return null;
  final size = double.parse(each.group(1)!) * (each.group(2) == 'ml' ? 0.001 : 1);
  return size * item.quantity;
}

class WaterDays {
  const WaterDays({required this.litres, required this.perDay, required this.counted, required this.notCounted});

  /// Drinking water in stock, in litres.
  final double litres;

  /// Litres the household needs a day.
  final double perDay;

  /// The items counted, and water items whose litres could not be told.
  final List<StockItem> counted;
  final List<StockItem> notCounted;

  /// Whole days it lasts (rounded down: day 4 half-way is not day 4).
  int get days => perDay <= 0 ? 0 : (litres / perDay + 1e-9).floor();
}

/// Water days for [people] at 3 L each a day, plus [extraLitresPerDay]
/// (pets, cooking) if the household sets it.
WaterDays waterDays(Iterable<StockItem> items, {required int people, double extraLitresPerDay = 0}) {
  final counted = <StockItem>[];
  final notCounted = <StockItem>[];
  var litres = 0.0;
  for (final i in items) {
    final l = waterLitres(i);
    if (l != null) {
      litres += l;
      counted.add(i);
    } else if (RegExp(r'\bwater\b').hasMatch(i.name.toLowerCase()) && !_notDrinking.hasMatch(i.name.toLowerCase())) {
      notCounted.add(i);
    }
  }
  return WaterDays(
    litres: litres,
    perDay: people * litresPerPersonPerDay + extraLitresPerDay,
    counted: counted,
    notCounted: notCounted,
  );
}

/// Date groups (use by and best before alike), soonest first.
enum DateGroup {
  expired('Past its date'),
  week('Within a week'),
  month('Within a month'),
  later('Later');

  const DateGroup(this.label);
  final String label;
}

DateGroup dateGroupOf(DateTime useBy, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(useBy.year, useBy.month, useBy.day).difference(today).inDays;
  if (d < 0) return DateGroup.expired;
  if (d <= 7) return DateGroup.week;
  if (d <= 31) return DateGroup.month;
  return DateGroup.later;
}

/// Items with a use-by date, grouped and soonest first. Items with none are
/// left out (the page counts them).
Map<DateGroup, List<StockItem>> byUseBy(Iterable<StockItem> items, DateTime now) {
  final dated = items.where((i) => i.useBy != null && i.quantity > 0).toList()
    ..sort((a, b) => a.useBy!.compareTo(b.useBy!));
  final out = <DateGroup, List<StockItem>>{};
  for (final i in dated) {
    (out[dateGroupOf(i.useBy!, now)] ??= []).add(i);
  }
  return out;
}

/// Every dated batch (v0.15), grouped like [byUseBy] but one entry per
/// batch: four yoghurts with two dates are two rows. Soonest first.
Map<DateGroup, List<(StockItem, StockBatch)>> lotsByUseBy(Iterable<StockItem> items, DateTime now) {
  final lots = [
    for (final i in items)
      if (i.quantity > 0)
        for (final b in i.batches) (i, b),
  ]..sort((a, b) => a.$2.useBy.compareTo(b.$2.useBy));
  final out = <DateGroup, List<(StockItem, StockBatch)>>{};
  for (final l in lots) {
    out.putIfAbsent(dateGroupOf(l.$2.useBy, now), () => []).add(l);
  }
  return out;
}

/// The "eat me first" line on a stock row (v0.15): the soonest batch when it
/// is due within a week or past, e.g. "eat 2 by Fri", "1 past date". Short:
/// it shares a line with the place and how long stock lasts.
/// Null when nothing is that close. [amount] formats a batch's amount.
String? eatFirstHint(StockItem item, DateTime now, String Function(double) amount) {
  if (item.isOut || item.batches.isEmpty) return null;
  final b = item.batches.first;
  final days = b.useBy.difference(DateTime(now.year, now.month, now.day)).inDays;
  if (days > 6) return null;
  final what = amount(b.amount);
  // A use by is a safety line; a best before is only about quality (v0.18).
  if (days < 0) return '$what past ${b.kind.lower}';
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final day = names[b.useBy.weekday - 1];
  final q = b.guessed ? '?' : '';
  if (b.kind == DateKind.bestBefore) {
    final when = days == 0 ? 'today' : (days == 1 ? 'tomorrow' : day);
    return '$what best before $when$q';
  }
  final when = days == 0 ? 'today' : (days == 1 ? 'tomorrow' : 'by $day');
  return 'eat $what $when$q';
}
