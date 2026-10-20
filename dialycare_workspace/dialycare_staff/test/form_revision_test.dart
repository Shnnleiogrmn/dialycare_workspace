import 'package:dialycare_staff/screens/patients/patient_form.dart';
import 'package:dialycare_staff/services/staff_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'background refresh cannot make an old Patient form overwrite a newer revision',
    (tester) async {
      final store = StaffStore(memoryOnly: true)
        ..workspaceVersion = 'revision-one';
      addTearDown(store.dispose);
      final person = store.patients.first;
      var saved = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PatientForm(
              store: store,
              patient: person,
              onDone: () => saved = true,
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('patient-name')),
        'Uncommitted name',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('patient-address')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('patient-address')),
        'Verification address',
      );
      store.workspaceVersion = 'revision-two';
      final save = find.widgetWithText(ElevatedButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved, false);
      expect(store.patientFor(person.id).name, person.name);
      expect(
        find.text(
          'The workspace changed while you were editing. Reopen the Patient record before saving.',
        ),
        findsOneWidget,
      );
      expect(store.workspaceVersion, 'revision-two');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
