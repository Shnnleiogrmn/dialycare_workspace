import 'package:core_shared/core_shared.dart';

import 'notification_delivery.dart';

const maritalStatuses = [
  'Unknown',
  'Single',
  'Married',
  'Widowed',
  'Separated',
  'Divorced',
];
const mdrStatuses = ['Unknown', 'No', 'Yes'];

class Companion {
  const Companion({
    this.id = '',
    this.publicId = '',
    this.mobileAccount = const MobileAccount(),
    this.registration = const AppRegistration(),
    this.name = '',
    this.relationship = 'Sister',
    this.address = '',
    this.contact = '',
  });
  final String id, publicId, name, relationship, address, contact;
  String get displayId =>
      publicId.isNotEmpty ? publicId : centerIdLabel(id, 'R-');
  final AppRegistration registration;
  final MobileAccount mobileAccount;
  Map<String, dynamic> toJson() => {
    'id': id,
    'publicId': publicId,
    'registration': registration.toJson(),
    'mobileAccount': mobileAccount.toJson(),
    'name': name,
    'relationship': relationship,
    'address': address,
    'contact': contact,
  };
  factory Companion.fromJson(Map<String, dynamic> j) => Companion(
    mobileAccount: MobileAccount.fromJson(
      (j['mobileAccount'] as Map?)?.cast<String, dynamic>(),
    ),
    id: j['id'] as String? ?? '',
    publicId: j['publicId'] as String? ?? '',
    registration: AppRegistration.fromJson(
      (j['registration'] as Map?)?.cast<String, dynamic>(),
    ),
    name: j['name'] as String? ?? '',
    relationship: j['relationship'] as String? ?? 'Other',
    address: j['address'] as String? ?? '',
    contact: j['contact'] as String? ?? '',
  );
}

class Patient {
  const Patient({
    required this.id,
    this.publicId = '',
    this.maritalStatus = 'Unknown',
    this.philHealthNumber = '',
    this.heightCm,
    this.weightKg,
    this.mdrStatus = 'Unknown',
    this.scheduleGroup,
    this.recordStatus = 'active',
    this.archivedAt,
    this.archivedBy,
    this.mobileAccount = const MobileAccount(),
    required this.name,
    required int age,
    required this.gender,
    required this.contact,
    this.room = 'Unassigned',
    this.batch = 'Batch A',
    this.time = '',
    // Legacy demo seed only. Operational state lives on SessionRecord.
    this.status = 'Pending',
    this.suffix = '',
    this.address = '',
    this.birthDate,
    this.bloodType = '',
    this.medicalNotes = '',
    this.treatmentNotes = '',
    this.companions = const [],
    this.registration = const AppRegistration(),
  }) : _legacyAge = age;
  final String id,
      name,
      gender,
      contact,
      room,
      batch,
      time,
      status,
      suffix,
      address,
      bloodType,
      medicalNotes,
      treatmentNotes;
  final String publicId, maritalStatus, philHealthNumber, mdrStatus;
  final double? heightCm, weightKg;
  final ScheduleGroup? scheduleGroup;
  String get displayId =>
      publicId.isNotEmpty ? publicId : centerIdLabel(id, 'DC-');
  final String recordStatus;
  final DateTime? archivedAt;
  final String? archivedBy;
  bool get archived => recordStatus == 'archived';
  final AppRegistration registration;
  final MobileAccount mobileAccount;
  final int _legacyAge;
  int get age {
    final dob = birthDate;
    if (dob == null) return _legacyAge;
    final now = DateTime.now();
    return now.year -
        dob.year -
        (now.month < dob.month || (now.month == dob.month && now.day < dob.day)
            ? 1
            : 0);
  }

  final DateTime? birthDate;
  final List<Companion> companions;
  Map<String, dynamic> toJson() => {
    'id': id,
    'publicId': publicId,
    'maritalStatus': maritalStatus,
    'philHealthNumber': philHealthNumber,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'mdrStatus': mdrStatus,
    if (scheduleGroup != null) 'scheduleGroup': scheduleGroup!.code,
    'recordStatus': recordStatus,
    'archivedAt': archivedAt?.toUtc().toIso8601String(),
    'archivedBy': archivedBy,
    'name': name,
    'registration': registration.toJson(),
    'mobileAccount': mobileAccount.toJson(),
    if (birthDate == null) 'age': age,
    'gender': gender,
    'contact': contact,
    'room': room,
    'batch': batch,
    'time': time,
    'status': status,
    'suffix': suffix,
    'address': address,
    'birthDate': birthDate?.toIso8601String(),
    'bloodType': bloodType,
    'medicalNotes': medicalNotes,
    'treatmentNotes': treatmentNotes,
    'companions': companions.map((c) => c.toJson()).toList(),
  };
  factory Patient.fromJson(Map<String, dynamic> j) => Patient(
    publicId: j['publicId'] as String? ?? '',
    maritalStatus: j['maritalStatus'] as String? ?? 'Unknown',
    philHealthNumber: j['philHealthNumber'] as String? ?? '',
    heightCm: double.tryParse(j['heightCm']?.toString() ?? ''),
    weightKg: double.tryParse(j['weightKg']?.toString() ?? ''),
    mdrStatus: j['mdrStatus'] as String? ?? 'Unknown',
    scheduleGroup: ScheduleGroup.parse(j['scheduleGroup']),
    recordStatus: j['recordStatus'] as String? ?? 'active',
    archivedAt: DateTime.tryParse(j['archivedAt'] as String? ?? ''),
    archivedBy: j['archivedBy'] as String?,
    mobileAccount: MobileAccount.fromJson(
      (j['mobileAccount'] as Map?)?.cast<String, dynamic>(),
    ),
    registration: AppRegistration.fromJson(
      (j['registration'] as Map?)?.cast<String, dynamic>(),
    ),
    id: j['id'] as String,
    name: j['name'] as String,
    age: j['age'] as int? ?? 0,
    gender: j['gender'] as String,
    contact: j['contact'] as String,
    room: j['room'] as String? ?? 'Unassigned',
    batch: j['batch'] as String? ?? 'Batch A',
    time: j['time'] as String? ?? '',
    status: j['status'] as String? ?? 'Pending',
    suffix: j['suffix'] as String? ?? '',
    address: j['address'] as String? ?? '',
    birthDate: DateTime.tryParse(j['birthDate'] as String? ?? ''),
    bloodType: j['bloodType'] as String? ?? '',
    medicalNotes: j['medicalNotes'] as String? ?? '',
    treatmentNotes: j['treatmentNotes'] as String? ?? '',
    companions: ((j['companions'] as List?) ?? [])
        .map((c) => Companion.fromJson(Map<String, dynamic>.from(c as Map)))
        .toList(),
  );
}
