import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pantry_app/app.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/data/storage_backend.dart';

// v0.18 (#42): Home's teal header. No greeting; how stocked the house is,
// split into good, low and out; three tiles that go where they say.

void main() {
  testWidgets('the header counts good, low and out once each, and the tiles go places', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final s = HouseholdStore(MemoryBackend(), clock: () => DateTime(2026, 11, 24, 9));
    await s.load();
    await s.addItem(name: 'Rice', locationId: 'pantry', quantity: 2, target: 1);
    await s.addItem(name: 'Oats', locationId: 'pantry', quantity: 1, target: 3);
    await s.addItem(name: 'Milk', locationId: 'fridge', quantity: 0, target: 2);
    await tester.pumpWidget(PantryApp(store: s));
    await tester.pumpAndSettle();
    expect(find.text('33%'), findsOneWidget);
    expect(find.text('1 good'), findsOneWidget);
    expect(find.text('1 low'), findsOneWidget, reason: 'Oats; Milk is out, not counted twice');
    expect(find.text('1 out'), findsOneWidget);
    for (final k in ['home-list', 'home-meals', 'home-dates', 'home-stock']) {
      expect(find.byKey(ValueKey(k)).hitTestable(), findsOneWidget, reason: '$k is on screen and not covered');
    }
    await tester.tap(find.byKey(const ValueKey('home-list')));
    await tester.pumpAndSettle();
    expect(find.text('Shopping list').hitTestable(), findsWidgets);
  });
}
