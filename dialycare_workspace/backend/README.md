# DialyCare backend

Current runtime: **existing Firebase project `dialycare-backend-3f0ed`, Spark, Firebase Authentication, and authenticated Firestore access**. The current Firestore Rules have been deployed and matched against the tested source. Running the existing Flutter apps does not require Cloud Functions, Blaze, or a new Firebase project.

Start with [SPARK_SETUP.md](SPARK_SETUP.md), [the current 43-point report](UI_SESSION_REPORT_2026-10-21.md), and [the session/scheduling guide](SESSION_INTERRUPTION_GUIDE.md). [ACCOUNT_SYSTEM.md](ACCOUNT_SYSTEM.md) describes current Staff-issued ID/PIN activation. Use the current Relative ID in Patient Details → Mobile Access when a previous link has been retired.

Authoritative records use `patients`, `relatives`, `patientRelativeLinks`, and `sessions`. Staff-only `sessionEvents` stores private operational history. Permission-specific views and recipient-scoped notifications support the Mobile clients; there is no separate Mobile Patient database. `clinical/state` coordinates workspace revisions rather than storing a duplicate clinical bundle.

Foreground refresh is once per minute with cache/access checks and quota backoff. Local display clocks do not write Firestore every second. In-app notifications are active; SMS and push delivery are not claimed.

The `functions/` folder and the archived notes below describe the earlier architecture. They are retained as historical reference and are not the current deployment instructions.

<details>
<summary>Archived pre-Spark architecture and deployment notes (not current instructions)</summary>

> Current integration: [Spark setup](SPARK_SETUP.md). Core data now uses authenticated Firestore access. Older Cloud Functions, invitations, billing, and push setup below describes the previous architecture. See the current implementation report for verified limits.

# DialyCare shared backend - manual deployment required

This backend uses the **existing** Firebase project `dialycare-backend-3f0ed`.
The code has been tested locally; it has NOT been deployed to your Firebase account.
No live patient login, cross-device synchronization, FCM delivery, or SMS delivery has been verified.

## Required setup

1. In the existing Firebase project, enable Email/Password Authentication and create Cloud Firestore in production mode. Enable billing/Cloud Functions and required APIs. Review the project's region, retention, access, and billing configuration before deploying clinical data.
2. Install Node.js 22 and Firebase CLI. In `backend/functions`, run `npm ci` and `npm test`.
3. In `backend`, run `firebase login`, confirm the selected project, then `firebase deploy --only functions,firestore:rules`. The API performs Firebase token and staff/link checks itself; its HTTP endpoint must accept requests at the infrastructure level. Firestore client access is denied by the supplied rules. Review existing rules before replacing them if you already have other Firestore consumers.
4. Create a real Staff email/password user in Firebase Authentication. In a trusted administrator environment with Application Default Credentials for this project, run `node tools/grant-staff.js FIREBASE_AUTH_UID` from `backend/functions`. Never copy administrator credentials into either app. Sign out/in after assigning the role. Firebase CLI login and Application Default Credentials are separate.
5. The apps default to `https://us-central1-dialycare-backend-3f0ed.cloudfunctions.net/api`. Check the URL printed by deployment. If different, run both apps with `--dart-define=DIALYCARE_API_URL=https://YOUR-DEPLOYED-API-URL`.
6. Open Staff Profile -> **Connect care center**, sign in with that staff account, and create verified patient/relative records and sessions in the shared workspace. This starts empty and does not import the local demonstration workspace. Existing local records remain on the computer. Review any real local records with your administrator before migrating them; automatic migration is intentionally not performed.
7. After verifying the person's identity, choose **Mobile invitation**. Supply the existing Patient ID, role, and, for a relative, the existing Relative ID shown in the patient's registration details. Privately give the person their account ID and single-use invitation. Invitations expire after 24 hours. A mobile sign-up creates an Auth account linked to that record; it never creates another patient or a new patient-relative relationship. The center's recorded name is authoritative.
8. In Mobile, select the assigned role, sign up using the invitation, then log in using that account ID and password. Patient and Relative account namespaces are separate. Password recovery requires center-assisted identity verification and an administrator reset, since synthetic account aliases are not real email inboxes.

## FCM

Android retains its existing Firebase application ID, `google-services.json`, and Firebase options. Do not change the Android application ID just to match the new folder name. Enable the Firebase Cloud Messaging API and allow notifications on a real Google Play services device. Token registrations belong to authenticated, currently linked accounts. Tokens are refreshed, revoked on online logout, and marked invalid when FCM rejects them. A registration expires after 30 days without device registration activity; reopening the app registers it again.

iOS retains the existing bundle ID. On a Mac, run FlutterFire configuration if needed, verify `GoogleService-Info.plist` membership, configure signing, enable Push Notifications and Background Modes/Remote notifications in Xcode, and upload an APNs key to the same Firebase project. iOS builds cannot be verified on this Windows machine. No signing/team identifiers have been invented.

Background FCM notifications use generic lock-screen text; actual schedule/pickup content is fetched from authorized notification history. Foreground messages refresh that history. FCM acceptance is recorded as **Sent**, never falsely as device-delivered. Staff displays Patient and Relative registrations independently. Device tokens are kept server-side; Staff receives a routing marker, not the real token.

## SMS - not configured

The trusted server includes a Twilio adapter. Choose/approve a provider account, sender, destination permissions and billing. For Twilio, set `TWILIO_ACCOUNT_SID`, `TWILIO_FROM`, and bind `TWILIO_AUTH_TOKEN` from Secret Manager to the deployed `api` function's environment using your cloud deployment administrator. Do not put the token in Dart, `.env` files committed to source, or mobile configuration. Redeployments must preserve the secret binding. Destinations must be E.164 numbers, such as a country-code-prefixed number; local `09...` numbers are not guessed or silently converted.

Until configured, SMS returns a clear failed/configuration result. The existing Staff routing handles each recipient separately: registered app -> FCM; no registration -> SMS; a known invalid push registration permits SMS fallback. An uncertain provider/network outcome stays Pending and must be reconciled against the server receipt/provider before retrying. Receipt keys prevent duplicate sends. SMS provider acceptance is **Sent**, not a delivery confirmation; delivery webhook reconciliation is not implemented. No live provider sends were tested.

## Storage and synchronization

`clinical/state` is the single authoritative bundle of patients, designated relatives, sessions, session statuses, notification events and delivery history, adapted to the existing Staff snapshot model. Staff uses an atomic revision check; stale edits are rejected, not silently overwritten. Mobile receives only its linked coordination records and own notifications from that same bundle, and cannot write clinical records. Staff refreshes every 20 seconds; Mobile every 15 seconds and on pull-to-refresh/foreground push. This is polling, not a Firestore subscription.

Separate collections hold `users` (verified links), `invitations` (hashed secrets), `devices`, `deliveryReceipts`, and per-user `reads`. Removing a designated relative/patient or disabling its user link revokes future mobile data access. Firebase token revocation is verified server-side. Backend role checks cannot be bypassed by changing a Flutter screen. Local workspace passwords are not sent to or used as backend authentication.

**Current capacity boundary:** the canonical snapshot is capped at 850 KB, below Firestore's document limit. Saves over the limit fail explicitly without overwriting existing records. This is suitable for verifying the current small workspace, not unlimited production history. Migrate canonical records to per-record collections with transactional versioning and paginated history before operating a larger center; do not silently prune audit history. Scheduled automatic reminder execution and delivery-receipt reconciliation still require a backend job/worker deployment. Manual Send Reminder and status-triggered events are wired through the existing Staff workflow.

## Validation and remaining acceptance work

Local automated API tests use isolated Firebase adapters; they do not contact production. On real accounts/devices after deployment, verify:

- Patient A cannot read Patient B; a relative cannot link without an invitation; removed links lose access.
- Staff creates/edits a session; Patient and its designated Relative see the same date/time/room/batch/status.
- Staff Send Reminder appears once in each intended recipient's history, unread count changes, opening it persists read state.
- Completed -> Ready for Pick Up creates the correct separate Patient/Relative history and provider requests.
- Patient connected/Relative unregistered, inverse, both connected, neither connected route independently.
- FCM token rotation, notification permission denial, invalid tokens, online logout revocation and background notification opening work on actual Android/iOS devices.
- Twilio acceptance/rejection/timeouts are reconciled safely before any resend. Confirm delivery using provider receipts rather than assuming it from HTTP acceptance.

See Firebase's [Flutter authentication](https://firebase.google.com/docs/auth/flutter/password-auth), [FCM setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started), and [token verification](https://firebase.google.com/docs/auth/admin/verify-id-tokens) documentation.


</details>
