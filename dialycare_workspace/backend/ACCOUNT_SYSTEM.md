# DialyCare accounts — center-issued IDs and Temporary PINs

Verification and limitations: [20 October repair report](BACKEND_UI_IDS_REPORT_2026-10-20.md).
Session timing and the approved synthetic cohort: [Staff workflow guide](SESSION_TIMER_AND_DEMO_DATA.md).

The existing Staff and Mobile applications share **dialycare-backend-3f0ed**, its
Spark plan, and the Standard `(default)` Firestore database in **asia-southeast1**.
Staff use their approved Firebase email/password account. Patient and Relative
accounts use center-issued IDs; they do not need a contact email address.

## Staff creates Mobile Access

1. Save the Patient in **Patients → Add Patient**. Personal and Medical Info include
   optional marital status, PhilHealth Number, height (cm), weight (kg), and MDR
   status. Existing records load with blank measurements and Unknown selections.
2. The system assigns a permanent **DC-000001**-style Patient ID. Save a designated
   Relative to assign a permanent **R-000001**-style Relative ID. These are read-only.
   A number displayed before saving is a preview; concurrent creation can change it.
3. Open **Patients → Edit → Mobile Access**, or Mobile Access in Patient Details.
   Select **Create Mobile Access** for the saved Patient or designated Relative.
4. Confirm creation. The six-digit Temporary PIN is shown once with its expiry.
   Give the public ID and PIN directly to the approved person. The PIN expires
   after 24 hours. No email or SMS is sent.
5. Pending access supports **Regenerate Temporary PIN** and **Cancel Mobile Access**.
   Regeneration invalidates the previous PIN; cancellation clears the pending
   binding. Staff cannot retrieve a closed PIN or reset an active password here.
6. **Refresh status** retrieves activation state. Foreground background-refresh
   also checks the saved account bindings approximately once per minute.

## Patient or Relative activates and logs in

1. Choose Patient or Relative, then **Activate Account**.
2. Enter the corresponding **DC-000001** or **R-000001** ID and Temporary PIN.
   Select **Verify Account**. Knowing a Patient ID cannot self-link a Relative.
3. Confirm the recorded name and ID. Create and confirm an **8–16 character**
   password. Passwords are never truncated.
4. Read Terms of Use and Privacy Notice. Agree to Terms and acknowledge Privacy
   using the separate checkboxes. Existing document versions and server timestamps
   are recorded atomically with activation; acknowledgment is not blanket consent
   to clinical processing. The documents retain their stated draft/review status.
5. Select **Activate Account**. The current PIN is consumed once and access becomes
   Active. Later login uses the public ID and the owner's chosen password.

The account does not recreate demographic or clinical records. Home, Schedule,
Notifications and More use the Staff-maintained, authorized records. Relative
Home identifies the linked Patient and highlights the current Ready for Pick Up
status. Persisted in-app notifications are supported; background push and SMS
sending are not configured.

## Account security and recovery

**More → Account & Security → Change Password** requires the current password,
Firebase reauthentication, and a new matching 8–16 character password. Existing
passwords are not changed by the ID migration. Legacy credentials remain usable
until their owner chooses a new password; the new-password policy does not
silently truncate or reset them.

**Forgot Password?** directs the owner to the dialysis center for identity
verification and trusted recovery. Regenerating a first-time PIN cannot reset an
already activated account. There is no fake email-reset route, password lookup,
or client-side privileged password reset. Staff password recovery remains the
existing Firebase email recovery flow, initiated only by the Staff user.

Account states are `notActivated`, `activationPending`, `active`, and `disabled`.
`accountBindings` is authoritative for current Mobile access. Staff can disable
or restore access without deleting clinical or session history. Replacing a
Relative's identity retires the old link and requires fresh activation.

## Stable public IDs and internal references

`patients` and `relatives` retain their original document IDs. Their `publicId`
field is the center-issued display/login ID. `users`, `accountBindings`, links,
sessions, notifications and consumed invitations keep internal references and
Firebase UIDs. Technical Auth aliases use the lowercase public ID with the
existing `.dialycare.invalid` role suffix; these are not inboxes.

`idCounters/center` stores the next Patient/Relative numbers. A save commits its
counter precondition, immutable `publicIds/{publicId}` reservation, clinical
record, projections and audit event atomically. Concurrent claims cannot share
an ID. New-Patient forms refresh and retry once with a fresh ID; existing edits
are not automatically written over another Staff member's update. Archived and
retired IDs remain reserved. The range is 000001–999999.

`migrate-center-ids.cjs` is a trusted, explicitly invoked migration tool, not a
Flutter dependency or a public endpoint. Preview is read-only; `--apply` performs
an atomic Firestore migration and separately verifies any necessary Auth alias
updates. It preserves UIDs/passwords and aborts on unexpected ownership or alias
collisions. Never embed its privileged CLI access in an application.

## Data access and synchronization

- `patients`: authoritative Staff-only clinical records, including PhilHealth/MDR.
- `relatives`: identity/contact records; medical fields are not allowed there.
- `patientProfiles`: limited shared coordination name, public ID and sync marker.
- `patientAccountProfiles`: Patient-only contact and designated Relative summary.
  Relative accounts cannot read this projection or full clinical records.
- `patientRelativeLinks`: authoritative relationships and current authorization.
- `sessions`: one existing combined schedule/operational-session record.
- `notifications`: recipient-scoped persisted history and server-owned read time.
- `users` and `accountBindings`: immutable UID mapping and current access binding.
- `auditEvents`: constrained append-only application events, readable by Staff.

Foreground refresh runs approximately once per minute and skips inactive windows.
Unchanged histories are cached with a five-minute full-refresh fallback; current
access and relationship checks still precede cached Mobile data. Pull-to-refresh
forces a full fetch. HTTP 429/RESOURCE_EXHAUSTED pauses new requests for 15 minutes
and displays the usage-limit condition. This reduces avoidable traffic; Spark
quotas are finite and are not bypassed by the application.

## Security limits and retained operational boundaries

Firebase Authentication manages credentials. Firestore stores no selected
password or raw PIN. The private PIN-derived invitation lookup remains subject
to role, expiry, current binding, single-use and atomic acceptance checks.
Diagnostics omit request bodies, passwords, tokens and PIN-derived lookup IDs.

This client/Rules deployment has no trusted per-record PIN guessing limit or
privileged recovery service. Public Auth signup can reserve an unlinked technical
alias, requiring trusted repair; this never grants a care role by itself.
Client password-length checks do not change the project-wide Auth password
policy. Automated backups and restore drills are not configured/verified.
These limits require review before production use; no certification or legal
compliance is claimed. No Blaze upgrade, Cloud Function deployment, service-account
credential in Flutter, developer portal, or additional Firebase project is used.
