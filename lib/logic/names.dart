import '../models/models.dart';

/// Matching what people type to what the household keeps (v0.11).
///
/// Chris, 16 Nov 2026: "We can't have a customer relying on their spelling to
/// be a 1:1 match to our inventory list of foods." No spelling checker is
/// right every time, so the app never guesses silently:
///
///  1. **Sure**: the same words once case, plurals, punctuation and the
///     names that mean the same thing are folded ("Shallots" = "spring
///     onions" = "scallions"), or a name the household taught it (an item's
///     [StockItem.aliases]). Used straight away.
///  2. **Close**: one or two letters out ("spring onoins"). Never counted
///     until someone answers "Is this your Spring onions?"; yes becomes an
///     alias, no a [StockItem.notAliases], on both phones.
///  3. **None**: a new thing.

/// Names that mean the same thing, in their singular form; the first of each
/// group is the one they all become. Australian names first.
const List<List<String>> sameThings = [
  // Fresh food. In NSW "shallots" are spring onions; the small brown bulbs
  // are eschalots (french shallots).
  ['eschalot', 'french shallot', 'eschallot'],
  ['spring onion', 'shallot', 'scallion', 'green onion'],
  ['capsicum', 'bell pepper', 'sweet pepper'],
  ['coriander', 'cilantro'],
  ['zucchini', 'courgette'],
  ['eggplant', 'aubergine'],
  ['rocket', 'arugula'],
  ['snow pea', 'mangetout'],
  ['beetroot', 'beet'],
  ['silverbeet', 'swiss chard', 'chard'],
  ['rockmelon', 'cantaloupe'],
  ['chickpea', 'garbanzo bean', 'garbanzo'],
  ['broad bean', 'fava bean'],
  ['chilli', 'chili', 'chile'],
  ['prawn', 'shrimp'],
  ['beef mince', 'ground beef', 'minced beef', 'mince beef'],
  ['sausage', 'snag', 'banger'],
  // Dairy.
  ['yoghurt', 'yogurt'],
  ['thickened cream', 'heavy cream', 'whipping cream'],
  ['full cream milk', 'whole milk'],
  ['skim milk', 'skimmed milk'],
  ['parmesan', 'parmigiano reggiano', 'parmigiano'],
  ['cheddar', 'tasty cheese'],
  // Pantry.
  ['cornflour', 'cornstarch', 'corn starch', 'corn flour'],
  ['bicarb soda', 'bicarbonate of soda', 'baking soda', 'sodium bicarbonate', 'bicarb'],
  ['plain flour', 'all purpose flour'],
  ['self raising flour', 'self rising flour'],
  ['icing sugar', 'powdered sugar', 'confectioners sugar'],
  ['caster sugar', 'castor sugar', 'superfine sugar'],
  ['tomato sauce', 'ketchup'],
  ['biscuit', 'cookie'],
  ['lolly', 'candy', 'lollie'],
  ['soft drink', 'fizzy drink', 'soda'],
  ['coke', 'coca cola', 'cola'],
  ['weetbix', 'weet bix'],
  ['muesli bar', 'granola bar', 'cereal bar'],
  // Household.
  ['dishwashing liquid', 'dish soap', 'washing up liquid', 'dishwashing detergent', 'dish liquid'],
  ['dishwasher tablet', 'dishwasher pod', 'dishwashing tablet'],
  ['laundry liquid', 'washing liquid'],
  ['laundry powder', 'washing powder'],
  ['paper towel', 'kitchen towel', 'kitchen paper'],
  ['cling wrap', 'glad wrap', 'plastic wrap', 'cling film'],
  ['foil', 'alfoil', 'aluminium foil', 'aluminum foil', 'tin foil'],
  ['toilet paper', 'toilet roll', 'loo roll', 'dunny roll'],
  ['tissue', 'kleenex', 'facial tissue'],
  ['nappy', 'diaper'],
  ['torch', 'flashlight'],
  ['jerry can', 'jerrycan'],
  // Medical.
  ['paracetamol', 'panadol', 'acetaminophen', 'tylenol'],
  ['ibuprofen', 'nurofen', 'advil'],
  ['bandaid', 'band aid', 'plaster', 'adhesive bandage'],
  ['electrolyte', 'hydralyte'],
];

/// Single words that are the same thing ("canned" and "tinned" are a tin).
const Map<String, String> _sameWord = {'canned': 'tin', 'tinned': 'tin', 'can': 'tin', 'and': ''};

const Map<String, String> _irregular = {
  'loaves': 'loaf',
  'halves': 'half',
  'leaves': 'leaf',
  'knives': 'knife',
  'lollies': 'lolly',
  'mice': 'mouse',
  'teeth': 'tooth',
  'children': 'child',
};

/// One word in its singular form: onions -> onion, potatoes -> potato,
/// berries -> berry, loaves -> loaf, boxes -> box. Short words are left.
String singular(String w) {
  final irregular = _irregular[w];
  if (irregular != null) return irregular;
  if (w.length <= 3) return w;
  if (w.endsWith('ies') && w.length > 4) return '${w.substring(0, w.length - 3)}y';
  if (w.endsWith('oes')) return w.substring(0, w.length - 2);
  for (final end in const ['ches', 'shes', 'sses', 'xes', 'zes']) {
    if (w.endsWith(end)) return w.substring(0, w.length - 2);
  }
  if (w.endsWith('s') && !w.endsWith('ss') && !w.endsWith('us') && !w.endsWith('is')) {
    return w.substring(0, w.length - 1);
  }
  return w;
}

/// Longest names first, so "french shallot" folds before "shallot".
final List<(String, String)> _phrases = () {
  final all = <(String, String)>[
    for (final group in sameThings)
      for (final variant in group.skip(1)) (variant, group.first),
  ];
  all.sort((a, b) => b.$1.length.compareTo(a.$1.length));
  return all;
}();

final Map<String, String> _canonicalCache = {};

/// A name as the app compares it: lower case, letters and digits only, each
/// word singular, and names that mean the same folded into one.
/// "Spring Onions!" and "shallots" both become "spring onion".
String canonicalName(String name) {
  final hit = _canonicalCache[name];
  if (hit != null) return hit;
  final words = name
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r"['’]"), '')
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .map(singular)
      .map((w) => _sameWord[w] ?? w)
      .where((w) => w.isNotEmpty);
  var t = ' ${words.join(' ')} ';
  for (final (from, to) in _phrases) {
    if (t.contains(' $from ')) t = t.replaceAll(' $from ', ' $to ');
  }
  final out = t.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (_canonicalCache.length > 5000) _canonicalCache.clear();
  return _canonicalCache[name] = out;
}

/// Letters to change, add, drop or swap to turn [a] into [b] (optimal
/// string alignment), stopping early past [limit].
int editDistance(String a, String b, {int limit = 3}) {
  if ((a.length - b.length).abs() > limit) return limit + 1;
  final d = List.generate(a.length + 1, (i) => List<int>.filled(b.length + 1, 0));
  for (var i = 0; i <= a.length; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= b.length; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= a.length; i++) {
    var rowMin = limit + 1;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var v = [d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost].reduce((x, y) => x < y ? x : y);
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        v = v < d[i - 2][j - 2] + 1 ? v : d[i - 2][j - 2] + 1;
      }
      d[i][j] = v;
      if (v < rowMin) rowMin = v;
    }
    if (rowMin > limit) return limit + 1;
  }
  return d[a.length][b.length];
}

/// How many letters a word may be out and still be "close": none for short
/// words (rice and mice are different things), one up to six letters, two
/// for longer words.
int _allowed(String a, String b) {
  final n = a.length < b.length ? a.length : b.length;
  if (n <= 3) return 0;
  if (n <= 6) return 1;
  return 2;
}

/// How well two words agree: 0 the same, a positive number of letters out
/// when close, null when different.
int? _wordGap(String a, String b) {
  if (a == b) return 0;
  final allowed = _allowed(a, b);
  if (allowed == 0) return null;
  final d = editDistance(a, b, limit: allowed);
  return d <= allowed ? d : null;
}

/// How [small]'s words sit inside [big]'s: the letters out in total, or null
/// when one of them is not there at all.
int? _within(List<String> small, List<String> big) {
  var total = 0;
  for (final w in small) {
    int? best;
    for (final b in big) {
      final g = _wordGap(w, b);
      if (g != null && (best == null || g < best)) best = g;
    }
    if (best == null) return null;
    total += best;
  }
  return total;
}

/// What a name was matched to, and how sure the app is.
class NameMatch {
  const NameMatch(this.item, {required this.sure, required this.rank, this.matchedName = ''});
  final StockItem item;

  /// False when the name was only close: the app asks before using it.
  final bool sure;

  /// Lower is better: 0 the same name, 1 a name the household taught it,
  /// 2 one name inside the other, 3+ close.
  final int rank;

  /// The item's name or alias that matched.
  final String matchedName;

  @override
  String toString() => 'NameMatch(${item.name}, sure: $sure, rank: $rank)';
}

/// Words that do not change what a thing is: "garlic cloves" is garlic,
/// "fresh coriander" is coriander. Any other extra word might ("coconut
/// milk" is not milk, "chicken stock" is not chicken), so the app asks.
const Set<String> neutralWords = {
  // How it comes.
  'clove', 'fillet', 'piece', 'slice', 'sprig', 'stalk', 'stick', 'bunch', 'head', 'tin', 'bottle', 'pack',
  'packet', 'jar', 'bag', 'box', 'carton', 'punnet', 'loaf', 'block', 'bulb', 'sachet', 'roll',
  // How big or fresh.
  'fresh', 'large', 'small', 'medium', 'big', 'ripe', 'organic', 'free', 'range', 'whole', 'raw', 'loose',
  'washed', 'unwashed', 'extra', 'family', 'value', 'brand', 'home',
};

/// Two-word names that are their own thing, not a kind of their last word:
/// coconut milk is not milk, spring onions are not onions.
const Set<String> ownThings = {
  'spring onion',
  'sweet potato',
  'coconut milk',
  'almond milk',
  'soy milk',
  'oat milk',
  'rice milk',
  'coconut cream',
  'sour cream',
  'ice cream',
  'cream cheese',
  'cottage cheese',
  'peanut butter',
  'chicken stock',
  'beef stock',
  'vegetable stock',
  'fish sauce',
  'soy sauce',
  'tomato sauce',
  'oyster sauce',
  'bbq sauce',
  'hot sauce',
  'chilli sauce',
  'sweet chilli sauce',
  'worcestershire sauce',
  'rice vinegar',
  'sesame oil',
  'coconut oil',
  'coconut water',
  'sparkling water',
  'soda water',
  'tonic water',
  'green bean',
  'baked bean',
  'kidney bean',
  'jelly bean',
  'black bean',
  'garlic bread',
  'fairy bread',
  'fish finger',
  'chicken nugget',
  'ginger beer',
  'root beer',
  'rice paper',
  'rice cracker',
  'corn chip',
  'potato chip',
  'tomato paste',
  'brown sugar',
  'icing sugar',
  'caster sugar',
  'raw sugar',
  'self raising flour',
  'cornflour',
  'plain flour',
  'chocolate milk',
  'condensed milk',
  'evaporated milk',
  'powdered milk',
  'milk powder',
  'baking powder',
  'curry powder',
  'chicken salt',
  'sea salt',
  'garlic salt',
  'onion powder',
  'garlic powder',
  'apple juice',
  'orange juice',
  'lemon juice',
  'lime juice',
  'cherry tomato',
  'egg noodle',
  'rice noodle',
  'egg white',
  'pork mince',
  'chicken mince',
  'beef mince',
  'lamb mince',
  'turkey mince',
  'bread crumb',
  'breadcrumb',
};

bool _isMeasure(String w) =>
    RegExp(r'\d').hasMatch(w) || const {'g', 'kg', 'ml', 'l', 'pk', 'x', 'pce', 'pcs'}.contains(w);

/// How [query] compares with one of an item's names: null when they are
/// different things.
({bool sure, int rank})? compareNames(String query, String name, {bool taught = false}) {
  final q = canonicalName(query), n = canonicalName(name);
  if (q.isEmpty || n.isEmpty) return null;
  if (q == n) return (sure: true, rank: taught ? 1 : 0);
  // A word run together or split ("weetbix", "weet bix").
  final a = q.replaceAll(' ', ''), b = n.replaceAll(' ', '');
  if (a == b) return (sure: true, rank: taught ? 1 : 2);
  final qw = q.split(' '), nw = n.split(' ');
  final (small, big) = qw.length <= nw.length ? (qw, nw) : (nw, qw);
  final gap = _within(small, big);
  if (gap != null) {
    // What the longer name adds: nothing that changes the thing ("garlic
    // cloves", "Spaghetti 500g") -> sure. A kind of the same thing ("Jasmine
    // rice" for rice, "brown onions" for onions: same last word, and not one
    // of [ownThings]) -> sure. Anything else ("rice wine", "chicken stock")
    // -> ask.
    final extra = big.where((w) => !small.any((s) => _wordGap(s, w) != null)).toList();
    final neutral = extra.every((w) => neutralWords.contains(w) || _isMeasure(w));
    final core = big.where((w) => !_isMeasure(w) && !neutralWords.contains(w)).toList();
    final smallCore = small.where((w) => !_isMeasure(w) && !neutralWords.contains(w)).toList();
    final bigName = core.join(' ');
    final kindOf =
        core.isNotEmpty &&
        smallCore.isNotEmpty &&
        core.last == smallCore.last &&
        !ownThings.any((t) => (' $bigName ').contains(' $t ') && !(' ${smallCore.join(' ')} ').contains(' $t '));
    if (gap == 0 && (neutral || kindOf)) return (sure: true, rank: taught ? 1 : 2);
    // Different last words ("chicken stock" and chicken, "torch batteries"
    // and a torch) are different things; a spelling slip or a name of its
    // own on the same last word ("coconut milk" and milk) is worth asking.
    final sameHead = core.isNotEmpty && smallCore.isNotEmpty && _wordGap(core.last, smallCore.last) != null;
    if (!neutral && !sameHead) return null;
    return (sure: false, rank: 3 + gap + (neutral || kindOf ? 0 : 1));
  }
  final g = _wordGap(a, b);
  return g == null ? null : (sure: false, rank: 3 + g);
}

/// The stock item [query] means, best first: the same name, then a name the
/// household taught, then one name inside the other, then close spellings
/// (not sure). Items the household said it is not are skipped. With
/// [inStockOnly] an item that has run out is passed over; otherwise an item
/// with stock wins a tie.
NameMatch? matchName(String query, Iterable<StockItem> items, {bool inStockOnly = false, bool allowClose = true}) {
  final q = canonicalName(query);
  if (q.isEmpty) return null;
  NameMatch? best;
  for (final item in items) {
    if (inStockOnly && item.isOut) continue;
    if (item.notAliases.any((n) => canonicalName(n) == q)) continue;
    for (final (name, taught) in [(item.name, false), for (final a in item.aliases) (a, true)]) {
      final c = compareNames(query, name, taught: taught);
      if (c == null || (!c.sure && !allowClose)) continue;
      final better =
          best == null ||
          c.rank < best.rank ||
          (c.rank == best.rank && best.item.isOut && !item.isOut) ||
          // Two names inside: the one with more words in common is closer.
          (c.rank == best.rank &&
              best.item.isOut == item.isOut &&
              canonicalName(name).split(' ').length > canonicalName(best.matchedName).split(' ').length);
      if (better) best = NameMatch(item, sure: c.sure, rank: c.rank, matchedName: name);
    }
  }
  return best;
}
