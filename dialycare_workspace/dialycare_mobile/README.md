> Current integration: [Spark setup](../backend/SPARK_SETUP.md). Core data now uses authenticated Firestore access. Older Cloud Functions, invitations, billing, and push setup below describes the previous architecture. See the current implementation report for verified limits.

# DialyCare Mobile

Reuses the original `dialycare_patient` Flutter project, renamed to support both Patient and Relative. Android/iOS application identities are preserved for the existing Firebase registrations.

The twelve-page mobile reference was reviewed before implementation. The first blue/wave opening design is used, with the original dark mobile logo, navy Patient button and teal Relative button. Role-specific authentication, secure invitation registration, Home, Schedule filters/details, persistent Notifications, Profile, password change and logout share the same visual language. Production screens contain no sample patient records.

From this folder:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

Connect an Android device with USB debugging or start an Android emulator first. iOS requires macOS/Xcode, signing and APNs setup.

**Manual backend setup is required before accounts or synchronization work.** Follow [the shared backend guide](../backend/README.md). Firebase Core configuration already points to `dialycare-backend-3f0ed`, but enabling Authentication, deploying the server, granting staff access, issuing invitations, and configuring FCM/APNs/SMS are separate steps. Running the app does not deploy cloud infrastructure.

The default server URL matches that project; override `DIALYCARE_API_URL` only if deployment prints a different endpoint. Patient login uses Patient ID + password; Relative uses its center-issued Relative ID + password. Names and links come from verified center records. Knowing a Patient ID alone grants no access.

Notifications are loaded from shared persisted history, not fabricated locally. Foreground FCM messages refresh the history; background notifications use generic lock-screen text. Logout requires an online device revocation before clearing the session. Screens handle loading, retry, empty states and errors. Information refreshes every 15 seconds while the app is active, on push, and by pulling down a screen.

Visual verification captures are in `verification/`; fixtures used in tests never enter production screens. See the workspace `VERIFICATION.md` for actual test/build results and outstanding device/cloud checks.


Verification limitation: the supplied Android image could not complete a stable user boot on this machine. APK installation succeeded, but package/activity services repeatedly became unavailable. Android application launch is not confirmed; retest using a working physical device or emulator. The temporary emulator was removed after testing. No Dart analysis errors remain and all mobile widget/data/layout tests pass. Native Staff Windows launch and its workflow test passed.

Windows preview: run `flutter run -d windows` from this folder. Its Firebase options reuse the existing DialyCare desktop registration in the same project; backend authorization still controls Patient/Relative access. Windows does not register an FCM token. Windows preview build/launch is verified after clearing the old renamed-project CMake cache and restoring the missing native Authentication libraries. Android device verification and backend deployment requirements above are unchanged.
