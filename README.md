# ExamReady

ExamReady is a Flutter application for students to track examination information
from traceable official sources. The foundation deliberately contains no
examination records, fabricated dates, scraping, or AI extraction.

## Technology baseline

- Flutter and Dart; Android is the first target.
- Riverpod for application state.
- Firebase Authentication, Cloud Firestore, Cloud Messaging, Cloud Functions,
  and App Check are the planned backend services.
- A Flutter Web admin application will share domain contracts later.

## Firebase setup (not committed)

1. Create separate Firebase projects/environments (at least development and
   production).
2. Register the Android app and use FlutterFire CLI to generate
   `lib/firebase_options.dart` and platform configuration files.
3. Enable Email/Password, Google, and Phone providers in Firebase
   Authentication. Do not store passwords outside Firebase Authentication.
4. Configure Firestore rules, Cloud Functions authorization, FCM, and App
   Check before connecting production data.

Generated Firebase files and platform configuration are ignored intentionally;
they must never include privileged service-account credentials in this repo.

## Current boundaries

`lib/core` contains application-wide contracts and navigation foundations.
`lib/features` follows feature-local `domain`, `data`, and `presentation`
layers. Domain contracts do not depend on Firebase, so Firebase adapters can be
introduced without coupling the application to its transport layer.

Run `flutter pub get`, then `flutter run` after Flutter and Android SDK tooling
are installed. This repository currently does not include a Firebase project
configuration, so Firebase initialization is intentionally not invoked.
