import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'data/household_store.dart';
import 'data/picture_finder.dart';
import 'data/storage_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = HouseholdStore(FileBackend());
  await store.load();
  runApp(PantryApp(store: store));
  // Pictures for items that have none fill in quietly in the background.
  PictureFinder.instance = PictureFinder(store)..nudge();
}
