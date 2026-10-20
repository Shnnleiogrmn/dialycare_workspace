# DialyCare Staff

This is the existing staff Flutter application, repaired and rebuilt against
DIALYCARE(Staff).pdf. Open this directory as the project in VS Code or Android
Studio, then run:

```sh
flutter pub get
flutter run
```

Choose Windows if prompted, or use `flutter run -d windows`. Windows and web
runners are included. Flutter 3.47.6 / Dart 3.13.5 were used for verification.

The app begins with demonstration records. Patient edits, relatives, medical
notes, schedules and notification read states persist on this device. Windows
storage is `%APPDATA%/DialyCare/Staff/workspace.json`; web uses local storage.
Profile actions provide help, a local workspace password and logout. No remote
clinical database, messaging service or account authentication is connected.
The password locks the UI; it does not encrypt the saved records.

Run `flutter analyze` and `flutter test` to verify. Tests exercise navigation,
forms, pickers, persistence, password verification and responsive layouts.
Rendered verification screenshots are in `verification/screens`.

For project-wide platform repair details and verification limitations, see the
workspace root README.md and VERIFICATION.md.

## Notification extension

Patient and relative app registration status now appears in the existing details
panel; click a patient's name or a Schedule/Session View. Send Reminder selects
recipients and automatically routes through the notification service. Session
status changes and schedule edits/cancellations generate persisted events and
recipient delivery records. Notifications shows channel/status and attempt history.

Providers are currently unconfigured: no real Push or SMS is sent and no fake
success is shown. Timed reminders have a backend scheduler entry point, but no
UI-only delivery timer. See [NOTIFICATION_SETUP.md](NOTIFICATION_SETUP.md) for the
integration contracts and exact services/credentials still needed.

A native workflow test is available with:

```sh
flutter test integration_test/notification_flow_test.dart -d windows
```

It uses isolated in-memory data and cannot contact real recipients.

## Session management update

The dashboard header is compact. In Sessions, use **Manage** to select a status,
then **Update Status** and **Confirm**. Dashboard, Schedules and Reports read the
same persisted session state. Existing notification routing is reused.

Sessions retain their tabs and are grouped by batch, ordered by start time. The
list defaults to today; the date selector opens other appointment dates. Details,
reminders and schedule editing remain available.

See [SESSION_MANAGEMENT.md](SESSION_MANAGEMENT.md) for mappings, migration and
verification, including the native window-control limitation.


### Shared Patient/Relative backend

Profile -> Connect care center now opens the authenticated cloud workspace. Existing local data remains local and is not automatically imported. The cloud workspace starts empty, uses staff Firebase authorization, and shares canonical sessions and notification history with `../dialycare_mobile`. Follow `../backend/README.md` for required deployment, staff authorization, invitation linking, FCM and SMS setup. Local mode remains available with its existing features. Do not treat local demo data as synchronized clinical records.
