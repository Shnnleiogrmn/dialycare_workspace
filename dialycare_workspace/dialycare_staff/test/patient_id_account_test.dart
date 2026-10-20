import 'package:flutter_test/flutter_test.dart';
import 'package:core_shared/core_shared.dart';
import 'package:dialycare_staff/models/patient.dart';
import 'package:dialycare_staff/services/staff_store.dart';

void main() {
  test('ordinary edits preserve approved account state and replacement relatives require activation', () async {
    final store = StaffStore(memoryOnly: true);
    addTearDown(store.dispose);
    const person = Patient(
      id: 'TEST-IDENTITY',
      name: 'Test Patient',
      age: 40,
      gender: 'Other',
      contact: '',
      mobileAccount: MobileAccount(status: MobileAccountStatus.active),
      companions: [
        Companion(
          id: 'TEST-RELATIVE',
          name: 'Test Relative',
          relationship: 'Other',
          mobileAccount: MobileAccount(status: MobileAccountStatus.active),
        ),
      ],
    );
    await store.savePatient(person);
    await store.savePatient(
      Patient.fromJson({
        ...person.toJson(),
        'mobileAccount': null,
        'companions': [
          {
            ...person.companions.single.toJson(),
            'mobileAccount': null,
            'relationship': 'Sibling',
          },
        ],
      }),
    );
    expect(store.patientFor(person.id).mobileAccount.label, 'Active');
    expect(
      store.patientFor(person.id).companions.single.mobileAccount.label,
      'Active',
    );
    await store.savePatient(
      Patient.fromJson({
        ...person.toJson(),
        'companions': [
          {
            ...person.companions.single.toJson(),
            'name': 'Replacement Test Relative',
          },
        ],
      }),
    );
    expect(
      store.patientFor(person.id).companions.single.id,
      isNot('TEST-RELATIVE'),
    );
    expect(
      store.patientFor(person.id).companions.single.mobileAccount.label,
      'Not Activated',
    );
  });

  test('Patient ID counter survives deletion and reload instead of reusing an identity', () async {
    String? saved;
    final store = StaffStore(
      readData: () async => saved,
      writeData: (s) async => saved = s,
    );
    final id = store.nextPatientId;
    final patient = Patient(
      id: id,
      name: 'Fictional Test Patient',
      age: 40,
      gender: 'Other',
      contact: '',
    );
    await store.savePatient(patient);
    await store.deletePatient(id);
    expect(store.nextPatientId, isNot(id));
    final loaded = StaffStore(
      readData: () async => saved,
      writeData: (s) async => saved = s,
    );
    await loaded.load();
    expect(loaded.nextPatientId, store.nextPatientId);
    store.dispose();
    loaded.dispose();
  });
}
