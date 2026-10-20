import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:core_shared/core_shared.dart'
    show SessionProgress, PersonAvatar;

import '../models/patient.dart';
import '../models/session.dart';
import '../models/notification_delivery.dart';
import '../services/staff_store.dart';
import '../services/notifications/providers.dart';
import '../screens/notifications/reminder_composer.dart';
import 'registration_details.dart';
import 'patient_mobile_access.dart';
import '../theme/staff_theme.dart';
import 'staff_components.dart';
import 'status_chip.dart';
import 'pickers.dart';

Future<void> showPatientDetails(
  BuildContext anchor,
  Patient p, {
  SessionRecord? session,
  String title = 'Patient Details',
  StaffStore? store,
}) async {
  await showAnchoredPanel<void>(
    anchor,
    width: 390,
    height: 580,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: StaffTheme.navy,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Close details',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 19),
            ),
          ],
        ),
        const Divider(color: StaffTheme.blue),
        Center(child: PersonAvatar(gender: p.gender, size: 64)),
        if (session == null) _detailSection('Personal Information'),
        for (final entry in {
          'Patient ID': p.displayId,
          if (p.archived) 'Record Status': 'Archived — history retained',
          'Patient Name': p.name,
          if (session == null) 'Age': '${p.age}',
          if (session == null) 'Gender': p.gender,
          if (session == null) 'Contact': p.contact,
          'Schedule Group':
              (session?.scheduleGroup ?? p.scheduleGroup)?.label ??
              'Not assigned',
          if (session == null) ...{
            'Marital Status': p.maritalStatus,
            if (p.birthDate != null) 'Date of Birth': shortDate(p.birthDate!),
            if (p.address.isNotEmpty) 'Address': p.address,
            'PhilHealth Number': p.philHealthNumber.isEmpty
                ? 'Not provided'
                : p.philHealthNumber,
          },
          if (session != null) ...{
            'Assigned Room': session.room,
            'Batch': session.batch,
            'Session Start Time':
                '${shortDate(session.start)} • ${sessionTime(session.start)}',
          },
        }.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    entry.key,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    entry.value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (session == null) ...[
          _detailSection('Medical Information'),
          for (final entry in {
            'Blood Type': p.bloodType.isEmpty ? 'Not recorded' : p.bloodType,
            'Height': p.heightCm == null ? 'Not recorded' : '${p.heightCm} cm',
            'Weight': p.weightKg == null ? 'Not recorded' : '${p.weightKg} kg',
            'MDR Status': p.mdrStatus,
            if (p.medicalNotes.isNotEmpty) 'Medical Notes': p.medicalNotes,
            if (p.treatmentNotes.isNotEmpty)
              'Treatment Notes': p.treatmentNotes,
          }.entries)
            _detailRow(entry.key, entry.value),
        ],
        if (store != null && session != null)
          RegistrationDetails(
            showDelivery: false,
            manageAccess: false,
            recipient: NotificationRecipient(
              id: p.id,
              publicId: p.displayId,
              patientId: p.id,
              name: p.name,
              phone: p.contact,
              type: RecipientType.patient,
              registration: p.registration,
              mobileAccount: p.mobileAccount,
            ),
            store: store,
          ),
        if (session != null) ...[
          SessionProgress(session: session),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusChip(session.status),
          ),
        ],
        for (final relative in p.companions) ...[
          const SizedBox(height: 20),
          const Divider(),
          const Text(
            'Designated Relative',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: StaffTheme.navy,
            ),
          ),
          const SizedBox(height: 8),
          const Align(alignment: Alignment.centerLeft, child: PersonAvatar()),
          Text('${relative.name}\n(${relative.relationship})'),
          Text(
            'Relative ID: ${relative.displayId}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: SelectableText(relative.contact)),
              IconButton(
                tooltip: 'Copy contact number',
                icon: const Icon(Icons.chat_bubble_outline, size: 21),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: relative.contact),
                  );
                  if (context.mounted) {
                    showNotice(context, 'Contact number copied.');
                  }
                },
              ),
            ],
          ),
          if (store != null && session != null)
            RegistrationDetails(
              showDelivery: false,
              manageAccess: false,
              recipient: NotificationRecipient(
                id: relative.id,
                publicId: relative.displayId,
                patientId: p.id,
                name: relative.name,
                phone: relative.contact,
                type: RecipientType.relative,
                registration: relative.registration,
                mobileAccount: relative.mobileAccount,
              ),
              store: store,
            ),
        ],
        if (p.companions.isEmpty && session != null) ...[
          const SizedBox(height: 18),
          const Text(
            'Designated Relative',
            style: TextStyle(
              color: StaffTheme.navy,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'No relative has been added for this patient.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
        if (session == null && p.companions.isEmpty) ...[
          _detailSection('Designated Relative'),
          const Text('No designated Relative has been added.'),
        ],
        if (session == null && store != null) ...[
          const SizedBox(height: 24),
          PatientMobileAccess(patientId: p.id, store: store),
        ],
        if (store != null) ...[
          const Divider(),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.notifications_active_outlined, size: 17),
                label: const Text('Send Reminder'),
                onPressed: () {
                  final target =
                      session ??
                      (store.sessions
                              .where((s) => s.patientId == p.id && s.upcoming)
                              .toList()
                            ..sort((a, b) => a.start.compareTo(b.start)))
                          .firstOrNull;
                  if (target == null) {
                    showNotice(
                      context,
                      'No upcoming schedule is available for this patient.',
                    );
                    return;
                  }
                  Navigator.pop(context);
                  showReminderComposer(anchor, store, target);
                },
              ),
              if (session != null && title != 'Report Details')
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: Text(
                    title == 'Session Details'
                        ? 'Change Status'
                        : 'Edit Schedule',
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    showSessionManagement(
                      anchor,
                      store,
                      session,
                      schedule: title != 'Session Details',
                    );
                  },
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

class ViewAction extends StatelessWidget {
  const ViewAction({
    super.key,
    required this.patient,
    this.session,
    this.store,
    this.title = 'Patient Details',
  });
  final Patient patient;
  final SessionRecord? session;
  final StaffStore? store;
  final String title;
  @override
  Widget build(BuildContext context) => Builder(
    builder: (anchor) => TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(54, 34),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      onPressed: () => showPatientDetails(
        anchor,
        patient,
        session: session,
        title: title,
        store: store,
      ),
      child: const Text(
        'View',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: StaffTheme.navy, fontSize: 14),
      ),
    ),
  );
}

Widget _detailSection(String text) => Padding(
  padding: const EdgeInsets.only(top: 18, bottom: 10),
  child: Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.bold,
      color: StaffTheme.navy,
      fontSize: 15,
    ),
  ),
);
Widget _detailRow(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 130,
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
      ),
      Expanded(
        child: SelectableText(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  ),
);
