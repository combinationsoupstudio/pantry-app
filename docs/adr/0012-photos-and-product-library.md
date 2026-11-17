# ADR 0012: Shared photos and a product library by barcode

- Status: Accepted (v0.13.0)
- Date: 2026-11-17
- Drops the plan to generate drawings at scale (16 Nov); the 30 drawings of v0.12 stay as a Settings option.

## Context
After a stocktake of the prep pantry, Chris, 17 Nov 2026:
- "Photos we each take and upload to products don't carry across to each other's device", and Emily's photo of the same item removed his (fixed for now in v0.12.1).
- "Photos from users or a database the users add to when uploading for their products ... the app database is updated to the next person who ... scans the same Barcode gets that product photo. That way we can have our own repository of items customers add over time."
- "When you scan a barcode, the time it takes to find the default photo ... is far too slow. It was quicker to take a photo than rely on an external database."
- "The add item suggested layout for each product wasn't always right ... it will confuse people."

## Decision
1. **Household photos.** A photo taken in the app is shrunk on the phone (640 px, JPEG 78, about 40-80 KB), named by its SHA-256 and kept; the item records `photoId`; the photo goes to the household's Durable Object (`PUT /h/:id/photo`, token) after each sync, and the other phones fetch it once (`GET /h/:id/photo/:hash`) and keep it. Photos from before v0.13 are shrunk and shared on first open.
2. **Product library.** One `Catalogue` Durable Object for everyone (same Worker, studio account, no new service), by barcode: name, brand, pack size, counted or measured and in what, kitchen or stored away, and the latest photo. Reads are open (a barcode is no secret); writes need a household token. A household's set-up beats what Open Food Facts said; the latest household's beats an earlier one. Nothing about the household (amounts, dates, places, who) is sent. Settings > Household has the switch.
3. **Scanning.** The library first (one request, under a second), then Open Food Facts only for a barcode it does not know, and that answer goes into the library so nobody waits on it again. The page never waits: after 3 seconds it says it is still looking and fills in later, never over what was typed.
4. **Counted or measured, up front.** A chooser at the top of the add page: "Count them (jars)" or "Measure what is left (500 g)". The guess (`count_or_measure.dart`): measured only for things used bit by bit (oil, sauces, flour, rice, milk...) with a known pack size; otherwise counted in what it comes in (jam -> jars, tins -> cans). Until now any pack size made it measured. The household's choice goes to the library, so the next scan of that barcode opens the way they keep it.

## Consequences
- Photos are public by barcode URL once shared to the library; household photos are not. Before other households use the app: a report button and a look at what is shared (moderation).
- Durable Object storage holds the photos (SQLite blobs, 600 KB cap each). Fine for a few thousand; move to R2 if it grows past a few GB.
- An older app (v0.12 and before) ignores `photoId`; both phones should run v0.13.
