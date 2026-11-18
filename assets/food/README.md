# Drawn food pictures

22 ink-and-wash drawings, one per everyday pantry food, shown for an item with no photo of its own (or for every item, when Settings > Pictures is set to Drawings).

- Made 16 Nov 2026 with Higgsfield `gpt_image_2_6` (text to image, 1:1), in the house ink-and-wash style of *The 90 Day Blackout* adapted for small icons. The prompts are in `jobs/INIT-pantry-app/design/icons-preview-20261116/_prompts.json` in the studio folder.
- Trimmed: the cream paper flood-filled away from the edges (tolerance 28), cropped to the drawing, squared with a 6% margin, 192 px, transparent PNG.
- Which names get which drawing: `artFor()` in `lib/ui/widgets/item_look.dart`.

## Fresh produce (`produce/`, v0.14)

228 drawings of 141 fruit, vegetables and herbs, named `<item>-<variant>.png`: `1` and `many` (picked one by one), `1` and `bunch`, `whole` and `cut`, or one of `bunch`, `punnet`, `bag`. Which names get which, and which picture for how many: `produceArt()` in `lib/ui/widgets/produce.dart`.

- Made 17-18 Nov 2026 with Higgsfield `gpt_image_2_6` (54.5 credits + 2.5 for the test), same house style. Prompts, contact sheets and 512 px masters: `jobs/INIT-pantry-app/design/produce-20261117/` in the studio folder.
- Trimmed as above (tolerance 40), 192 px, then cut to 128 colours (no dither) to keep the set at 1.9 MB.
