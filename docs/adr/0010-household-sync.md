# ADR 0010: Household sync through one Durable Object per household

- Status: Accepted (v0.9.0)
- Date: 2026-11-16
- Supersedes the storage choice in ADR 0003 (D1); the Worker and the reasons for a server stand.

## Context
Chris, 16 Nov 2026: "I want to be able to 'sync' to the household after changes are made. Then, over time, make every change just natively update the server instantly so the next person can see it change within a few seconds." Chris (S21+) and Emily (S25) keep one pantry. Each phone already keeps the whole list locally (ADR 0002) and must keep working with no signal.

## Options
1. **Cloudflare Worker + D1** (ADR 0003's plan). The studio's Cloudflare token is refused D1 (Oct 2026), so it cannot be deployed through the studio's tools.
2. **Cloudflare Worker + a SQLite Durable Object per household.** Same account, same pattern as the studio's tally Worker. Each household is its own small database, which also gives it one place to hold websockets later (stage 3).
3. **Firebase.** A second platform for one feature.

## Decision
Option 2. Worker `pantry-sync` on the studio Cloudflare account (https://pantry-sync.combinationsoupstudio.workers.dev); source in `server/`, deployed by the studio's `deploy-pantry-sync.js`.

- **Joining.** The first phone starts a household and gets an 8-character id, a 40-character token and a join code (`K7QM4RXT-482913`). The code works once, for 48 hours. A joining phone gets its own token. Only SHA-256 hashes of tokens are stored. The Worker holds no secret.
- **Records.** Every location, item, list line, recipe, price, history line and the shared settings is one record (kind, id, JSON). Who is using the phone and the reminder settings stay on each phone.
- **Sync.** A phone sends what changed since it was last in step (found by comparing each record with a snapshot), then takes everything with a sequence number above its cursor. Last write wins per record; stock amounts also go as a change (+2, -1) so two people using the same thing both count; prices and history are only ever added; deletes are kept as tombstones.
- **When.** Stage 1: on opening, and the Sync button. Stage 2 (v0.9.0): 2 seconds after a change, and every 5 seconds while the app is open. Stage 3 (v0.9.1): a live line. Each open phone holds a websocket to the household's Durable Object (hibernating, so an idle line costs nothing; "ping" is answered without waking it). After any sync that changed something the household sends `{cursor, from}` to every line; the other phones sync at once. Changes go 0.8 s after they are made. Measured: 0.9 s phone to phone against a local server, 2.2 s against the live one from overseas. With the line up, the 5-second check eases to 30 s; if it drops, it reopens with backoff and the 5-second check carries on.
- **Joining a phone that already has a list** offers "use theirs" (this phone's list is saved to a backup file first, then replaced) or "add mine".

## Consequences
- With the live line up, an open phone makes about 120 small requests an hour plus one per change, well inside the Workers free plan.
- Own photos (`photoPath`) are files on one phone and do not travel yet; the other phone shows the product picture or a blank. Shared photos through R2 are next.
- The household's whole history is on Cloudflare in the studio account. Nothing in it is a secret beyond what a shopping list says.
