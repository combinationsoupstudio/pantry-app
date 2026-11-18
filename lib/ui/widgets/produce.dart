import '../../logic/names.dart';

/// Fresh produce drawings (assets/food/produce/, v0.14): 228 ink-and-wash
/// pictures of 141 fruit, vegetables and herbs sold in Australia, loose or in
/// punnets and bags. Chris, 17 Nov 2026: "1 x potato. Then when any more than
/// 1 potato is needed, you have a bunch. So some items need two or three
/// images."
///
/// Each has one to three pictures:
///  * `1` one of it, `many` a small heap (picked one by one);
///  * `1` and `bunch` (bananas, carrots, bok choy, beetroot);
///  * `whole` and `cut` (sold whole or cut: pumpkin, melons, cabbage);
///  * just one of `bunch`, `punnet` or `bag` (herbs, berries, salad leaves).
///
/// Made with Higgsfield `gpt_image_2_6`; prompts, contact sheets and the
/// larger masters are in `jobs/INIT-pantry-app/design/produce-20261117/` in
/// the studio folder.
const List<(String, List<String>, List<String>)> produceTable = [
  (
    'apple',
    ['1', 'many'],
    ['apple', 'red apple', 'pink lady', 'royal gala', 'gala apple', 'fuji apple', 'jazz apple', 'red delicious'],
  ),
  ('green-apple', ['1', 'many'], ['green apple', 'granny smith']),
  ('pear', ['1', 'many'], ['pear', 'packham', 'packham pear', 'williams pear', 'beurre bosc', 'corella pear']),
  ('nashi', ['1', 'many'], ['nashi', 'nashi pear', 'asian pear']),
  ('banana', ['1', 'bunch'], ['banana', 'lady finger banana', 'cavendish banana']),
  ('orange', ['1', 'many'], ['orange', 'navel orange', 'valencia orange', 'blood orange']),
  ('mandarin', ['1', 'many'], ['mandarin', 'imperial mandarin', 'clementine', 'satsuma']),
  ('lemon', ['1', 'many'], ['lemon']),
  ('lime', ['1', 'many'], ['lime']),
  ('grapefruit', ['1', 'many'], ['grapefruit', 'pink grapefruit', 'ruby grapefruit']),
  ('kiwifruit', ['1', 'many'], ['kiwifruit', 'kiwi fruit', 'kiwi', 'gold kiwifruit']),
  ('mango', ['1', 'many'], ['mango', 'kensington pride', 'r2e2 mango', 'calypso mango']),
  ('avocado', ['1', 'many'], ['avocado', 'avo', 'hass avocado', 'shepard avocado']),
  ('peach', ['1', 'many'], ['peach', 'white peach', 'yellow peach']),
  ('nectarine', ['1', 'many'], ['nectarine']),
  ('plum', ['1', 'many'], ['plum']),
  ('apricot', ['1', 'many'], ['apricot']),
  ('passionfruit', ['1', 'many'], ['passionfruit', 'passion fruit']),
  ('cherry', ['1', 'many'], ['cherry']),
  ('lychee', ['1', 'many'], ['lychee', 'litchi']),
  ('pomegranate', ['1', 'many'], ['pomegranate']),
  ('persimmon', ['1', 'many'], ['persimmon']),
  ('custard-apple', ['1', 'many'], ['custard apple']),
  ('feijoa', ['1', 'many'], ['feijoa']),
  ('quince', ['1', 'many'], ['quince']),
  ('dragon-fruit', ['1', 'many'], ['dragon fruit', 'dragonfruit', 'pitaya']),
  ('coconut', ['1'], ['coconut', 'fresh coconut']),
  ('red-grapes', ['bunch'], ['grape', 'red grape', 'black grape', 'purple grape', 'crimson grape']),
  ('green-grapes', ['bunch'], ['green grape', 'white grape', 'thompson grape']),
  ('strawberry', ['punnet'], ['strawberry']),
  ('blueberry', ['punnet'], ['blueberry']),
  ('raspberry', ['punnet'], ['raspberry']),
  ('blackberry', ['punnet'], ['blackberry']),
  ('fig', ['punnet'], ['fig', 'fresh fig']),
  ('pineapple', ['whole', 'cut'], ['pineapple']),
  ('watermelon', ['whole', 'cut'], ['watermelon']),
  ('rockmelon', ['whole', 'cut'], ['rockmelon']),
  ('honeydew', ['whole', 'cut'], ['honeydew', 'honeydew melon']),
  ('papaya', ['whole', 'cut'], ['papaya', 'pawpaw', 'papaw', 'red papaya']),
  ('rhubarb', ['bunch'], ['rhubarb']),
  (
    'potato',
    ['1', 'many'],
    ['potato', 'washed potato', 'brushed potato', 'white potato', 'red potato', 'sebago', 'desiree potato'],
  ),
  ('sweet-potato', ['1', 'many'], ['sweet potato', 'kumara', 'orange sweet potato']),
  ('baby-potatoes', ['bag'], ['baby potato', 'chat potato', 'new potato']),
  ('carrot', ['1', 'bunch'], ['carrot', 'dutch carrot']),
  ('onion', ['1', 'many'], ['onion', 'brown onion', 'white onion']),
  ('red-onion', ['1', 'many'], ['red onion', 'spanish onion', 'purple onion']),
  ('shallot', ['1', 'many'], ['eschalot']),
  ('spring-onion', ['bunch'], ['spring onion']),
  ('leek', ['1', 'many'], ['leek']),
  ('garlic', ['1', 'many'], ['garlic', 'garlic bulb', 'fresh garlic']),
  ('ginger', ['1'], ['ginger', 'fresh ginger', 'ginger root']),
  ('broccoli', ['1', 'many'], ['broccoli']),
  ('broccolini', ['bunch'], ['broccolini']),
  ('cauliflower', ['whole', 'cut'], ['cauliflower', 'cauli']),
  ('cabbage', ['whole', 'cut'], ['cabbage', 'green cabbage', 'savoy cabbage', 'drumhead cabbage']),
  ('red-cabbage', ['whole', 'cut'], ['red cabbage', 'purple cabbage']),
  ('wombok', ['whole', 'cut'], ['wombok', 'chinese cabbage', 'napa cabbage']),
  ('brussels-sprout', ['1', 'many'], ['brussels sprout', 'brussel sprout']),
  ('iceberg-lettuce', ['1'], ['lettuce', 'iceberg', 'iceberg lettuce']),
  ('cos-lettuce', ['1'], ['cos', 'cos lettuce', 'baby cos', 'romaine']),
  (
    'salad-leaves',
    ['bag'],
    ['salad leaf', 'salad mix', 'mixed salad', 'mixed leaf', 'mesclun', 'lettuce mix', 'mixed lettuce'],
  ),
  ('rocket', ['bag'], ['rocket', 'baby rocket']),
  ('spinach', ['bag'], ['spinach', 'baby spinach']),
  ('english-spinach', ['bunch'], ['english spinach']),
  ('silverbeet', ['bunch'], ['silverbeet', 'rainbow chard']),
  ('kale', ['bunch'], ['kale', 'curly kale', 'tuscan kale']),
  ('bok-choy', ['1', 'bunch'], ['bok choy', 'pak choy', 'buk choy', 'baby bok choy', 'baby pak choy']),
  ('choy-sum', ['bunch'], ['choy sum']),
  ('gai-lan', ['bunch'], ['gai lan', 'kai lan', 'chinese broccoli']),
  ('celery', ['whole', 'cut'], ['celery']),
  ('cucumber', ['1', 'many'], ['cucumber', 'continental cucumber', 'telegraph cucumber', 'long cucumber']),
  ('lebanese-cucumber', ['1', 'many'], ['lebanese cucumber', 'baby cucumber', 'qukes']),
  ('zucchini', ['1', 'many'], ['zucchini']),
  ('eggplant', ['1', 'many'], ['eggplant']),
  ('red-capsicum', ['1', 'many'], ['capsicum', 'red capsicum']),
  ('green-capsicum', ['1', 'many'], ['green capsicum']),
  ('yellow-capsicum', ['1', 'many'], ['yellow capsicum', 'orange capsicum']),
  ('chilli', ['1', 'many'], ['chilli', 'red chilli', 'green chilli', 'birdseye chilli', 'long red chilli']),
  ('tomato', ['1', 'many'], ['tomato', 'gourmet tomato', 'round tomato']),
  ('roma-tomato', ['1', 'many'], ['roma tomato', 'roma', 'plum tomato']),
  ('truss-tomato', ['bunch'], ['truss tomato', 'vine tomato', 'tomato on the vine', 'tomato on vine']),
  ('cherry-tomato', ['punnet'], ['cherry tomato', 'grape tomato', 'mini roma', 'cocktail tomato']),
  ('mushroom', ['1', 'many'], ['mushroom', 'cup mushroom', 'button mushroom', 'white mushroom']),
  ('swiss-brown-mushroom', ['1', 'many'], ['swiss brown', 'swiss brown mushroom', 'brown mushroom']),
  ('field-mushroom', ['1', 'many'], ['field mushroom', 'flat mushroom', 'portobello', 'portobello mushroom']),
  ('corn', ['1', 'many'], ['corn', 'sweet corn', 'sweetcorn', 'corn cob', 'corn on the cob']),
  ('green-bean', ['1', 'many'], ['green bean', 'string bean', 'runner bean', 'french bean', 'fresh bean']),
  ('snow-pea', ['1', 'many'], ['snow pea', 'snowpea']),
  ('sugar-snap-pea', ['1', 'many'], ['sugar snap', 'sugar snap pea', 'snap pea']),
  ('asparagus', ['bunch'], ['asparagus']),
  ('beetroot', ['1', 'bunch'], ['beetroot', 'fresh beetroot']),
  ('radish', ['bunch'], ['radish']),
  ('turnip', ['1', 'many'], ['turnip']),
  ('parsnip', ['1', 'many'], ['parsnip']),
  ('swede', ['1', 'many'], ['swede', 'rutabaga']),
  ('celeriac', ['1'], ['celeriac']),
  ('fennel', ['1', 'many'], ['fennel', 'fennel bulb']),
  ('butternut', ['whole', 'cut'], ['butternut', 'butternut pumpkin', 'butternut squash']),
  ('pumpkin', ['whole', 'cut'], ['pumpkin', 'kent pumpkin', 'jap pumpkin', 'kabocha', 'queensland blue']),
  ('squash', ['punnet'], ['squash', 'button squash', 'baby squash', 'patty pan', 'pattypan']),
  ('okra', ['1', 'many'], ['okra']),
  ('artichoke', ['1', 'many'], ['artichoke', 'globe artichoke']),
  ('daikon', ['1'], ['daikon', 'white radish']),
  ('kohlrabi', ['1'], ['kohlrabi']),
  ('witlof', ['1', 'many'], ['witlof', 'witloof', 'endive', 'chicory']),
  ('bean-sprouts', ['bag'], ['bean sprout', 'bean shoot', 'mung bean sprout']),
  ('snow-pea-sprouts', ['punnet'], ['snow pea sprout', 'snow pea shoot', 'pea shoot', 'pea sprout']),
  ('parsley', ['bunch'], ['parsley', 'flat leaf parsley', 'continental parsley', 'curly parsley', 'italian parsley']),
  ('coriander', ['bunch'], ['coriander']),
  ('basil', ['bunch'], ['basil', 'sweet basil']),
  ('mint', ['bunch'], ['mint', 'spearmint']),
  ('dill', ['bunch'], ['dill']),
  ('chives', ['bunch'], ['chive']),
  ('rosemary', ['bunch'], ['rosemary']),
  ('thyme', ['bunch'], ['thyme', 'lemon thyme']),
  ('oregano', ['bunch'], ['oregano']),
  ('sage', ['bunch'], ['sage']),
  ('thai-basil', ['bunch'], ['thai basil']),
  ('lemongrass', ['bunch'], ['lemongrass', 'lemon grass']),
  ('bay-leaves', ['bunch'], ['bay leaf', 'bay leave']),
  ('vietnamese-mint', ['bunch'], ['vietnamese mint', 'laksa leaf']),
  ('tangelo', ['1', 'many'], ['tangelo']),
  ('rambutan', ['1', 'many'], ['rambutan']),
  ('longan', ['1', 'many'], ['longan']),
  ('mangosteen', ['1', 'many'], ['mangosteen']),
  ('starfruit', ['1', 'many'], ['starfruit', 'star fruit', 'carambola']),
  ('guava', ['1', 'many'], ['guava']),
  ('tamarillo', ['1', 'many'], ['tamarillo']),
  ('cumquat', ['punnet'], ['cumquat', 'kumquat']),
  ('jackfruit', ['whole', 'cut'], ['jackfruit']),
  ('broad-bean', ['1', 'many'], ['broad bean']),
  ('pea', ['1', 'many'], ['fresh pea', 'pea pod', 'garden pea', 'peas in the pod', 'pea in pod']),
  ('radicchio', ['1'], ['radicchio']),
  ('watercress', ['bunch'], ['watercress', 'cress']),
  ('turmeric', ['1', 'many'], ['turmeric', 'fresh turmeric', 'turmeric root']),
  ('horseradish', ['1'], ['horseradish', 'horseradish root']),
  ('jerusalem-artichoke', ['1', 'many'], ['jerusalem artichoke', 'sunchoke']),
  ('kipfler-potato', ['1', 'many'], ['kipfler', 'kipfler potato']),
  ('tarragon', ['bunch'], ['tarragon']),
  ('curry-leaves', ['bunch'], ['curry leaf']),
  ('marjoram', ['bunch'], ['marjoram']),
];

/// Words that make a name something else made from the produce (a tin, a
/// juice, a dried herb, a cake), so it never gets the fresh drawing: "Tinned
/// tomatoes", "Orange juice", "Dried oregano", "Banana bread", "Garlic
/// powder". A name for the produce itself that has one of these words in it
/// ("salad mix") lists it in its own names.
const Set<String> notFresh = {
  'tin', 'frozen', 'dried', 'dry', 'powder', 'powdered', 'ground', 'juice', 'sauce', 'paste', 'jam', //
  'chip', 'crisp', 'flake', 'soup', 'bread', 'cake', 'puree', 'concentrate', 'cordial', 'oil', 'vinegar', //
  'flavour', 'flavoured', 'stock', 'mix', 'seasoning', 'pickled', 'pickle', 'crushed', 'minced', 'jar', //
  'smoothie', 'yoghurt', 'milk', 'cream', 'chutney', 'relish', 'salsa', 'essence', 'extract', 'syrup', //
  'lolly', 'biscuit', 'muffin', 'pie', 'spread', 'butter', 'pesto', 'slice', 'chocolate', 'choc', //
  'baked', 'creamed', 'desiccated', 'shredded', 'water', 'beer', 'wine', 'tea', 'marinated', 'sundried', //
  'seed', 'kernel', 'salad', 'coleslaw', 'slaw', 'bar', 'cereal', 'muesli', 'dip', 'sorbet', 'ice', //
  'nectar', 'drink', 'candied', 'glace', 'preserved', 'pouch', 'tart', 'crumble', 'chunk', 'ring', //
  'sachet', 'tablet', 'capsule', 'flavor', 'soap', 'shampoo', 'candle', 'spray', 'wipe', //
};

/// Every (picture, name) pair, longest name first, so "sweet potato" is
/// found before "potato" and "custard apple" before "apple".
final List<(String, Set<String>, String)> _byName = () {
  final out = <(String, Set<String>, String)>[];
  for (final (slug, variants, names) in produceTable) {
    for (final n in names) {
      final c = canonicalName(n);
      if (c.isNotEmpty) out.add((slug, variants.toSet(), c));
    }
  }
  out.sort((a, b) {
    final words = b.$3.split(' ').length.compareTo(a.$3.split(' ').length);
    return words != 0 ? words : b.$3.length.compareTo(a.$3.length);
  });
  return out;
}();

/// The produce [name] is, as (picture name, pictures it has), or null.
(String, Set<String>)? produceOf(String name) {
  final c = canonicalName(name);
  if (c.isEmpty) return null;
  final n = ' $c ';
  final words = c.split(' ').toSet();
  for (final (slug, variants, phrase) in _byName) {
    if (!n.contains(' $phrase ')) continue;
    final phraseWords = phrase.split(' ').toSet();
    // A tin, a juice, a dried herb: not the fresh thing.
    if (words.any((w) => notFresh.contains(w) && !phraseWords.contains(w))) return null;
    // A name of its own that only shares a word ("coconut milk").
    if (ownThings.any((t) => n.contains(' $t ') && !' $phrase '.contains(' $t '))) return null;
    return (slug, variants);
  }
  return null;
}

/// The produce drawing for [name] (an asset path), or null: one of it when
/// [count] is 1, the heap or bunch for 2 or more, and the cut piece when
/// [part] (less than one whole: half a pumpkin).
String? produceArt(String name, {int count = 1, bool part = false}) {
  final hit = produceOf(name);
  if (hit == null) return null;
  final (slug, has) = hit;
  final order = part
      ? const ['cut', '1', 'whole', 'bunch', 'punnet', 'bag', 'many']
      : count >= 2
      ? const ['many', 'bunch', 'whole', 'punnet', 'bag', '1', 'cut']
      : const ['1', 'whole', 'bunch', 'punnet', 'bag', 'many', 'cut'];
  final v = order.firstWhere(has.contains);
  return 'assets/food/produce/$slug-$v.png';
}
