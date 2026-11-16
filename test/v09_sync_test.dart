import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/data/storage_backend.dart';
import 'package:pantry_app/data/sync_service.dart';

/// The Worker's rules (server/src/merge.js) in Dart, for phone-to-phone tests.
class FakeServer {
  final records = <String, Map<String, Object?>>{}; // "kind|id" -> {kind,id,data,updatedAt,deleted,seq}
  final tokens = <String>{};
  String? code;
  int seq = 0;
  int tokenCount = 0;
  bool offline = false;

  late final client = MockClient((req) async {
    if (offline) throw http.ClientException('offline');
    final body = (jsonDecode(req.body) as Map).cast<String, Object?>();
    final path = req.url.path;
    if (path == '/households') {
      code = 'ABCD2345-123456';
      return _ok({'household': 'ABCD2345', 'token': _token(), 'code': code});
    }
    if (path.endsWith('/join')) {
      if (code == null || body['code'] != code!.split('-').last) {
        return http.Response(jsonEncode({'error': 'wrong or old code'}), 403);
      }
      code = null;
      return _ok({'token': _token()});
    }
    final auth = req.headers['authorization']?.replaceFirst('Bearer ', '');
    if (!tokens.contains(auth)) return http.Response(jsonEncode({'error': 'not allowed'}), 401);
    if (path.endsWith('/invite')) {
      code = 'ABCD2345-654321';
      return _ok({'code': code});
    }
    final since = (body['since'] as num).toInt();
    for (final c in (body['changes'] as List).cast<Map<String, Object?>>()) {
      final key = '${c['kind']}|${c['id']}';
      final existing = records[key];
      final deleted = c['deleted'] == true;
      Map<String, Object?> next;
      if (existing == null) {
        next = {'data': deleted ? null : c['data'], 'updatedAt': c['updatedAt'], 'deleted': deleted};
      } else if (c['kind'] == 'prices' || c['kind'] == 'activity') {
        continue;
      } else {
        final wins = (c['updatedAt'] as num) >= (existing['updatedAt'] as num);
        next = wins
            ? {'data': deleted ? null : c['data'], 'updatedAt': c['updatedAt'], 'deleted': deleted}
            : {...existing};
        if (c['kind'] == 'items' && c['qtyDelta'] is num && next['deleted'] != true && next['data'] != null) {
          final base = existing['deleted'] == true ? 0 : ((existing['data'] as Map)['quantity'] as num? ?? 0);
          final q = (base + (c['qtyDelta'] as num)).clamp(0, double.infinity);
          next['data'] = {...(next['data'] as Map), 'quantity': q};
        }
      }
      records[key] = {...next, 'kind': c['kind'], 'id': c['id'], 'seq': ++seq};
    }
    final out = records.values.where((r) => (r['seq'] as int) > since).toList()
      ..sort((a, b) => (a['seq'] as int).compareTo(b['seq'] as int));
    return _ok({'cursor': seq, 'records': out, 'refused': []});
  });

  String _token() {
    final t = 'token-${++tokenCount}';
    tokens.add(t);
    return t;
  }

  http.Response _ok(Object body) => http.Response(jsonEncode(body), 200);
}

Future<(HouseholdStore, SyncService)> phone(FakeServer server, {DateTime Function()? clock}) async {
  final store = HouseholdStore(MemoryBackend(), clock: clock);
  await store.load();
  final sync = SyncService(store, backend: MemoryBackend(), client: server.client, server: 'https://x', clock: clock);
  return (store, sync);
}

void main() {
  test('a second phone joins and sees the first phone\'s list', () async {
    final server = FakeServer();
    final (chris, chrisSync) = await phone(server);
    await chris.addItem(name: 'Rice', locationId: 'pantry', quantity: 5, unit: 'kg');
    final code = await chrisSync.start();
    expect(chrisSync.joined, isTrue);
    expect(chrisSync.error, isNull);

    final (emily, emilySync) = await phone(server);
    await emilySync.join(code, JoinMode.useHousehold);
    expect(emilySync.error, isNull);
    expect(emily.itemByName('Rice')?.quantity, 5);
    expect(emilySync.waiting, 0);
  });

  test('joining with "use the household\'s list" takes this phone\'s own things off', () async {
    final server = FakeServer();
    final (chris, chrisSync) = await phone(server);
    await chris.addItem(name: 'Rice', locationId: 'pantry', quantity: 5);
    final code = await chrisSync.start();

    final (emily, emilySync) = await phone(server);
    await emily.addItem(name: 'Old test thing', locationId: 'pantry', quantity: 1);
    await emilySync.join(code, JoinMode.useHousehold);
    expect(emily.itemByName('Old test thing'), isNull);
    expect(emily.itemByName('Rice'), isNotNull);
    // Nothing of Emily's old list reached the household.
    await emilySync.syncNow();
    await chrisSync.syncNow();
    expect(chris.itemByName('Old test thing'), isNull);
  });

  test('joining with "add mine" brings this phone\'s things to the household', () async {
    final server = FakeServer();
    final (chris, chrisSync) = await phone(server);
    await chris.addItem(name: 'Rice', locationId: 'pantry', quantity: 5);
    final code = await chrisSync.start();

    final (emily, emilySync) = await phone(server);
    await emily.addItem(name: 'Nappies', locationId: 'hygiene', quantity: 2);
    await emilySync.join(code, JoinMode.addMine);
    await chrisSync.syncNow();
    expect(chris.itemByName('Nappies')?.quantity, 2);
    expect(emily.itemByName('Rice')?.quantity, 5);
  });

  test('two people using the same thing both count (+2 and -1 = +1)', () async {
    final server = FakeServer();
    final (chris, chrisSync) = await phone(server);
    final rice = await chris.addItem(name: 'Rice', locationId: 'pantry', quantity: 5);
    final code = await chrisSync.start();
    final (emily, emilySync) = await phone(server);
    await emilySync.join(code, JoinMode.useHousehold);

    await emily.adjust(rice.id, 2);
    await chris.adjust(rice.id, -1);
    await emilySync.syncNow();
    await chrisSync.syncNow();
    await emilySync.syncNow();
    expect(chris.item(rice.id)?.quantity, 6);
    expect(emily.item(rice.id)?.quantity, 6);
  });

  test('deletes, shopping and recipes go across', () async {
    final server = FakeServer();
    final (chris, chrisSync) = await phone(server);
    final rice = await chris.addItem(name: 'Rice', locationId: 'pantry', quantity: 5);
    final code = await chrisSync.start();
    final (emily, emilySync) = await phone(server);
    await emilySync.join(code, JoinMode.useHousehold);

    await emily.addShopping(name: 'Milk');
    await chris.removeItem(rice.id);
    await emilySync.syncNow();
    await chrisSync.syncNow();
    await emilySync.syncNow();
    expect(emily.item(rice.id), isNull);
    expect(chris.shopping.any((s) => s.name == 'Milk'), isTrue);
  });

  test('history from both phones ends up on both, once', () async {
    final server = FakeServer();
    final (chris, chrisSync) = await phone(server);
    final rice = await chris.addItem(name: 'Rice', locationId: 'pantry', quantity: 5);
    final code = await chrisSync.start();
    final (emily, emilySync) = await phone(server);
    await emilySync.join(code, JoinMode.useHousehold);
    await emily.adjust(rice.id, -1);
    await emilySync.syncNow();
    await chrisSync.syncNow();
    await chrisSync.syncNow();
    expect(chris.activity.length, emily.activity.length);
  });

  test('reminder settings stay on each phone; household settings are shared', () async {
    final server = FakeServer();
    final (chris, chrisSync) = await phone(server);
    await chris.setSetting('remindShopDay', 4);
    await chris.setSetting('people', 3);
    final code = await chrisSync.start();
    final (emily, emilySync) = await phone(server);
    await emily.setSetting('remindShopDay', 6);
    await emilySync.join(code, JoinMode.useHousehold);
    expect(emily.setting<int>('people', 0), 3);
    expect(emily.setting<int>('remindShopDay', 0), 6);
  });

  test('a sync with nothing new sends nothing and changes nothing', () async {
    final server = FakeServer();
    final (chris, chrisSync) = await phone(server);
    await chris.addItem(name: 'Rice', locationId: 'pantry', quantity: 5);
    await chrisSync.start();
    final seq = server.seq;
    await chrisSync.syncNow();
    await chrisSync.syncNow();
    expect(server.seq, seq);
    expect(chrisSync.waiting, 0);
  });

  test('no connection keeps the changes waiting and says so', () async {
    final server = FakeServer();
    final (chris, chrisSync) = await phone(server);
    final rice = await chris.addItem(name: 'Rice', locationId: 'pantry', quantity: 5);
    await chrisSync.start();
    server.offline = true;
    await chris.adjust(rice.id, 1);
    await chrisSync.syncNow();
    expect(chrisSync.error, contains('No connection'));
    expect(chrisSync.waiting, 2); // the stock change and its history line
    server.offline = false;
    await chrisSync.syncNow();
    expect(chrisSync.error, isNull);
    expect(chrisSync.waiting, 0);
  });

  test('a wrong code is refused and the phone stays on its own', () async {
    final server = FakeServer();
    final (_, chrisSync) = await phone(server);
    await chrisSync.start();
    final (_, emilySync) = await phone(server);
    await expectLater(emilySync.join('ABCD2345-000000', JoinMode.useHousehold), throwsA(isA<SyncException>()));
    await expectLater(emilySync.join('hello', JoinMode.useHousehold), throwsA(isA<SyncException>()));
    expect(emilySync.joined, isFalse);
  });

  test('the household, cursor and snapshot survive a restart', () async {
    final server = FakeServer();
    final store = HouseholdStore(MemoryBackend());
    await store.load();
    final backend = MemoryBackend();
    final sync = SyncService(store, backend: backend, client: server.client, server: 'https://x');
    await store.addItem(name: 'Rice', locationId: 'pantry', quantity: 5);
    await sync.start();
    final again = SyncService(store, backend: backend, client: server.client, server: 'https://x');
    await again.load();
    expect(again.household, 'ABCD2345');
    expect(again.waiting, 0);
  });
}
