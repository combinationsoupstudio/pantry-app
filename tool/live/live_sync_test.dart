// Two "phones" against the real household server. Not run in CI:
//   flutter test tool/live/live_sync_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/data/storage_backend.dart';
import 'package:pantry_app/data/sync_service.dart';

void main() {
  test('two phones through the live server', () async {
    final chris = HouseholdStore(MemoryBackend());
    await chris.load();
    final rice = await chris.addItem(name: 'Rice', locationId: 'pantry', quantity: 5, unit: 'kg');
    final a = SyncService(chris, backend: MemoryBackend());
    final code = await a.start();
    expect(a.error, isNull);

    final emily = HouseholdStore(MemoryBackend());
    await emily.load();
    final b = SyncService(emily, backend: MemoryBackend());
    await b.join(code, JoinMode.useHousehold);
    expect(b.error, isNull);
    expect(emily.item(rice.id)?.quantity, 5);

    await emily.adjust(rice.id, 2);
    await chris.adjust(rice.id, -1);
    final t = Stopwatch()..start();
    await b.syncNow();
    await a.syncNow();
    await b.syncNow();
    // ignore: avoid_print
    print('three syncs: ${t.elapsedMilliseconds} ms');
    expect(chris.item(rice.id)?.quantity, 6);
    expect(emily.item(rice.id)?.quantity, 6);
    expect(a.waiting, 0);
    expect(b.waiting, 0);
  }, timeout: const Timeout(Duration(minutes: 1)));
}
