# ADR 0002: One store, local first, storage behind an interface

- Status: Accepted
- Date: 2026-11-15

## Context
Phase 0 has to be usable on day one with no server. Phase 1 adds sync between two phones. The move from one to the other should not mean rewriting the pages.

## Decision
- `HouseholdStore` (a `ChangeNotifier`) is the only way to change household data. Each method validates the change, records an `ActivityEntry` (who, what, how much, when), notifies the UI and saves.
- Saving goes through a `StorageBackend` interface. Phase 0 uses `FileBackend`: a JSON file in the app's private folder, written to a temp file and renamed over the real one so a crash cannot leave half a file. Tests use `MemoryBackend`.
- No state-management package: an `InheritedNotifier` (`StoreScope`) hands the store to the widget tree. Fewer dependencies, nothing hidden.
- The saved JSON carries a `schema` number so later versions can migrate it.

## Consequences
- Each phone has its own copy in phase 0. Two people will drift until phase 1; CSV export/import is the stop-gap.
- The activity log is capped at 1,000 entries on the phone.
