import 'names.dart';

/// How a scanned product is kept track of (v0.13), so the add page opens
/// set up right: counted ("2 jars") or measured ("300 g left of a 500 g
/// bag"). Chris, 17 Nov 2026: "the add item suggested layout for each product
/// wasn't always right ... it will confuse people." Until now any pack size
/// from Open Food Facts made it measured, so a 500 g jar of jam asked for
/// grams. Now it is measured only when it is used bit by bit; everything else
/// is counted in what it comes in. The household's choice for a barcode is
/// kept in the product library and wins next time.
class KeepAs {
  const KeepAs.count(this.countUnit) : measured = false;
  const KeepAs.measure() : measured = true, countUnit = '';

  final bool measured;

  /// What it is counted in: jars, cans, bottles, packs, boxes, rolls or items.
  final String countUnit;

  @override
  String toString() => measured ? 'measure' : 'count $countUnit';
}

/// Things used a bit at a time: worth measuring what is left.
const _bitByBit = [
  'oil',
  'vinegar',
  'sauce',
  'soy sauce',
  'milk',
  'cream',
  'flour',
  'cornflour',
  'sugar',
  'rice',
  'oat',
  'honey',
  'syrup',
  'salt',
  'pepper',
  'spice',
  'paprika',
  'cumin',
  'cinnamon',
  'coffee',
  'cocoa',
  'cereal',
  'muesli',
  'pasta',
  'spaghetti',
  'lentil',
  'stock powder',
  'gravy',
  'custard powder',
  'baking powder',
  'bicarb soda',
  'yeast',
  'detergent',
  'laundry liquid',
  'laundry powder',
  'dishwashing liquid',
  'shampoo',
  'conditioner',
  'body wash',
  'juice',
  'cordial',
  'water',
  'peanut butter',
  'vegemite',
  'mayonnaise',
  'mayo',
  'mustard',
  'tomato sauce',
  'ketchup',
  'bbq sauce',
  'flake',
  'pet food',
  'dog food',
  'cat food',
  'kibble',
];

/// What it comes in, by the words in its name, first match wins.
const _comesIn = [
  (['tin', 'baked bean', 'tuna', 'sardine', 'soup', 'coconut milk', 'corned beef', 'spam'], 'cans'),
  (['jam', 'spread', 'pickle', 'relish', 'paste', 'pesto', 'olive', 'jar', 'passata', 'salsa', 'chutney'], 'jars'),
  (['soft drink', 'beer', 'wine', 'bottle', 'drink'], 'bottles'),
  (['toilet paper', 'paper towel', 'foil', 'cling wrap', 'roll'], 'rolls'),
  (['cereal', 'tissue', 'box', 'matches', 'teabag', 'tea bag', 'dishwasher tablet'], 'boxes'),
  (['packet', 'pack', 'noodle', 'biscuit', 'chip', 'cracker', 'bar', 'battery', 'nappy', 'wipe', 'mix'], 'packs'),
];

bool _has(String folded, String phrase) => folded.contains(' ${canonicalName(phrase)} ');

/// The best guess for a product called [name] that comes in [packSize]
/// [unit] packs (0 and '' when not known).
KeepAs guessKeepAs(String name, {double packSize = 0, String unit = ''}) {
  final n = ' ${canonicalName(name)} ';
  // Its own kind of thing first ("coconut milk" is a tin, not milk to measure).
  for (final (words, comes) in _comesIn) {
    for (final w in words) {
      if (!_has(n, w)) continue;
      final ownThing = ownThings.any((t) => _has(n, t) && canonicalName(t).contains(canonicalName(w)));
      if (ownThing || !_bitByBit.any((b) => _has(n, b))) return KeepAs.count(comes);
    }
  }
  if (_bitByBit.any((b) => _has(n, b)) && packSize > 0) return const KeepAs.measure();
  return const KeepAs.count('items');
}
