# Feedback, History and canonical Patient IDs

This guide describes source behavior and rollout boundaries. Operational ID
mappings, live inventory, account identities and recovery snapshots are private
and must remain outside version control.

## Feedback and authorization

The repository and Rules use `feedbackConcerns/{id}` and append-only
`responses/{responseId}`. Staff review/respond/resolve/close. Mobile ownership
comes from the authenticated mapping and current Patient/Relative relationship.
Another Patient or Relative cannot inherit a ticket. Original text and replies
remain immutable. Staff-only session notes and audit logs remain separate.

Submission atomically creates a generic Staff in-app notice in existing
`notifications`. Rules permit Mobile to create only the exact notice tied to its
own ticket in the same commit; Mobile cannot read Staff notices. Replies/status
changes create generic notices for the original submitter. Foreground notification
refresh works even when clinical rows are cached. No SMS or paid service is used.

The reviewed Spark Rules were deployed separately on 24 October 2026. Earlier
Feedback/History denials came from an older deployed policy. Git publication does
not deploy Rules; a different environment must verify its active policy separately.

## History and navigation

- Staff: **Reports → History** using the Reports header button; **Back** restores
  the existing Reports overview. There are no Overview/History tabs.
- Mobile, both roles: bottom navigation **Home · Feedback · History · More**.
  Home still opens Schedule and Notifications through their existing routes.
- Staff categories: terminal Sessions, Schedule Changes, resolved/closed Feedback
  & Concerns, Communications (recipient role/type/time/read state, no body).
- Mobile: own/linked Patient Sessions and Schedule Changes, plus the authenticated
  submitter's resolved/closed concerns. Patient and Relative tickets stay separate.

History supports category/date/text/Patient-ID filters, descending date order,
Refresh and read-only details. The shared compact date-range dialog provides month
navigation, selected endpoints/range highlighting, Cancel and Apply. The date
control shows the selected range. Both calendar dates are inclusive; Cancel leaves
the filter unchanged and Clear dates removes it.

Session details use recorded scheduled/actual times, final status, planned/active
duration and pause/resume intervals. Missing values say Not recorded. Clinical
notes are excluded. `scheduleHistory/{id}` holds minimal immutable before/after
snapshots atomically saved with future changes. Rules compare actual old/new
session data and require server time. Old events are not fabricated. Actor
identity stays in the Staff-only audit trail; shared history says Authorized Staff.
Mobile Access history is omitted because a safe dedicated projection does not exist.

## Canonical Patient IDs

The public format is **DP-YYYY-NNN**, with an annual sequence from 001 through
999. Relative IDs retain their existing format. Public IDs are separate from
internal document IDs and Firebase Auth UIDs. The approved transition preserves
existing numeric portions and all permanently reserved gaps; it does not infer
an issuance year from enrollment dates.

Migration patches public display IDs/issuance-year metadata, authorized profile
labels/sync markers, canonical reservations, pending invitation display metadata,
the yearly counter and refresh revision. It retains legacy reservations, internal
document keys, foreign keys, original messages, Auth UIDs, passwords and technical
login aliases. Pending PIN-derived lookup keys remain unchanged. Bounded
legacy/canonical login and activation accept only the same approved identity.

## Controlled migration and recovery

`node canonical-patient-migration.cjs` performs a read-only preview using
ID/reference metadata rather than clinical content. It checks mapping conflicts,
missing projections, incompatible Auth aliases, ownership mismatches, pending
unbound Auth identities and the atomic batch limit.

Apply requires explicit `--apply --approved-digest=<reviewed SHA-256>` arguments
and prior owner authorization for that exact current plan. It also checks the
published policy and cross-collection integrity. An unresolved relationship or
account state stops execution; the tool must not infer permission to reactivate a
link. Approval does not override a failed safety check. The live migration was
previously authorized conditionally but stopped before writes; it is not complete.

Before any future approved apply, retain a usable private metadata/recovery
snapshot and exact write inventory, repeat all live preflight/Auth checks, and
review the mapping/digest against current records. Update-time and non-existence
preconditions protect the atomic commit. Read back and verify every mapping,
counter, reservation, immutable reference and account relationship afterward,
including idempotency. A successful script exit alone is insufficient.

If verification fails, stop additional writes and registration. A trusted
maintainer must review recovery patches against the snapshot and current
preconditions. Never blindly decrement counters, delete reservations, recreate
Auth accounts or apply a stale database export. There is no destructive automatic
rollback. New Patient registration remains paused while noncanonical records
require the reviewed migration; existing issued records remain available.

## Verification and deployment boundaries

Run analyzer/unit/widget suites in all Flutter packages. `npm run test:local`
includes API/dataset and migration tests. `npm run test:rules` runs the defined
Rules suites under the local Firestore emulator. `run-capstone-checks.cjs` under
explicit demo Auth/Firestore emulators checks real repository workflows, retained
alias login with unchanged fixture UID/password, role-scoped History/Feedback,
notifications and Rules. Ordinary-suite conditional skips are reported separately.

Windows device tests launch production app shells with synthetic stores; they do
not establish live Firebase login or Android/iOS verification. See the root README
for the latest recorded validation results and available targets.

Committing/pushing source, starting the apps and running local tests do not deploy
Rules or execute migration. Rules rollout, migration, live disposable-content
acceptance tests and recovery are separately authorized operations. No provider
change, new composite index, billing upgrade, Cloud Function or SMS setup is
required for these modules. Foreground refresh, bounded-volume queries and local
filtering remain limitations; background delivery is not claimed.
