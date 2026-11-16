/// What the phone should remind the household of, worked out from the stock.
/// Plain logic: the notification service (data/reminder_service.dart)
/// schedules what this plans, again every time the stock changes, so the
/// words are always current. Nothing here talks to the phone.
library;

import '../models/models.dart';

/// One reminder to show at [when] (local time), once or every week.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
    this.weekly = false,
  });
  final int id;
  final DateTime when;
  final String title;
  final String body;
  final bool weekly;

  @override
  String toString() => '$id @ $when${weekly ? ' weekly' : ''}: $title / $body';
}

/// The household's reminder choices (kept in the store's settings).
class ReminderSettings {
  const ReminderSettings({this.shopDay, this.shopHour = 9, this.useBy = true, this.backupDay});

  /// Weekday (1 = Monday ... 7 = Sunday) for the running-low reminder, or
  /// null for none.
  final int? shopDay;
  final int shopHour;

  /// Alerts two days before an item's use-by date (at 9 am).
  final bool useBy;

  /// Weekday for a weekly "back up the pantry" nudge at 7 pm, or null.
  final int? backupDay;

  factory ReminderSettings.from(T Function<T>(String key, T fallback) setting) => ReminderSettings(
    shopDay: setting<int?>('remindShopDay', null),
    shopHour: setting<int>('remindShopHour', 9),
    useBy: setting<bool>('remindUseBy', true),
    backupDay: setting<int?>('remindBackupDay', null),
  );
}

const shopReminderId = 1;
const backupReminderId = 2;

/// At most this many use-by alerts are booked at once (Android keeps a few
/// hundred; the household needs the soonest).
const maxUseByAlerts = 40;

/// The next [weekday] at [hour]:00 after [now] (today if still ahead).
DateTime nextWeekday(DateTime now, int weekday, int hour) {
  var d = DateTime(now.year, now.month, now.day, hour);
  while (d.weekday != weekday || !d.isAfter(now)) {
    d = DateTime(d.year, d.month, d.day + 1, hour);
  }
  return d;
}

/// A stable id for an item's use-by alert (well clear of 1 and 2).
int useByIdFor(StockItem item) => 1000 + (item.id.hashCode & 0x3fffffff) % 1000000000;

List<PlannedReminder> planReminders({
  required List<StockItem> items,
  required int runningLow,
  required int onList,
  required ReminderSettings settings,
  required DateTime now,
}) {
  final out = <PlannedReminder>[];

  final shopDay = settings.shopDay;
  if (shopDay != null) {
    final parts = [if (runningLow > 0) '$runningLow running low', if (onList > 0) '$onList on the list'];
    out.add(
      PlannedReminder(
        id: shopReminderId,
        when: nextWeekday(now, shopDay, settings.shopHour),
        title: 'Shop day',
        body: parts.isEmpty
            ? 'Nothing running low. Check the pantry before you go.'
            : '${parts.join(', ')}. Tap to check before you go.',
        weekly: true,
      ),
    );
  }

  final backupDay = settings.backupDay;
  if (backupDay != null) {
    out.add(
      PlannedReminder(
        id: backupReminderId,
        when: nextWeekday(now, backupDay, 19),
        title: 'Back up the pantry',
        body: 'Settings > Back up now keeps everything safe if a phone is lost.',
        weekly: true,
      ),
    );
  }

  if (settings.useBy) {
    final dated = items.where((i) => i.useBy != null && i.quantity > 0).toList()
      ..sort((a, b) => a.useBy!.compareTo(b.useBy!));
    var booked = 0;
    for (final i in dated) {
      if (booked >= maxUseByAlerts) break;
      final d = i.useBy!;
      final day = DateTime(d.year, d.month, d.day);
      // Two days before at 9 am; the day before if that has passed; skip if
      // even that has passed (the dates page shows it).
      var at = DateTime(day.year, day.month, day.day - 2, 9);
      if (!at.isAfter(now)) at = DateTime(day.year, day.month, day.day - 1, 9);
      if (!at.isAfter(now)) continue;
      final daysBefore = day.difference(DateTime(at.year, at.month, at.day)).inDays;
      out.add(
        PlannedReminder(
          id: useByIdFor(i),
          when: at,
          title: '${i.name}: use by ${daysBefore == 1 ? 'tomorrow' : '${d.day}/${d.month}'}',
          body: 'Use it or move it to the front.',
        ),
      );
      booked++;
    }
  }
  return out;
}
