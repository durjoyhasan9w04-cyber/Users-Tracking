# User Hub Native Android — glassmorphic rebuild

A native Android app built with Kotlin, Jetpack Compose and a private on-device SQLite database. The UI is rebuilt around a dark navy / cyan / violet glass-inspired visual system. daisyUI, FlyonUI and shadcn/ui are design references only; they are web libraries and are not embedded in this native app.

## Implemented in this rebuild
- Redesigned dashboard with today's DP, today's bonus, monthly DP/bonus, DP entry count, multiple-DP users, contacted-today count and quick actions
- Add and search user profiles; duplicate phone numbers are rejected
- Daily DP entry with five optional amount fields and automatic total preview
- Separate bonus entries with Deposit / Special / Promotional / Other reasons
- User profile lifetime DP and bonus totals, first-added date and last DP date
- Follow-up queue based on last DP date: Active (up to 3 days), 4–7, 8–14, 15–30, 31+ and Never DP
- Monthly DP totals grouped by transaction date
- Sports preferences: sports, teams/players, competitions and language
- Manual match calendar entries

## Not yet implemented / not verified
- Full searchable DP and bonus transaction history and editing/deletion
- CSV export and scheduled monthly archive
- User-triggered database backup/restore and automated daily backup
- Automated online fixture discovery / Google search sync (manual fixtures only)
- Match-to-user relevance matching and reminder scheduling
- Import/migration from the Flask + Termux SQLite database
- Complete automated UI and device-runtime testing

Do not treat this build as a complete replacement for the web app until the remaining items are implemented and tested.

## Data safety
The Android app uses its own private `tracker.db` on the device. It does not connect to, change, or overwrite the existing Termux database. Never commit real user records, phone numbers, database files, or backups to GitHub. Back up the old web app database separately before any future migration.

## Build
GitHub Actions builds a debug APK on pushes to branches and on manual workflow dispatch. The workflow must complete successfully before an APK can be considered build-verified. Download the `user-hub-debug-apk` artifact from the successful Actions run.

## Toolchain
Java 17, Gradle 8.9, Android Gradle Plugin 8.7.3, Kotlin 2.0.21, compile/target SDK 35, min SDK 26.
