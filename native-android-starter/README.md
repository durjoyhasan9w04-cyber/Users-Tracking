# User Hub Native Android — v2 glassmorphic rebuild

Native Android application built with Kotlin, Jetpack Compose and on-device SQLite. The visual system uses a dark navy foundation, cyan/violet accents, frosted-glass inspired cards and mobile-first bottom navigation. daisyUI, FlyonUI and shadcn/ui are design references only; they are web libraries and are not embedded in this native app.

## Implemented from the uploaded User Hub v5.5 source

- Dashboard: users, today's DP total and amount count, users with DP today, multiple-DP users, today's bonus, contacted/not-contacted today, monthly DP and bonus, active monthly DP users, no-DP-this-month, never-DP and follow-up queue
- User directory: search by name/number, duplicate phone-number rejection, New vs Previous onboarding type, added date, lifecycle status, separate DP activity status, historical DP/bonus totals and do-not-contact flag
- User profile: full DP history, bonus history, contact history, last DP, days since DP, notes and saved sports/contact preferences
- Daily DP: one new dated record per submission, five optional amount fields, positive-value validation and calculated preview
- Bonus manager: separate dated transactions, related DP amount, Deposit Bonus / Special Bonus / Promotional Bonus / Other reasons and bonus history
- Contact history: status, reason, channel, notes and agreed follow-up date; declined-contact state is respected by reminders
- Follow-up center: Active (0–3), Follow-up (4–7), Inactive (8–14), Long inactive (15–29), Very long inactive (30+) and Never DP, plus not-contacted-today
- Monthly reports and DP activity calendar use transaction dates
- CSV export for users, DP records and bonus records
- Automatic daily local SQLite snapshot when the app starts, manual local snapshots, database export and restore
- Sports preferences: Cricket, Football, Kabaddi, Tennis, Badminton, Esports, teams, players, competitions, language, channel, contact window, frequency and separate consent flags
- Match calendar: automatic best-effort discovery using SportScore, TheSportsDB and selected OpenLigaDB leagues, manual fixtures, Bangladesh time display and source attribution
- Match reminders: grouped internal reminders for relevant fixtures, only for users with contact and event-update consent; do-not-contact and declined-contact users are excluded. No messages are sent automatically.

## Known limitations before production use

- This branch is a development build and must pass the Android build workflow and device testing before installation or real-world use.
- DP and bonus transactions are currently view-only after saving; editing/deleting these accounting records is not implemented.
- Fixture discovery depends on free providers, rate limits and provider coverage. It is not guaranteed to find every worldwide league or match. Verify important fixtures. Kabaddi, badminton, esports and missing events can be entered manually.
- Fixture refresh runs when Match Calendar is opened (with an eight-hour cooldown) or when manually requested. There are no background notifications.
- Daily automatic backup runs when the app starts; it does not run while Android has stopped the app.
- CSV export currently covers users, DP and bonuses; contacts are visible in-app but not exported as CSV.
- The Android UI is not yet a pixel-for-pixel copy of the Flask UI. It is a native Compose implementation of the main workflows.

## Import the existing Termux v5.5 database

The Android app can restore/import a compatible SQLite database using **More → Backup & restore → Restore database backup**.

1. In Termux, stop the Flask server with \`CTRL + C\`.
2. Copy the database to shared Downloads (do not move or delete the original):
   \`\`\`bash
   cp ~/user_management_dp_tracker/data/tracker.db ~/storage/downloads/userhub_v5_5_backup.db
   \`\`\`
3. Open the Android app, go to **More → Backup & restore → Restore database backup**, and choose \`userhub_v5_5_backup.db\`.
4. The app validates SQLite integrity and required tables, creates a safety snapshot of its current database, then imports the selected file. The app upgrades compatible schema columns on open.

The app never accesses or overwrites the original Termux database. Keep a separate copy of that original database until you have checked imported user counts, DP totals, bonuses, contacts, preferences and fixtures.

## Data safety

The Android app stores its own private \`tracker.db\` and local backup snapshots in app-private storage. No live database, user phone numbers, or backups are committed to GitHub. No paid cloud service or Telegram integration is used.

## Build

The pull request is configured to run the Android build workflow automatically for validation.

The GitHub Actions workflow builds a debug APK using Java 17, Gradle 8.9 and Android Gradle Plugin 8.7.3. A downloadable APK is available only after a successful workflow run as the \`user-hub-debug-apk\` artifact. This is a debug build, not a Play Store release.

## Toolchain

- Kotlin 2.0.21
- Jetpack Compose / Material 3
- Android Gradle Plugin 8.7.3
- Gradle 8.9
- Java 17
- compile/target SDK 35, min SDK 26
