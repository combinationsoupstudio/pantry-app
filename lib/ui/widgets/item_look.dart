import 'package:material_ui/material_ui.dart';

import '../../logic/names.dart';

/// What an item looks like when it has no photo: an icon for what it is, on
/// the colour of its family (greens for fresh food, wheat for bread, blue for
/// dairy). Replaces the plain first letter (v0.10).
@immutable
class ItemLook {
  const ItemLook(this.icon, this.family);
  final IconData icon;
  final LookFamily family;
}

enum LookFamily {
  produce(Color(0xFFDDE8C4), Color(0xFF3F5A1C), Color(0xFF34401F), Color(0xFFCFE0A6)),
  bakery(Color(0xFFF3E1C0), Color(0xFF8A5A17), Color(0xFF45351C), Color(0xFFF0CE8E)),
  dairy(Color(0xFFDDE7F0), Color(0xFF2F5878), Color(0xFF223443), Color(0xFFB7D0E6)),
  protein(Color(0xFFF6D9D2), Color(0xFF9A3A28), Color(0xFF4A2620), Color(0xFFF0B3A4)),
  grains(Color(0xFFF5E6BE), Color(0xFF85631A), Color(0xFF473A1A), Color(0xFFEBD38B)),
  tins(Color(0xFFF4DDD3), Color(0xFFA2432C), Color(0xFF4B2A21), Color(0xFFEDB7A3)),
  drinks(Color(0xFFD5EBE6), Color(0xFF1F6659), Color(0xFF1E3B35), Color(0xFFA3D5C9)),
  treats(Color(0xFFF2DCE4), Color(0xFF8A3A5C), Color(0xFF452634), Color(0xFFE7B2C6)),
  frozen(Color(0xFFDCEAF4), Color(0xFF2A6390), Color(0xFF1F3546), Color(0xFFB0D2EA)),
  medical(Color(0xFFF8DCD8), Color(0xFFB0372A), Color(0xFF4F2420), Color(0xFFF2AFA6)),
  hygiene(Color(0xFFE6DFF2), Color(0xFF5B4A8A), Color(0xFF332B45), Color(0xFFC9BBE7)),
  household(Color(0xFFE4E2DC), Color(0xFF55524A), Color(0xFF34322C), Color(0xFFCFCBC0)),
  other(Color(0xFFEDE3CF), Color(0xFF6B5A3C), Color(0xFF3A3326), Color(0xFFDCCBA6));

  const LookFamily(this.background, this.foreground, this.darkBackground, this.darkForeground);
  final Color background, foreground, darkBackground, darkForeground;

  Color bg(Brightness b) => b == Brightness.light ? background : darkBackground;
  Color fg(Brightness b) => b == Brightness.light ? foreground : darkForeground;
}

/// Words, most specific first. Each matches a whole word in the name, with or
/// without a plural "s" or "es" ("tin" matches "Tins: fish"; "can" does not
/// match "Canola oil").
const List<(List<String>, IconData, LookFamily)> _rules = [
  // Medical and hygiene first: "Hydralyte sachets" is not a drink.
  (['bandage', 'band-aid', 'bandaid', 'plaster', 'gauze', 'first aid', 'tape'], Icons.healing, LookFamily.medical),
  (
    ['panadol', 'paracetamol', 'nurofen', 'ibuprofen', 'tablet', 'pill', 'capsule', 'antihistamine', 'vitamin'],
    Icons.medication,
    LookFamily.medical,
  ),
  (
    ['hydralyte', 'electrolyte', 'syrup', 'drops', 'saline', 'antiseptic', 'betadine'],
    Icons.medication_liquid,
    LookFamily.medical,
  ),
  (['mask'], Icons.masks, LookFamily.medical),
  (['sanitiser', 'sanitizer'], Icons.sanitizer, LookFamily.hygiene),
  (['soap', 'body wash', 'shampoo', 'conditioner', 'toothpaste', 'deodorant'], Icons.soap, LookFamily.hygiene),
  (['toilet', 'tissue', 'paper towel', 'wipes'], Icons.clean_hands, LookFamily.hygiene),
  (['nappies', 'nappy', 'formula', 'baby'], Icons.child_care, LookFamily.hygiene),
  (['detergent', 'laundry', 'washing'], Icons.local_laundry_service, LookFamily.household),
  (['bleach', 'spray', 'cleaner', 'sponge', 'dishwash', 'bin bag'], Icons.cleaning_services, LookFamily.household),
  (['battery', 'batteries'], Icons.battery_full, LookFamily.household),
  (['torch', 'flashlight', 'headlamp'], Icons.flashlight_on, LookFamily.household),
  (['globe', 'bulb', 'lantern'], Icons.lightbulb, LookFamily.household),
  (['gas', 'butane', 'propane'], Icons.propane_tank, LookFamily.household),
  (['match', 'lighter', 'firelighter', 'candle'], Icons.local_fire_department, LookFamily.household),
  (['fuel', 'petrol', 'diesel', 'jerry'], Icons.oil_barrel, LookFamily.household),
  (['dog', 'cat food', 'pet', 'kibble'], Icons.pets, LookFamily.household),
  // Food.
  (['egg'], Icons.egg, LookFamily.dairy),
  (['milk', 'uht'], Icons.local_drink, LookFamily.dairy),
  (['cheese', 'butter', 'cream', 'yoghurt', 'yogurt', 'margarine'], Icons.breakfast_dining, LookFamily.dairy),
  (['ice cream', 'icecream', 'gelato'], Icons.icecream, LookFamily.frozen),
  (['frozen', 'peas', 'ice'], Icons.ac_unit, LookFamily.frozen),
  (['oat', 'cereal', 'weet-bix', 'weetbix', 'muesli', 'porridge'], Icons.breakfast_dining, LookFamily.grains),
  (
    ['bread', 'loaf', 'loaves', 'roll', 'wrap', 'bun', 'crumpet', 'muffin', 'bagel'],
    Icons.bakery_dining,
    LookFamily.bakery,
  ),
  (['flour', 'yeast', 'baking'], Icons.cake, LookFamily.bakery),
  (['biscuit', 'cookie', 'cracker', 'shapes', 'tim tam'], Icons.cookie, LookFamily.treats),
  (['chocolate', 'lollies', 'lolly', 'cake', 'sugar', 'honey', 'jam'], Icons.cake, LookFamily.treats),
  (['coffee'], Icons.coffee, LookFamily.drinks),
  (['tea'], Icons.emoji_food_beverage, LookFamily.drinks),
  (['wine'], Icons.wine_bar, LookFamily.drinks),
  (['beer'], Icons.sports_bar, LookFamily.drinks),
  (['water', 'cask'], Icons.water_drop, LookFamily.drinks),
  (['juice', 'cordial', 'soft drink', 'coke', 'lemonade', 'drink'], Icons.local_drink, LookFamily.drinks),
  (['tin', 'tinned', 'can', 'canned', 'baked beans'], Icons.inventory_2, LookFamily.tins),
  (['soup', 'stock'], Icons.soup_kitchen, LookFamily.tins),
  (['fish', 'tuna', 'salmon', 'sardine', 'prawn'], Icons.set_meal, LookFamily.protein),
  (
    ['chicken', 'beef', 'mince', 'lamb', 'pork', 'sausage', 'bacon', 'ham', 'steak', 'meat'],
    Icons.kebab_dining,
    LookFamily.protein,
  ),
  (['pasta', 'spaghetti', 'penne', 'lasagne', 'macaroni'], Icons.dinner_dining, LookFamily.grains),
  (['noodle', 'ramen'], Icons.ramen_dining, LookFamily.grains),
  (['rice'], Icons.rice_bowl, LookFamily.grains),
  (
    ['oil', 'vinegar', 'sauce', 'ketchup', 'mayo', 'mustard', 'soy', 'salt', 'pepper', 'spice', 'stock cube'],
    Icons.blender,
    LookFamily.grains,
  ),
  (
    [
      'potato',
      'veggie',
      'vegetable',
      'onion',
      'garlic',
      'carrot',
      'tomato',
      'lettuce',
      'broccoli',
      'pumpkin',
      'veg',
      'bean',
      'lentil',
      'chickpea',
    ],
    Icons.eco,
    LookFamily.produce,
  ),
  (['apple', 'banana', 'orange', 'lemon', 'fruit', 'berries', 'grape', 'pear', 'mango'], Icons.spa, LookFamily.produce),
  (['herb', 'basil', 'parsley', 'coriander', 'mint'], Icons.grass, LookFamily.produce),
];

/// Where it is kept, when the name says nothing.
const Map<String, (IconData, LookFamily)> _byLocation = {
  'medical': (Icons.medical_services, LookFamily.medical),
  'hygiene': (Icons.soap, LookFamily.hygiene),
  'garage': (Icons.handyman, LookFamily.household),
  'freezer': (Icons.ac_unit, LookFamily.frozen),
  'fridge': (Icons.kitchen, LookFamily.dairy),
};

ItemLook lookFor(String name, {String? locationId}) {
  final n = ' ${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\- ]'), ' ')} ';
  for (final (words, icon, family) in _rules) {
    for (final w in words) {
      if (n.contains(' $w ') || n.contains(' ${w}s ') || n.contains(' ${w}es ')) return ItemLook(icon, family);
    }
  }
  final byPlace = _byLocation[locationId];
  if (byPlace != null) return ItemLook(byPlace.$1, byPlace.$2);
  return const ItemLook(Icons.shopping_basket, LookFamily.other);
}

/// Drawn pictures of everyday pantry foods (assets/food/), each with the
/// names it is for, most specific first. Fresh fruit, vegetables and herbs
/// have their own, count-aware set (produce.dart), looked at first. Names
/// are compared folded (names.dart), word by word: "Tins: fish" is the tuna
/// tin.
const List<(String, List<String>)> _art = [
  ('tinned-tomatoes', ['tin tomato', 'tomato tin', 'diced tomato', 'crushed tomato', 'chopped tomato', 'passata']),
  ('baked-beans', ['baked bean']),
  ('tuna', ['tuna', 'tin fish', 'fish tin', 'sardine']),
  ('olive-oil', ['olive oil']),
  ('soy-sauce', ['soy sauce', 'tamari']),
  ('frozen-peas', ['frozen pea', 'pea']),
  ('mince', ['beef mince', 'pork mince', 'lamb mince', 'chicken mince', 'turkey mince', 'mince']),
  ('chicken', ['chicken']),
  ('eggs', ['egg']),
  ('bread', ['bread', 'loaf', 'toast', 'sandwich bread']),
  ('milk', ['milk', 'uht', 'full cream milk', 'skim milk']),
  ('cheese', ['cheese', 'cheddar', 'parmesan', 'mozzarella', 'feta']),
  ('butter', ['butter', 'margarine']),
  ('yoghurt', ['yoghurt']),
  ('rice', ['rice']),
  ('pasta', ['pasta', 'spaghetti', 'penne', 'macaroni', 'fettuccine', 'lasagne', 'fusilli']),
  ('flour', ['flour', 'plain flour', 'self raising flour', 'cornflour']),
  ('sugar', ['sugar', 'brown sugar', 'icing sugar', 'caster sugar', 'raw sugar']),
  ('oats', ['oat', 'rolled oat', 'porridge', 'muesli']),
  ('coffee', ['coffee']),
  ('tea', ['tea']),
  ('honey', ['honey']),
];

/// The drawn picture for [name] (an asset path), or null. A name of its own
/// that only shares a word ("coconut milk", "peanut butter", "chicken
/// stock", "sweet potato") gets none rather than the wrong one.
String? artFor(String name) {
  final n = ' ${canonicalName(name)} ';
  if (n.trim().isEmpty) return null;
  for (final (art, phrases) in _art) {
    for (final p in phrases) {
      if (!n.contains(' $p ')) continue;
      final clash = ownThings.any((t) => n.contains(' $t ') && !phrases.contains(t));
      if (clash) break;
      return 'assets/food/$art.png';
    }
  }
  return null;
}
