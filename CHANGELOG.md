# Changelog

All notable changes to this project are listed here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions: [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
- CI on every push and pull request; signed release APKs from version tags.
