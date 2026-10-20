# Compact header and session management

The existing staff app was updated in place. Sidebar, assets, navigation, main
page layouts and notification provider architecture are preserved.

## Header

The dashboard's bell/date container previously added 20 pixels above and below a
48-pixel control row (88 pixels total). It now has a fixed 48-pixel height and
horizontal padding only. The greeting starts 18 pixels below it. Header height
never depends on screen height. Date text is single-line with an overflow guard.

## Session controls

Sessions Management is the operational page. Each row has a compact Manage action
and retains View for details/reminders. Manage Dialysis Session shows the patient,
ID, scheduled batch/room/time, authoritative current status and a typed selector:
Pending, In Progress, Completed, Ready for Pick Up, Missed.

Selecting a value changes only the draft. Update Status opens a confirmation
panel before persistence. Controls are disabled while updating. The existing
local workspace sign-in gate is checked; stale dialog revisions are rejected.
Staff can correct a status back to Pending or another supported state, with
confirmation. No irreversible transition rules were invented.

SessionRecord.status is a SessionStatus enum, and saved JSON retains the existing
labels for compatibility. Old `Missing` labels migrate to Missed. Legacy Waiting
and Cancelled records remain readable, but are not new operational selector
choices. Patient.status remains legacy demonstration seed metadata only; operational
screens and reports never read it as a current session status.

All relevant screens read the same SessionRecord list. There is no extra report
status or copied dashboard state. One StatusChip style is shared across screens;
Missed has a distinct muted red badge.

Status changes persist through the existing StaffStore transaction. Failed writes
roll back status and queued events. After persistence, the existing notification
service dispatches the queued event. A notification-recording failure is reported
as a saved session with a delivery warning, rather than falsely claiming the
session failed to save or that a message was delivered.

- In Progress: Session Started event, once per persisted transition.
- Completed: treatment completion recorded; no pickup message.
- Ready for Pick Up: existing patient/relative pickup workflow, once per transition.
- Missed: recorded and included in Reports; no invented pickup message.

The existing Push/SMS providers remain unconfigured. This work does not claim real
message delivery or introduce another notification service. Timed reminders and
real provider/backend integration requirements remain in NOTIFICATION_SETUP.md.

## Batch organization

Sessions defaults to today. A compact date selector preserves access to other
scheduled/historical dates. The existing Ongoing, Upcoming and Completed tabs
remain. Their selected sessions are grouped by the session's assigned batch,
not the patient's default batch. Headers show unique patient counts.

- Upcoming: Pending.
- Ongoing: In Progress; existing Waiting records remain here.
- Completed tab: finished records (Completed, Ready for Pick Up, Missed, and legacy
  Cancelled), retaining access for corrections.
- Dashboard Active Sessions counts In Progress only. Its Completed summary counts
  finished treatment (Completed/Ready for Pick Up), excluding Missed/Cancelled.

Batch order is deterministic, including A..Z..AA and numeric batch suffixes. Rows
sort by scheduled start time, then patient/session IDs for deterministic ties.
All batch tables use identical column definitions for headers and body cells.
Progress is retained for Ongoing; every tab shows Batch, Status and compact actions.
Horizontal scrolling is available when the window cannot fit the columns.

## Verification

Flutter 3.47.6 / Dart 3.13.5 on Windows:

- Dependency resolution succeeded; analysis reports no issues.
- All 36 tests pass, including the original notification/UI tests and new status,
  persistence, stale-edit, correction, grouping, sorting, and header-size tests.
- Native Windows integration exercises Pending → In Progress → Completed → Ready
  for Pick Up, Pending → Missed, correction back to Pending, confirmation cancel,
  Dashboard count changes, Reports and notification event deduplication.
- Rendered screenshots were reviewed at 1920x1080, 1280x720 and 900x600. Header
  height is also tested at 390x650. Screenshots are in verification/screens.
- Normal Windows build/launch and production web build succeeded.
- No real patients/relatives were contacted. Tests use isolated records.

The native desktop-control tool failed to initialize (`failed to write kernel
assets: The system cannot find the path specified`). Native workflow execution is
verified, but directly clicking maximize/restore on the OS window could not be
verified. Rendered large/restored dimensions and compact-header geometry were
checked instead; this distinction is deliberate.

Run the staff project normally with `flutter pub get` and `flutter run -d windows`.
The native workflow test is:

```sh
flutter test integration_test/session_management_flow_test.dart -d windows
```



October 15 integration: `SessionStatus` and `SessionRecord` now live in `../core_shared/lib/session.dart`; the original Staff import re-exports them for compatibility. Both frontends use that model. Shared serialization writes UTC timestamps and converts them to local display time when read; legacy local timestamps remain readable. See `../backend/README.md` for the authenticated cloud mode and pending deployment.
