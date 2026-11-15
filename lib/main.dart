import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'data/household_store.dart';
import 'data/storage_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = HouseholdStore(FileBackend());
  await store.load();
  runApp(PantryApp(store: store));
}
