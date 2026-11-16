import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/data/storage_backend.dart';
import 'package:pantry_app/logic/reminders.dart';
import 'package:pantry_app/logic/voice_parse.dart';
import 'package:pantry_app/ui/widgets/voice_add.dart';
import 'package:pantry_app/app.dart';
import 'package:pantry_app/ui/pages/settings_page.dart';
import 'package:material_ui/material_ui.dart';

Future<HouseholdStore> newStore() async {
  final s = HouseholdStore(MemoryBackend());
  await s.load();
  return s;
}

void main() {
  group('say it to add it', () {
    List<String> said(String t) => parseSpoken(t).map((l) => l.toString()).toList();

    test('numbers, counting words and measures', () {
      expect(said('two tins of tomatoes and a dozen eggs, milk'), ['2.0 tins Tomatoes', '12.0 Eggs', '1.0 Milk']);
      expect(said('3 kg rice'), ['3.0 kg Rice']);
      expect(said('half a kilo of mince'), ['0.5 kg Mince']);
      expect(said('a couple of onions then some bread please'), ['2.0 Onions', '1.0 Bread']);
      expect(said('500 grams of butter and 2 litres of milk'), ['500.0 g Butter', '2.0 l Milk']);
      expect(said('four packets of pasta.'), ['4.0 packets Pasta']);
      expect(said(''), isEmpty);
    });
  });

  group('reminders', () {
    final now = DateTime(2026, 11, 16, 16, 40); // a Monday

    test('next weekday at an hour, never in the past', () {
      expect(nextWeekday(now, DateTime.saturday, 9), DateTime(2026, 11, 21, 9));
      expect(nextWeekday(now, DateTime.monday, 9), DateTime(2026, 11, 23, 9), reason: '9 am today has passed');
      expect(nextWeekday(now, DateTime.monday, 18), DateTime(2026, 11, 16, 18));
    });

    test('shop day says what is low and on the list; backup nudge; nothing when off', () async {
      final s = await newStore();
      final plan = planReminders(
        items: s.items,
        runningLow: 8,
        onList: 12,
        settings: const ReminderSettings(shopDay: DateTime.saturday, useBy: false, backupDay: DateTime.sunday),
        now: now,
      );
      expect(plan.map((r) => (r.id, r.when, r.weekly)), [
        (shopReminderId, DateTime(2026, 11, 21, 9), true),
        (backupReminderId, DateTime(2026, 11, 22, 19), true),
      ]);
      expect(plan.first.body, '8 running low, 12 on the list. Tap to check before you go.');
      expect(
        planReminders(
          items: s.items,
          runningLow: 8,
          onList: 1,
          settings: const ReminderSettings(useBy: false),
          now: now,
        ),
        isEmpty,
      );
    });

    test('use-by alerts two days before at 9, or the day before; none for past or empty', () async {
      final s = await newStore();
      await s.addItem(name: 'Milk', locationId: 'fridge', quantity: 1, useBy: DateTime(2026, 11, 20));
      await s.addItem(name: 'Yoghurt', locationId: 'fridge', quantity: 1, useBy: DateTime(2026, 11, 18));
      await s.addItem(name: 'Cream', locationId: 'fridge', quantity: 1, useBy: DateTime(2026, 11, 17));
      await s.addItem(name: 'Old', locationId: 'fridge', quantity: 1, useBy: DateTime(2026, 11, 1));
      await s.addItem(name: 'Empty', locationId: 'fridge', useBy: DateTime(2026, 11, 30));
      final plan = planReminders(
        items: s.items,
        runningLow: 0,
        onList: 0,
        settings: const ReminderSettings(),
        now: now,
      );
      expect(plan.map((r) => (r.title, r.when)), [
        ('Yoghurt: use by tomorrow', DateTime(2026, 11, 17, 9)),
        ('Milk: use by 20/11', DateTime(2026, 11, 18, 9)),
      ], reason: 'cream is due tomorrow and both 9 am slots have passed');
      expect(plan.map((r) => r.id).toSet().length, 2);
    });

    test('settings are read from the store', () async {
      final s = await newStore();
      await s.setSetting('remindShopDay', DateTime.friday);
      await s.setSetting('remindUseBy', false);
      final r = ReminderSettings.from(s.setting);
      expect((r.shopDay, r.shopHour, r.useBy, r.backupDay), (DateTime.friday, 9, false, null));
    });
  });

  group('adding what was said', () {
    test('to the list: one line each, measures kept, counting words dropped', () async {
      final s = await newStore();
      final n = await addSpoken(s, parseSpoken('two tins of tomatoes and 3 kg rice'), VoiceTarget.shopping);
      expect(n, 2);
      expect(s.shopping.map((l) => (l.name, l.quantity, l.unit)), [('Tomatoes', 2.0, ''), ('Rice', 3.0, 'kg')]);
    });

    test('to stock: tops up what is there in its own unit, adds what is new', () async {
      final s = await newStore();
      final rice = await s.addItem(name: 'Rice', locationId: 'pantry', quantity: 1, unit: 'kg');
      final soy = await s.addItem(name: 'Soy sauce', locationId: 'pantry', quantity: 100, unit: 'ml', packSize: 500);
      await addSpoken(
        s,
        parseSpoken('500 grams of rice, a soy sauce and 2 tins of tuna'),
        VoiceTarget.stock,
        locationId: 'prep',
      );
      expect(s.item(rice.id)!.quantity, 1.5);
      expect(s.item(soy.id)!.quantity, 600, reason: 'one pack');
      final tuna = s.itemByName('Tuna')!;
      expect((tuna.quantity, tuna.unit, tuna.locationId), (2.0, 'tins', 'prep'));
    });
  });

  testWidgets('settings: choosing a shop day keeps it', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final s = await newStore();
    await tester.pumpWidget(PantryApp(store: s));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byKey(const ValueKey('remind-shop')), matching: find.byType(DropdownButton<int>)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saturday').last);
    await tester.pumpAndSettle();
    expect(s.setting<int?>('remindShopDay', null), DateTime.saturday);
    expect(find.text('Saturdays at 9 am'), findsOneWidget);
  });
}
