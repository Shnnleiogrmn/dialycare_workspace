import 'dart:io';
import 'dart:ui' as ui;

import 'package:dialycare_staff/screens/patients/patient_form.dart';
import 'package:dialycare_staff/services/staff_store.dart';
import 'package:dialycare_staff/theme/staff_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [1400.0, 390.0]) {
    testWidgets(
      'Patient fields validate and save without changing identity at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        if (File('C:/Windows/Fonts/arial.ttf').existsSync()) {
          await (FontLoader('Arial')..addFont(
                Future.value(
                  ByteData.sublistView(
                    File('C:/Windows/Fonts/arial.ttf').readAsBytesSync(),
                  ),
                ),
              ))
              .load();
        }
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        final store = StaffStore(memoryOnly: true);
        addTearDown(store.dispose);
        final original = store.patients.first;
        var saved = false;
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: StaffTheme.theme,
              home: Scaffold(
                body: PatientForm(
                  store: store,
                  patient: original,
                  onDone: () => saved = true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> capture(String section) async {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'verification/patient-fields-$section-${width.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        Future<void> field(String key, String value) async {
          final finder = find.byKey(ValueKey(key));
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.enterText(finder, value);
        }

        await field('patient-address', 'Verification address');
        await field('patient-philhealth', '0000-0000-0000');
        await tester.ensureVisible(
          find.byKey(const ValueKey('patient-marital-status')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('patient-marital-status')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Married').last);
        await tester.pumpAndSettle();
        await capture('personal');
        await tester.ensureVisible(find.text('Medical Info'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Medical Info'));
        await tester.pumpAndSettle();
        await field('patient-height', '-2');
        await field('patient-weight', '62.2');
        await tester.ensureVisible(
          find.byKey(const ValueKey('patient-mdr-status')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('patient-mdr-status')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Yes').last);
        await tester.pumpAndSettle();
        Future<void> save() async {
          final button = find.widgetWithText(ElevatedButton, 'Save');
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          await tester.tap(button);
          await tester.pumpAndSettle();
        }

        await save();
        expect(saved, false);
        expect(
          find.text('Enter a positive numeric height in cm.'),
          findsOneWidget,
        );
        await field('patient-height', '168.5');
        await save();
        expect(saved, true);
        final person = store.patientFor(original.id);
        expect(person.id, original.id);
        expect(person.displayId, 'DC-000001');
        expect(person.heightCm, 168.5);
        expect(person.weightKg, 62.2);
        expect(person.maritalStatus, 'Married');
        expect(person.philHealthNumber, '0000-0000-0000');
        expect(person.mdrStatus, 'Yes');
        await tester.ensureVisible(
          find.byKey(const ValueKey('patient-height')),
        );
        await tester.pumpAndSettle();
        await capture('medical');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
