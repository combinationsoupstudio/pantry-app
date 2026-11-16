# ADR 0003: Cloudflare Worker + D1 for sync and price search

- Status: Superseded in part by [ADR 0010](0010-household-sync.md) (storage: Durable Objects, not D1)
- Date: 2026-11-15

## Context
Phase 1 needs the two phones to share one household. Phase 2 needs a small Claude model to look up Batemans Bay prices on a schedule. An API key must never ship inside an APK, where anyone holding the phone can pull it out. The studio already runs on Cloudflare and avoids adding vendors where an existing one can do the job.

## Options
1. **Cloudflare Worker + D1 (SQLite) + R2 for photos.** Already in use, free at this scale, keeps secrets server-side, runs scheduled jobs (Cron Triggers) for the price search.
2. **Firebase (Firestore).** Live sync and offline built in, but a second backend platform, and the price search would still need server code somewhere.
3. **No server, phones sync directly.** Fragile, and nowhere safe for the API key.

## Decision (proposed)
Option 1. The Worker exposes a small REST API (changes since a cursor; post a batch of changes), one token per person, stored as Worker secrets. Each phone keeps working offline and sends queued changes when it is back. Conflicts on the same item are settled per field, last write wins, with the activity log kept in full.

## Consequences
- The app gains a `SyncBackend` behind the existing `StorageBackend` interface (ADR 0002).
- The Claude API key lives only in the Worker's secrets.
