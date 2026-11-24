# Changelog

All notable changes to this project are listed here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions: [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.18.0] - 2026-11-24

### Added
- **Use by or Best before** on every date. A switch on every date picker; picking one unpicks the other. Past a use by reads "Don't eat" in red; past a best before reads "Check it" in amber, because it is usually still fine. Each item remembers which kind it gets, so guessed dates on top-ups match. Older data reads as use by. ([#36](https://github.com/combinationsoupstudio/pantry-app/issues/36))
- **Split into lots** when adding: several of one product, each with its own amount, place and date. "2 tins best before May in the Pantry, 4 tins best before August in the Prep pantry" goes in as one add; each place gets its stock and its dates, topping up what is already there. ([#37](https://github.com/combinationsoupstudio/pantry-app/issues/37))
- **Colour glow-up** and a choice of look in Settings: *Warm pantry*, richer (herb green, saffron, tomato, a deep olive bar), or *Market fresh*, bold (teal, citrus, coral). Every status colour passes WCAG AA, checked by a test. ([#38](https://github.com/combinationsoupstudio/pantry-app/issues/38))

### Changed
- The Dates page and Home say "Dates" rather than "Use-by dates", since a date can now be either kind.

## [0.17.0] - 2026-11-19

### Added
- **50 more starter recipes** (pack 2 of 4; 105 in all). Breakfasts, pub classics, curries from Thailand, Malaysia and Japan, BBQ, slow cooks and Aussie baking: chicken parmigiana, beef rendang, pad Thai, sticky BBQ ribs, beef and Guinness pie, pavlova, lamingtons, sticky date pudding and more. 35 are written for Pantry; 15 are adapted from Queensland Health's *Healthy New Communities Cookbook* (CC BY 4.0, credited on each recipe), including lamb biryani, ghormeh sabzi, ashak and bakso. ([#30](https://github.com/combinationsoupstudio/pantry-app/issues/30))
- **Smoko burritos**, the house recipe: charred chipotle Smoko sauce and crusted, spiced beef.
- A test that no recipe name or id repeats across any pack.
- `CLAUDE.md`: how work flows here (issue, branch, commits naming the issue, a pull request that closes it, CI, release), for people and AI assistants alike. ([#32](https://github.com/combinationsoupstudio/pantry-app/issues/32))

## [0.16.0] - 2026-11-18

### Added
- **55 starter recipes with full methods** (pack 1 of 4 toward 200+). Breakfasts, weeknight dinners, curries, slow cooks, soups and baking, in Australian metric (1 cup 250 ml, 1 tbsp 20 ml). 45 are written for Pantry; 10 are adapted from Queensland Health's *Healthy New Communities Cookbook* (CC BY 4.0, credited on each recipe).
- Every pack recipe opens like your own: ingredients checked against stock on one tab, the numbered method on the other, plus serves, time, tips and who wrote it.
- **Untested** label on every pack recipe until the household has cooked and rated it.
- **Browse all starter recipes**: search by name or ingredient, filter by Breakfast, Dinner, Quick, Vegetarian, Soup, Baking, Slow cook; the ones you can make soonest come first.
- Ingredient lines can say which part of a recipe they are for ("Smash", "Marinade"). The part is shown beside the line, never as a line of its own, so a heading can never reach the shopping list.
- Salt and pepper you do not track are taken as in the cupboard: shown under *From the cupboard*, never counted missing, never added to the list. Track them and they behave like anything else.

### Fixed
- A count of parts no longer compares with whole things kept: "4 garlic cloves" against 2 garlic, or "4 rashers bacon" against 1 pack, used to say *short*.

## [0.15.0] - 2026-11-18

### Added
- **Use-by batches.** Some of an item can carry one date and some another: 2 yoghurts good till Friday, 2 till next week, 1 with no date. The item's page lists each batch, soonest first and marked *Use these first*; tap one to change its date, × takes the date off.
- **Eat me first.** Using stock always takes the soonest-dated first, however it is used: − on the list, *Use some…*, *I cooked this*, a stocktake. Moving stock to another place takes its dates with it.
- **Date it in two taps.** *Date it* on the undated stock asks how much (all of it to start), then one tap on +3 days, +1 week, +2 weeks, +1 month, +6 months, +1 year, *Same as last time*, or the calendar.
- **Guessed dates for top-ups.** Once something has been dated, the app remembers how long it keeps. The next lot from +, *Put away* or a scanned receipt gets a guessed date ("about 2/12/2026") with nothing to type. Tap it to check it. Things never dated stay undated, so nothing nags.
- The stock row says what to eat first when a batch is due within a week ("eat 2 by Fri", "1 past date").
- The use-by dates page lists each batch on its own row ("2 of 4"), with guesses marked.

### Changed
- Reminders, Home's use-soon count and Insights use the soonest batch.
- A phone still on 0.14 sees the soonest date only. Update both phones, or an edit made on the old one sets the whole item to that date.

## [0.14.0] - 2026-11-18

### Added
- **Drawings of fresh fruit, vegetables and herbs.** 228 ink-and-wash pictures of 141 things sold in Australia, loose or in punnets and bags: 49 fruit, 75 vegetables, 17 herbs (Chris: "every vegetable or fruit we can possibly buy in Australia"). Bundled in the app (1.9 MB, no download), shown when an item has no photo of its own.
- **One of it, or a heap.** 1 potato shows one potato; 2 or more shows a heap of potatoes with the count on it (Chris: "1 x potato. Then when any more than 1 potato is needed, you have a bunch"). Bananas, carrots, bok choy and beetroot go to a bunch; pumpkins, melons and cabbages stay whole, and show the cut piece when you have less than one (half a pumpkin). Berries show their punnet, herbs their bunch, salad leaves their bag. Loose produce kept by weight (1.5 kg of potatoes) shows the heap.
- Names are matched however they are typed: "Shallots" are spring onions, "Kumara" is sweet potato, "Cantaloupe" is rockmelon, "Bell pepper" is capsicum. Things made from produce never get the fresh drawing: tinned tomatoes, orange juice, dried oregano, garlic powder, banana bread, frozen peas.

### Changed
- Produce pictures are not fanned out into a pile any more: the heap or bunch drawing already shows more than one, with "×4" on it. Everything else (tins, jars, packs) still fans out.
- The eight first produce drawings (apples, bananas, carrots, onions, garlic, potatoes, tomatoes, spring onions) are replaced by the new set; the other 22 pantry drawings stay.

## [0.13.0] - 2026-11-17

### Added
- **Photos travel between phones.** A photo you take is shrunk (about 60 KB) and shared with the household, so Emily sees Chris's and the other way round. Photos taken before this update are shared the first time it opens.
- **Our own product library, by barcode.** Add something with a barcode and its name, size, how you count it, where it lives (kitchen or stored away) and your photo go to the library. The next scan of that barcode, on any phone, opens set up that way in under a second. Settings > Household: *Share barcode set-ups and photos* (never your amounts, dates, places or who you are).
- **Count it or measure it, up front.** The add page asks first: *Count them (jars)* or *Measure what is left (500 g)*, with the best guess picked: jam, passata and tins are counted; oil, flour, rice and sauces are measured.

### Changed
- **Scanning is quick.** The library answers first; Open Food Facts only for a barcode nobody has added yet, and only once ever per barcode. The page never waits: after 3 seconds it says it is still looking and fills in later, never over what you typed.
- A product with a known pack size is no longer always set up in grams or millilitres (Chris: "the add item suggested layout ... wasn't always right").

### Dropped
- Generating drawings for every product (16 Nov plan): your own photos and the library do it better. The 30 drawings stay as an option in Settings.

## [0.12.1] - 2026-11-17

### Fixed
- **Dates** (Emily: "Can't do forward slash to manually change date"). Use-by dates are picked on a calendar, never typed, and the app is Australian: 17/11/2026. One-tap buttons under the date: +1 week, +1 month, +6 months, +1 year, +2 years. The receipt date picker is a calendar too.
- **A photo taken on one phone no longer wipes the other's** (Chris: "if Emily takes a photo of the same one I've uploaded, and saves it, it then removes from mine"). Each phone keeps its own photo until photos travel between phones (v0.13).

## [0.12.0] - 2026-11-16

### Added
- **Drawn food pictures.** 30 soft ink-and-wash drawings in the style of *The 90 Day Blackout* (bread, eggs, milk, cheese, butter, yoghurt, rice, pasta, flour, sugar, tinned tomatoes, baked beans, tuna, olive oil, soy sauce, onions, garlic, potatoes, carrots, spring onions, tomatoes, apples, bananas, oats, coffee, tea, chicken, mince, frozen peas, honey), trimmed to sit on the cards and bundled in the app (1.4 MB, no download).
- They go on by name, however it is typed: Shallots get the spring onions, "Tins: fish" the tuna tin, "Diced tomatoes" the tin. Names of their own that share a word (coconut milk, peanut butter, chicken stock, sweet potato) get none rather than the wrong one.
- **Settings > Pictures: Product photos / Drawings.** Your own photos always come first; then whichever you pick, with the other filling in. Shared with the household.

## [0.11.0] - 2026-11-16

### Added
- **Names match however they are typed** (Chris: "We can't have a customer relying on their spelling"). Case, plurals and punctuation never matter, and names that mean the same thing are one thing: shallots, spring onions, scallions; capsicum and bell pepper; coriander and cilantro; cornflour and cornstarch; Panadol and paracetamol; glad wrap and cling wrap, and about 60 more. ADR 0011.
- **Close spellings are asked about, never guessed.** "spring onoins" in a recipe shows *Is it your Shallots? Yes / No*; the shopping list and the item editor ask the same. The answer is remembered on every phone in the household.
- **Every recipe line says which of your things it is.** Tap any line to match it to something else, or to "Not something we keep".
- **Also called** on each item: other names, with commas. Recipes, the list and receipts use them.
- **No twins.** Adding an item you already keep, under any name, offers to add to the one you have.
- Receipts learn: a line matched by hand is matched by itself next time.

### Changed
- One matcher for recipes, the shopping list, voice, receipts and history. Metrics count sure matches only: "onion" no longer counts your spring onions, "milk" no longer counts coconut milk, "rice wine" is not rice.
- Both phones should update: an older version drops the "also called" names when it edits an item.

## [0.10.0] - 2026-11-16

### Changed
- **Warm pantry look** (Chris picked it): a cream page, olive green for doing things, mustard for low, tomato red for out. Headings in Fraunces, everything else in Nunito Sans (both bundled, SIL Open Font License). Softer, rounder cards and chips.
- **Four tabs instead of six:** Home, Pantry, Shopping, Recipes. **Pantry holds everything kept**: the kitchen first (pantry, fridge, freezer), then the extra stock "Stored away" further down (prep pantry, spare cupboard, garage, medical, hygiene). Each place is still a chip at the top. **Insights** opens from the House stock card on Home, and from the button under Running low.
- **Icons instead of letters.** Things without a photo show an icon for what they are (bread, eggs, milk, tins, rice, pasta, batteries, torch, bandages, tablets and more) on their family's colour, or where they are kept when the name says nothing.
- **Lighter stock rows.** The amount reads in plain words ("2 loaves · need 1", "1 loaf", "30 ml of 500 ml"), the place and "about 1 day left" sit on a small line under it, the bar is thinner, and − / + are light round buttons so the row reads first.
- **Tidier shopping list.** A round tick on the left; tap anywhere on a line to put it in the trolley. − amount + on the right. Ticked lines sink to the bottom of their shop. Each shop's heading says how many to get and how many are in the trolley. "Added by" shows only when someone else added it. Hold a line to choose its shop.

## [0.9.1] - 2026-11-16

### Added
- **Instant updates.** While the app is open, each phone keeps a live line (a websocket) to the household. The moment one phone's change lands, the others are told and fetch it: about a second on the same network, two to three seconds across the internet. Changes go 0.8 s after they are made. If the line drops it is opened again (2, 4, 8 … up to 60 s), and the 5-second check carries on until it is back; with the line up, that check eases to every 30 s.
- Household page and the cloud on Home say "Live" while the line is open.

## [0.9.0] - 2026-11-16

### Added
- **Household sync** (Settings > Household, and the cloud on Home). Start a household on one phone, give the code to the other (it works once, for 48 hours), and both phones keep one list: stock, the shopping list, recipes, prices, history, locations and household settings. A change goes 2 seconds after it is made and the other phone picks it up within about 5 seconds while the app is open; it also syncs on opening, and the cloud button syncs now. With no signal, changes wait on the phone and go when it is back.
- Two people using the same thing both count: Emily adds 2 rice while Chris uses 1, and both phones end on +1.
- Joining with a phone that already has a list: **use theirs** (this phone's list is saved to a backup file first) or **add mine**.
- The household server: a Cloudflare Worker with one small database per household, in `server/` (ADR 0010). Tokens are stored only as hashes.

### Not yet
- Your own photos stay on the phone that took them; the other phone shows the product picture.

## [0.8.1] - 2026-11-16

### Fixed
- **Receipts from photos** (Chris: a saved Woolworths e-receipt JPEG could not be read). A tall image is now cut into overlapping sections read at full size, each line kept once; the photo is no longer shrunk to 2400 px wide before reading.
- When a receipt cannot be read, the app says why and shows the text it did read, with a Copy button, so the reader can be tuned on it.

## [0.8.0] - 2026-11-16

### Added
- **Scan a receipt** (Shopping, receipt button: camera or a photo already taken). The phone reads the text itself (Google ML Kit, on the phone; nothing is sent anywhere) and finds the shop, the date, each line with its price, "QTY 3 @ $1.10" and "1.250 kg @ $3.50/kg" quantities, discounts ("Promotional Price -1.50" comes off the line above) and the total.
- **Check the receipt** page before anything is saved: the shop and date, a green "matches the receipt total" check (amber with the difference if a line was missed or misread), each line matched to a stock item where its name fits ("KIKKOMAN SOY SAUCE 600ML" is Soy sauce) and what it adds to stock ("+12" for a 12-pack of eggs, "+600 ml" from the size printed on the receipt). Tap a line to fix it, tap the stock chip to change or clear the match, untick to leave a line out. Weighed lines that cannot become a count (1.25 kg into potatoes counted as items) are not added and say so.
- **Save receipt**: a price for every line (price memory and this week's spend), stock added for ticked lines, and matching shopping-list lines taken off the list. ADR 0009.

### Changed
- The release download is built for 64-bit ARM phones only (both household phones, and every recent Android phone), so it stays small now the receipt reader's text model is included: about a third of the size of a build for every processor type.
- Release builds keep R8 rules for the ML Kit languages that are deliberately not bundled.

## [0.7.0] - 2026-11-16

### Added
- **Reminders** (Settings > Reminders): a **shop-day** reminder on the day and hour you pick ("8 running low, 12 on the list"), **use-by alerts** two days before a date at 9 am (or the day before), and a weekly **backup reminder**. The words are re-booked a few seconds after any stock change, so the counts are current. The phone asks for notification permission when one is turned on. Times are Sydney time.
- **Say it to add it** (microphone on Shopping, Pantry and Storage): say "two tins of tomatoes and a dozen eggs, milk", check the lines, add them to the list or to stock. Number words, "a couple of", "half a kilo", tins / packets / bottles and measures are understood; stock that exists goes up in its own unit (a pack for a measured item), new names become new items. Uses the phone's own speech recognition (Australian English); the phone asks for microphone permission on first use.

### Changed
- Android: compile level 37 (the notification library needs it; target and minimum unchanged); core library desugaring on (needed by the notification library); permissions for notifications, restart re-booking and the microphone; a query for the speech service. ADR 0008.

## [0.6.0] - 2026-11-16

### Added
- **Back up now / Restore** (Settings): the whole household (stock, list, recipes, prices, history, settings) and your own photos in one file, saved wherever you choose with the phone's share sheet (Google Drive, Files, email). Restore warns first, then replaces what is on the phone. Product pictures are not copied; they download again. ADR 0007.
- **Stocktake** (Pantry and Storage, top bar): walk a cupboard one item at a time with its picture: "That's right", or type or step the real count and save; skip; a summary at the end. Logged as "counted", so it never skews "runs out in".
- **Scan to use** (Pantry and Storage, top bar): scan what you are using or binning: used one, used some, or finished the open pack (spare packs stay). A barcode not in stock offers to add it, looked up already.
- **Use-by dates**: every dated item, grouped past its date, within a week, within a month, later, with a filter per cupboard (Medical, Fridge ...). Open it from the "use by soon" tile on Home. Counts the items with no date and suggests dating medicines.
- **Water days** (Home): drinking water in stock against 3 L per person a day (NSW Health and NSW RFS), with - / + for people. Litres come from the unit (40 L) or the name ("Cask water 10 L" x 2 = 20 L); water items it cannot measure are named.

### Not yet
- Food days need calories per item, which the app does not have; it is not guessed.

## [0.5.1] - 2026-11-16

### Fixed
- **Pictures for typed and imported items.** v0.5 only found pictures for scanned items or ones you picked, so a household loaded from a stock list saw letters only. A background finder now looks every item up, one search every few seconds (Open Food Facts limits searches), by barcode when it has one, else by its name. A name match is used only when the product's name holds every word and is about the same thing ("Sugar" takes "Raw sugar", not "Sugar free V"; "Tins: fish" never takes "Fish fingers"). Pictures found this way say "Found by name. Check it is your pack" in the editor. Items with nothing trustworthy keep their letter and are not searched again until renamed, or *Settings > Find pictures again*.
- **I cooked this**: the bottom button sat under the phone's own navigation buttons. Every bottom sheet now keeps clear of them.
- **I cooked this** starting amounts: a line with no amount now starts at one tin / item, 250 g or ml, or a quarter kilo or litre, instead of "1 kg" or "0.1 tins".

### Added
- **I cooked this: type the amount.** Tap any amount to type what you used, in any measure that converts (g, kg, ml, L, cups, tbsp, tsp), with "= 420 g of 1200 g" shown before it is set.

## [0.5.0] - 2026-11-16

### Added
- **Product pictures**: items show a picture of the product. Your own photo comes first; else the product's picture from Open Food Facts, found by barcode (items scanned in v0.4 get theirs automatically) or picked with **Find picture**, a name search of Australian products that shows each one's picture and pack size. Nothing is bundled: each picture (about 4-13 KB) is downloaded the first time it is needed and kept on the phone. No picture: a plain tinted square with the item's first letter, never a wrong picture. ADR 0006.
- **Picture piles**: a card shows one picture per item or pack, fanned out with a "×4" badge: 4 washed potatoes is four, 9 tins is nine, a measured item shows its packs. Things counted by weight or volume without a pack size (3 kg pasta) show one picture, so the pile never claims 3 kg is three packs.
- **− / + on shopping lines**: change how many to buy right on the list; the pile grows and shrinks with it.

### Changed
- Find picture ranks products whose names hold your words first ("washed potatoes" before a facial wash).
- Settings credits Open Food Facts pictures (CC BY-SA 3.0); the editor says "Picture: Open Food Facts" when one is used.
- `tool/screens/fetch_pictures.py` fetches real product pictures for the README screenshots (not committed).

## [0.4.0] - 2026-11-16

### Added
- **Measured stock**: an item can be measured instead of counted: a pack size (e.g. a 500 ml bottle) and how much is left in ml, L, g or kg. Cards read "300 / 500 ml", or "1150 ml · 1 full + 400" with spare packs. The editor takes the pack size, what is left in the open one (with Full / ¾ / ½ / ¼ / Empty), unopened packs, and a target in packs.
- **Use some…**: take an amount off in any measure that converts: ml, L, cups, tablespoons, teaspoons (Australian: cup 250 ml, tbsp 20 ml, tsp 5 ml), or g / kg, with a live "takes 40 ml, leaves 260 ml" line. The - button opens it for measured items; + adds a whole pack.
- **Recipes check the amount left**: a line like "100 ml soy sauce" against 20 ml left shows "Short 80 ml" under *To buy*, with what you have and the last price per shop; *Add to list* adds whole packs. Counts compare only when they count the same thing ("3 eggs" against eggs, not "2 garlic cloves" against bulbs).
- **Scan barcode**: in the item editor, reads EAN/UPC barcodes with the camera (or typed). A barcode already in stock offers to add a pack to it; a new one is looked up on Open Food Facts for the name and pack size. ADR 0005.
- **Take photo**: a photo of the item, kept on the phone and shown on its card.

### Changed
- Running low and recipe top-ups put measured items on the list in packs ("2 × 500 ml"); putting them away adds the amount (1000 ml). Prices for packs show per pack.
- *I cooked this* starts a measured item with no amount on the line at one sensible step (e.g. 25 ml), and uses up what a recipe was short of.

### Known limits
- CSV import/export does not carry pack size, barcode or photo yet.
- Photos stay on the phone that took them until sync (v0.8).

## [0.3.0] - 2026-11-16

### Added
- **I cooked this** on a recipe: lists what comes out of stock, with amounts worked out from the recipe where units convert (500 g pasta from a kg item takes 0.5 kg; 2 eggs takes 2), each adjustable or untickable, then takes it out.
- **Runs out in**: each item's rate of use is learned from the last 30 days of history; stock cards show "~6 days left" (amber within a week), and Home lists what runs out within a week.
- **Price memory**: *Put away* asks, optionally, what each line cost. Prices are kept per shop; an item's editor shows the last price per shop per unit, cheapest first.
- **Spent this week** on Insights: total since Monday, per shop.

## [0.2.2] - 2026-11-16

### Changed
- UI refresh so each element reads as itself: a tinted page with white, edged cards; one meaning per colour everywhere (green fine, amber low, red out).
- Stock items are cards with a coloured edge, a *Low* or *Out* tag, a bold amount against the target, a thicker bar and solid - / + buttons.
- Bottom bar always shows its labels. Section headings are small capitals in the brand colour.
- Shopping list: each shop is a card with its count; the amount sits in a pill; the shop menu shows which shop is chosen.
- Recipe badges and the to-buy icons use the low colour; summary tiles carry coloured icons, and turn amber or red when they need attention; Insights bars follow the same colours.
- Summary tiles have room for larger phone text sizes.

### Added
- `tool/screens/screens_test.dart` renders every screen at phone size with demo data; README screenshots come from it.

## [0.2.1] - 2026-11-16

### Changed
- Recipes page: one banner per recipe (name, time, ingredient count, a *Ready* or *N to buy* badge). Adding to the list happens inside the recipe.
- Recipe page laid out for a phone: the header (what you have, time, source) and the *Ingredients | Method* tabs stay put, only the list under them scrolls, and *Add N missing to shopping list* is fixed at the bottom. Ingredients show with amounts, *To buy* first, then *You have* with the stock item that covers each.
- Method shows as numbered steps, one per line. A linked recipe's method opens the site's print view of the recipe card: ingredients and steps, nothing else to scroll past.
- The add button adds each missing ingredient once, then says they are on the list.

### Fixed
- Headings and page clutter ("Ingredients", "Instructions", "For serving:", "Cook mode", comments, dates, nutrition) are never taken as ingredients or added to the shopping list, including in recipes saved before this version.
- Tick boxes and bullets copied from a web page are stripped from ingredient lines.
- An ingredient list that looks like a whole pasted web page (over 40 lines, or very long lines) is refused with a reason; such a recipe saved earlier is flagged on its banner.

### Added
- Shopping list: *Clear list*, after a yes.
- Pasting a link reads it straight away; no button to find.

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
