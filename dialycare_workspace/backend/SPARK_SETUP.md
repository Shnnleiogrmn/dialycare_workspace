# DialyCare Spark backend

Current account and ID workflow: [ACCOUNT_SYSTEM.md](ACCOUNT_SYSTEM.md).
Verification and limitations: [20 October repair report](BACKEND_UI_IDS_REPORT_2026-10-20.md).
Session timing and synthetic data: [workflow and setup guide](SESSION_TIMER_AND_DEMO_DATA.md).
The 20 October 2026 implementation keeps the existing Staff/Mobile projects and
**dialycare-backend-3f0ed** on Spark. Patient/Relative onboarding is public ID +
Temporary PIN, then public ID + password (8–16 characters for new passwords).
Email-based Patient/Relative activation instructions in older reports are historical.

Use the app directories `dialycare_staff` or `dialycare_mobile` within the workspace:

```powershell
flutter pub get
flutter run
```

Staff Windows, Mobile Android, and the configured Mobile Windows preview share
the same backend. No separate local backend service or Cloud Function is required
for normal application use. Approved Staff mappings require `role: staff` or
`admin`, `accountStatus: active`, and `disabled: false`; roles are not self-assigned.

The current rule source is `firestore.spark.rules`. Trusted deployment uses:

```powershell
firebase deploy --only firestore:rules --config firebase.spark.json --project dialycare-backend-3f0ed
```

ID migration tooling remains outside Flutter. `node migrate-center-ids.cjs`
previews the existing-project plan; `--apply` is an explicitly privileged operation.
Do not rerun migrations merely to start the app. See the current implementation
report for the migration and live-verification result.

## Historical implementation notes

The remaining notes describe earlier checkpoints and are retained for context.
Where they mention email verification, old ID formats, or previous dates, follow
[ACCOUNT_SYSTEM.md](ACCOUNT_SYSTEM.md) instead.

## App connection

Staff now opens the existing shared-workspace sign-in screen by default. Its
approved Firebase email/password account must have a trusted `users/{uid}` Staff
mapping. An explicit legacy local preview remains available with
`--dart-define=DIALYCARE_CLOUD=false`; that mode does not synchronize or upload its
sample workspace. Never use preview data as evidence of a live connection.

Mobile preserves role selection and its visual design. New accounts use the
center-issued Activate Account flow and real email/password credentials.
Firebase Auth and Rules enforce verified ownership, an immutable UID mapping,
the active binding and current relationship. Knowing a Patient ID grants nothing.

Both apps use `core_shared/lib/firestore_repository.dart`. Firebase ID tokens
authenticate directly to Firestore REST and are subject to Security Rules. No
service-account credentials are included. The original Functions adapter/code is
retained for future privileged features but core reads, writes, and in-app
notifications no longer call it.

## Implemented schema

| Path | Content and access |
| --- | --- |
| users/{uid} | Immutable approved role/care mapping. Staff/Admin provisioning is trusted-only; Mobile can create only its own mapping through a rules-validated atomic invitation claim. |
| accountBindings/{role}_{recipientId} | Unique pending invitation or activated owner, current accountStatus, activationId and server activatedAt. Staff can disable/enable approved Mobile access without changing ownership. |
| invitations/{secret} | Private email-bound, expiring, single-use activation; see ACCOUNT_SYSTEM.md. |
| patients/{patientId} | Existing Staff patient fields, including private clinical/contact fields. Staff only. Relatives are normalized separately. |
| patientProfiles/{patientId} | id/name only, a minimal materialized coordination projection. Saved atomically with patient changes; readable only by Staff and authorized linked Mobile accounts. It is not an independent patient record. |
| relatives/{relativeId} | Existing Companion fields, excluding relationship and registration. Staff or the currently linked relative can read. |
| patientRelativeLinks/{relativeId}_{patientId} | relativeId, patientId, relationship, active. Staff controls relationships; Mobile cannot create links. |
| sessions/{sessionId} | Existing shared SessionRecord. start/room/batch describe the planned schedule; status/progress/expectedEnd/revision describe operation. No duplicate schedules collection. |
| notifications/{id} | Per-recipient immutable message/event/session fields, recipientKey, server-created createdAt, recipient readAt, independent staffRead, and channel attempts. Mobile can update only its own readAt with server time. |
| clinical/state | Staff-only revision metadata, Staff summary notifications/event deduplication and staffName. No full clinical snapshot or credentials. |

Patient/Relative session queries include their mapped patientId. Notifications
queries include their exact role:recipientId:patientId recipientKey. Mobile never
downloads all patient records and filters them. No composite indexes are needed
for these single-field equality queries. Sorting happens after scoped retrieval.

Staff assembles the existing store from normalized documents, so Dashboard and
Reports use the same authoritative data as Patients/Schedules/Sessions. A revision
updateTime precondition protects atomic commits from stale Staff saves. Patient
projection, relatives/links, session transition and new pickup notifications are
committed together. Repeat transitions do not enqueue duplicate pickup events.
This is client-originated business logic, not an autonomous server trigger.

Notifications are available **in app**, without claiming background push, SMS, or
phone delivery. The recipients' readAt timestamps are preserved through Staff
updates. Staff marking history read uses staffRead and does not mark a recipient's
notification read.

Current refresh is periodic: Staff 20 seconds, Mobile 15 seconds, plus explicit
refresh and notification reads. It is not a Firestore snapshot listener. Monitor
Spark read quotas; high-volume or always-on use needs listener/pagination work.
Atomic saves are capped at 450 writes and report an error rather than splitting
a coordinated operation or silently overwriting records. Legacy server snapshots
are rejected with a migration message instead of being silently uploaded/rewritten.

## Current onboarding

Use [ACCOUNT_SYSTEM.md](ACCOUNT_SYSTEM.md) for Staff-issued Patient/Relative
activation and recovery. The normal Mobile UI uses **Activate Account**; there
is no unrestricted signup or public Staff role creation.

## Legacy controlled provisioning reference

The steps below are retained only for trusted setup of older fictional ID-only
fixtures. They are not the current Mobile onboarding path. Staff Flutter cannot
create privileged Auth accounts, view passwords, or assign Staff privileges.

1. In the existing project's Authentication Users section, the account owner/
   trusted development administrator creates an Email/Password identity. Use a
   real controlled email for Staff. Do not put passwords in source, Firestore,
   shell arguments, reports, or Flutter configuration.
2. Copy the Staff account UID. From this backend directory, the signed-in trusted
   administrator runs `node tools/link-spark-user.cjs STAFF_UID staff`.
3. Sign in through Staff and create fictional patient/relative domain records.
   The Patient form normally assigns a DC-... ID; use the actual generated IDs
   when provisioning normal UI accounts. TEST-001 is exercised programmatically
   through the actual StaffStore/repository in the emulator verification flow.
4. Create the Patient Auth identity using the role-specific internal alias:
   `test-001@patient.dialycare.invalid` for TEST-001 (or lowercase actual Patient ID).
   The Relative alias is lowercase Relative ID + `@relative.dialycare.invalid`.
   These are internal identifiers, not password-recovery email inboxes.
5. Link an existing Auth UID only after verifying ownership:

   ```powershell
   node tools/link-spark-user.cjs PATIENT_UID patient TEST-001
   node tools/link-spark-user.cjs RELATIVE_UID relative TEST-001 TEST-R001
   ```

   The tool uses the already authenticated Firebase CLI on this trusted Windows
   workstation. It checks Auth identity, expected alias, patient profile and
   designated relationship. A create-only precondition prevents silently replacing
   an existing mapping. It never requests a password or prints credentials.
6. Mobile selects the approved role and signs in with its visible ID/password.

Legacy aliases cannot receive recovery email. Current real-email activation uses
the atomic, rules-enforced claim described in ACCOUNT_SYSTEM.md. No real patient
data should be used before the center completes live acceptance testing.

## Rules and verification commands

Both `firebase.json` and `firebase.spark.json` pin `(default)` and Singapore
`asia-southeast1`. Active rules are `firestore.spark.rules`; the old deny-all
`firestore.rules` and functions source are historical, not the active Spark target.
Never deploy a different database location or assume configuration proves the
actual location. Verify first with the existing Firebase project.

```powershell
firebase deploy --only firestore:rules --config firebase.spark.json --project dialycare-backend-3f0ed
npm ci
firebase emulators:exec --only firestore --config firebase.spark.json --project demo-dialycare-activation "node --test --test-concurrency=1 rules.test.cjs activation.rules.test.cjs"
firebase emulators:exec --only firestore --config firebase.spark.json --project demo-dialycare-spark "node run-staff-emulator.cjs"
```

Emulator tests use unsigned **emulator-only** identities in test code, never in
the production app. They do not demonstrate real Firebase Auth login. The
repository flow uses real HTTP, the actual StaffStore and the actual repository
under emulator-enforced rules, including stale saves, read timestamps and
revocation. The 17 official rules tests cover activation, roles and denied paths.
Local test dependencies use patched gRPC; npm audit reported zero vulnerabilities.

## Run the existing applications

```powershell
cd 'C:\Users\INFINIX\OneDrive\Documents\Desktop\dialycare_workspace-main\dialycare_workspace\dialycare_staff'
flutter pub get
flutter run -d windows
```

```powershell
cd 'C:\Users\INFINIX\OneDrive\Documents\Desktop\dialycare_workspace-main\dialycare_workspace\dialycare_mobile'
flutter pub get
flutter devices
flutter run -d YOUR_ANDROID_DEVICE_ID
```

Firebase project setup and approved account links must work before these launch
commands can demonstrate live shared data. Compilation alone does not verify it.

Reference: Firebase documents that [REST requests using Firebase ID tokens are
subject to Firestore Security Rules](https://firebase.google.com/docs/firestore/use-rest-api).
The local authorization suite uses the [official Rules testing workflow](https://firebase.google.com/docs/rules/unit-tests).

## Staff login checkpoint — 17 October 2026

The Staff identity shown by the owner now has its approved Firestore role mapping.
Creating an Auth user alone does not grant Staff access; the users/{uid} mapping
is also required. Passwords were not changed. Existing app instances can retry
Connect immediately because the mapping is server-side. Rebuilding is required
only to display the new, more specific error messages on future failures.
