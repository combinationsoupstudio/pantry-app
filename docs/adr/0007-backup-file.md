# ADR 0007: Backups are one file the household keeps

- Status: Accepted
- Date: 2026-11-16

## Context
Until sync (v0.11), each phone's household lives only on that phone: a lost or broken phone loses the stock list, prices, recipes and photos. Chris asked for "Back up now" before sync.

## Options
1. **Cloud backup to our own Cloudflare account.** Needs the Worker and accounts that sync will build; too early.
2. **Android Auto Backup.** Silent, Google-controlled, not restorable on demand, and its size cap excludes photos.
3. **One JSON file the person saves** through the phone's share sheet (Google Drive, Files, email), and restores through the file picker.

## Decision
Option 3. The file holds `kind: pantry-app-backup`, when it was made, the store's own JSON (the same shape the app saves), and the household's own photos as base64. Product pictures are not copied: their addresses are kept and they download again (ADR 0006). Restore refuses anything that is not a pantry backup, warns that it replaces what is on the phone, writes photos under new names and points the items at them. Libraries: `share_plus` and `file_picker` (no service, no account).

## Consequences
- No automatic schedule yet; reminders (v0.7) can nudge a weekly backup.
- A backup is readable JSON: it holds what the household keeps (no passwords or payment data exist in the app).
