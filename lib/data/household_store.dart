import 'package:flutter/foundation.dart';

import '../logic/recipe_link.dart';
import '../logic/usage.dart';
import '../models/models.dart';
import 'csv_import.dart';
import 'storage_backend.dart';

/// The people who share this household in phase 0.
const householdMembers = ['Chris', 'Emily'];

/// Default locations for a new household.
List<StockLocation> defaultLocations() => const [
  StockLocation(id: 'pantry', name: 'Pantry', kind: LocationKind.pantry),
  StockLocation(id: 'fridge', name: 'Fridge', kind: LocationKind.pantry),
  StockLocation(id: 'freezer', name: 'Freezer', kind: LocationKind.pantry),
  StockLocation(id: 'prep', name: 'Prep pantry', kind: LocationKind.storage),
  StockLocation(id: 'spare', name: 'Spare cupboard', kind: LocationKind.storage),
  StockLocation(id: 'garage', name: 'Garage', kind: LocationKind.storage),
  StockLocation(id: 'medical', name: 'Medical', kind: LocationKind.storage),
  StockLocation(id: 'hygiene', name: 'Hygiene', kind: LocationKind.storage),
];

/// Single source of truth for the household. Every change goes through a
/// method here, is logged in [activity], and is saved through the backend.
class HouseholdStore extends ChangeNotifier {
  HouseholdStore(this._backend, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final StorageBackend _backend;
  final DateTime Function() _clock;

  static const maxActivity = 1000;

  List<StockLocation> _locations = [...defaultLocations()];
  List<StockItem> _items = [];
  List<ShoppingItem> _shopping = [];
  List<ActivityEntry> _activity = [];
  List<SavedRecipe> _recipes = [];
  List<PricePoint> _prices = [];
  String _user = householdMembers.first;
  bool _loaded = false;

  List<StockLocation> get locations => List.unmodifiable(_locations);
  List<StockItem> get items => List.unmodifiable(_items);
  List<ShoppingItem> get shopping => List.unmodifiable(_shopping);

  /// Prices paid, newest first.
  List<PricePoint> get prices => List.unmodifiable(_prices);

  /// The household's saved recipes, by name.
  List<SavedRecipe> get recipes => List.unmodifiable(_recipes);

  SavedRecipe? recipe(String id) {
    for (final r in _recipes) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Newest first.
  List<ActivityEntry> get activity => List.unmodifiable(_activity);
  String get user => _user;
  bool get loaded => _loaded;

  List<StockLocation> locationsOf(LocationKind kind) => _locations.where((l) => l.kind == kind).toList();

  StockLocation? location(String id) {
    for (final l in _locations) {
      if (l.id == id) return l;
    }
    return null;
  }

  StockItem? item(String id) {
    for (final i in _items) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// Items in locations of [kind], sorted by name.
  List<StockItem> itemsOf(LocationKind kind, {String? locationId}) {
    final ids = locationsOf(kind).map((l) => l.id).toSet();
    final list =
        _items.where((i) => ids.contains(i.locationId) && (locationId == null || i.locationId == locationId)).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Everything under target, worst first.
  List<StockItem> get runningLow {
    final list = _items.where((i) => i.isLow).toList()..sort((a, b) => a.fill.compareTo(b.fill));
    return list;
  }

  // ---------------------------------------------------------------- loading

  Future<void> load() async {
    final data = await _backend.load();
    if (data != null) _apply(data);
    _loaded = true;
    _rates = null;
    notifyListeners();
    if (data != null && _shoppingNeedsSave) {
      _shoppingNeedsSave = false;
      await _backend.save(toJson());
    }
  }

  /// Replaces everything with a backup's data (`toJson()` of another store,
  /// or this one earlier). Refuses something that is not a household.
  Future<void> restore(Map<String, Object?> data) async {
    if (data['schema'] is! int || data['items'] is! List || data['locations'] is! List) {
      throw const FormatException('Not a pantry backup');
    }
    _apply(data);
    _shoppingNeedsSave = false;
    await _commit();
  }

  void _apply(Map<String, Object?> data) {
    {
      // One block, as load() had it.
      _locations = (data['locations'] as List? ?? [])
          .map((e) => StockLocation.fromJson((e as Map).cast<String, Object?>()))
          .toList();
      if (_locations.isEmpty) _locations = [...defaultLocations()];
      _items = (data['items'] as List? ?? [])
          .map((e) => StockItem.fromJson((e as Map).cast<String, Object?>()))
          .toList();
      _shopping = (data['shopping'] as List? ?? [])
          .map((e) => ShoppingItem.fromJson((e as Map).cast<String, Object?>()))
          .toList();
      _activity = (data['activity'] as List? ?? [])
          .map((e) => ActivityEntry.fromJson((e as Map).cast<String, Object?>()))
          .toList();
      _recipes = (data['recipes'] as List? ?? [])
          .map((e) => SavedRecipe.fromJson((e as Map).cast<String, Object?>()))
          .toList();
      _prices = (data['prices'] as List? ?? [])
          .map((e) => PricePoint.fromJson((e as Map).cast<String, Object?>()))
          .toList();
      _shoppingNeedsSave = _consolidateShopping();
      final savedUser = data['user'] as String?;
      if (savedUser != null && householdMembers.contains(savedUser)) _user = savedUser;
      _settings = {...?(data['settings'] as Map?)?.cast<String, Object?>()};
    }
  }

  Map<String, Object?> _settings = {};

  /// A household setting (people for water days, ...), or [fallback].
  T setting<T>(String key, T fallback) {
    final v = _settings[key];
    return v is T ? v : fallback;
  }

  Future<void> setSetting(String key, Object? value) async {
    if (_settings[key] == value) return;
    if (value == null) {
      _settings.remove(key);
    } else {
      _settings[key] = value;
    }
    await _commit();
  }

  /// Sets an item to what is really there (stocktake), logging the
  /// difference. Returns the change.
  Future<double> countItem(String itemId, double counted) async {
    final i = item(itemId);
    if (i == null) return 0;
    final q = counted < 0 ? 0.0 : counted;
    final delta = q - i.quantity;
    final index = _items.indexWhere((x) => x.id == itemId);
    _items[index] = i.copyWith(quantity: q, updatedAt: _clock(), updatedBy: _user);
    _log(i.name, 'counted', delta: delta, unit: i.unit);
    await _commit();
    return delta;
  }

  bool _shoppingNeedsSave = false;

  Map<String, Object?> toJson() => {
    'schema': 1,
    'user': _user,
    'locations': _locations.map((l) => l.toJson()).toList(),
    'items': _items.map((i) => i.toJson()).toList(),
    'shopping': _shopping.map((s) => s.toJson()).toList(),
    'activity': _activity.map((a) => a.toJson()).toList(),
    'recipes': _recipes.map((r) => r.toJson()).toList(),
    'prices': _prices.map((p) => p.toJson()).toList(),
    if (_settings.isNotEmpty) 'settings': _settings,
  };

  Map<String, double>? _rates;

  /// How much of each item is used per day (by name), from recent history.
  Map<String, double> get useRates => _rates ??= usePerDay(_activity, _clock());

  /// Days until [item] runs out at its recent rate, or null if not in use.
  double? daysLeftFor(StockItem item) => daysLeft(item, useRates);

  /// Items that will run out within [days] at their recent rate, soonest first.
  List<StockItem> runningOutWithin(double days) {
    final list = <(StockItem, double)>[];
    for (final i in _items) {
      final d = daysLeftFor(i);
      if (d != null && d <= days) list.add((i, d));
    }
    list.sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final e in list) e.$1];
  }

  Future<void> _commit() async {
    _rates = null;
    notifyListeners();
    await _backend.save(toJson());
  }

  void _log(String itemName, String action, {double delta = 0, String unit = ''}) {
    _activity.insert(
      0,
      ActivityEntry(at: _clock(), who: _user, itemName: itemName, action: action, delta: delta, unit: unit),
    );
    if (_activity.length > maxActivity) _activity.removeRange(maxActivity, _activity.length);
  }

  // ------------------------------------------------------------------ people

  Future<void> setUser(String name) async {
    if (!householdMembers.contains(name) || name == _user) return;
    _user = name;
    await _commit();
  }

  // --------------------------------------------------------------- locations

  Future<StockLocation> addLocation(String name, LocationKind kind) async {
    final existing = _findLocationByName(name);
    if (existing != null) return existing;
    final loc = StockLocation(id: newId(), name: name.trim(), kind: kind);
    _locations.add(loc);
    await _commit();
    return loc;
  }

  StockLocation? _findLocationByName(String name) {
    final key = name.trim().toLowerCase();
    for (final l in _locations) {
      if (l.name.toLowerCase() == key) return l;
    }
    return null;
  }

  // ------------------------------------------------------------------- stock

  Future<StockItem> addItem({
    required String name,
    required String locationId,
    double quantity = 0,
    String unit = '',
    double target = 0,
    DateTime? useBy,
    String notes = '',
    double packSize = 0,
    String? barcode,
    String? photoPath,
    String? imageUrl,
  }) async {
    final item = StockItem(
      id: newId(),
      name: name.trim(),
      locationId: locationId,
      quantity: quantity < 0 ? 0 : quantity,
      unit: unit.trim(),
      target: target < 0 ? 0 : target,
      useBy: useBy,
      notes: notes,
      updatedAt: _clock(),
      updatedBy: _user,
      packSize: packSize < 0 ? 0 : packSize,
      barcode: (barcode == null || barcode.trim().isEmpty) ? null : barcode.trim(),
      photoPath: photoPath,
      imageUrl: imageUrl,
    );
    _items.add(item);
    _log(item.name, 'added', delta: item.quantity, unit: item.unit);
    await _commit();
    return item;
  }

  Future<void> updateItem(StockItem updated) async {
    final index = _items.indexWhere((i) => i.id == updated.id);
    if (index < 0) return;
    _items[index] = updated.copyWith(updatedAt: _clock(), updatedBy: _user);
    _log(updated.name, 'edited');
    await _commit();
  }

  /// The stock item with this barcode, if one was scanned before.
  StockItem? itemByBarcode(String code) {
    final c = code.trim();
    if (c.isEmpty) return null;
    for (final i in _items) {
      if (i.barcode == c) return i;
    }
    return null;
  }

  /// Sets (or clears, with null) an item's product picture. Not logged as an
  /// edit: it changes how the item looks, not what the household has.
  /// [byName] marks a picture the app matched by name, for checking.
  Future<void> setPicture(String itemId, String? imageUrl, {bool byName = false}) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index < 0) return;
    final i = _items[index];
    if (i.imageUrl == imageUrl && i.pictureByName == byName) return;
    _items[index] = i.copyWith(imageUrl: imageUrl, clearImage: imageUrl == null, pictureByName: byName);
    await _commit();
  }

  /// Records that a name search found no picture it could trust.
  Future<void> markPictureTried(String itemId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index < 0 || _items[index].pictureTried) return;
    _items[index] = _items[index].copyWith(pictureTried: true);
    await _commit();
  }

  /// Lets every item without a picture be searched for again. Returns how many.
  Future<int> retryPictures() async {
    var n = 0;
    for (var k = 0; k < _items.length; k++) {
      if (_items[k].pictureTried) {
        _items[k] = _items[k].copyWith(pictureTried: false);
        n++;
      }
    }
    if (n > 0) await _commit();
    return n;
  }

  /// Adds one pack of a measured item, or one of a counted one.
  Future<void> addPack(String itemId) async {
    final i = item(itemId);
    if (i == null) return;
    await adjust(itemId, i.isMeasured ? i.packSize : 1);
  }

  /// Adds (positive) or uses (negative) stock. Never goes below zero.
  Future<void> adjust(String itemId, double delta) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index < 0 || delta == 0) return;
    final current = _items[index];
    final next = (current.quantity + delta).clamp(0, double.infinity).toDouble();
    final applied = next - current.quantity;
    if (applied == 0) return;
    _items[index] = current.copyWith(quantity: next, updatedAt: _clock(), updatedBy: _user);
    _log(current.name, applied > 0 ? 'topped up' : 'used', delta: applied, unit: current.unit);
    await _commit();
  }

  /// Moves [amount] of an item to another location. If the destination
  /// already holds the same item (same name and unit), it is topped up;
  /// otherwise a new item is made there.
  Future<void> move(String itemId, String toLocationId, double amount) async {
    final source = item(itemId);
    if (source == null || source.locationId == toLocationId || amount <= 0) return;
    final moved = amount > source.quantity ? source.quantity : amount;
    if (moved <= 0) return;
    final now = _clock();

    final srcIndex = _items.indexWhere((i) => i.id == itemId);
    _items[srcIndex] = source.copyWith(quantity: source.quantity - moved, updatedAt: now, updatedBy: _user);

    final destIndex = _items.indexWhere(
      (i) =>
          i.locationId == toLocationId &&
          i.name.toLowerCase() == source.name.toLowerCase() &&
          i.unit.toLowerCase() == source.unit.toLowerCase(),
    );
    if (destIndex >= 0) {
      final dest = _items[destIndex];
      _items[destIndex] = dest.copyWith(quantity: dest.quantity + moved, updatedAt: now, updatedBy: _user);
    } else {
      _items.add(
        StockItem(
          id: newId(),
          name: source.name,
          locationId: toLocationId,
          quantity: moved,
          unit: source.unit,
          target: 0,
          updatedAt: now,
          updatedBy: _user,
          packSize: source.packSize,
          barcode: source.barcode,
          photoPath: source.photoPath,
          imageUrl: source.imageUrl,
        ),
      );
    }
    final toName = location(toLocationId)?.name ?? 'another spot';
    _log(source.name, 'moved to $toName', delta: moved, unit: source.unit);
    await _commit();
  }

  Future<void> removeItem(String itemId) async {
    final existing = item(itemId);
    if (existing == null) return;
    _items.removeWhere((i) => i.id == itemId);
    _shopping = _shopping.map((s) => s.stockItemId == itemId ? _unlink(s) : s).toList();
    _log(existing.name, 'removed');
    await _commit();
  }

  ShoppingItem _unlink(ShoppingItem s) => ShoppingItem(
    id: s.id,
    name: s.name,
    quantity: s.quantity,
    unit: s.unit,
    store: s.store,
    addedBy: s.addedBy,
    bought: s.bought,
  );

  // ---------------------------------------------------------------- shopping

  /// Adds to the shopping list. If the same thing is already on it, not yet
  /// bought, the amount stacks onto that line instead of making a new one.
  /// "The same thing" is the same stock item, or the same name ignoring case
  /// and spacing, in a compatible unit. A line with no stock item is linked
  /// to a stock item of the same name, so putting it away restocks it.
  /// Returns the line that now holds it.
  Future<ShoppingItem> addShopping({
    required String name,
    double quantity = 1,
    String unit = '',
    Store store = Store.any,
    String? stockItemId,
  }) async {
    final line = _stack(
      name: name,
      quantity: quantity <= 0 ? 1 : quantity,
      unit: unit,
      store: store,
      stockItemId: stockItemId,
    );
    await _commit();
    return line;
  }

  ShoppingItem _stack({
    required String name,
    required double quantity,
    required String unit,
    required Store store,
    String? stockItemId,
  }) {
    final trimmedName = name.trim();
    var linkedId = stockItemId;
    var lineUnit = unit.trim();
    if (linkedId == null) {
      final match = _stockByName(trimmedName);
      if (match != null) {
        linkedId = match.id;
        if (lineUnit.isEmpty) lineUnit = match.shoppingUnit;
      }
    } else if (lineUnit.isEmpty) {
      lineUnit = item(linkedId)?.shoppingUnit ?? '';
    }
    final index = _findStackTarget(name: trimmedName, unit: lineUnit, stockItemId: linkedId);
    if (index >= 0) {
      final existing = _shopping[index];
      final merged = existing.copyWith(
        quantity: existing.quantity + quantity,
        unit: existing.unit.isEmpty ? lineUnit : existing.unit,
        stockItemId: existing.stockItemId ?? linkedId,
      );
      _shopping[index] = merged;
      return merged;
    }
    final line = ShoppingItem(
      id: newId(),
      name: trimmedName,
      quantity: quantity,
      unit: lineUnit,
      store: store,
      addedBy: _user,
      stockItemId: linkedId,
    );
    _shopping.add(line);
    return line;
  }

  /// The stock item called [name] (ignoring case, plurals and punctuation).
  StockItem? itemByName(String name) => _stockByName(name);

  StockItem? _stockByName(String name) {
    final key = nameKey(name);
    for (final i in _items) {
      if (nameKey(i.name) == key) return i;
    }
    return null;
  }

  /// The not-yet-bought line that [name] / [stockItemId] should stack onto, or -1.
  int _findStackTarget({required String name, required String unit, String? stockItemId}) {
    final key = nameKey(name);
    for (var i = 0; i < _shopping.length; i++) {
      final s = _shopping[i];
      if (s.bought) continue;
      if (!_sameThing(s.stockItemId, s.name, s.unit, stockItemId, key, unit)) continue;
      return i;
    }
    return -1;
  }

  static bool _sameThing(String? idA, String nameA, String unitA, String? idB, String keyB, String unitB) {
    if (idA != null && idB != null) {
      if (idA != idB) return false; // two different stock items, even if named alike
    } else if (nameKey(nameA) != keyB) {
      return false;
    }
    // Amounts only stack in the same unit (or where one side has none).
    return unitA.isEmpty || unitB.isEmpty || unitA.toLowerCase() == unitB.toLowerCase();
  }

  /// Merges not-yet-bought lines that are the same thing. Lists saved by
  /// v0.1.0 could hold such duplicates. Returns true if anything merged.
  bool _consolidateShopping() {
    final result = <ShoppingItem>[];
    var merged = false;
    for (final s in _shopping) {
      final index = s.bought
          ? -1
          : result.indexWhere(
              (r) => !r.bought && _sameThing(r.stockItemId, r.name, r.unit, s.stockItemId, nameKey(s.name), s.unit),
            );
      if (index < 0) {
        result.add(s);
      } else {
        final r = result[index];
        result[index] = r.copyWith(
          quantity: r.quantity + s.quantity,
          unit: r.unit.isEmpty ? s.unit : r.unit,
          stockItemId: r.stockItemId ?? s.stockItemId,
        );
        merged = true;
      }
    }
    _shopping = result;
    return merged;
  }

  /// Puts everything that is under target on the list, for the amount needed
  /// to get back to target. An item already on the list is not added twice:
  /// its line is linked and raised to the shortfall if it was less.
  /// Returns how many items were added or raised.
  Future<int> addRunningLowToShopping() async {
    var changed = 0;
    for (final low in runningLow) {
      final index = _findStackTarget(name: low.name, unit: low.shoppingUnit, stockItemId: low.id);
      if (index < 0) {
        _shopping.add(
          ShoppingItem(
            id: newId(),
            name: low.name,
            quantity: low.restock,
            unit: low.shoppingUnit,
            store: Store.any,
            addedBy: _user,
            stockItemId: low.id,
          ),
        );
        changed++;
        continue;
      }
      final existing = _shopping[index];
      if (existing.stockItemId == low.id && existing.quantity >= low.restock) continue;
      _shopping[index] = existing.copyWith(
        stockItemId: low.id,
        unit: existing.unit.isEmpty ? low.shoppingUnit : existing.unit,
        quantity: existing.quantity >= low.restock ? existing.quantity : low.restock,
      );
      changed++;
    }
    if (changed > 0) await _commit();
    return changed;
  }

  Future<void> setBought(String shoppingId, bool bought) async {
    final index = _shopping.indexWhere((s) => s.id == shoppingId);
    if (index < 0) return;
    _shopping[index] = _shopping[index].copyWith(bought: bought);
    await _commit();
  }

  /// Sets how many of a shopping line to buy. Below one, the line stays at one;
  /// swipe it away to remove it.
  Future<void> setShoppingQuantity(String shoppingId, double quantity) async {
    final index = _shopping.indexWhere((s) => s.id == shoppingId);
    if (index < 0) return;
    final q = quantity < 1 ? 1.0 : quantity;
    if (_shopping[index].quantity == q) return;
    _shopping[index] = _shopping[index].copyWith(quantity: q);
    await _commit();
  }

  Future<void> setStore(String shoppingId, Store store) async {
    final index = _shopping.indexWhere((s) => s.id == shoppingId);
    if (index < 0) return;
    _shopping[index] = _shopping[index].copyWith(store: store);
    await _commit();
  }

  /// Empties the shopping list. Returns how many lines went.
  Future<int> clearShopping() async {
    final n = _shopping.length;
    if (n == 0) return 0;
    _shopping.clear();
    await _commit();
    return n;
  }

  /// True if [name] (or the stock item [stockItemId]) already has an open line.
  bool isOnShoppingList(String name, {String? stockItemId}) =>
      _findStackTarget(name: name, unit: '', stockItemId: stockItemId) >= 0;

  Future<void> removeShopping(String shoppingId) async {
    _shopping.removeWhere((s) => s.id == shoppingId);
    await _commit();
  }

  /// Everything ticked as bought goes into stock (when it is linked to a
  /// stock item) and leaves the list. [paid] holds what was paid for a line,
  /// by its id, in dollars; each one is kept as a price with the line's shop.
  /// Returns how many were put away.
  Future<int> putAwayBought({Map<String, double> paid = const {}}) async {
    final bought = _shopping.where((s) => s.bought).toList();
    if (bought.isEmpty) return 0;
    final now = _clock();
    for (final s in bought) {
      final index = s.stockItemId == null ? -1 : _items.indexWhere((i) => i.id == s.stockItemId);
      final unit = s.unit.isEmpty && index >= 0 ? _items[index].unit : s.unit;
      if (index >= 0) {
        final current = _items[index];
        // Packs of a measured item go in as their amount: 2 × 500 ml = 1000 ml.
        final added = current.isMeasured && nameKey(s.unit) != nameKey(current.unit)
            ? s.quantity * current.packSize
            : s.quantity;
        _items[index] = current.copyWith(quantity: current.quantity + added, updatedAt: now, updatedBy: _user);
        _log(current.name, 'bought', delta: added, unit: current.unit);
      } else {
        _log(s.name, 'bought', delta: s.quantity, unit: s.unit);
      }
      final total = paid[s.id];
      if (total != null && total > 0) {
        _prices.insert(
          0,
          PricePoint(
            id: newId(),
            name: index >= 0 ? _items[index].name : s.name,
            stockItemId: index >= 0 ? _items[index].id : null,
            store: s.store,
            total: total,
            quantity: s.quantity,
            unit: unit,
            at: now,
            by: _user,
          ),
        );
      }
    }
    if (_prices.length > maxPrices) _prices.removeRange(maxPrices, _prices.length);
    _shopping.removeWhere((s) => s.bought);
    await _commit();
    return bought.length;
  }

  static const maxPrices = 2000;

  /// Prices paid for a stock item (or anything of the same name), newest first.
  List<PricePoint> pricesFor(StockItem item) {
    final key = nameKey(item.name);
    return _prices.where((p) => p.stockItemId == item.id || nameKey(p.name) == key).toList();
  }

  /// The latest price per shop for an item, cheapest per unit first.
  List<PricePoint> latestByStore(StockItem item) {
    final seen = <Store>{};
    final latest = <PricePoint>[];
    for (final p in pricesFor(item)) {
      if (seen.add(p.store)) latest.add(p);
    }
    latest.sort((a, b) => a.unitPrice.compareTo(b.unitPrice));
    return latest;
  }

  /// Dollars spent per shop since Monday (the start of [now]'s week).
  Map<Store, double> spendThisWeek(DateTime now) {
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final out = <Store, double>{};
    for (final p in _prices) {
      if (p.at.isBefore(monday)) continue;
      out[p.store] = (out[p.store] ?? 0) + p.total;
    }
    return out;
  }

  /// Takes what a cooked recipe used out of stock: [uses] maps stock item ids
  /// to amounts. Each comes off as a "used" entry, so "runs out in" learns
  /// from cooking too.
  Future<void> cook(String recipeName, Map<String, double> uses) async {
    final now = _clock();
    var changed = false;
    uses.forEach((id, amount) {
      final index = _items.indexWhere((i) => i.id == id);
      if (index < 0 || amount <= 0) return;
      final current = _items[index];
      final next = (current.quantity - amount).clamp(0, double.infinity).toDouble();
      final applied = next - current.quantity;
      if (applied == 0) return;
      _items[index] = current.copyWith(quantity: next, updatedAt: now, updatedBy: _user);
      _log(current.name, 'used', delta: applied, unit: current.unit);
      changed = true;
    });
    if (!changed) return;
    _log(recipeName, 'cooked');
    await _commit();
  }

  // ---------------------------------------------------------------- recipes

  Future<SavedRecipe> addRecipe({
    required String name,
    required List<String> ingredients,
    String? url,
    String? printUrl,
    int? minutes,
    String method = '',
  }) async {
    final hasUrl = url != null && url.trim().isNotEmpty;
    final recipe = SavedRecipe(
      id: newId(),
      name: name.trim(),
      url: hasUrl ? url.trim() : null,
      printUrl: hasUrl && printUrl != null && printUrl.trim().isNotEmpty ? printUrl.trim() : null,
      minutes: (minutes == null || minutes <= 0) ? null : minutes,
      ingredients: _cleanIngredients(ingredients),
      method: method.trim(),
      addedBy: _user,
      createdAt: _clock(),
    );
    _recipes.add(recipe);
    _sortRecipes();
    _log(recipe.name, 'saved recipe');
    await _commit();
    return recipe;
  }

  Future<void> updateRecipe(SavedRecipe updated) async {
    final index = _recipes.indexWhere((r) => r.id == updated.id);
    if (index < 0) return;
    _recipes[index] = updated.copyWith(
      name: updated.name.trim(),
      ingredients: _cleanIngredients(updated.ingredients),
      method: updated.method.trim(),
    );
    _sortRecipes();
    await _commit();
  }

  Future<void> removeRecipe(String id) async {
    final existing = recipe(id);
    if (existing == null) return;
    _recipes.removeWhere((r) => r.id == id);
    _log(existing.name, 'removed recipe');
    await _commit();
  }

  void _sortRecipes() => _recipes.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// Trims, drops blanks and drops repeats (ignoring case and spacing).
  static List<String> _cleanIngredients(List<String> raw) {
    final seen = <String>{};
    final out = <String>[];
    for (final r in raw) {
      final t = cleanIngredientLine(r);
      if (!isIngredientLine(t) || !seen.add(nameKey(t))) continue;
      out.add(t);
    }
    return out;
  }

  // ----------------------------------------------------------------- import

  /// Adds rows from CSV text (name, location, quantity, unit, target).
  /// Unknown locations are created on the Storage page. Rows for an item
  /// that already exists in that location update it instead of doubling it.
  Future<CsvImportResult> importCsv(String text) async {
    final parsed = parseStockCsv(text);
    var added = 0;
    var updated = 0;
    final now = _clock();
    for (final row in parsed.rows) {
      var loc = _findLocationByName(row.location);
      if (loc == null) {
        loc = StockLocation(id: newId(), name: row.location, kind: LocationKind.storage);
        _locations.add(loc);
      }
      final index = _items.indexWhere((i) => i.locationId == loc!.id && i.name.toLowerCase() == row.name.toLowerCase());
      if (index >= 0) {
        _items[index] = _items[index].copyWith(
          quantity: row.quantity,
          unit: row.unit,
          target: row.target,
          updatedAt: now,
          updatedBy: _user,
        );
        updated++;
      } else {
        _items.add(
          StockItem(
            id: newId(),
            name: row.name,
            locationId: loc.id,
            quantity: row.quantity,
            unit: row.unit,
            target: row.target,
            updatedAt: now,
            updatedBy: _user,
          ),
        );
        added++;
      }
    }
    if (added + updated > 0) {
      _log('${added + updated} items', 'imported');
      await _commit();
    }
    return CsvImportResult(added: added, updated: updated, skipped: parsed.skipped);
  }

  /// The whole stock list as CSV, in the same shape [importCsv] reads.
  String exportCsv() {
    final buffer = StringBuffer('name,location,quantity,unit,target\n');
    final sorted = [..._items]
      ..sort((a, b) {
        final byLoc = (location(a.locationId)?.name ?? '').compareTo(location(b.locationId)?.name ?? '');
        return byLoc != 0 ? byLoc : a.name.compareTo(b.name);
      });
    for (final i in sorted) {
      buffer.writeln(
        [
          csvEscape(i.name),
          csvEscape(location(i.locationId)?.name ?? ''),
          formatQty(i.quantity),
          csvEscape(i.unit),
          formatQty(i.target),
        ].join(','),
      );
    }
    return buffer.toString();
  }
}

class CsvImportResult {
  const CsvImportResult({required this.added, required this.updated, required this.skipped});
  final int added;
  final int updated;
  final int skipped;
}
