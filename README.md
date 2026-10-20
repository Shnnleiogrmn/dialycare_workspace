# DialyCare

The existing Staff app and Patient/Relative Mobile app share the existing Firebase project **dialycare-backend-3f0ed** on Spark. The current clients use Firebase Authentication and authenticated Firestore access. Cloud Functions, Blaze, a separate backend server, and a second Patient database are not required.

Verified SDK: Flutter 3.47.6 / Dart 3.13.5. The package constraints require Dart >=3.13.2 <4.0.0.

## Run Staff

Open `dialycare_workspace/dialycare_staff` as the Flutter project:

```sh
flutter pub get
flutter run
```

Choose Windows if Flutter asks for a target, or use `flutter run -d windows`. Normal startup opens the Staff login for the shared workspace. Existing Staff credentials and roles are unchanged; there is no public Staff signup. Local demonstration mode remains available for development with `--dart-define=DIALYCARE_CLOUD=false`; it does not automatically upload a local sample workspace.

## Run Patient/Relative Mobile

Open `dialycare_workspace/dialycare_mobile` and run the same two commands. Use an attached Android device/emulator for Android, or `flutter run -d windows` for the desktop preview. iOS execution requires macOS/Xcode and was not verified on this Windows machine.

Select Patient or Relative. First-time access uses the **current center-issued ID and PIN**, followed by the owner's chosen password. Normal login uses that ID/password. It does not require a real email inbox. Staff authorize access through **Patient Details → Mobile Access**. A retired Relative link does not transfer its owner's login to a replacement identity; use the current Relative shown in Staff.

## Current UI and session controls

The Dashboard prioritizes today's operations with a compact group chip. Schedules use date-aware batch panels and explicit Patient selection. Batch hours/capacity are optional Center Admin configuration; MWF/TThS remains the Patient's regular day group. Gender avatars use stored gender with a neutral fallback.

Staff can Start, Pause, Resume, Complete, End Early, or cancel a pre-start appointment through the appropriate confirmed workflow. Reasons/notes remain Staff-only. Shared timing survives restart, excludes pauses, and never automatically completes a session at 100%. Mobile views are read-only. In-app notifications are supported; SMS/push delivery is not claimed.

## Verification and documentation

- [Current 43-point implementation and verification report](dialycare_workspace/backend/UI_SESSION_REPORT_2026-10-21.md)
- [Session/scheduling usage guide](dialycare_workspace/backend/SESSION_INTERRUPTION_GUIDE.md)
- [Current Spark architecture/setup](dialycare_workspace/backend/SPARK_SETUP.md)
- [Account system](dialycare_workspace/backend/ACCOUNT_SYSTEM.md)

Run `flutter analyze` and `flutter test` in each of `core_shared`, `dialycare_staff`, and `dialycare_mobile` under `dialycare_workspace`. The containing workspace and `core_shared` are not runnable apps. The report records real Firebase verification, security tests, builds, launch results, and remaining platform/toolchain limits.

The original DialyCare artwork is retained. Shared avatar assets are declared in `core_shared/pubspec.yaml`; both apps retain their existing Material icon and other asset declarations. Staff uses the platform Arial font.
