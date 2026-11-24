import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pantry_app/app.dart';
import 'package:pantry_app/data/backup.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/data/storage_backend.dart';
import 'package:pantry_app/logic/supplies.dart';
import 'package:pantry_app/ui/pages/dates_page.dart';
import 'package:pantry_app/ui/pages/stocktake_page.dart';
import 'package:pantry_app/data/store_scope.dart';
import 'package:pantry_app/ui/widgets/scan_to_use.dart';

Future<HouseholdStore> newStore([DateTime Function()? clock]) async {
  final s = HouseholdStore(MemoryBackend(), clock: clock);
  await s.load();
  return s;
}

void main() {
  group('backup', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('backup'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('everything and the photos come back on another phone', () async {
      final photo = File('${dir.path}/soy.jpg')..writeAsBytesSync([9, 8, 7]);
      final a = await newStore();
      final soy = await a.addItem(name: 'Soy sauce', locationId: 'pantry', quantity: 300, unit: 'ml', packSize: 500);
      await a.updateItem(a.item(soy.id)!.copyWith(photoPath: photo.path));
      await a.addShopping(name: 'Bread');
      await a.setSetting('people', 4);
      final text = makeBackup(a, now: DateTime(2026, 11, 16, 16, 42));
      expect(backupFileName(DateTime(2026, 11, 16, 16, 42)), 'pantry-backup-2026-11-16-1642.json');

      final b = await newStore();
      final r = await restoreBackup(b, text, Directory('${dir.path}/other-phone'));
      expect((r.items, r.photos, r.made), (1, 1, DateTime(2026, 11, 16, 16, 42)));
      final back = b.items.single;
      expect((back.name, back.quantity, back.packSize), ('Soy sauce', 300.0, 500.0));
      expect(back.photoPath, startsWith('${dir.path}/other-phone/'));
      expect(File(back.photoPath!).readAsBytesSync(), [9, 8, 7]);
      expect(b.shopping.single.name, 'Bread');
      expect(b.setting<int>('people', 3), 4);
    });

    test('anything that is not a pantry backup is refused and changes nothing', () async {
      final s = await newStore();
      await s.addItem(name: 'Rice', locationId: 'pantry');
      for (final bad in [
        'not json',
        jsonEncode({'kind': 'other'}),
        jsonEncode({'kind': backupKind, 'data': 'x'}),
      ]) {
        expect(restoreBackup(s, bad, dir), throwsFormatException);
      }
      expect(s.items.single.name, 'Rice');
    });
  });

  group('stocktake and finishing packs', () {
    test('a count sets the amount and is logged as counted, not used', () async {
      final s = await newStore();
      final rice = await s.addItem(name: 'Rice', locationId: 'prep', quantity: 10, unit: 'kg');
      expect(await s.countItem(rice.id, 8.5), -1.5);
      expect(s.item(rice.id)!.quantity, 8.5);
      expect((s.activity.first.action, s.activity.first.delta), ('counted', -1.5));
      expect(s.useRates, isEmpty, reason: 'a stocktake is not use');
    });

    test('finishing the open pack leaves the spare packs', () async {
      final s = await newStore();
      final oil = await s.addItem(name: 'Olive oil', locationId: 'pantry', quantity: 1150, unit: 'ml', packSize: 750);
      final full = await s.addItem(name: 'Soy', locationId: 'pantry', quantity: 1000, unit: 'ml', packSize: 500);
      final tins = await s.addItem(name: 'Tins', locationId: 'pantry', quantity: 4, unit: 'tins');
      expect([openPack(oil), openPack(full), openPack(tins)], [400, 500, 4]);
    });
  });

  group('water days and dates', () {
    test('litres from the unit or the name; not hot water bottles', () async {
      final s = await newStore();
      final jerry = await s.addItem(name: 'Water jerry cans', locationId: 'garage', quantity: 40, unit: 'L');
      final cask = await s.addItem(name: 'Cask water 10 L', locationId: 'garage', quantity: 2, unit: 'casks');
      final bottles = await s.addItem(
        name: 'Spring water',
        locationId: 'pantry',
        quantity: 1200,
        unit: 'ml',
        packSize: 600,
      );
      final hot = await s.addItem(name: 'Hot water bottle', locationId: 'spare', quantity: 1);
      final mystery = await s.addItem(name: 'Water bladders', locationId: 'garage', quantity: 3);
      expect([waterLitres(jerry), waterLitres(cask), waterLitres(bottles), waterLitres(hot)], [40, 20, 1.2, null]);

      final w = waterDays(s.items, people: 3);
      expect((w.litres, w.perDay, w.days), (61.2, 9.0, 6));
      expect(w.notCounted.single.id, mystery.id);
      expect(waterDays(s.items, people: 3, extraLitresPerDay: 1).days, 6);
      expect(waterDays(s.items, people: 2).days, 10);
    });

    test('use-by dates are grouped, soonest first; empty items are left out', () async {
      final now = DateTime(2026, 11, 16, 9);
      final s = await newStore();
      await s.addItem(name: 'Panadol', locationId: 'medical', quantity: 1, useBy: DateTime(2026, 11, 10));
      await s.addItem(name: 'Milk', locationId: 'fridge', quantity: 1, useBy: DateTime(2026, 11, 20));
      await s.addItem(name: 'Bandages', locationId: 'medical', quantity: 1, useBy: DateTime(2027, 5, 1));
      await s.addItem(name: 'Yoghurt', locationId: 'fridge', quantity: 1, useBy: DateTime(2026, 12, 1));
      await s.addItem(name: 'Gone', locationId: 'fridge', useBy: DateTime(2026, 11, 1));
      final g = byUseBy(s.items, now);
      expect(g.map((k, v) => MapEntry(k, v.map((i) => i.name).toList())), {
        DateGroup.expired: ['Panadol'],
        DateGroup.week: ['Milk'],
        DateGroup.month: ['Yoghurt'],
        DateGroup.later: ['Bandages'],
      });
    });
  });

  testWidgets('stocktake: right, recount, skip, then a summary', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final s = await newStore();
    final a = await s.addItem(name: 'Rice', locationId: 'prep', quantity: 10, unit: 'kg');
    final b = await s.addItem(name: 'Pasta', locationId: 'prep', quantity: 2, unit: 'kg');
    final c = await s.addItem(name: 'Sugar', locationId: 'prep', quantity: 1, unit: 'kg');
    await tester.pumpWidget(
      StoreScope(
        store: s,
        child: MaterialApp(
          home: StocktakePage(title: 'Prep pantry', itemIds: [a.id, b.id, c.id]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 of 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stocktake-right')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('stocktake-count')), '3.5');
    await tester.tap(find.byKey(const ValueKey('stocktake-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stocktake-skip')));
    await tester.pumpAndSettle();
    expect(find.text('3 checked: 1 right, 1 changed, 1 skipped.'), findsOneWidget);
    expect([s.item(a.id)!.quantity, s.item(b.id)!.quantity, s.item(c.id)!.quantity], [10, 3.5, 1]);
  });

  testWidgets('water days sit with the stock stored away; people can be changed; home opens dates', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final s = await newStore();
    await s.addItem(name: 'Water jerry cans', locationId: 'garage', quantity: 40, unit: 'L');
    await s.addItem(name: 'Panadol', locationId: 'medical', quantity: 1, useBy: DateTime(2020));
    await tester.pumpWidget(PantryApp(store: s));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-water')), findsNothing, reason: 'off Home since v0.18 (#42)');
    await tester.tap(find.byKey(const ValueKey('nav-pantry')));
    await tester.pumpAndSettle();
    final water = find.byKey(const ValueKey('water-days'));
    await tester.scrollUntilVisible(water, 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('4 days'), findsOneWidget, reason: '40 L / (3 people x 3 L)');
    await tester.tap(find.byKey(const ValueKey('people-less')));
    await tester.pumpAndSettle();
    expect(find.text('6 days'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-dates')));
    await tester.pumpAndSettle();
    expect(find.byType(DatesPage), findsOneWidget);
    expect(find.text('PAST ITS DATE (1)'), findsOneWidget, reason: 'section headers are capitals');
  });
}
