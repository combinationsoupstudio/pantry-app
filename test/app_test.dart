import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pantry_app/app.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/data/storage_backend.dart';
import 'package:pantry_app/data/store_scope.dart';
import 'package:pantry_app/logic/recipe_link.dart';
import 'package:pantry_app/ui/pages/recipe_editor_page.dart';

Future<HouseholdStore> seededStore() async {
  final store = HouseholdStore(MemoryBackend());
  await store.load();
  await store.addItem(name: 'Rice', locationId: 'pantry', quantity: 1, unit: 'kg', target: 5);
  await store.addItem(name: 'Toilet paper', locationId: 'hygiene', quantity: 12, unit: 'rolls', target: 24);
  await store.addItem(name: 'Bread', locationId: 'pantry', quantity: 1);
  await store.addItem(name: 'Baked beans', locationId: 'prep', quantity: 4, unit: 'cans');
  return store;
}

/// Runs widget tests at a typical Android phone size (411 x 914 dp).
void phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('the dashboard shows the house assessment and running-low items', (tester) async {
    phoneSize(tester);
    final store = await seededStore();
    await tester.pumpWidget(PantryApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text("G'day Chris"), findsWidgets);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('0 of 2 targets met, 2 running low.'), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);
  });

  testWidgets('every page in the bottom bar opens', (tester) async {
    phoneSize(tester);
    final store = await seededStore();
    await tester.pumpWidget(PantryApp(store: store));
    await tester.pumpAndSettle();

    for (final tab in AppTab.values) {
      await tester.tap(find.byKey(ValueKey('nav-${tab.name}')));
      await tester.pumpAndSettle();
      final title = tab == AppTab.home
          ? "G'day Chris"
          : tab == AppTab.shopping
          ? 'Shopping list'
          : tab.label;
      expect(find.text(title).hitTestable(), findsWidgets, reason: tab.name);
    }
  });

  testWidgets('tapping plus on the pantry page adds stock', (tester) async {
    phoneSize(tester);
    final store = await seededStore();
    final rice = store.items.firstWhere((i) => i.name == 'Rice');
    await tester.pumpWidget(PantryApp(store: store));
    await tester.tap(find.byKey(const ValueKey('nav-pantry')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('plus-${rice.id}')).hitTestable());
    await tester.pumpAndSettle();
    expect(store.item(rice.id)!.quantity, 2);
    expect(find.textContaining('2 kg of 5').hitTestable(), findsOneWidget);
  });

  testWidgets('adding an item through the editor', (tester) async {
    phoneSize(tester);
    final store = await seededStore();
    await tester.pumpWidget(PantryApp(store: store));
    await tester.tap(find.byKey(const ValueKey('nav-storage')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add item').hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('field-name')), 'Torch batteries');
    await tester.enterText(find.byKey(const ValueKey('field-qty')), '8');
    await tester.enterText(find.byKey(const ValueKey('field-target')), '16');
    await tester.tap(find.byKey(const ValueKey('save-item')));
    await tester.pumpAndSettle();

    final added = store.items.firstWhere((i) => i.name == 'Torch batteries');
    expect(added.quantity, 8);
    expect(added.target, 16);
    expect(store.location(added.locationId)!.name, 'Prep pantry');
  });

  testWidgets('shopping: add running low, tick, put away', (tester) async {
    phoneSize(tester);
    final store = await seededStore();
    await tester.pumpWidget(PantryApp(store: store));
    await tester.tap(find.byKey(const ValueKey('nav-shopping')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-low')));
    await tester.pumpAndSettle();
    expect(store.shopping, hasLength(2));

    for (final box in find.byType(Checkbox).hitTestable().evaluate().toList()) {
      await tester.tap(find.byWidget(box.widget));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('put-away')));
    await tester.pumpAndSettle();
    expect(store.shopping, isEmpty);
    expect(store.runningLow, isEmpty);
  });

  testWidgets('adding the missing items of a recipe twice stacks them, no duplicate lines', (tester) async {
    phoneSize(tester);
    final store = await seededStore();
    await tester.pumpWidget(PantryApp(store: store));
    await tester.tap(find.byKey(const ValueKey('nav-recipes')));
    await tester.pumpAndSettle();

    final button = find.text('Add missing to list').hitTestable().first;
    await tester.tap(button);
    await tester.pumpAndSettle();
    final firstCount = store.shopping.length;
    await tester.tap(find.text('Add missing to list').hitTestable().first);
    await tester.pumpAndSettle();

    final keys = store.shopping.map((l) => l.name.toLowerCase()).toList();
    expect(keys.toSet().length, keys.length, reason: 'no two lines for the same thing');
    expect(store.shopping.length, firstCount);
    expect(store.shopping.every((l) => l.quantity == 2), isTrue);
    expect(store.shopping.first.name[0], store.shopping.first.name[0].toUpperCase());
  });

  testWidgets('write your own recipe, open it, add what is missing', (tester) async {
    phoneSize(tester);
    final store = await seededStore();
    await tester.pumpWidget(PantryApp(store: store));
    await tester.tap(find.byKey(const ValueKey('nav-recipes')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-recipe')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-own')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('field-link')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('field-recipe-name')), 'Beans on toast deluxe');
    await tester.enterText(find.byKey(const ValueKey('field-ingredients')), 'bread\nbaked beans\nbutter');
    await tester.enterText(find.byKey(const ValueKey('field-method')), 'Toast. Beans. Butter.');
    await tester.tap(find.byKey(const ValueKey('save-recipe')));
    await tester.pumpAndSettle();

    expect(store.recipes.single.method, 'Toast. Beans. Butter.');
    expect(find.text('Beans on toast deluxe'), findsOneWidget);
    expect(find.textContaining('1 missing'), findsWidgets);

    await tester.tap(find.text('Beans on toast deluxe'));
    await tester.pumpAndSettle();
    expect(find.text('Method'), findsOneWidget);
    expect(find.byKey(const ValueKey('open-recipe')), findsNothing);
    await tester.tap(find.text('Add missing to list').first);
    await tester.pumpAndSettle();
    expect(store.shopping.single.name, 'Butter');
  });

  testWidgets('from a link: read fills the form, method is not taken', (tester) async {
    phoneSize(tester);
    final store = await seededStore();
    Future<RecipeDraft> fake(String link) async =>
        RecipeDraft(name: 'Test fried rice', ingredients: const ['rice', 'eggs', 'soy sauce'], minutes: 25, url: link);
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(home: RecipeEditorPage(startFromLink: true, fetcher: fake)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('field-link')), 'https://example.com/fried-rice');
    await tester.tap(find.byKey(const ValueKey('read-link')));
    await tester.pumpAndSettle();
    expect(find.text('Read 3 ingredients. Check them, then save.'), findsOneWidget);
    expect(find.text('Notes (optional)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save-recipe')));
    await tester.pumpAndSettle();
    final saved = store.recipes.single;
    expect(saved.name, 'Test fried rice');
    expect(saved.minutes, 25);
    expect(saved.ingredients, ['rice', 'eggs', 'soy sauce']);
    expect(saved.url, 'https://example.com/fried-rice');
    expect(saved.method, isEmpty);
  });

  testWidgets('a link that cannot be read still lets you type it in', (tester) async {
    phoneSize(tester);
    final store = await seededStore();
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: const MaterialApp(home: RecipeEditorPage(startFromLink: true)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('field-link')), 'not a link');
    await tester.tap(find.byKey(const ValueKey('read-link')));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not look like a web link'), findsOneWidget);
  });
}
