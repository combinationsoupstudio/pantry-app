import 'package:flutter/foundation.dart';

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
  String _user = householdMembers.first;
  bool _loaded = false;

  List<StockLocation> get locations => List.unmodifiable(_locations);
  List<StockItem> get items => List.unmodifiable(_items);
  List<ShoppingItem> get shopping => List.unmodifiable(_shopping);

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
    if (data != null) {
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
      final savedUser = data['user'] as String?;
      if (savedUser != null && householdMembers.contains(savedUser)) _user = savedUser;
    }
    _loaded = true;
    notifyListeners();
  }

  Map<String, Object?> toJson() => {
    'schema': 1,
    'user': _user,
    'locations': _locations.map((l) => l.toJson()).toList(),
    'items': _items.map((i) => i.toJson()).toList(),
    'shopping': _shopping.map((s) => s.toJson()).toList(),
    'activity': _activity.map((a) => a.toJson()).toList(),
  };

  Future<void> _commit() async {
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

  Future<void> addShopping({
    required String name,
    double quantity = 1,
    String unit = '',
    Store store = Store.any,
    String? stockItemId,
  }) async {
    _shopping.add(
      ShoppingItem(
        id: newId(),
        name: name.trim(),
        quantity: quantity <= 0 ? 1 : quantity,
        unit: unit.trim(),
        store: store,
        addedBy: _user,
        stockItemId: stockItemId,
      ),
    );
    await _commit();
  }

  /// Puts everything that is under target on the list, for the amount
  /// needed to get back to target. Skips items already on the list.
  /// Returns how many were added.
  Future<int> addRunningLowToShopping() async {
    final onList = _shopping.map((s) => s.stockItemId).whereType<String>().toSet();
    var added = 0;
    for (final low in runningLow) {
      if (onList.contains(low.id)) continue;
      _shopping.add(
        ShoppingItem(
          id: newId(),
          name: low.name,
          quantity: low.shortfall,
          unit: low.unit,
          store: Store.any,
          addedBy: _user,
          stockItemId: low.id,
        ),
      );
      added++;
    }
    if (added > 0) await _commit();
    return added;
  }

  Future<void> setBought(String shoppingId, bool bought) async {
    final index = _shopping.indexWhere((s) => s.id == shoppingId);
    if (index < 0) return;
    _shopping[index] = _shopping[index].copyWith(bought: bought);
    await _commit();
  }

  Future<void> setStore(String shoppingId, Store store) async {
    final index = _shopping.indexWhere((s) => s.id == shoppingId);
    if (index < 0) return;
    _shopping[index] = _shopping[index].copyWith(store: store);
    await _commit();
  }

  Future<void> removeShopping(String shoppingId) async {
    _shopping.removeWhere((s) => s.id == shoppingId);
    await _commit();
  }

  /// Everything ticked as bought goes into stock (when it is linked to a
  /// stock item) and leaves the list. Returns how many were put away.
  Future<int> putAwayBought() async {
    final bought = _shopping.where((s) => s.bought).toList();
    if (bought.isEmpty) return 0;
    final now = _clock();
    for (final s in bought) {
      final index = s.stockItemId == null ? -1 : _items.indexWhere((i) => i.id == s.stockItemId);
      if (index >= 0) {
        final current = _items[index];
        _items[index] = current.copyWith(quantity: current.quantity + s.quantity, updatedAt: now, updatedBy: _user);
        _log(current.name, 'bought', delta: s.quantity, unit: current.unit);
      } else {
        _log(s.name, 'bought', delta: s.quantity, unit: s.unit);
      }
    }
    _shopping.removeWhere((s) => s.bought);
    await _commit();
    return bought.length;
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
