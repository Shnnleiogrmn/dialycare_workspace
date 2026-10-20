# Session timing and demonstration data

The existing Staff and Patient/Relative apps still use `dialycare-backend-3f0ed` on Spark.

## Staff workflow

1. In Patient Personal Info, select **Schedule Group**: MWF or TThS. Existing Patients may remain unassigned.
2. In **Schedules → Add Schedule**, choose the Patient, batch, date/time and **Planned Duration**. Presets are 3, 3½, 4, 4½ and 5 hours. Unstarted schedules can be changed through **View → Edit Schedule**.
3. In **Sessions → Upcoming → Manage**, select **In Progress** and confirm. The server records actual start; the scheduled clock alone does not start treatment.
4. In **Ongoing**, view elapsed time, percentage and estimated end. **Complete Session** opens the existing confirmation dialog. Reaching 100% does not complete treatment.
5. After completion, select **Ready for Pick Up** explicitly through Manage. Patient/Relative in-app notifications follow the authorized account links. No SMS delivery is configured or claimed.

An existing session without historical timing displays **Not recorded**. For an old Pending schedule without a planned duration, set it through Edit Schedule before starting. Completed treatment cannot be reset/restarted; create a new session for a new treatment.

## Patient and Relative

Current Session and Session Details show the stored start, locally calculated elapsed/progress, plan and estimated end. Completion freezes actual duration. Estimates can change and are not guaranteed discharge times. Relative sees only its authorized linked Patient's operational data.

## Approved synthetic cohort

- 22 MWF and 21 TThS Patients: **43 new synthetic Patients**.
- **45 Patients overall**, preserving the two existing records, as approved.
- Public IDs **DC-000005–DC-000047** and **R-000005–R-000047**.
- Invented identities; fictional/non-deliverable addresses; non-contactable contact text; no PhilHealth numbers, personal email addresses or clinical prescriptions.
- One explicit demonstration appointment per Patient, distributed across existing Room 01–06 and Batch A/B/C labels on matching group days. No machine/chair capacity is asserted.

Group membership does not automatically create future appointments. Staff continue scheduling explicitly. The seed does not activate accounts or assign passwords: use the existing **Mobile Access → Temporary PIN** workflow when activation is needed.

## Safe explicit setup tooling

`synthetic-dataset.cjs` is the single deterministic profile source. The seed has already been applied. Running the seed tool again verifies the existing cohort and makes no writes:

```powershell
node seed-synthetic-patients.cjs
node verify-synthetic-schedule.cjs
```

Only an explicitly authorized trusted setup action uses `--apply`; it is never run by app startup. Partial seeds, identifier conflicts and changed workspace revisions abort instead of overwriting records. Permanent reservations are retained for issued IDs, including disposable verification IDs.

See the [34-point implementation and verification report](SESSION_TIMER_DATASET_REPORT_2026-10-20.md).


## Current designated Relative IDs (2026-10-21)

The original seed Relative IDs remain historical identities. Staff have since edited/replaced the designated Relative identities/contact details. Use the **current Relative ID shown in Patient Details → Mobile Access**, not an old seed list, when authorizing Mobile access. Retired relationships do not transfer their owner's login to the replacement identity. Patient IDs and historical records remain persistent. See `UI_SESSION_REPORT_2026-10-21.md` for the current read-only inventory and link review.
