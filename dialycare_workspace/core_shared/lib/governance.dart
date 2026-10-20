import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const termsVersion = 'capstone-2026-10-19-v1';
const privacyNoticeVersion = 'capstone-2026-10-19-v1';
const policyUpdated = '19 October 2026';
const dialyCareDescription =
    'DialyCare is a dialysis-center management and patient coordination system designed to support patient records, dialysis scheduling, session monitoring, notifications, and communication between the dialysis center, patients, and designated relatives.';
const applicationVersion = String.fromEnvironment(
  'DIALYCARE_VERSION',
  defaultValue: '1.0.0+1',
);
const capstoneEnvironment = 'Development / Capstone — fictional data only';

const draftTerms =
    """DRAFT / CAPSTONE TERMS
Version: $termsVersion
Last updated: $policyUpdated

DialyCare is a single-center development prototype for fictional records. These draft terms have not been legally reviewed and are not a production service agreement.

Permitted use
Use only the functions and fictional records authorized by the center. Do not access another person's account, attempt to bypass access controls, or enter real Patient information into this capstone deployment.

Account responsibilities
Keep passwords and first-time activation PINs private. Do not share accounts or credentials. Patient and Relative access must originate from an existing center-approved record. A Relative may view only the information permitted by their recorded relationship.

Service limitations
Information may be delayed or unavailable. Notifications do not guarantee delivery or receipt. Push/SMS delivery is not configured in this prototype. DialyCare is not an emergency communication channel and must not replace clinical judgment or the center's care procedures. For urgent medical concerns, contact appropriate healthcare or emergency services directly.

Access changes
Authorized center personnel can archive records, change relationships, and disable or restore Mobile Access. Archiving preserves history; it is not permanent deletion. Account recovery beyond pending PIN regeneration needs trusted administration.

Support
For account or record questions, contact your dialysis center. The authorized technical support contact has not yet been configured; obtain it from the capstone project team. Do not send passwords, PINs, tokens or medical records with support requests.

Privacy and changes
The separate Privacy Notice explains prototype information handling. Agreeing to these terms does not provide blanket consent to health-data processing. Material document changes need new versioned review. Production use requires reviewed agreements and additional safeguards.
""";

const draftPrivacyNotice =
    """DRAFT / CAPSTONE PRIVACY NOTICE
Version: $privacyNoticeVersion
Last updated: $policyUpdated

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
""";

Future<void> showPolicyDocument(
  BuildContext context, {
  required bool privacy,
}) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(privacy ? 'Privacy Notice' : 'Terms of Use'),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: SelectableText(privacy ? draftPrivacyNotice : draftTerms),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  ),
);

String safeDiagnostics({required String application, DateTime? timestamp}) =>
    'DialyCare $application\nApplication Version: $applicationVersion\nPlatform: ${kIsWeb ? 'web' : defaultTargetPlatform.name}\nEnvironment: $capstoneEnvironment\nBuild: ${kReleaseMode
        ? 'release'
        : kProfileMode
        ? 'profile'
        : 'debug'}\nTimestamp: ${(timestamp ?? DateTime.now()).toUtc().toIso8601String()}';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key, required this.application});
  final String application;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help & Support')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'DialyCare $application Support',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        const Text('Please contact your dialysis center.'),
        const SizedBox(height: 12),
        const Text(
          'Your center can help with account access, schedule questions, linked Relative information, and record corrections. Have your center-issued ID ready.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Keep your password and Temporary PIN private. Never include them in a support request.',
        ),
        const SizedBox(height: 16),
        const Text(
          'For urgent medical concerns, contact the center or emergency services directly. DialyCare notifications are not an emergency communication channel.',
        ),
        const SizedBox(height: 24),
        const Text('Application Version: $applicationVersion'),
        TextButton(
          onPressed: () => showPolicyDocument(context, privacy: false),
          child: const Text('Terms of Use'),
        ),
        TextButton(
          onPressed: () => showPolicyDocument(context, privacy: true),
          child: const Text('Privacy Notice'),
        ),
      ],
    ),
  );
}

const auditLabels = <String, String>{
  'patientCreated': 'Patient created',
  'patientUpdated': 'Patient updated',
  'patientArchived': 'Patient archived',
  'patientRestored': 'Patient restored',
  'relativeCreated': 'Relative created',
  'relativeUpdated': 'Relative updated',
  'relativeLinked': 'Relative linked',
  'relativeUnlinked': 'Relative unlinked',
  'mobileAccessCreated': 'Mobile Access created',
  'pinRegenerated': 'Temporary activation regenerated',
  'activationCancelled': 'Activation cancelled',
  'accountActivated': 'Account activated',
  'mobileAccessDisabled': 'Mobile Access disabled',
  'mobileAccessRestored': 'Mobile Access restored',
  'sessionCreated': 'Schedule/session created',
  'syntheticDatasetCreated': 'Synthetic demonstration dataset added',
  'sessionEdited': 'Schedule/session edited',
  'sessionStatusChanged': 'Session status changed',
  'sessionRemoved': 'Schedule/session removed',
  'reminderCreated': 'Staff reminder created',
  'centerSettingsChanged': 'Center information changed',
};
String auditGroup(String action) => action.startsWith('patient')
    ? 'Patients'
    : action.startsWith('relative')
    ? 'Relatives'
    : action == 'sessionStatusChanged'
    ? 'Sessions'
    : action.startsWith('session')
    ? 'Schedules'
    : [
        'mobileAccessCreated',
        'pinRegenerated',
        'activationCancelled',
        'accountActivated',
        'mobileAccessDisabled',
        'mobileAccessRestored',
      ].contains(action)
    ? 'Mobile Access'
    : action == 'reminderCreated'
    ? 'Notifications'
    : 'Settings';
