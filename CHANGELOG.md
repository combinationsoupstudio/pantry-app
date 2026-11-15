# Changelog

All notable changes to this project are listed here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions: [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.2.0] - 2026-11-15

### Added
- Saved recipes. **From a link:** paste a recipe page link, tap *Read*, and the app fills in the name, time and ingredients from the page's recipe data; check them and save. The method stays on the site, opened with *Open recipe*. **Your own:** name, time, ingredients and method in your own words.
- Recipe page: what you have and what is missing, which stock item covers each ingredient, add missing to the list, edit and remove.
- Saved recipes are matched against stock like the starter ideas; ingredient names match either way round ("garlic" stock covers "garlic cloves").

### Build
- CI builds a release APK on every pull request (was debug), so release-only failures are caught before merge.
- Java 21 in CI and release. Android lint's release-time check is off: it crashed on a plugin's sources and is not the project's gate.

### Changed
- The Recipes page shows your recipes first, then only the starter ideas you can nearly make.

## [0.1.1] - 2026-11-15

### Fixed
- Shopping list: adding something already on the list now stacks onto that line instead of making a new one. This holds for recipes, the Add button and running low alike, ignoring case and spacing, in the same unit. Ticked lines are left alone.
- Lists saved by 0.1.0 with duplicate lines are merged when the app opens.

### Changed
- Shopping lines link to the stock item they refer to (by name, or by recipe ingredient), so *Put away* restocks it, and running low joins a line already typed in rather than adding another.
- Ingredients added from recipes are named like stock items ("Bread", not "bread").

## [0.1.0] - 2026-11-15

### Added
- Six pages: Home (readiness assessment), Pantry, Storage, Shopping, Recipes, Insights.
- Stock items with quantity, unit, "keep at least" target and use-by date, in eight default locations.
- One-tap use and top-up; move stock between locations; running-low list.
- Shopping list grouped by shop, filled from running-low in one tap; bought items put away into stock.
- Starter recipes matched against stock, with missing ingredients added to the list.
- Insights: targets met, low and out counts, readiness by location, use-by soon, most used in 30 days, change history.
- Who is using the phone (Chris or Emily), recorded on every change.
- CSV import and export of the stock list.
- CI on every push and pull request; signed release APKs published when the version is bumped.
