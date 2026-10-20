import 'package:flutter/material.dart';

import '../services/notifications/providers.dart';
import '../models/notification_delivery.dart';
import '../services/staff_store.dart';
import '../theme/staff_theme.dart';
import 'mobile_access_details.dart';

/// Uses the saved care identities, independently of unsaved form fields.
class PatientMobileAccess extends StatefulWidget {
  const PatientMobileAccess({
    super.key,
    required this.patientId,
    required this.store,
  });
  final String patientId;
  final StaffStore store;

  @override
  State<PatientMobileAccess> createState() => _PatientMobileAccessState();
}

class _PatientMobileAccessState extends State<PatientMobileAccess> {
  bool refreshing = false;
  Future<void> refresh() async {
    setState(() => refreshing = true);
    try {
      await widget.store.refreshShared();
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  Widget card(
    String heading,
    NotificationRecipient recipient, {
    String? relationship,
  }) => Card(
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            heading,
            style: const TextStyle(
              color: StaffTheme.navy,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(recipient.name),
          if (relationship != null) Text('Relationship: $relationship'),
          SelectableText(
            '${recipient.type.name == 'patient' ? 'Patient' : 'Relative'} ID: ${recipient.displayId}',
          ),
          if (relationship != null)
            Text(
              'Linked Patient: ${widget.store.patientFor(widget.patientId).name} / ${widget.store.publicIdFor(widget.patientId)}',
            ),
          const SizedBox(height: 12),
          MobileAccessDetails(
            key: ValueKey('${recipient.type.name}_${recipient.id}'),
            allowActivation: !widget.store
                .patientFor(widget.patientId)
                .archived,
            recipient: recipient,
            store: widget.store,
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final patient = widget.store.patients
          .where((p) => p.id == widget.patientId)
          .firstOrNull;
      if (patient == null) {
        return const Text(
          'This Patient is no longer available. Reopen Patients to refresh.',
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mobile Access',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: StaffTheme.navy,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: refreshing ? null : refresh,
                icon: const Icon(Icons.refresh),
                label: Text(refreshing ? 'Refreshing…' : 'Refresh status'),
              ),
            ],
          ),
          const Text(
            'Manage access for saved Patient and Relative records. Save any record changes first.',
          ),
          if (patient.archived)
            const Text(
              'Archived Patient: restore the saved Patient before creating new Mobile Access. Historical records remain preserved.',
            ),
          if (!widget.store.shared)
            const Text(
              'Connect to the shared workspace to manage Mobile Access.',
            ),
          if (widget.store.loadError != null)
            const Text(
              'Unable to refresh account status. Check your connection and try again.',
              style: TextStyle(color: Colors.red),
            ),
          card(
            'Patient Mobile Access',
            NotificationRecipient(
              id: patient.id,
              publicId: patient.displayId,
              patientId: patient.id,
              name: patient.name,
              phone: patient.contact,
              type: RecipientType.patient,
              registration: patient.registration,
              mobileAccount: patient.mobileAccount,
            ),
          ),
          for (final relative in patient.companions)
            card(
              'Designated Relative Mobile Access',
              NotificationRecipient(
                id: relative.id,
                publicId: relative.displayId,
                patientId: patient.id,
                name: relative.name,
                phone: relative.contact,
                type: RecipientType.relative,
                registration: relative.registration,
                mobileAccount: relative.mobileAccount,
              ),
              relationship: relative.relationship,
            ),
          if (patient.companions.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text(
                'No designated Relative. Add and save a Relative in Relative Info before creating their Mobile Access.',
              ),
            ),
        ],
      );
    },
  );
}
