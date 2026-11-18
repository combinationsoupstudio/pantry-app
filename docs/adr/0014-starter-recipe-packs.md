# ADR 0014: Starter recipes come in text packs, our own or openly licensed

- Status: Accepted
- Date: 2026-11-18

## Context
The household asked for the app to be bulked out with 200+ recipes with full methods, in Australian metric, across a broad range (Chris, 18 Nov 2026). ADR 0004 stands: no recipe site's method is copied into the app or this public repo. Chris ruled out Wikibooks and picked two sources: free Australian government cookbook recipes, credited, and recipes written for the app.

## Options
1. **Code.** Recipes as Dart constants, like the first short starter ideas. Rejected: 200 recipes with methods is content, not code, and nobody should need a build to fix a typo.
2. **JSON.** Machine-friendly, but noisy to write and review by hand.
3. **A small plain-text format** (docs/recipe-pack-format.md), parsed on the phone at start, checked by a test.

## Decision
Option 3. Packs live in `assets/recipes/`, about 50 recipes each, four packs to reach 200+. A recipe is either written for Pantry (credit `original`) or adapted from a source whose licence allows it, such as Queensland Health's *Healthy New Communities Cookbook* (CC BY 4.0); the credit, the licence and what was changed travel with the recipe and are shown under its method. Every pack recipe is marked untested until rated.

Ingredient lines can name the part of the recipe they belong to; the part is metadata on the line, never a line itself, so headings cannot reach the shopping list. Salt and pepper are "basics": assumed when untracked, never on the list unless the household tracks them and has run out.

## Consequences
- The starter library is the packs first, then the short starter ideas whose names no pack replaces.
- A pack with a bad line still loads what it can on the phone; the test fails the build on any error.
- Ratings (to clear *Untested*) are the next step; until then the label stays on.
