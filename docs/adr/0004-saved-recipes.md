# ADR 0004: Saved recipes are links or the household's own

- Status: Accepted
- Date: 2026-11-15

## Context
The household wanted their favourite recipes from a recipe site in the app, matched against stock. A recipe's method is the author's written work, and this repository is public. Copying a site's recipes into the app, or into this repo, would republish that work and take readers away from the site that made it.

## Options
1. **Copy recipes in, method and all.** Rejected: it republishes someone else's writing.
2. **Links.** Save the page's link with its name, time and ingredient names (facts used for matching). The method stays on the page; the app opens it.
3. **The household's own recipes,** typed in, method included. Stored only on the phones.

## Decision
Options 2 and 3 together. When a link is pasted, the phone fetches that one page on the person's request and reads only the schema.org `Recipe` data that recipe sites publish for search engines: `name`, `totalTime` (or `prepTime` + `cookTime`) and `recipeIngredient`. `recipeInstructions` is never read or stored. Ingredient lines are cut down to what you would look for in a shop ("500g / 1 lb chicken thighs, skinless" → "chicken thighs"), and the person checks them before saving.

Nothing from any site is bundled with the app or committed here; tests use made-up pages.

## Consequences
- Matching works the same for saved and starter recipes; ingredient names match stock either way round ("garlic" stock matches "garlic cloves").
- The app needs the Internet permission (fetching a page) and a `VIEW https` query (opening it).
- A page without recipe data, or with no connection, falls back to typing it in.
