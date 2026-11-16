# ADR 0006: Product pictures are fetched on demand and kept on the phone

- Status: Accepted
- Date: 2026-11-16

## Context
Chris wants every product the household owns or might buy to show its picture, accurate to the pack and size, without a big download. He also wants the amount to show visually: picking 4 washed potatoes should show four.

## Options
1. **Bundle a picture library in the app.** Thousands of products at 10 KB is tens of MB, mostly products the household never buys, and stale as packaging changes.
2. **Retailer pictures (Woolworths, Coles).** Their copyright; taking them breaks their terms.
3. **Open Food Facts pictures, fetched when first needed** and kept on the phone. Free, CC BY-SA 3.0, keyed by barcode, so the picture is that exact product and pack size.
4. **Only the household's own photos.** Accurate but slow to build up.

## Decision
3 with 4 on top. A picture is resolved in this order: the household's own photo; the product's small (200 px) front picture from Open Food Facts, by barcode or picked from a name search of Australian products (search.openfoodfacts.org); else a plain tinted square with the first letter. Pictures are downloaded once into the app's own folder (`PictureCache`, only from images.openfoodfacts.org) and held in memory while shown. Measured in this release: 4-13 KB each, so 200 products is about 2-3 MB, spread over time.

Piles draw one picture per item, or per pack for a measured item, up to five, with the true count on a badge. An item counted by weight or volume without a pack size shows one picture: the pile never claims more precision than the data has.

## Consequences
- Coverage is good for big brands, patchy for small ones and loose produce; the household's own photo fills gaps. Search results can include unrelated products, so names holding the search words are ranked first and the person picks.
- Credits: Settings, the editor ("Picture: Open Food Facts") and the README.
- With sync (v0.9), picture URLs and own photos travel with the item; Open Food Facts pictures are fetched again per phone.
