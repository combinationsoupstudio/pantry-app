import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pantry_app/app.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/data/storage_backend.dart';
import 'package:pantry_app/ui/widgets/item_sheets.dart';

void main() {
  test('use-by buttons count from today, months by the calendar', () {
    final t = DateTime(2026, 11, 17, 21, 45);
    expect(useByFromToday(t, days: 7), DateTime(2026, 11, 24));
    expect(useByFromToday(t, months: 1), DateTime(2026, 12, 17));
    expect(useByFromToday(t, months: 6), DateTime(2027, 5, 17));
    expect(useByFromToday(t, months: 24), DateTime(2028, 11, 17));
    expect(useByFromToday(DateTime(2027, 1, 31), months: 1), DateTime(2027, 2, 28));
    expect(formatDayMonthYear(DateTime(2026, 11, 17)), '17/11/2026');
  });

  test("a photo from the other phone never wipes this phone's", () async {
    final store = HouseholdStore(MemoryBackend());
    await store.load();
    store.photoOnThisPhone = (p) => p.startsWith('/chris/');
    final i = await store.addItem(name: 'Passata', locationId: 'prep', quantity: 3);
    await store.updateItem(store.item(i.id)!.copyWith(photoPath: '/chris/passata.jpg'));
    // Emily photographs the same jar; her record arrives with her path.
    final hers = store.item(i.id)!.copyWith(photoPath: '/emily/passata.jpg', quantity: 4).toJson();
    await store.applySync([('items', i.id, hers)]);
    expect(store.item(i.id)!.photoPath, '/chris/passata.jpg');
    expect(store.item(i.id)!.quantity, 4, reason: 'everything else still comes across');
  });

  testWidgets('the date picker is a calendar in Australian order', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final store = HouseholdStore(MemoryBackend());
    await store.load();
    await tester.pumpWidget(PantryApp(store: store));
    await tester.pumpAndSettle();
    final ctx = tester.element(find.byType(Scaffold).first);
    expect(Localizations.localeOf(ctx), const Locale('en', 'AU'));
    expect(MaterialLocalizations.of(ctx).formatCompactDate(DateTime(2026, 11, 17)), '17/11/2026');
  });
}
