# Rappel+

Rappel+ is a privacy-conscious mobile companion for reminders, routines and
habits. It supports local scheduling, optional app locking, accessibility
preferences, and eight interface languages.

## Development

```bash
flutter pub get
flutter analyze
flutter test
```

## Release checks

Run `./build.sh` on macOS/Linux or `./build.ps1` on Windows. The scripts run
static analysis, tests, and Android release builds. Android release artifacts
are signed with the debug key until a production signing configuration is
provided; do not upload them to a store.

For a store build, configure a private release signing key in the Android
project/CI environment, then build the AAB with `flutter build appbundle
--release`.
