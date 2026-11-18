/// Core data types for the household. Plain Dart, no Flutter imports,
/// so they can be tested and later shared with the sync layer.
library;

import '../logic/names.dart';

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
    this.packSize = 0,
    this.barcode,
    this.photoPath,
    this.imageUrl,
    this.pictureByName = false,
    this.pictureTried = false,
    this.aliases = const [],
    this.notAliases = const [],
    this.photoId,
  });

  final String id;
  final String name;
  final String locationId;

  /// The household's own photo of it (v0.13): the SHA-256 of a small JPEG
  /// kept on the household server, so it shows on every phone (photo_store.dart).
  final String? photoId;

  /// Other names the household calls this ("spring onions" for Shallots),
  /// added by hand or by answering "Is this your …?" (v0.11).
  final List<String> aliases;

  /// Names someone said are NOT this item, so it is never guessed again.
  final List<String> notAliases;

  /// For a measured item (kept in g, kg, ml or L): how much one pack holds,
  /// in [unit], e.g. 500 for a 500 ml bottle. 0 for an item that is counted.
  /// A measured item's [quantity] and [target] are amounts in [unit], so a
  /// 500 ml bottle with about 300 ml left has quantity 300.
  final double packSize;

  /// The product barcode (EAN/UPC), when it was scanned.
  final String? barcode;

  /// A photo of the item, kept in the app's own folder on the phone.
  final String? photoPath;

  /// A product picture from Open Food Facts (small, 200 px), found by
  /// barcode or picked from a name search. Downloaded once and kept on the
  /// phone. The household's own [photoPath] always shows first.
  final String? imageUrl;

  /// The picture was found by matching the item's name, not picked or
  /// scanned: the editor asks for it to be checked.
  final bool pictureByName;

  /// A name search found nothing it could trust; not searched again until the
  /// name changes or "Find pictures again" is pressed.
  final bool pictureTried;

  /// True when this item still wants a picture looked up for it.
  bool get wantsPicture => photoPath == null && imageUrl == null && !pictureTried;

  /// How many to draw in a picture pile: whole items for a counted item
  /// (2 potatoes, 4 tins), whole packs for a measured one. Something counted
  /// by weight or volume without a pack size ("3 kg" of pasta) is one
  /// picture: 3 kg is not three packs, and the pile never claims it is.
  int get pileCount {
    if (quantity <= 0) return 0;
    if (isMeasured) return (quantity / packSize - 1e-9).ceil();
    if (const {'g', 'kg', 'ml', 'l'}.contains(unit.trim().toLowerCase())) return 1;
    return quantity < 1 ? 1 : quantity.round();
  }

  /// [pileCount] for [amount] of this item in its [shoppingUnit] (a list line).
  int pileFor(double amount) {
    if (amount <= 0) return 0;
    if (!isMeasured && const {'g', 'kg', 'ml', 'l'}.contains(unit.trim().toLowerCase())) return 1;
    return amount < 1 ? 1 : amount.round();
  }

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

  /// True when this item is measured out of packs (ml, g ...) rather than counted.
  bool get isMeasured => packSize > 0 && const {'g', 'kg', 'ml', 'l'}.contains(unit.trim().toLowerCase());

  /// Kept by weight or volume with no pack size (2 kg of loose potatoes): a
  /// produce drawing shows the heap, not one.
  bool get byWeight => !isMeasured && const {'g', 'kg', 'ml', 'l'}.contains(unit.trim().toLowerCase());

  /// "500 ml" for a measured item; '' otherwise.
  String get packLabel => isMeasured ? '${formatQty(packSize)} ${_displayUnit(unit)}' : '';

  /// What this item is bought in: "× 500 ml" (packs) for a measured item,
  /// its own unit otherwise.
  String get shoppingUnit => isMeasured ? '× $packLabel' : unit;

  /// Whole packs needed to cover [amount] (in [unit]); [amount] itself for a
  /// counted item.
  double packsFor(double amount) {
    if (amount <= 0) return 0;
    if (!isMeasured) return amount;
    return (amount / packSize - 1e-9).ceilToDouble();
  }

  /// How many to put on the list to get back to target, in [shoppingUnit].
  double get restock => packsFor(shortfall);
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
    double? packSize,
    String? barcode,
    bool clearBarcode = false,
    String? photoPath,
    bool clearPhoto = false,
    String? imageUrl,
    bool clearImage = false,
    bool? pictureByName,
    bool? pictureTried,
    List<String>? aliases,
    List<String>? notAliases,
    String? photoId,
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
    packSize: packSize ?? this.packSize,
    barcode: clearBarcode ? null : (barcode ?? this.barcode),
    photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    imageUrl: clearImage ? null : (imageUrl ?? this.imageUrl),
    pictureByName: pictureByName ?? this.pictureByName,
    pictureTried: pictureTried ?? this.pictureTried,
    aliases: aliases ?? this.aliases,
    notAliases: notAliases ?? this.notAliases,
    photoId: clearPhoto ? null : (photoId ?? this.photoId),
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
    if (packSize > 0) 'packSize': packSize,
    if (barcode != null) 'barcode': barcode,
    if (photoPath != null) 'photoPath': photoPath,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (pictureByName) 'pictureByName': true,
    if (pictureTried) 'pictureTried': true,
    if (aliases.isNotEmpty) 'aliases': aliases,
    if (notAliases.isNotEmpty) 'notAliases': notAliases,
    if (photoId != null) 'photoId': photoId,
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
    packSize: (json['packSize'] as num? ?? 0).toDouble(),
    barcode: json['barcode'] as String?,
    photoPath: json['photoPath'] as String?,
    imageUrl: json['imageUrl'] as String?,
    pictureByName: json['pictureByName'] == true,
    pictureTried: json['pictureTried'] == true,
    aliases: [for (final a in (json['aliases'] as List? ?? const [])) a as String],
    notAliases: [for (final a in (json['notAliases'] as List? ?? const [])) a as String],
    photoId: json['photoId'] as String?,
  );
}

String _displayUnit(String unit) => unit.trim().toLowerCase() == 'l' ? 'L' : unit.trim();

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
/// Two names are the same thing when their keys are equal: case, plurals,
/// punctuation and names that mean the same are folded (names.dart).
String nameKey(String name) => canonicalName(name);

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
    this.printUrl,
    this.minutes,
    this.method = '',
  });

  final String id;
  final String name;

  /// The site's print view of just the recipe card, when it has one.
  final String? printUrl;

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

  /// What "Open recipe" opens: the recipe card on its own where the site has
  /// a print view, so there is no article to scroll past. RecipeTin Eats
  /// links saved before print views were recorded get theirs worked out.
  String? get openUrl {
    if (!isLinked) return null;
    if (printUrl != null && printUrl!.isNotEmpty) return printUrl;
    final uri = Uri.tryParse(url!);
    if (uri != null && uri.host.endsWith('recipetineats.com')) {
      final slug = uri.pathSegments.where((p) => p.isNotEmpty).lastOrNull;
      if (slug != null && slug != 'wprm_print') return 'https://www.recipetineats.com/wprm_print/$slug';
    }
    return url;
  }

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
    String? printUrl,
    int? minutes,
    bool clearMinutes = false,
    List<String>? ingredients,
    String? method,
  }) => SavedRecipe(
    id: id,
    name: name ?? this.name,
    url: clearUrl ? null : (url ?? this.url),
    printUrl: clearUrl ? null : (printUrl ?? this.printUrl),
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
    'printUrl': printUrl,
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
    printUrl: json['printUrl'] as String?,
    minutes: (json['minutes'] as num?)?.toInt(),
    ingredients: (json['ingredients'] as List? ?? []).cast<String>(),
    method: json['method'] as String? ?? '',
    addedBy: json['addedBy'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt']! as String),
  );
}

/// What was paid for something, recorded when a shop is put away.
class PricePoint {
  const PricePoint({
    required this.id,
    required this.name,
    required this.store,
    required this.total,
    required this.quantity,
    required this.unit,
    required this.at,
    required this.by,
    this.stockItemId,
  });

  final String id;
  final String name;
  final String? stockItemId;
  final Store store;

  /// Dollars paid for [quantity] [unit].
  final double total;
  final double quantity;
  final String unit;
  final DateTime at;
  final String by;

  /// Dollars per one [unit] (or per item).
  double get unitPrice => quantity > 0 ? total / quantity : total;

  /// "each", "kg", or "500 ml" for a pack of a measured item ("× 500 ml").
  String get perLabel => unit.isEmpty ? 'each' : (unit.startsWith('× ') ? unit.substring(2) : unit);

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'stockItemId': stockItemId,
    'store': store.name,
    'total': total,
    'quantity': quantity,
    'unit': unit,
    'at': at.toIso8601String(),
    'by': by,
  };

  factory PricePoint.fromJson(Map<String, Object?> json) => PricePoint(
    id: json['id']! as String,
    name: json['name']! as String,
    stockItemId: json['stockItemId'] as String?,
    store: Store.values.byName(json['store'] as String? ?? 'any'),
    total: (json['total']! as num).toDouble(),
    quantity: (json['quantity'] as num? ?? 1).toDouble(),
    unit: json['unit'] as String? ?? '',
    at: DateTime.parse(json['at']! as String),
    by: json['by'] as String? ?? '',
  );
}

/// "$4.50"
String formatMoney(double dollars) => '\$${dollars.toStringAsFixed(2)}';
