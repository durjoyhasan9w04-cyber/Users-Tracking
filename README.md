# User Hub

A new, standalone Android app for user activity tracking and relationship management.

## Technology

- Flutter and Dart
- Material 3-inspired UI
- SQLite local database
- Offline-first architecture
- Android local notifications

## Product principles

- Independent of the previous Flask web app and its database.
- No login/online-activity monitoring feature.
- DP-based lifetime and monthly user levels.
- Separate registered-user and potential-user records.
- Respect contact preferences and notification opt-outs.
- No automatic deposit-promoting messages.

## Build

Install Flutter stable, then run:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

The GitHub Actions workflow builds a release APK and uploads it as an artifact.

## Advanced features

- Advanced analytics: compare a selected 7/30/90-day period with the immediately preceding equal-length period, rank DP contributions, calculate DP active-day consistency, group bonuses by reason, and chart monthly new-user growth.
- Global search across users, activity transactions, quiz participants, quizzes, and activity categories. Activity search is filtered in SQLite before applying the result limit.
- Activity Center record details show the source and exact record ID, date, amount and linked user.
- Dashboard sections can be reordered, hidden, or pinned to the top. Preferences are stored locally.
- Reports support a custom date range and a transaction preview filter by type, user, phone, reason, and notes. Exports use the filtered preview.
- SQLite activity indexes are created idempotently without increasing the main database schema version.

## Optional encrypted Google Drive backup

1. In Google Cloud Console, create a project and enable the Google Drive API.
2. Configure the OAuth consent screen and create an **Android OAuth client** for the app's exact Android application ID and signing-certificate SHA-1 fingerprints. Add the **Web application OAuth client ID** as well; enter that Web client ID in User Hub's Encrypted Google Drive Backup screen.
3. Ensure the Google Drive API is enabled for the same project. The app requests only the `drive.appdata` scope and stores the encrypted backup in the private Drive app-data area.
4. Choose a strong backup passphrase of at least 10 characters. The app encrypts a combined backup of both `user_hub.db` and `quiz_participants.db` with AES-256-GCM and a PBKDF2-HMAC-SHA256-derived key before upload. The passphrase is never uploaded or saved.
5. Keep the passphrase separately. Google cannot recover it; losing it means the encrypted backup cannot be restored.

Google Drive backup is manual and optional. Existing local backups remain available. Before restoring, the app validates both SQLite files and keeps rollback copies while applying the restore. OAuth configuration is required before the Drive connection can be used.
