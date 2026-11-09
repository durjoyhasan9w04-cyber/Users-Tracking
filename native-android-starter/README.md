# User Hub Native Android — starter

Kotlin + Jetpack Compose native Android starter for the User Management & DP Tracker.

## Included in this starter
- Dark native Android interface
- Private local SQLite database with core tables modeled on the existing Flask/SQLite app
- Dashboard totals: users, today's DP, DP entries, today's bonus, all-time DP
- Add user and search users
- Daily DP entry with up to five values and a contacted-today flag
- Add bonus with Deposit / Special / Promotional / Other reasons
- GitHub Actions workflow to build a debug APK

## Not complete yet
This is not a full replacement for the web app. Full DP/bonus history views, contact log and follow-up buckets, CSV reports, backup/restore, sports preference editing, match calendar/reminders, and search-based fixture discovery still need implementation.

## Data safety
The Android app creates its own private tracker.db. It does not connect to, change, or overwrite the existing Termux SQLite database. Do not upload live user data to GitHub. Database migration must be separately backed up and tested before real use.

## Build
Open the repository Actions tab and run Build Android APK. When the run succeeds, download the user-hub-debug-apk artifact and extract app-debug.apk. The workflow is the build verification; no APK is claimed until GitHub Actions succeeds.

## Toolchain
Java 17, Gradle 8.9, Android Gradle Plugin 8.7.3, Kotlin 2.0.21, compile/target SDK 35, min SDK 26.