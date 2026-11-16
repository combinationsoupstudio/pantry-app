import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'data/household_store.dart';
import 'data/picture_finder.dart';
import 'data/reminder_service.dart';
import 'data/storage_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = HouseholdStore(FileBackend());
  await store.load();
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
