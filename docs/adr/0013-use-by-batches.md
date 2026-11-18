# 0013. Use-by batches, soonest first, guessed dates for top-ups

Date: 2026-11-18. Status: accepted (v0.15.0).

## Context
One use-by date per item was wrong once a second lot came home: 4 yoghurts are often 2 dates. Chris asked for "use-by batches / eat me first" (16 Nov). The risk: receipts carry no dates, so if dating takes more than a tap nobody does it and the feature sits empty.

## Decision
- `StockItem.batches`: dated lots (amount in the item's unit, day, `guessed`). Whatever is over their total has no date. Kept tidy by one function (`normaliseBatches`): one per day, soonest first, never more than the quantity.
- Every decrease, however it happens, goes through `copyWith` and takes the soonest batch first (`takeSoonest`). Move carries the batches it took.
- `keepDays` is learned when someone dates fresh stock. A top-up (+, Put away, receipt) of an item with a `keepDays` gets a guessed batch; never-dated items stay undated (no nagging).
- `useBy` is now the soonest batch's date. JSON still writes `useBy` so a phone on 0.14 reads the soonest date; an old JSON with only `useBy` reads as one batch of the whole quantity.

## Consequences
- An edit saved on a 0.14 phone flattens the batches to one date. Both phones should update.
- Reminders stay one per item (the soonest batch), not one per batch, to keep the alert count bounded.
