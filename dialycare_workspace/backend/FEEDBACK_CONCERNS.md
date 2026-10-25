# Feedback & Concerns

Structured, authenticated tickets connect Patients/designated Relatives with the
existing Staff workspace. This is not public chat or an emergency-care channel.

## Access and workflow

- Mobile: bottom navigation **Feedback → Submit New Concern / My Concerns**.
- Staff: **Feedback & Concerns** in the sidebar (or compact navigation drawer).
- Categories: Feedback, Complaint, Service Concern, Application/System Issue,
  Schedule Concern, Other. Related areas provide optional context without
  attaching clinical records.
- Statuses advance **Submitted → Under Review → Resolved → Closed**. Sending a
  first response also moves Submitted to Under Review. Resolved/Closed tickets
  do not accept further responses; Closed is terminal.
- Staff can search by reference/subject/authorized identity and filter by type,
  status, and submission date. Submitted/Under Review/Resolved/Total counters
  provide the inbox indicator. Open pages refresh approximately once per minute
  in the foreground; explicit Refresh is also available. Detail dialogs have
  explicit Refresh. No instantaneous/background delivery is promised.

## Authoritative records and identity

`feedbackConcerns/{concernId}` stores the original category, area, subject,
message, authenticated submitter UID/role, authorized Patient ID, Relative ID
when relevant, server timestamps, workflow revision, and resolution/closure times.
The form never accepts a UID or selectable Patient relationship. The shared REST
repository obtains identity from the existing trusted account mapping.

`feedbackConcerns/{concernId}/responses/{responseId}` stores append-only Staff
responses, responder UID/role, and server time. Replies use the workflow revision
for a stable response ID. A preconditioned atomic commit updates the parent,
appends a response when present, and creates one generic in-app notification.
Original content and original timestamps are never rewritten by this update.

Staff resolves display names and public Patient labels from authorized existing
records instead of duplicating profile/medical data in tickets. Normal screens
do not display Auth UIDs. The responder's trusted reference is retained; Mobile
shows Staff/Center Admin and response time.

## Security

Rules enforce current account/binding access, Patient archival state, active
Relative relationship, exact submitter ownership, permitted fields, length
limits, initial state and server time. A Patient cannot read a Relative's ticket
even for the same Patient; another Relative cannot inherit ticket ownership.
Revoked accounts/links cannot read old tickets or their replies. Authorized Staff
can retain management access to the original submitted records.

Mobile cannot update/delete tickets or write responses. Staff cannot edit the
original submission or edit/delete responses. Workflow changes must be sequential;
response append and parent response metadata must agree in the same commit.
Concurrent Staff updates reject stale preconditions and require Refresh.

No Staff internal-note field is implemented. Every Staff response is explicitly
labelled **Response to Patient/Relative**. Private internal notes must not be
entered there. Concern lists omit message bodies and clinical information.

## Notifications and limits

The existing `notifications` collection stores `concernUpdate` records for the
original Patient or Relative recipient. Messages only say that Staff responded
or that status changed; subject, concern body, and response text are excluded.
Submission also atomically creates a generic `concernSubmitted` Staff notice.
Rules require the exact notice to accompany the submitter's own ticket; Mobile
cannot read Staff notices. Both clients refresh notifications while clinical rows
are cached. The Submitted inbox count remains an additional indicator. No new
notification is emitted for archived Patients; Staff can still manage their
retained tickets. No new
notification collection, push sender, SMS gateway, or paid service is introduced.

Attachments, Mobile follow-up messages, reopening tickets, internal notes,
automatic reminders, pagination, and trusted server-side submission rate limiting
are not implemented. Lists currently retrieve authorized tickets and filter/sort
locally, consistent with existing repositories; review volume/quotas before
expanding usage. This module does not establish a retention/deletion policy.

## Deployment boundary

No Firebase Console provider/storage setup, new index, billing change, or Cloud
Function is required. The changed **firestore.spark.rules** must be reviewed and
deployed before connected use. This includes the previously pending annual-ID
changes: review the complete diff, `PATIENT_ID_TRANSITION.md`, and
`HISTORY_AND_CANONICAL_IDS.md` together. The reviewed Spark Rules were deployed
separately on 24 October 2026; the earlier Feedback denial was an old-policy
mismatch. Verify a target environment's active policy before connected acceptance.
Application startup or Git publication does not deploy these Rules.

From `dialycare_workspace/backend`, an authorized maintainer can deploy after
successful local verification and review:

```powershell
firebase deploy --only firestore:rules --config firebase.spark.json --project dialycare-backend-3f0ed
```

Publish/restart both updated clients together so Staff understands the new
notification type. No live records, accounts, migrations, or Rules deployment are
changed by implementing or testing this module locally.

## Verification entry points

- Shared: `test/feedback_concerns_test.dart` checks validation, account-derived
  submissions, server timestamps, immutable-content patches and atomic replies.
- Mobile: `test/feedback_ui_test.dart` exercises both roles from Feedback through
  required-field validation, submission, status and response display.
- Staff: `test/feedback_ui_test.dart` exercises inbox search, original content,
  response, resolution and closure.
- `test/spark_repository_flow_test.dart` additionally exercises the real REST
  ticket repositories, isolation, multiple replies, stale-write rejection,
  terminal states and notification retrieval with Auth/Firestore emulators.
- `feedback.rules.test.cjs` tests ownership, impersonation, invalid fields,
  revocation, immutable originals/replies and sequential Staff workflow.

The local combined runner includes all Rules suites and the existing repository
workflows. A working JDK is needed; a failing Java PATH shim is an environment
failure rather than an executed test result. Set JAVA_HOME/PATH for the test
process only when selecting an already installed working JDK.

## Historical local results — initial implementation, 24 October 2026

These results predate the compact History calendar and navigation update. See the
root README for the current validation record.

- Shared analysis clean; 44 tests passed.
- Staff analysis clean; 73 tests passed, 3 explicit emulator/live skips.
- Mobile analysis clean; 20 tests passed.
- Local API/dataset/migration tests: 22 passed.
- Dedicated local Auth/Firestore repository workflows: 2 passed, including the
  real concern lifecycle, original-content preservation, multiple replies,
  scoped access, stale-write rejection, and in-app notification retrieval.
- Rules/activation/Feedback/History suite: 42 passed, zero failures/skips.
- Staff and small-screen concern layouts rendered and inspected using fictional
  fixtures; captures remain in ignored verification output. Temporary visual
  test sources were removed after the check.
- No live Firebase deployment, account change, Patient change, billing change,
  Git staging, commit, or push was performed.

## Implementation file inventory

New files (paths relative to `dialycare_workspace`):

- `backend/FEEDBACK_CONCERNS.md`
- `backend/feedback.rules.test.cjs`
- `core_shared/lib/feedback_concerns.dart`
- `core_shared/lib/feedback_concerns_page.dart`
- `core_shared/test/feedback_concerns_test.dart`
- `core_shared/test/helpers/concern_fake.dart`
- `dialycare_mobile/test/feedback_ui_test.dart`
- `dialycare_staff/test/feedback_ui_test.dart`

Existing files updated for this feature:

- Root `README.md`
- `backend/firestore.spark.rules`
- `backend/package.json`
- `backend/run-capstone-checks.cjs`
- `core_shared/lib/core_shared.dart`
- `dialycare_mobile/lib/main.dart`
- `dialycare_mobile/lib/mobile_store.dart`
- `dialycare_staff/lib/models/notification_delivery.dart`
- `dialycare_staff/lib/screens/cloud_workspace.dart`
- `dialycare_staff/lib/screens/staff_portal.dart`
- `dialycare_staff/lib/services/staff_store.dart`
- `dialycare_staff/lib/services/notifications/staff_notification_workflow.dart`
- `dialycare_staff/lib/widgets/staff_shell.dart`
- `dialycare_staff/test/spark_repository_flow_test.dart`

Earlier uncommitted annual-ID/UI changes remain present and were not reverted.
