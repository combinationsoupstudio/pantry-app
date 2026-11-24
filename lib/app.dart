import 'package:material_ui/material_ui.dart';

import 'data/household_store.dart';
import 'data/store_scope.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/pantry_page.dart';
import 'ui/pages/recipes_page.dart';
import 'ui/pages/shopping_page.dart';
import 'ui/theme.dart';

class PantryApp extends StatelessWidget {
  const PantryApp({super.key, required this.store});

  final HouseholdStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      // The look follows the household setting (v0.18, #38).
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final look = PantryLook.fromName(store.setting<String>('look', 'market'));
          return MaterialApp(
            title: 'Pantry',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light, look: look),
            darkTheme: buildTheme(Brightness.dark, look: look),
            // Australian dates (17/11/2026) in pickers and anything localised.
            locale: const Locale('en', 'AU'),
            supportedLocales: const [Locale('en', 'AU')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const AppShell(),
          );
        },
      ),
    );
  }
}

/// The four pages (v0.10: Storage is inside Pantry, Insights opens from
/// Home). Order here is the order in the bottom bar.
enum AppTab {
  home('Home', Icons.home_outlined, Icons.home),
  pantry('Pantry', Icons.kitchen_outlined, Icons.kitchen),
  shopping('Shopping', Icons.shopping_basket_outlined, Icons.shopping_basket),
  recipes('Recipes', Icons.menu_book_outlined, Icons.menu_book);

  const AppTab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppTab _tab = AppTab.home;

  void go(AppTab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final shoppingCount = store.shopping.where((s) => !s.bought).length;
    final pages = <AppTab, Widget>{
      AppTab.home: HomePage(onGo: go),
      AppTab.pantry: const PantryPage(),
      AppTab.shopping: const ShoppingPage(),
      AppTab.recipes: const RecipesPage(),
    };
    return Scaffold(
      body: IndexedStack(index: _tab.index, children: [for (final t in AppTab.values) pages[t]!]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (i) => go(AppTab.values[i]),
        destinations: [
          for (final t in AppTab.values)
            NavigationDestination(
              key: ValueKey('nav-${t.name}'),
              icon: t == AppTab.shopping && shoppingCount > 0
                  ? Badge(label: Text('$shoppingCount'), child: Icon(t.icon))
                  : Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.label,
              tooltip: t.label,
            ),
        ],
      ),
    );
  }
}
