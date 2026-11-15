import 'package:material_ui/material_ui.dart';

import 'data/household_store.dart';
import 'data/store_scope.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/insights_page.dart';
import 'ui/pages/pantry_page.dart';
import 'ui/pages/recipes_page.dart';
import 'ui/pages/shopping_page.dart';
import 'ui/pages/storage_page.dart';
import 'ui/theme.dart';

class PantryApp extends StatelessWidget {
  const PantryApp({super.key, required this.store});

  final HouseholdStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: MaterialApp(
        title: 'Pantry',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const AppShell(),
      ),
    );
  }
}

/// The six pages. Order here is the order in the bottom bar.
enum AppTab {
  home('Home', Icons.dashboard_outlined, Icons.dashboard),
  pantry('Pantry', Icons.kitchen_outlined, Icons.kitchen),
  storage('Storage', Icons.inventory_2_outlined, Icons.inventory_2),
  shopping('Shopping', Icons.shopping_cart_outlined, Icons.shopping_cart),
  recipes('Recipes', Icons.restaurant_menu_outlined, Icons.restaurant_menu),
  insights('Insights', Icons.insights_outlined, Icons.insights);

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
      AppTab.storage: const StoragePage(),
      AppTab.shopping: const ShoppingPage(),
      AppTab.recipes: const RecipesPage(),
      AppTab.insights: const InsightsPage(),
    };
    return Scaffold(
      body: IndexedStack(index: _tab.index, children: [for (final t in AppTab.values) pages[t]!]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
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
