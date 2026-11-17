// Two "phones" against the real household server. Not run in CI:
//   flutter test tool/live/live_sync_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_app/data/catalogue.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/data/photo_store.dart';
import 'package:pantry_app/data/storage_backend.dart';
import 'package:pantry_app/data/sync_service.dart';

/// PANTRY_SERVER=http://localhost:8799 for a local `wrangler dev`.
final server = Platform.environment['PANTRY_SERVER'] ?? syncServer;

void main() {
  test('two phones through the live server', () async {
    final chris = HouseholdStore(MemoryBackend());
    await chris.load();
    final rice = await chris.addItem(name: 'Rice', locationId: 'pantry', quantity: 5, unit: 'kg');
    final a = SyncService(chris, backend: MemoryBackend(), server: server);
    final code = await a.start();
    expect(a.error, isNull);

    final emily = HouseholdStore(MemoryBackend());
    await emily.load();
    final b = SyncService(emily, backend: MemoryBackend(), server: server);
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

  test('live line: a change shows on the other phone in about a second', () async {
    final chris = HouseholdStore(MemoryBackend());
    await chris.load();
    final rice = await chris.addItem(name: 'Rice', locationId: 'pantry', quantity: 5, unit: 'kg');
    final a = SyncService(chris, backend: MemoryBackend(), server: server);
    final code = await a.start();
    final emily = HouseholdStore(MemoryBackend());
    await emily.load();
    final b = SyncService(emily, backend: MemoryBackend(), server: server);
    await b.join(code, JoinMode.useHousehold);
    a.startLive();
    b.startLive();
    addTearDown(a.stopLive);
    addTearDown(b.stopLive);
    for (var i = 0; i < 50 && !(a.liveLine && b.liveLine); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(a.liveLine && b.liveLine, isTrue, reason: 'live line did not open');
    await Future<void>.delayed(const Duration(seconds: 1));

    final t = Stopwatch()..start();
    await chris.adjust(rice.id, -2);
    while (emily.item(rice.id)?.quantity != 3 && t.elapsed < const Duration(seconds: 10)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    // ignore: avoid_print
    print('change seen on the other phone after ${t.elapsedMilliseconds} ms');
    expect(emily.item(rice.id)?.quantity, 3);
    expect(t.elapsed, lessThan(const Duration(seconds: 4)));
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('photos and the product library on the live server', () async {
    final store = HouseholdStore(MemoryBackend());
    await store.load();
    final sync = SyncService(store, backend: MemoryBackend(), server: server);
    await sync.start();
    final jpeg = PhotoStore.shrink(Uint8List.fromList(img.encodeJpg(img.Image(width: 1200, height: 900))));
    expect(await sync.uploadPhoto(jpeg), isTrue);
    expect(await sync.downloadPhoto(PhotoStore.hashOf(jpeg)), jpeg);

    final lib = Catalogue(server: server, auth: () => sync.authHeaders);
    const code = '99999999000017'; // a test barcode, not a real product
    final t = Stopwatch()..start();
    expect(
      await lib.share(
        const CatalogueProduct(barcode: code, name: 'Test passata', countUnit: 'jars', locationKind: 'storage'),
      ),
      isTrue,
    );
    expect(await lib.sharePhoto(code, jpeg), isTrue);
    final back = (await lib.lookup(code))!;
    // ignore: avoid_print
    print('share + photo + lookup: ${t.elapsedMilliseconds} ms');
    expect((back.name, back.countUnit, back.locationKind, back.hasPhoto), ('Test passata', 'jars', 'storage', true));
  }, timeout: const Timeout(Duration(minutes: 1)));
}
