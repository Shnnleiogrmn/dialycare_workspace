# DialyCare session and scheduling controls

Use the existing Staff and Patient/Relative apps with the same Firebase project.

## Staff session controls

Open **Sessions**, choose the appointment date, and open **Manage** for a Patient.

- **Start:** choose In Progress for a Pending appointment. A planned duration must already be set in Edit Schedule. Firestore records the actual start.
- **Pause:** use Pause on an active session or choose Paused in Manage. Select an operational reason and optionally enter an internal note. Confirm the change.
- **Resume:** use Resume on a paused session. It continues the same treatment timer and preserves all previous pauses.
- **Complete:** available while In Progress. Confirm normal completion. The recorded active duration then stays fixed.
- **End Early:** use the separate red action for an active or paused session. Select a reason, optionally add an internal note, and confirm. This does not mark the treatment Completed.
- **Cancel before treatment:** open Edit Schedule, select a cancellation reason, then Cancel Schedule and confirm. A started treatment must use End Early.
- **Ready for Pick Up:** remains a separate Staff update after Completed.

Manage also shows the persisted **Session History**. Reasons, notes, and Staff identity belong to the private event history. They are never included in the Patient/Relative Session document or in automatic notification messages. New events require an authorized Staff login, server timestamps, and the correct Session revision.

The active timer subtracts all pause intervals. During Pause, active elapsed time and percentage stay fixed; the pause counter can continue locally. Estimated End is withheld while paused and is extended by accumulated pause time after resuming. Reaching 100% does not complete treatment. Legacy records with no actual timing remain explicitly unrecorded rather than receiving fabricated historical times.

## Schedule and batches

The Schedule page groups appointments by the selected date and batch. MWF/TThS describes regular treatment **days**, while a batch describes a daily **time slot**. Sunday has no regular group.

Use Add Patients inside a batch to open the eligible Patient list. Its group filter starts enabled for the selected day; turn it off when an explicitly approved exception is needed. Select the Patient, date/time, batch, and planned duration, then Add and Confirm. No group is automatically scheduled. Overlapping appointments are rejected; workspace version checks reject stale concurrent saves.

An authorized **Center Admin** can use **Schedules → Configure Batches** to set a batch name, start/end in 24-hour HH:mm format, optional capacity, and active state. Staff cannot alter this configuration. No machine/chair count is assumed. Existing appointments remain visible when a batch is deactivated. Batch C appears only when configured or needed by actual appointments; it is not an obligatory empty section.

If no configuration exists, legacy batch assignments remain usable. No capacity denominator or center-wide time range is invented.

## Patient and Relative

Home and Session details show authorized timing and status from the same Session collection used by Staff. History includes completed, cancelled, missed, and ended-early records. There are no treatment-control buttons.

Use pull to refresh for an immediate check. Foreground background refresh remains once per minute, with access checks and quota backoff. The one-second display clock makes no network request and performs no write. Meaningful state changes create existing Firestore in-app notifications. SMS and push delivery are not claimed.

Default avatars use only explicit stored Male/Female values. Other, blank, and unknown values use a neutral avatar. Relative has no stored gender field and therefore uses the neutral avatar. A custom image supplied to the shared avatar component takes priority.
