import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'data/household_store.dart';
import 'data/picture_finder.dart';
import 'data/reminder_service.dart';
import 'data/storage_backend.dart';
import 'data/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = HouseholdStore(FileBackend());
  await store.load();
  // Household sync: in step on open, then every few seconds while open.
  final sync = SyncService.instance = SyncService(store);
  await sync.load();
  if (sync.joined) sync.startLive();
  AppLifecycleListener(
    onResume: () {
      if (sync.joined) sync.startLive();
    },
    onPause: sync.stopLive,
  );
  runApp(PantryApp(store: store));
  // Pictures for items that have none fill in quietly in the background.
  PictureFinder.instance = PictureFinder(store)..nudge();
  // Reminders the household turned on are booked (and re-booked as stock changes).
  ReminderService.instance = ReminderService(store);
  try {
    await ReminderService.instance!.start();
  } catch (_) {
    // A phone without notification support still runs the app.
  }
}
