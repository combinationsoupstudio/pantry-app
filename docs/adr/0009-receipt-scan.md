# ADR 0009: Receipts are read on the phone and checked before saving

- Status: Accepted
- Date: 2026-11-16

## Context
Chris wants scanned receipts to track shop spend (16 Nov 2026), and the household wants prices and stock to follow without typing every line.

## Options
1. **A cloud receipt API** (paid, sends receipts off the phone).
2. **A large language model** reading the photo (cost per receipt; planned for messy receipts in the AI release).
3. **On-device text recognition (Google ML Kit, latin)** plus our own parser, with a review screen.

## Decision
Option 3. `google_mlkit_text_recognition` returns lines with their positions; `rowsOf` joins description and price pieces on the same row; `parseReceipt` reads shop, date, lines, quantity rows ("QTY 3 @", "kg @ /kg"), discounts and the total, skipping payment and tax rows. Nothing is saved until the person checks the lines: the page shows whether the lines add up to the total, the stock match (`matchStock`: every word of the item's name in the line, most specific wins) and what goes into stock. The size printed on the receipt beats the saved pack size; a weighed line never becomes a guessed count.

## Consequences
- Supermarket layouts vary; the parser is tested on Woolworths/Coles-style rows and will be tuned on real receipts from the household.
- The ML Kit text model is bundled (a few MB on the APK) so it works with no signal.
- Prices are recorded with the receipt's date, so this week's spend is right even for a receipt scanned later.
