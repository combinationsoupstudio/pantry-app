# ADR 0011: Names: fold what is the same, ask about what is close, remember the answer

- Status: Accepted (v0.11.0)
- Date: 2026-11-16

## Context
Chris, 16 Nov 2026, after the first day of sync: "We need to make sure that words such as shallots/spring onions however typed in are matched appropriately. We can't have a customer relying on their spelling to be a 1:1 match to our inventory list of foods. How do we ensure that closeness is 100% so no metrics or lists are inaccurate based off spelling?"

Names meet stock in five places: recipe ingredients, the shopping list (typed, voice, running low), receipts, adding an item, and history (use rates). Until now each compared names its own way, mostly whole-word containment, which both missed ("spring onions" vs Shallots) and over-matched ("onion" inside "spring onions", "milk" inside "coconut milk").

## Options
1. **Fuzzy matching alone** (edit distance). Catches typos, but any threshold either misses or wrongly matches (rice / mice, ham / jam), and wrong matches are silent.
2. **A product database / AI to decide.** Network, cost, and still a guess.
3. **Fold, ask, remember.** One matcher (`lib/logic/names.dart`) with three outcomes: *sure* (used), *close* (asked once), *none* (new). The household's answers become data on the item and sync.

## Decision
Option 3. 100% comes from never guessing silently, not from a perfect speller.

- **Canonical name:** lower case, letters and digits, each word singular (onions, potatoes, berries, loaves), "canned"/"tinned" folded, and ~60 groups of names that mean the same (Australian first: shallots = spring onions = scallions; capsicum = bell pepper; cornflour = cornstarch; Panadol = paracetamol; glad wrap = cling wrap...). Eschalots (french shallots) stay their own thing.
- **Sure:** the same canonical name; a name the household taught the item (`aliases`); or one inside the other where the extra words do not change the thing: how it comes or how big ("garlic cloves", "Spaghetti 500g") or a kind of the same thing (same last word: "Jasmine rice" for rice), unless the longer name is one of ~80 things of their own ("coconut milk", "spring onion", "chicken stock", "tomato paste").
- **Close:** a slip of a letter or two in words of four letters or more (none for shorter words), or a name of its own on the same last word. Close is never counted: recipes show "Is it your Shallots? Yes / No"; the shopping list and the item editor ask before adding. Yes adds an alias, No a `notAliases` entry, both on the item record, so both phones know at once.
- **Different last words** ("chicken stock" and Chicken, "torch batteries" and Torch) are different things.
- Every recipe line says which item it is matched to and can be changed with a tap; receipts learn from matches changed by hand; adding an item that is already kept (any name) offers to add to it, so nothing is counted twice.

## Consequences
- Metrics (meals ready, running low, use rates) use sure matches only.
- A phone on v0.10 or earlier drops `aliases` when it edits an item: both phones should run v0.11.
- The word lists are code; adding a missed pair is a one-line change with a test.
