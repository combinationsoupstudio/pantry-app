# Working on Pantry

Instructions for any AI assistant (and any person) working in this repo. Read this first, every session.

## What this is
Pantry is an Android app (Flutter) for a household's stock: pantry, fridge, freezer and spare storage, what is running low, the shopping list, and recipes matched to what is in the cupboard. Two or more phones share one household through a small sync server (`server/`, Cloudflare). Built by Combination Soup Studio.

## How work flows
Idea, spec, build, test, release. Every piece of work follows the same path:

1. **Issue first.** Nothing is built without a GitHub issue. The issue says the idea, the spec, a *Done when* checklist and what is out of scope. Ask for an issue if there is none.
2. **Branch** from `main`, named for the issue: `feat/30-recipes-pack-2`, `fix/41-quantity-below-zero`.
3. **Commits name the issue**: `feat(recipes): pack 2 recipes (#30)`. Conventional Commits.
4. **Pull request closes the issue**: the body says `Closes #30` and ticks the *Done when* list. Fill in the template.
5. **CI must be green**: formatting, `flutter analyze` with no issues, every test, the APK build.
6. **Release**: bump `version:` in `pubspec.yaml` and move the CHANGELOG notes in the same pull request. The Release workflow tags and publishes the signed APK on merge. Never tag by hand. See `docs/RELEASING.md`.

One issue per pull request where possible. If work uncovers something else, open a new issue for it rather than widening the current one.

## Rules
- Logic that can be pure Dart lives in `lib/logic/` with unit tests. New behaviour comes with a test. Widget tests run at phone size.
- Every change to household data goes through `HouseholdStore`.
- A change to architecture, storage, a vendor or the release process gets an ADR in `docs/adr/`.
- No new vendor where Cloudflare or Google already does the job.
- Australian English in the interface. Australian metric everywhere: 1 cup 250 ml, 1 tbsp 20 ml, 1 tsp 5 ml, grams, °C.
- Run `dart format lib test` (line width 120) before committing.

## Recipes
- Packs live in `assets/recipes/` as plain text; the format is `docs/recipe-pack-format.md`; the packs shipped are listed in `lib/data/recipe_library.dart`.
- A recipe from anywhere else must be openly licensed (CC BY or similar), with the licence checked at the source, and carry its credit and link (ADR 0014). Never copy a recipe whose licence is unknown.
- Our own recipes are written for Pantry: classics done the standard way, in our own words.
- No recipe name or id may repeat across packs; `test/recipe_pack_test.dart` checks every pack.
- Headings are never ingredients. Water is never an ingredient. Salt and pepper are basics (`~`).

## Never in this repo
Keys, passwords, keystores, `.env` files, personal notes or anything about the people using the app. The signing key lives off GitHub; CI reads it from repository secrets.
