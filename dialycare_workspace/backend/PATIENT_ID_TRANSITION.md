# Canonical Patient IDs — controlled migration

The current policy is **DP-YYYY-NNN**, for example `DP-2026-001`. This supersedes
the earlier four-digit proposal. Each local registration year has its own sequence
from 001 through 999. Exhaustion stops registration rather than widening the
format. Relative IDs keep their existing `R-` format.

The shared repository atomically saves the yearly counter, permanent reservation,
Patient/projections and clinical revision. Update-time/non-existence preconditions
prevent concurrent reuse. Failed commits allocate nothing. Rules validate the
matching year/sequence and deny new legacy Patient IDs and counter rollback.
Existing legacy records remain editable without changing their issued IDs.

New Patient registration is paused while existing noncanonical records require
migration. This prevents new records taking IDs reserved for existing Patients.
Existing records remain available. Publishing Rules alone does not migrate them.

See [History and canonical IDs](HISTORY_AND_CANONICAL_IDS.md) for the dry-run plan,
approval boundary, deployment and recovery. The migration defaults to read-only
preview. **Do not apply until the owner approves the current plan.**

Owner approval does not bypass safety checks. Apply also checks cross-collection
integrity before committing, including Patient projections, session ownership,
account bindings and active Relative links. An unresolved reference stops the
migration; it never repairs or reactivates a relationship automatically. Review
the private metadata snapshot, preserve a recovery copy, and resolve the cause
through the authorized account/relationship workflow before revalidating.

Only public IDs and display metadata change. Internal IDs, relationships, Auth
UIDs/passwords and Relative IDs stay unchanged. Bounded login/PIN compatibility
accepts the same identity's canonical and historical aliases. An activated Patient
keeps the existing Auth account. Running the apps does not perform migration.
