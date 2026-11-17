import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:pantry_app/data/catalogue.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/data/open_food_facts.dart';
import 'package:pantry_app/data/photo_store.dart';
import 'package:pantry_app/data/storage_backend.dart';
import 'package:pantry_app/data/store_scope.dart';
import 'package:pantry_app/models/models.dart';
import 'package:pantry_app/ui/theme.dart';
import 'package:pantry_app/ui/widgets/item_sheets.dart';

Uint8List bigPhoto() => Uint8List.fromList(img.encodeJpg(img.Image(width: 2000, height: 1500), quality: 95));

void main() {
  group('household photos', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('photos'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('a camera photo is shrunk to 640 px and named by its hash', () {
      final small = PhotoStore.shrink(bigPhoto());
      final back = img.decodeJpg(small)!;
      expect((back.width, back.height), (640, 480));
      expect(PhotoStore.hashOf(small), hasLength(64));
    });

    test('photos wait on the phone until the household has them', () async {
      final sent = <String>[];
      var online = false;
      final a = PhotoStore(
        root: () async => tmp,
        upload: (b) async {
          if (online) sent.add(PhotoStore.hashOf(b));
          return online;
        },
      );
      final id = await a.addBytes(PhotoStore.shrink(bigPhoto()));
      expect(await a.sendWaiting(), 0);
      online = true;
      expect(await a.sendWaiting(), 1);
      expect(sent, [id]);
      expect(await a.sendWaiting(), 0, reason: 'sent once');
    });

    test('the other phone fetches it by hash, once, and refuses a wrong file', () async {
      final jpeg = PhotoStore.shrink(bigPhoto());
      final id = PhotoStore.hashOf(jpeg);
      var fetches = 0;
      final other = Directory('${tmp.path}/other')..createSync();
      final b = PhotoStore(
        root: () async => other,
        download: (h) async {
          fetches++;
          return h == id ? jpeg : Uint8List.fromList([1, 2, 3]);
        },
      );
      expect(await b.bytesFor(id), jpeg);
      expect(await b.bytesFor(id), jpeg);
      expect(fetches, 1);
      expect(await b.bytesFor('0' * 64), isNull);
    });

    test('the photo id travels with the item; the old file path does not wipe it', () async {
      final store = HouseholdStore(MemoryBackend());
      await store.load();
      final i = await store.addItem(name: 'Passata', locationId: 'prep', quantity: 3);
      await store.updateItem(store.item(i.id)!.copyWith(photoId: 'a' * 64));
      expect(StockItem.fromJson(store.item(i.id)!.toJson()).photoId, 'a' * 64);
      // Editing on a phone without the photo file keeps the shared photo.
      await store.updateItem(store.item(i.id)!.copyWith(quantity: 2, photoPath: null));
      expect(store.item(i.id)!.photoId, 'a' * 64);
    });
  });

  group('product library', () {
    test('reads open, shares with the household token, never without', () async {
      final seen = <http.Request>[];
      Map<String, String>? headers;
      final c = Catalogue(
        server: 'https://x',
        auth: () => headers,
        client: MockClient((req) async {
          seen.add(req);
          if (req.method == 'GET') {
            return http.Response(
              jsonEncode({
                'product': {
                  'barcode': '9300633603204',
                  'name': "Leggo's passata",
                  'countAs': 'count',
                  'countUnit': 'jars',
                  'locationKind': 'storage',
                  'hasPhoto': true,
                  'updatedAt': 5,
                },
              }),
              200,
            );
          }
          return http.Response('{"ok":true}', 200);
        }),
      );
      final p = (await c.lookup('9300633603204'))!;
      expect(
        (p.name, p.measured, p.countUnit, p.locationKind, p.hasPhoto),
        ("Leggo's passata", false, 'jars', 'storage', true),
      );
      expect(c.photoUrl('9300633603204', 5), 'https://x/catalogue/9300633603204/photo?v=5');
      expect(await c.share(p), isFalse, reason: 'not in a household');
      headers = {'authorization': 'Bearer t', 'x-household': 'ABCD2345'};
      expect(await c.share(p), isTrue);
      expect(seen.last.headers['x-household'], 'ABCD2345');
      expect(jsonDecode(seen.last.body)['countUnit'], 'jars');
      expect(await c.lookup('not a barcode'), isNull);
    });
  });

  group('scanning', () {
    late Catalogue savedCatalogue;
    late OpenFoodFacts savedOff;
    setUp(() {
      savedCatalogue = Catalogue.instance;
      savedOff = OpenFoodFacts.instance;
    });
    tearDown(() {
      Catalogue.instance = savedCatalogue;
      OpenFoodFacts.instance = savedOff;
    });

    Future<HouseholdStore> open(WidgetTester tester, String barcode) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      final store = HouseholdStore(MemoryBackend());
      await store.load();
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: Builder(
              builder: (c) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showItemEditor(c, barcode: barcode),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      return store;
    }

    testWidgets('a barcode the library knows opens set up as a household keeps it', (tester) async {
      var offAsked = false;
      Catalogue.instance = Catalogue(
        server: 'https://x',
        client: MockClient(
          (req) async => http.Response(
            jsonEncode({
              'product': {
                'barcode': '9300633603204',
                'name': 'Strawberry jam',
                'packSize': 500,
                'unit': 'g',
                'countAs': 'count',
                'countUnit': 'jars',
                'locationKind': 'storage',
              },
            }),
            200,
          ),
        ),
      );
      OpenFoodFacts.instance = OpenFoodFacts(
        client: MockClient((req) async {
          offAsked = true;
          return http.Response('{}', 200);
        }),
      );
      final store = await open(tester, '9300633603204');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Strawberry jam'), findsOneWidget);
      final chooser = tester.widget<SegmentedButton<bool>>(find.byKey(const ValueKey('field-measured')));
      expect(chooser.selected, {false}, reason: 'counted, not 500 g');
      expect(find.textContaining('Count them (jars)'), findsOneWidget);
      // Kept where that household keeps it: stored away.
      final kept = tester.widget<DropdownButtonFormField<String>>(
        find.byWidgetPredicate(
          (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('kept-in-'),
        ),
      );
      expect(store.location(kept.initialValue ?? '')?.kind, LocationKind.storage);
      expect(offAsked, isFalse, reason: 'Open Food Facts is not asked');
    });

    testWidgets('a new barcode: jam from Open Food Facts is counted in jars, not grams', (tester) async {
      Catalogue.instance = Catalogue(server: 'https://x', client: MockClient((req) async => http.Response('{}', 404)));
      OpenFoodFacts.instance = OpenFoodFacts(
        client: MockClient(
          (req) async => http.Response(
            jsonEncode({
              'status': 1,
              'product': {'product_name': 'Strawberry jam', 'brands': 'IXL', 'quantity': '500 g'},
            }),
            200,
          ),
        ),
      );
      await open(tester, '9300000000017');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'IXL Strawberry jam'), findsOneWidget);
      expect(tester.widget<SegmentedButton<bool>>(find.byKey(const ValueKey('field-measured'))).selected, {false});
      expect(find.textContaining('Count them (jars)'), findsOneWidget);
      // One tap to measure instead, with the pack size ready.
      await tester.tap(find.byKey(const ValueKey('measure-it')));
      await tester.pumpAndSettle();
      expect(find.textContaining('500 g'), findsWidgets);
    });

    testWidgets('a slow lookup never holds the page up', (tester) async {
      Catalogue.instance = Catalogue(server: 'https://x', client: MockClient((req) async => http.Response('{}', 404)));
      final answer = Completer<http.Response>();
      OpenFoodFacts.instance = OpenFoodFacts(client: MockClient((req) => answer.future));
      await open(tester, '9300000000024');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 3));
      expect(find.textContaining('Still looking it up'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('field-name')), 'Our name');
      answer.complete(
        http.Response(
          jsonEncode({
            'status': 1,
            'product': {'product_name': 'Their name', 'quantity': '1 L'},
          }),
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Our name'), findsOneWidget, reason: 'what was typed stays');
    });
  });
}
