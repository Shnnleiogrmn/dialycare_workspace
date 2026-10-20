import 'package:core_shared/core_shared.dart' show PersonLabel;
import 'package:flutter/material.dart';

import '../../models/patient.dart';
import '../../services/staff_store.dart';
import '../../widgets/staff_components.dart';

import 'patient_form.dart';
import '../../widgets/patient_details.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key, required this.store});
  final StaffStore store;
  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  String query = '';
  bool editing = false, showingArchived = false;
  Patient? patient;
  Future<void> _delete(Patient p) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: p.archived ? 'Restore Patient?' : 'Archive Patient?',
        width: 420,
        actions: [
          AppButton('Cancel', onPressed: () => Navigator.pop(context, false)),
          AppButton(
            p.archived ? 'Restore Patient' : 'Archive Patient',
            primary: true,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
        child: Text(
          '${p.name}\n${p.displayId}\n\n${p.archived ? 'Restore this Patient to active operations using the same ID.' : 'This Patient will be removed from active registration and new-session selection. Historical records and sessions will be preserved.'}',
        ),
      ),
    );
    if (result != true) {
      return;
    }
    try {
      await widget.store.setPatientArchived(p.id, !p.archived);
      if (mounted) {
        setState(() {});
        showNotice(
          context,
          p.archived ? 'Patient restored.' : 'Patient archived.',
        );
      }
    } catch (_) {
      if (mounted) {
        showNotice(
          context,
          'Could not change the Patient archive status. The saved data has not changed.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (editing) {
      return PatientForm(
        key: ValueKey(patient?.id ?? 'new'),
        store: widget.store,
        patient: patient,
        onDone: () => setState(() => editing = false),
      );
    }
    final rows = widget.store.patients
        .where((p) => p.archived == showingArchived)
        .where(
          (p) => [
            p.name,
            p.displayId,
            p.contact,
          ].any((v) => v.toLowerCase().contains(query)),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader('Patient Information', date: true),
        PageBody(
          children: [
            Wrap(
              spacing: 12,
              children: [
                ChoiceChip(
                  label: const Text('Active Patients'),
                  selected: !showingArchived,
                  onSelected: (_) => setState(() => showingArchived = false),
                ),
                ChoiceChip(
                  label: const Text('Archived Patients'),
                  selected: showingArchived,
                  onSelected: (_) => setState(() => showingArchived = true),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) => Wrap(
                spacing: 22,
                runSpacing: 14,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: c.maxWidth > 550 ? c.maxWidth - 178 : c.maxWidth,
                    child: AppSearchField(
                      onChanged: (v) =>
                          setState(() => query = v.trim().toLowerCase()),
                    ),
                  ),
                  AppButton(
                    '+ Add Patient',
                    primary: true,
                    onPressed: () => setState(() {
                      patient = null;
                      editing = true;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            AppPanel(
              child: DialyCareTable(
                minWidth: 730,
                columns: const [
                  TableColumn('Patient ID', 15),
                  TableColumn('Name', 24),
                  TableColumn('Age', 8),
                  TableColumn('Gender', 13),
                  TableColumn('Contact', 24),
                  TableColumn('Action', 13),
                ],
                rows: [
                  for (final p in rows)
                    [
                      Text(p.displayId),
                      Builder(
                        builder: (anchor) => InkWell(
                          onTap: () => showPatientDetails(
                            anchor,
                            p,
                            store: widget.store,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: PersonLabel(name: p.name, gender: p.gender),
                          ),
                        ),
                      ),
                      Text('${p.age}'),
                      Text(p.gender),
                      Text(p.contact),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            style: IconButton.styleFrom(
                              minimumSize: const Size(36, 36),
                              fixedSize: const Size(36, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 36,
                              height: 36,
                            ),
                            tooltip: 'Edit ${p.name}',
                            icon: const Icon(Icons.edit_outlined, size: 19),
                            color: Colors.grey,
                            onPressed: () => setState(() {
                              patient = p;
                              editing = true;
                            }),
                          ),
                          IconButton(
                            style: IconButton.styleFrom(
                              minimumSize: const Size(36, 36),
                              fixedSize: const Size(36, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 36,
                              height: 36,
                            ),
                            tooltip: p.archived
                                ? 'Restore ${p.name}'
                                : 'Archive ${p.name}',
                            icon: Icon(
                              p.archived
                                  ? Icons.unarchive_outlined
                                  : Icons.archive_outlined,
                              size: 19,
                            ),
                            color: Colors.grey,
                            onPressed: () => _delete(p),
                          ),
                        ],
                      ),
                    ],
                ],
                empty: 'No patients found.',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
