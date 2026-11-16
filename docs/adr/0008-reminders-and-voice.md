# ADR 0008: Reminders are local notifications; voice uses the phone's own recogniser

- Status: Accepted
- Date: 2026-11-16

## Context
Chris asked (16 Nov 2026) for reminders (running low on shop day, use-by alerts) and for adding things by voice. No server exists yet (sync is v0.11), and the studio rule is to use what the phone and existing accounts already provide.

## Decision
- **Reminders**: `flutter_local_notifications` + `timezone`, scheduled on the phone. A pure planner (`logic/reminders.dart`) decides what to book; `ReminderService` cancels and re-books the plan 3 s after any stock change, so "8 running low" is current. Inexact timing (`inexactAllowWhileIdle`): no exact-alarm permission, a few minutes' drift is fine. Times are `Australia/Sydney` (the household's zone; a device-zone lookup would add another plugin). Settings live in the store's `settings` and travel in backups.
- **Voice**: `speech_to_text`, which uses Android's built-in speech recognition (Google's on these phones), `en_AU`. A pure parser (`logic/voice_parse.dart`) turns words into lines; nothing is added until the person presses Add.

## Consequences
- New permissions: POST_NOTIFICATIONS and RECORD_AUDIO (both asked at first use), RECEIVE_BOOT_COMPLETED (re-booking after a restart). Core library desugaring is on.
- Reminders come from each phone separately until sync.
- Speech may be sent to Google by the phone's recogniser (the phone's own setting decides on-device or online); the app keeps only the words it shows.
