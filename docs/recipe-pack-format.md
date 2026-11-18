# Recipe pack format

The app's starter recipes live in plain text files in `assets/recipes/`, one pack per file, listed in `lib/data/recipe_library.dart`. Anyone can read and edit them without touching code. `test/recipe_pack_test.dart` reads every shipped pack and fails on any line it cannot read.

Australian metric only: 1 cup = 250 ml, 1 tbsp = 20 ml, 1 tsp = 5 ml, grams, millilitres, °C.

```
# A comment.
@credit original: Written for Pantry by Combination Soup Studio.
@credit qld-hnc: Adapted from ... CC BY 4.0. | https://link-to-the-source

=== Corn fritters with avocado smash      <- a new recipe, its name
id: corn-fritters                         <- unique across all packs
serves: 4
minutes: 30
tags: breakfast, lunch, vegetarian        <- the browse filters read these
credit: original                          <- a key from an @credit line
-- Fritters                               <- the part of the recipe the next lines are for
- 2 eggs                                  <- an ingredient; its shop name is worked out
- 1 cup self-raising flour | self-raising flour; flour
                                          <- after "|": the shop name, then other names it may be kept under
-- Smash
- 2 avocados | avocado
~ salt                                    <- a basic: never missing, never on the list unless tracked
> Whisk the flour, eggs and milk ...      <- one method step per line, in order
note: A tip shown under the method.
```

Rules the test enforces: every recipe has an id, serves, minutes, tags, at least 3 ingredients and 3 steps, and a known credit; ids are unique; no ingredient is a heading ("Ingredients:", "Method"); no ounces, pounds or Fahrenheit. Water is never an ingredient: say how much in the method.

Recipes copied from anywhere must be openly licensed (for example CC BY) and carry their credit; see ADR 0014. Every pack recipe shows as *Untested* until the household rates it.
