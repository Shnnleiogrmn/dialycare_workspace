> October 15 update: an authenticated shared Firebase server, Staff cloud workspace, and Patient/Relative mobile client have now been added. Follow `../backend/README.md` for deployment and account linking. The local mode described below remains local. Live Firebase/FCM/SMS delivery has not been configured or verified.

# Notification delivery integration

The existing staff UI is preserved. Open a patient name or a Schedule/Session View
for app registration status and the compact Send Reminder action. The composer
selects recipients, not channels. Session View also offers Change Status; Schedule
View offers Edit Schedule and cancellation. Notifications retains All, Patients,
Relatives and System, with smaller delivery metadata and an attempt history panel.

## Current implementation

- Patient and Companion are extended, not duplicated. Each relative has a stable
  ID under its patient. Old JSON records migrate without losing clinical fields.
- App registration includes backend verification, connection status, token, last
  activity if supplied, and notifications-enabled preference. Tokens are absent
  from staff widgets. There is no app-download flag or manual connection toggle.
- Without a registration source, the local record has no registered device. The
  UI explicitly says backend registration is not verified; it does not invent a
  last-connected date. A nonempty token alone cannot produce App Connected.
- RecipientResolver evaluates each patient/relative separately. Automatic events
  honor DeliveryRules and notification preferences. Manual reminders choose an
  explicit subset of recipients whose notifications remain enabled.
- NotificationService uses replaceable PushNotificationService and SmsService.
  The defaults are explicitly unconfigured, not success-returning mocks.
- Known push failure attempts SMS. A confirmed invalid token is cleared and marked
  unavailable, independently for that recipient; later attempts avoid that token.
  If a newer registration arrives during sending, it is not invalidated by an old
  token's error.
- SMS requires a syntactically valid international E.164 number. A deployment may
  supply countryCallingCode for national numbers beginning with zero. There is no
  guessed country default. Existing example contacts are not valid SMS targets.
- Event and recipient records are persisted before providers are called. Each push
  or SMS attempt has a pending record and its result, provider ID, timestamps and
  reason. Sent means provider acceptance; Delivered requires provider confirmation.
  Successful SMS after failed push is Fallback Sent. No configured provider means
  Failed with the reason visible, never Sent or Delivered.
- Provider exceptions/timeouts have unknown acceptance. They stay Pending with an
  explicit reconciliation message, and do not automatically send another SMS that
  could duplicate a notification already accepted by push.
- Automatic status events occur in the store, never widget build methods. In
  Progress creates Session Started, Ready for Pick Up creates patient and relative
  pickup messages, cancellation creates Schedule Cancelled. Changed date/time
  creates Schedule Rescheduled; room/batch changes create Schedule Updated.
- processDueNotifications(now) is the scheduler entry point. Defaults are reminders
  within 24 hours before appointment and ending-soon within 10 minutes of a recorded
  expectedEnd. It is deliberately not run by a UI timer. A session has no assumed
  end time; staff can record it in Session Status.
- Persisted event keys deduplicate repeated status calls and scheduler invocations,
  including reloads. Manual resend creates a distinct staff-triggered event.
- History survives patient deletion; it retains the recipient name, patient and
  relative IDs, event type, trigger and related SessionRecord ID. This existing
  model represents both schedules and sessions, so no second schedule table exists.

Implementation: lib/models/notification_delivery.dart,
lib/services/notifications/providers.dart, notification_service.dart and
staff_notification_workflow.dart. UI additions reuse the existing custom panels,
colors, typography and buttons.

## Real services still required

The project only configured Firebase Core in `dialycare-backend-3f0ed`. It has no
Firebase account/role authentication, notification server, registered mobile
accounts, SMS credentials or durable backend job scheduler. Local workspace
passwords are not server authentication. Nothing has been deployed or sent to a
real patient or relative as part of this task.

1. Implement authenticated server-side sending in the existing Firebase project
   (or its existing trusted server when available). Validate the staff account,
   center/role and ownership of the patient/relative. Resolve phone numbers and
   device registrations on the server; do not trust an arbitrary destination/token
   posted by a desktop client. Keep Firebase Admin credentials on that server using
   its managed identity or server environment configuration. Never put a service
   account key or SMS secret in Flutter or a dart-define. Firebase describes the
   trusted environment in its [server setup guide](https://firebase.google.com/docs/cloud-messaging/server-environment).
2. Enable and configure Firebase Cloud Messaging for that server and future mobile
   apps. Implement verified phone/account linking independently for patient and
   relative, permission handling, device registration, token refresh and unlink/
   revocation. Supply an authenticated RegistrationSource to syncRegistrations.
   Connected means the source verified the account/device registration, not simply
   a value staff entered. See [Flutter FCM registration](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)
   and [token management](https://firebase.google.com/docs/cloud-messaging/manage-tokens).
3. Supply an SMS provider account, server-side API credentials, authorized sender
   configuration, recipient consent/preferences, country dialing policy and
   delivery-receipt integration. Provider selection is intentionally independent
   of the UI. Implement SmsService as a client of the authenticated backend, with
   provider credentials held in that backend's environment/secret configuration.
4. Implement PushNotificationService as an authenticated backend client too. Use
   the Firebase Admin messaging result to distinguish acceptance from delivery.
   Map a confirmed unregistered device to failed + invalidRegistration. Do not
   classify every invalid argument/network error as a bad device token. See
   [FCM error classifications](https://firebase.google.com/docs/cloud-messaging/error-codes).
5. Honor the supplied stable per-attempt idempotency keys (`deliveryId:push` and
   `deliveryId:sms`) server-side. Persist provider responses and reconcile Pending
   attempts before retrying. A crash after provider acceptance but before local
   recording must not cause a blind resend. There is intentionally no automatic
   local replay of uncertain attempts. Async delivery receipts and remote history
   synchronization still need the backend adapter; the current log is local.
6. Move/bridge the event persistence and scheduler entry point to authoritative
   server storage and a durable scheduler. Schedule reminders and ending-soon
   events must run when staff closes the desktop app. The current local event
   ledger deduplicates one workspace; multiple desktops require server-side atomic
   event/revision guards. No UI-only timer or background job has been invented.

Provider test doubles only exist under test/. Real-provider acceptance and actual
SMS/push receipt cannot be verified until the above services are supplied. Those
are deployment requirements, not additional Flutter compilation fixes.

## Verification

Run in this staff directory:

```sh
flutter pub get
flutter analyze
flutter test
flutter test integration_test/notification_flow_test.dart -d windows
flutter run -d windows
```

The native integration test uses isolated in-memory records with unconfigured
providers, exercises manual selection/error/result, Ready for Pick Up, notification
read/history and schedule editing, and never contacts real recipients. Service
tests use injected doubles to verify both-channel combinations, failure/fallback,
missing phone, token invalidation, pending/unknown outcomes, durable history,
rollback and duplicate prevention. Existing screen/resize tests remain included.
