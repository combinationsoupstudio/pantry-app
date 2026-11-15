/// Core data types for the household. Plain Dart, no Flutter imports,
/// so they can be tested and later shared with the sync layer.
library;

/// Where a location shows up in the app.
enum LocationKind {
  /// Everyday food: shown on the Pantry page.
  pantry,

  /// Bulk, backup and non-food stock: shown on the Storage page.
  storage,
}

/// The shops a shopping item can be assigned to.
enum Store {
  any('Any shop'),
  woolworths('Woolworths'),
  coles('Coles'),
  aldi('Aldi'),
  iga('IGA');

  const Store(this.label);
  final String label;
}

String newId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  final salt = (now ^ _counter++).toRadixString(36);
  return '${now.toRadixString(36)}$salt';
}

int _counter = 0;

class StockLocation {
  const StockLocation({required this.id, required this.name, required this.kind});

  final String id;
  final String name;
  final LocationKind kind;

  StockLocation copyWith({String? name, LocationKind? kind}) =>
      StockLocation(id: id, name: name ?? this.name, kind: kind ?? this.kind);

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'kind': kind.name};

  factory StockLocation.fromJson(Map<String, Object?> json) => StockLocation(
    id: json['id']! as String,
    name: json['name']! as String,
    kind: LocationKind.values.byName(json['kind']! as String),
  );
}

class StockItem {
  const StockItem({
    required this.id,
    required this.name,
    required this.locationId,
    required this.quantity,
    required this.unit,
    required this.target,
    required this.updatedAt,
    required this.updatedBy,
    this.useBy,
    this.notes = '',
  });

  final String id;
  final String name;
  final String locationId;

  /// How many we have now.
  final double quantity;
  final String unit;

  /// How many we want to have at least. 0 means "no target".
  final double target;
  final DateTime? useBy;
  final String notes;
  final DateTime updatedAt;
  final String updatedBy;

  bool get hasTarget => target > 0;
  bool get isLow => hasTarget && quantity < target;
  bool get isOut => quantity <= 0;

  /// 0..1, how close we are to the target (1 when there is no target).
  double get fill => hasTarget ? (quantity / target).clamp(0, 1).toDouble() : 1;

  /// How many to buy to get back to target.
  double get shortfall => isLow ? target - quantity : 0;

  StockItem copyWith({
    String? name,
    String? locationId,
    double? quantity,
    String? unit,
    double? target,
    DateTime? useBy,
    bool clearUseBy = false,
    String? notes,
    DateTime? updatedAt,
    String? updatedBy,
  }) => StockItem(
    id: id,
    name: name ?? this.name,
    locationId: locationId ?? this.locationId,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    target: target ?? this.target,
    useBy: clearUseBy ? null : (useBy ?? this.useBy),
    notes: notes ?? this.notes,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedBy: updatedBy ?? this.updatedBy,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'locationId': locationId,
    'quantity': quantity,
    'unit': unit,
    'target': target,
    'useBy': useBy?.toIso8601String(),
    'notes': notes,
    'updatedAt': updatedAt.toIso8601String(),
    'updatedBy': updatedBy,
  };

  factory StockItem.fromJson(Map<String, Object?> json) => StockItem(
    id: json['id']! as String,
    name: json['name']! as String,
    locationId: json['locationId']! as String,
    quantity: (json['quantity']! as num).toDouble(),
    unit: json['unit'] as String? ?? '',
    target: (json['target'] as num? ?? 0).toDouble(),
    useBy: json['useBy'] == null ? null : DateTime.parse(json['useBy']! as String),
    notes: json['notes'] as String? ?? '',
    updatedAt: DateTime.parse(json['updatedAt']! as String),
    updatedBy: json['updatedBy'] as String? ?? '',
  );
}

class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.store,
    required this.addedBy,
    this.stockItemId,
    this.bought = false,
  });

  final String id;
  final String name;
  final double quantity;
  final String unit;
  final Store store;
  final String addedBy;

  /// The stock item this tops up, if any. Putting it away adds to that item.
  final String? stockItemId;
  final bool bought;

  ShoppingItem copyWith({double? quantity, String? unit, Store? store, String? stockItemId, bool? bought}) =>
      ShoppingItem(
        id: id,
        name: name,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        store: store ?? this.store,
        addedBy: addedBy,
        stockItemId: stockItemId ?? this.stockItemId,
        bought: bought ?? this.bought,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'store': store.name,
    'addedBy': addedBy,
    'stockItemId': stockItemId,
    'bought': bought,
  };

  factory ShoppingItem.fromJson(Map<String, Object?> json) => ShoppingItem(
    id: json['id']! as String,
    name: json['name']! as String,
    quantity: (json['quantity']! as num).toDouble(),
    unit: json['unit'] as String? ?? '',
    store: Store.values.byName(json['store'] as String? ?? 'any'),
    addedBy: json['addedBy'] as String? ?? '',
    stockItemId: json['stockItemId'] as String?,
    bought: json['bought'] as bool? ?? false,
  );
}

/// One line in the household's history: who changed what, and by how much.
class ActivityEntry {
  const ActivityEntry({
    required this.at,
    required this.who,
    required this.itemName,
    required this.action,
    this.delta = 0,
    this.unit = '',
  });

  final DateTime at;
  final String who;
  final String itemName;

  /// Short verb: added, used, topped up, moved, edited, removed, bought.
  final String action;
  final double delta;
  final String unit;

  Map<String, Object?> toJson() => {
    'at': at.toIso8601String(),
    'who': who,
    'itemName': itemName,
    'action': action,
    'delta': delta,
    'unit': unit,
  };

  factory ActivityEntry.fromJson(Map<String, Object?> json) => ActivityEntry(
    at: DateTime.parse(json['at']! as String),
    who: json['who'] as String? ?? '',
    itemName: json['itemName'] as String? ?? '',
    action: json['action'] as String? ?? '',
    delta: (json['delta'] as num? ?? 0).toDouble(),
    unit: json['unit'] as String? ?? '',
  );
}

/// The form two names are compared in: "  Tinned  Tomatoes" and "tinned tomatoes" match.
String nameKey(String name) => name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Formats a quantity without a trailing ".0" (2.0 -> "2", 1.5 -> "1.5").
String formatQty(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

/// A recipe the household saved: a link to someone's page (whose method
/// stays there), or one of their own. Only ingredient names are kept for a
/// linked recipe, to match against stock.
class SavedRecipe {
  const SavedRecipe({
    required this.id,
    required this.name,
    required this.ingredients,
    required this.addedBy,
    required this.createdAt,
    this.url,
    this.minutes,
    this.method = '',
  });

  final String id;
  final String name;

  /// Where the recipe lives, for a linked recipe. Null for the household's own.
  final String? url;
  final int? minutes;

  /// Ingredient names, one each, as they are matched to stock.
  final List<String> ingredients;

  /// The household's own method (own recipes) or notes (linked ones).
  final String method;
  final String addedBy;
  final DateTime createdAt;

  bool get isLinked => url != null && url!.isNotEmpty;

  /// The site's name for display, e.g. "recipetineats.com".
  String? get siteName {
    if (!isLinked) return null;
    final host = Uri.tryParse(url!)?.host ?? '';
    return host.startsWith('www.') ? host.substring(4) : (host.isEmpty ? null : host);
  }

  SavedRecipe copyWith({
    String? name,
    String? url,
    bool clearUrl = false,
    int? minutes,
    bool clearMinutes = false,
    List<String>? ingredients,
    String? method,
  }) => SavedRecipe(
    id: id,
    name: name ?? this.name,
    url: clearUrl ? null : (url ?? this.url),
    minutes: clearMinutes ? null : (minutes ?? this.minutes),
    ingredients: ingredients ?? this.ingredients,
    method: method ?? this.method,
    addedBy: addedBy,
    createdAt: createdAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'minutes': minutes,
    'ingredients': ingredients,
    'method': method,
    'addedBy': addedBy,
    'createdAt': createdAt.toIso8601String(),
  };

  factory SavedRecipe.fromJson(Map<String, Object?> json) => SavedRecipe(
    id: json['id']! as String,
    name: json['name']! as String,
    url: json['url'] as String?,
    minutes: (json['minutes'] as num?)?.toInt(),
    ingredients: (json['ingredients'] as List? ?? []).cast<String>(),
    method: json['method'] as String? ?? '',
    addedBy: json['addedBy'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt']! as String),
  );
}
