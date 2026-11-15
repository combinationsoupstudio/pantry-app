# ADR 0001: Flutter for the Android app

- Status: Accepted
- Date: 2026-11-15

## Context
The app must install on two Android phones now, and may reach other households and iPhones later. It is also a portfolio piece, so it should be built with tools and practices a working mobile team would recognise.

## Options
1. **Flutter (Dart).** One codebase for Android now and iOS later. Mature testing (unit, widget, integration), strong Material 3 support, builds cleanly in CI.
2. **Kotlin + Jetpack Compose.** The native Android choice. Best platform fit, but iPhone would mean a second app.
3. **An installable web app.** Fastest to start, but not a real app on the phone, and weaker offline and notifications.

## Decision
Flutter, on the stable channel, pinned in CI (3.50.0). Material comes from the `material_ui` package, where Flutter 3.47+ moved it.

## Consequences
- Android first; iOS needs only platform setup when it is wanted.
- Widget tests stand in for most manual checks, and CI runs them at phone size.
