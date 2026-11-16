/// Books the planned reminders (logic/reminders.dart) as phone notifications,
/// and books them again a moment after the stock changes, so "8 running low"
/// is always today's number. Inexact timing (no exact-alarm permission): a
/// reminder can come a few minutes late, which is fine for a shopping nudge.
library;

import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../logic/reminders.dart';
import 'household_store.dart';

class ReminderService {
  ReminderService(this.store);

  /// The service the app runs; null in tests.
  static ReminderService? instance;

  final HouseholdStore store;
  final _plugin = FlutterLocalNotificationsPlugin();
  Timer? _debounce;
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'pantry_reminders',
    'Reminders',
    channelDescription: 'Shop day, use-by dates and backups',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  /// Sets up the plugin and books what is planned. The household is in NSW;
  /// times are Sydney time (summer time handled by the time zone data).
  Future<void> start() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Australia/Sydney'));
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    _ready = true;
    store.addListener(_changed);
    await sync();
  }

  /// Asks the phone for permission to show notifications (Android 13+).
  /// True when they may be shown.
  Future<bool> askPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () => unawaited(sync()));
  }

  /// Cancels everything booked and books the current plan.
  Future<void> sync() async {
    if (!_ready) return;
    final plan = planReminders(
      items: store.items,
      runningLow: store.runningLow.length,
      onList: store.shopping.where((s) => !s.bought).length,
      settings: ReminderSettings.from(store.setting),
      now: DateTime.now(),
    );
    await _plugin.cancelAll();
    for (final r in plan) {
      await _plugin.zonedSchedule(
        id: r.id,
        scheduledDate: tz.TZDateTime(tz.local, r.when.year, r.when.month, r.when.day, r.when.hour, r.when.minute),
        notificationDetails: const NotificationDetails(android: _channel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.body,
        matchDateTimeComponents: r.weekly ? DateTimeComponents.dayOfWeekAndTime : null,
      );
    }
  }
}
