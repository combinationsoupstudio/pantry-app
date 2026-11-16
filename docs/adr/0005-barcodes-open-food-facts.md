# ADR 0005: Barcodes are looked up on Open Food Facts

- Status: Accepted
- Date: 2026-11-16

## Context
Adding a part-used bottle should be quick: point the camera at the barcode, get the name and pack size, say roughly how much is left. That needs two things: a barcode reader on the phone, and somewhere that knows what a barcode is.

## Options
1. **Type everything.** Works, but it is the friction this release removes.
2. **A paid product API** (retailer or commercial barcode service). Costs money, needs a key on the phone or a server, and terms that usually forbid storing results.
3. **Open Food Facts**, the free, open, crowd-built food database (ODbL). No key. Coverage of Australian groceries is good for big brands and patchy for small ones.
4. **Our own Cloudflare Worker** with a product table. We have Cloudflare already, but no product data to put in it.

## Decision
Option 3, with option 1 always there. Barcodes are read on the phone with `mobile_scanner` (Google ML Kit, on-device; nothing leaves the phone to read it). Only the barcode number is sent, from the phone, to `world.openfoodfacts.org/api/v2/product/<code>`, asking for name, brand and quantity fields only, with a User-Agent naming the app as Open Food Facts asks. A barcode already in the household's stock never goes out: it offers to add a pack instead. When a product is not found, or there is no signal, the barcode is still kept on the item so the next scan finds it locally. Settings credits Open Food Facts and its licence. Chris approved its use on 16 Nov 2026.

Photos are taken with the phone's camera app (`image_picker`), resized to 1024 px and kept in the app's own folder; they are not uploaded.

## Consequences
- Adds the CAMERA permission (asked on first use) and an `IMAGE_CAPTURE` query to the manifest; ML Kit's barcode model is bundled (a few MB on the APK).
- When sync arrives (v0.8) the household's own barcode-to-item map syncs with the stock; Open Food Facts stays a lookup, never a store.
- The same lookup can later give Nutri-Score for the health grade (v0.6).
