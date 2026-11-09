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
