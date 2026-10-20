DRAFT / CAPSTONE PRIVACY NOTICE
Version: capstone-2026-10-19-v1
Last updated: 19 October 2026

Scope
This single-center development deployment is intended for fictional/test information only. This notice has not been legally reviewed. It does not assert compliance with healthcare or privacy law.

Information processed and purposes
Staff-created Patient and Relative records may contain identity/contact fields and treatment-related notes. Schedules, sessions, status updates and notifications support center coordination. Firebase Authentication manages account credentials; Firestore stores application records, links, access status and minimal acceptance evidence. Internal authentication identifiers are implementation details, not contact inboxes.

Who can access information
Authorized center Staff/Admin use operational records. Patients receive their own permitted Mobile information. Relatives receive only explicitly linked coordination information, not unrestricted clinical records. Technical support should use minimal diagnostics and obtain authorization before any necessary record access.

Storage and safeguards
The current cloud service is Firebase, with Firestore configured in Singapore (asia-southeast1). Access is governed by account mappings and Security Rules. There is no claim that Firebase alone establishes legal compliance. This client-based prototype has known security limitations, including temporary-PIN guessing controls and trusted account recovery.

History and retention
Archiving hides a Patient from active registration/scheduling selection while preserving records and sessions. Archiving is not deletion. No automatic legal retention period or permanent-disposal service is configured. Automated backups are NOT CONFIGURED / NOT VERIFIED. Historical information must not be deleted merely because an account becomes inactive.

Activity and acceptance
Basic audit events record actor ID/role, action, record reference, outcome and server time without copying clinical details or secrets. Terms agreement and Privacy Notice acknowledgment are separate, versioned records. No IP address, device fingerprint or marketing consent is collected for acceptance. Acknowledgment is not blanket consent to medical processing.

Sharing and inquiries
No activation email or SMS is sent. Do not share records with unauthorized recipients or include them in diagnostics. For access, correction, privacy questions or concerns, contact the center's authorized contact. Center/privacy contact details are NOT CONFIGURED and must be established and reviewed before real deployment. The project team must verify applicable legal bases, rights, retention, cloud-processing arrangements and contact responsibilities before production.
