import 'package:flutter/widgets.dart';

import 'household_store.dart';

/// Makes the [HouseholdStore] available to every page and rebuilds
/// dependants when it changes.
class StoreScope extends InheritedNotifier<HouseholdStore> {
  const StoreScope({super.key, required HouseholdStore store, required super.child}) : super(notifier: store);

  static HouseholdStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    assert(scope != null, 'No StoreScope above this widget');
    return scope!.notifier!;
  }

  /// Reads the store without listening (for callbacks).
  static HouseholdStore read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<StoreScope>();
    return (element!.widget as StoreScope).notifier!;
  }
}
