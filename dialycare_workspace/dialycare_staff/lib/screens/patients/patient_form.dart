import 'package:core_shared/core_shared.dart';

import '../../models/notification_delivery.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/patient.dart';
import '../../services/staff_store.dart';
import '../../theme/staff_theme.dart';
import '../../widgets/staff_components.dart';
import '../../widgets/pickers.dart';
import '../../widgets/patient_mobile_access.dart';

class _RelativeFields {
  _RelativeFields(this.original)
    : name = TextEditingController(text: original?.name),
      address = TextEditingController(text: original?.address),
      contact = TextEditingController(text: original?.contact),
      relationship = original?.relationship ?? 'Sister';
  final Companion? original;

  final TextEditingController name, address, contact;
  String relationship;
  void dispose() {
    name.dispose();
    address.dispose();
    contact.dispose();
  }

  Companion get value => Companion(
    id: original?.id ?? '',
    publicId: original?.publicId ?? '',
    registration: original?.registration ?? const AppRegistration(),
    name: name.text.trim(),
    relationship: relationship,
    address: address.text.trim(),
    contact: contact.text.trim(),
  );
}

class PatientForm extends StatefulWidget {
  const PatientForm({
    super.key,
    required this.store,
    required this.onDone,
    this.patient,
  });
  final StaffStore store;
  final VoidCallback onDone;
  final Patient? patient;
  @override
  State<PatientForm> createState() => _PatientFormState();
}

class _PatientFormState extends State<PatientForm> {
  int tab = 0;
  bool busy = false;
  String? error;
  String? openedVersion;
  late final TextEditingController name,
      suffix,
      contact,
      address,
      medical,
      treatment,
      philHealth,
      height,
      weight;
  late final List<_RelativeFields> relatives;
  DateTime? birth;
  ScheduleGroup? scheduleGroup;
  String gender = 'Female', blood = '', marital = 'Unknown', mdr = 'Unknown';
  @override
  void initState() {
    super.initState();
    final p = widget.patient;
    scheduleGroup = p?.scheduleGroup;
    openedVersion = widget.store.workspaceVersion;
    name = TextEditingController(text: p?.name);
    suffix = TextEditingController(text: p?.suffix);
    contact = TextEditingController(text: p?.contact);
    address = TextEditingController(text: p?.address);
    medical = TextEditingController(text: p?.medicalNotes);
    treatment = TextEditingController(text: p?.treatmentNotes);
    philHealth = TextEditingController(text: p?.philHealthNumber);
    height = TextEditingController(text: p?.heightCm?.toString() ?? '');
    weight = TextEditingController(text: p?.weightKg?.toString() ?? '');
    marital = maritalStatuses.contains(p?.maritalStatus)
        ? p!.maritalStatus
        : 'Unknown';
    mdr = mdrStatuses.contains(p?.mdrStatus) ? p!.mdrStatus : 'Unknown';
    birth = p?.birthDate;
    gender = p?.gender ?? 'Female';
    blood = p?.bloodType ?? '';
    relatives = List.generate(
      math.max(2, p?.companions.length ?? 0),
      (i) => _RelativeFields(
        i < (p?.companions.length ?? 0) ? p!.companions[i] : null,
      ),
    );
    if (p == null || p.companions.length < 2) {
      relatives[1].relationship = 'Father';
    }
  }

  @override
  void dispose() {
    for (final c in [
      name,
      suffix,
      contact,
      address,
      medical,
      treatment,
      philHealth,
      height,
      weight,
    ]) {
      c.dispose();
    }
    for (final r in relatives) {
      r.dispose();
    }
    super.dispose();
  }

  Widget _label(String title, Widget field, {bool required = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text.rich(
        TextSpan(
          text: title,
          style: const TextStyle(color: StaffTheme.navy, fontSize: 15),
          children: required
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: Colors.red),
                  ),
                ]
              : [],
        ),
      ),
      const SizedBox(height: 9),
      field,
    ],
  );
  Widget _text(
    String label,
    TextEditingController controller, {
    String hint = '',
    bool required = false,
    String? id,
    int lines = 1,
    TextInputType? keyboardType,
  }) => _label(
    label,
    TextField(
      key: id == null ? null : ValueKey(id),
      controller: controller,
      maxLines: lines,
      decoration: InputDecoration(hintText: hint),
      keyboardType:
          keyboardType ??
          (label.contains('Contact')
              ? TextInputType.phone
              : TextInputType.text),
    ),
    required: required,
  );
  Widget _pair(Widget left, Widget right) => LayoutBuilder(
    builder: (context, c) => c.maxWidth < 600
        ? Column(children: [left, const SizedBox(height: 22), right])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: left),
              const SizedBox(width: 56),
              Expanded(flex: 2, child: right),
            ],
          ),
  );
  Future<void> _save() async {
    if (busy) {
      return;
    }
    if (name.text.trim().isEmpty ||
        contact.text.replaceAll(RegExp(r'\D'), '').length < 7 ||
        contact.text.trim().length > 40 ||
        name.text.trim().length > 160 ||
        address.text.trim().isEmpty ||
        (birth == null && widget.patient == null)) {
      setState(() {
        tab = 0;
        error =
            'Enter a name, date of birth, valid contact number, and address.';
      });
      return;
    }
    for (final entry in {
      'height': height.text,
      'weight': weight.text,
    }.entries) {
      final value = double.tryParse(entry.value.trim());
      if (entry.value.trim().isNotEmpty &&
          (value == null || !value.isFinite || value <= 0)) {
        setState(() {
          tab = 2;
          error =
              'Enter a positive numeric ${entry.key} in ${entry.key == 'height' ? 'cm' : 'kg'}.';
        });
        return;
      }
    }
    if (philHealth.text.trim().length > 30 ||
        (philHealth.text.trim().isNotEmpty &&
            !RegExp(r'^[0-9 -]+$').hasMatch(philHealth.text.trim()))) {
      setState(() {
        tab = 0;
        error =
            'Enter a valid PhilHealth Number using digits, spaces, or hyphens.';
      });
      return;
    }
    for (final r in relatives) {
      if (r.name.text.isNotEmpty ||
          r.contact.text.isNotEmpty ||
          r.address.text.isNotEmpty) {
        if (r.name.text.trim().isEmpty ||
            r.contact.text.replaceAll(RegExp(r'\D'), '').length < 7 ||
            r.contact.text.trim().length > 40 ||
            r.name.text.trim().length > 160) {
          setState(() {
            tab = 1;
            error = 'Each relative needs a name and valid contact number.';
          });
          return;
        }
      }
    }
    setState(() {
      busy = true;
      error = null;
    });
    final old = widget.patient;
    String assignedId;
    try {
      assignedId = old?.id ?? widget.store.nextPatientId;
    } on BackendException catch (failure) {
      setState(() {
        error = failure.message;
        busy = false;
      });
      return;
    }
    final now = DateTime.now();
    final age = birth == null
        ? old!.age
        : now.year -
              birth!.year -
              ((now.month < birth!.month ||
                      now.month == birth!.month && now.day < birth!.day)
                  ? 1
                  : 0);
    final p = Patient(
      id: assignedId,
      publicId: old?.publicId ?? assignedId,
      maritalStatus: marital,
      philHealthNumber: philHealth.text.trim(),
      heightCm: double.tryParse(height.text.trim()),
      weightKg: double.tryParse(weight.text.trim()),
      mdrStatus: mdr,
      scheduleGroup: scheduleGroup,
      registration: old?.registration ?? const AppRegistration(),
      name: name.text.trim(),
      age: age,
      gender: gender,
      contact: contact.text.trim(),
      suffix: suffix.text.trim(),
      address: address.text.trim(),
      birthDate: birth,
      bloodType: blood,
      medicalNotes: medical.text.trim(),
      treatmentNotes: treatment.text.trim(),
      room: old?.room ?? 'Unassigned',
      batch: old?.batch ?? 'Batch A',
      time: old?.time ?? '',
      status: old?.status ?? 'Pending',
      companions: relatives
          .where((r) => r.name.text.trim().isNotEmpty)
          .map((r) => r.value)
          .toList(),
    );
    try {
      try {
        await widget.store.savePatient(
          p,
          expectedVersion: old == null ? null : openedVersion,
        );
      } on BackendException catch (failure) {
        final conflict =
            failure.statusCode == 409 ||
            (failure is FirestoreFailure &&
                [
                  'FAILED_PRECONDITION',
                  'ABORTED',
                  'ALREADY_EXISTS',
                ].contains(failure.code));
        if (old != null || !conflict) rethrow;
        // A new record can safely obtain another ID; existing Patient edits are
        // never retried over another Staff member's changes.
        await widget.store.refreshShared();
        if (widget.store.loadError != null) {
          throw BackendException(widget.store.loadError!);
        }
        final freshId = widget.store.nextPatientId;
        await widget.store.savePatient(
          Patient.fromJson({...p.toJson(), 'id': freshId, 'publicId': freshId}),
        );
      }
      openedVersion = widget.store.workspaceVersion;
      if (mounted) {
        showNotice(
          context,
          old == null ? 'Patient added.' : 'Patient updated.',
        );
        widget.onDone();
      }
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = failure is BackendException
              ? failure.message
              : 'Could not save the patient. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Widget _personal() => Column(
    children: [
      _pair(
        _text(
          'Full Name',
          name,
          hint: 'Name',
          required: true,
          id: 'patient-name',
        ),
        _text('Suffix Name', suffix),
      ),
      const SizedBox(height: 28),
      _pair(
        _label(
          'Date of Birth',
          Builder(
            builder: (anchor) => SelectorButton(
              key: const ValueKey('patient-dob'),
              label: birth == null ? 'Select date' : shortDate(birth!),
              icon: Icons.calendar_month_outlined,
              onPressed: () async {
                final date = await chooseDate(
                  anchor,
                  birth ?? DateTime(DateTime.now().year - 40, 1, 1),
                  birth: true,
                );
                if (date != null && mounted) {
                  setState(() => birth = date);
                }
              },
            ),
          ),
          required: true,
        ),
        _label(
          'Gender',
          DropdownButtonFormField<String>(
            initialValue: gender,
            items: [
              for (final g in ['Female', 'Male', 'Other'])
                DropdownMenuItem(value: g, child: Text(g)),
            ],
            onChanged: (v) => setState(() => gender = v!),
          ),
          required: true,
        ),
      ),
      const SizedBox(height: 28),
      DropdownButtonFormField<String>(
        key: const ValueKey('patient-schedule-group'),
        initialValue: scheduleGroup?.code ?? '',
        decoration: const InputDecoration(labelText: 'Schedule Group'),
        isExpanded: true,
        items: [
          const DropdownMenuItem(value: '', child: Text('Not assigned')),
          for (final group in ScheduleGroup.values)
            DropdownMenuItem(
              value: group.code,
              child: Text(
                '${group.label} • ${group.daysLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
        onChanged: (value) =>
            setState(() => scheduleGroup = ScheduleGroup.parse(value)),
      ),
      const SizedBox(height: 24),
      _text(
        'Contact Number',
        contact,
        hint: '123-456-789-0',
        required: true,
        id: 'patient-contact',
      ),
      const SizedBox(height: 24),
      _text(
        'Address',
        address,
        hint: 'Enter Complete Address',
        required: true,
        id: 'patient-address',
      ),
      const SizedBox(height: 24),
      _pair(
        _label(
          'Marital Status',
          DropdownButtonFormField<String>(
            key: const ValueKey('patient-marital-status'),
            initialValue: marital,
            items: [
              for (final value in maritalStatuses)
                DropdownMenuItem(value: value, child: Text(value)),
            ],
            onChanged: (value) => setState(() => marital = value!),
          ),
        ),
        _text(
          'PhilHealth Number',
          philHealth,
          id: 'patient-philhealth',
          keyboardType: TextInputType.number,
        ),
      ),
    ],
  );
  Widget _relative() => Column(
    children: [
      if (widget.patient != null)
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'Changing a designated relative’s name or phone creates a replacement identity and requires new activation. Previous access is retired.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
      for (var i = 0; i < relatives.length; i++) ...[
        if (i > 0) const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Designated Relative ${i + 1}',
            style: const TextStyle(
              color: StaffTheme.navy,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: SelectableText(
            relatives[i].original == null
                ? 'Relative ID is assigned when saved.'
                : 'Relative ID: ${relatives[i].original!.displayId}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
        const SizedBox(height: 16),
        _pair(
          _text(
            'Full Name',
            relatives[i].name,
            hint: 'Name',
            id: 'relative-name-$i',
          ),
          _label(
            'Relationship',
            DropdownButtonFormField<String>(
              initialValue: relatives[i].relationship,
              items: [
                for (final r in [
                  'Sister',
                  'Brother',
                  'Father',
                  'Mother',
                  'Spouse',
                  'Son',
                  'Daughter',
                  'Friend',
                  'Other',
                ])
                  DropdownMenuItem(value: r, child: Text(r)),
              ],
              onChanged: (v) => setState(() => relatives[i].relationship = v!),
            ),
          ),
        ),
        const SizedBox(height: 22),
        _pair(
          _text(
            'Address',
            relatives[i].address,
            hint: 'Enter Complete Address',
          ),
          _text(
            'Contact Number',
            relatives[i].contact,
            hint: '123-456-789-0',
            id: 'relative-contact-$i',
          ),
        ),
      ],
    ],
  );
  String get patientIdLabel {
    if (widget.patient != null) return widget.patient!.displayId;
    try {
      return widget.store.nextPatientId;
    } on BackendException {
      return 'ID range exhausted — contact your administrator';
    }
  }

  Widget _medical() => Column(
    children: [
      _pair(
        _label(
          'Patient ID',
          TextFormField(
            initialValue:
                widget.patient?.displayId ?? widget.store.nextPatientId,
            readOnly: true,
          ),
        ),
        _label(
          'Type of Blood',
          Builder(
            builder: (anchor) => SelectorButton(
              label: blood.isEmpty ? '--' : blood,
              onPressed: () async {
                final value = await chooseOption(
                  anchor,
                  title: 'Type of Blood',
                  options: const [
                    'A+',
                    'AB+',
                    'A-',
                    'AB-',
                    'B+',
                    'O+',
                    'B-',
                    'O-',
                  ],
                  value: blood,
                  columns: 2,
                );
                if (value != null && mounted) {
                  setState(() => blood = value);
                }
              },
            ),
          ),
        ),
      ),
      const SizedBox(height: 28),
      _pair(
        _text(
          'Height (cm)',
          height,
          id: 'patient-height',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        _text(
          'Weight (kg)',
          weight,
          id: 'patient-weight',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ),
      const SizedBox(height: 24),
      _label(
        'MDR Status — Multi-Drug Resistance',
        DropdownButtonFormField<String>(
          key: const ValueKey('patient-mdr-status'),
          initialValue: mdr,
          items: [
            for (final value in mdrStatuses)
              DropdownMenuItem(value: value, child: Text(value)),
          ],
          onChanged: (value) => setState(() => mdr = value!),
        ),
      ),
      const SizedBox(height: 24),
      _pair(
        _text('Medical notes', medical, lines: 3),
        _text('Additional treatment notes', treatment, lines: 3),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PageHeader(
        widget.patient != null
            ? 'Edit Patient'
            : tab == 0
            ? 'Add Patient'
            : tab == 1
            ? 'Add Companion'
            : 'Add Medical Info',
      ),
      PageBody(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: AppPanel(
                child: Column(
                  children: [
                    SectionTabs(
                      labels: const [
                        'Personal Info',
                        'Relative Info',
                        'Medical Info',
                        'Mobile Access',
                      ],
                      index: tab,
                      onChanged: (v) => setState(() => tab = v),
                      color: StaffTheme.gray,
                      height: 72,
                    ),
                    Padding(
                      padding: EdgeInsets.all(
                        MediaQuery.sizeOf(context).width < 700 ? 22 : 42,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (error != null) ...[
                            Text(
                              error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 20),
                          ],
                          switch (tab) {
                            0 => _personal(),
                            1 => _relative(),
                            3 =>
                              widget.patient == null
                                  ? const Text(
                                      'Save the Patient and designated Relative before creating Mobile Access.',
                                    )
                                  : PatientMobileAccess(
                                      patientId: widget.patient!.id,
                                      store: widget.store,
                                    ),
                            _ => _medical(),
                          },
                          const SizedBox(height: 30),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 24,
                            runSpacing: 12,
                            children: [
                              AppButton(
                                'Cancel',
                                onPressed: busy ? null : widget.onDone,
                              ),
                              AppButton(
                                busy ? 'Saving...' : 'Save',
                                primary: true,
                                onPressed: busy ? null : _save,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
