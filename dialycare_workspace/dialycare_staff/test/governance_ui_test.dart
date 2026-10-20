import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:core_shared/core_shared.dart';
import 'package:dialycare_staff/main.dart';
import 'package:dialycare_staff/screens/patients/patients_screen.dart';
import 'package:dialycare_staff/services/staff_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [1400.0, 390.0]) {
    testWidgets(
      'Settings route, documents, audit, support and backup status at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var auditReads = 0;
        late final StaffStore store;
        store = StaffStore(
          memoryOnly: true,
          shared: true,
          readAuditEvents: () async {
            auditReads++;
            return store.auditEvents;
          },
        );
        addTearDown(store.dispose);
        store.auditEvents = [
          {
            'actorUid': 'fictional-staff',
            'actorRole': 'staff',
            'action': 'patientArchived',
            'resourceType': 'patient',
            'resourceId': 'DC-001',
            'timestamp': '2026-10-19T08:00:00Z',
            'outcome': 'success',
          },
        ];
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
        final boundary = GlobalKey();
        Future<void> capture(String page) async {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'verification/capstone-$page-${width.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: DialyCareApp(store: store),
          ),
        );
        await tester.pumpAndSettle();
        if (width < 850) {
          await tester.tap(find.byTooltip('Open navigation menu'));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('Settings'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        Future<void> tap(String text) async {
          await tester.ensureVisible(find.text(text).last);
          await tester.tap(find.text(text).last);
          await tester.pumpAndSettle();
        }

        await capture('settings');
        await tap('Center Information');
        expect(
          tester.widget<TextField>(find.byType(TextField).first).readOnly,
          isTrue,
        );
        expect(find.text('Save Center Information'), findsNothing);
        await tap('All Settings');
        await tap('Privacy & Terms');
        await tap('Terms of Use');
        expect(find.textContaining('DRAFT / CAPSTONE TERMS'), findsOneWidget);
        await tap('Close');
        await tap('Privacy Notice');
        expect(
          find.textContaining('DRAFT / CAPSTONE PRIVACY NOTICE'),
          findsOneWidget,
        );
        await tap('Close');
        await tap('All Settings');
        expect(auditReads, 0);
        await tap('Audit Activity');
        expect(auditReads, 1);
        await tap('Refresh Activity');
        expect(auditReads, 2);
        await capture('audit');
        expect(find.text('Patient archived'), findsOneWidget);
        await tap('Mobile Access');
        expect(find.text('Patient archived'), findsNothing);
        await tap('Patients');
        expect(find.text('Patient archived'), findsOneWidget);
        await tap('All Settings');
        await tap('Data & Backup Status');
        await capture('backup');
        expect(find.text('NOT CONFIGURED / NOT VERIFIED'), findsOneWidget);
        await tap('All Settings');
        await tap('Help & Support');
        expect(find.text('Copy Diagnostic Information'), findsNothing);
        expect(
          find.text('Please contact your dialysis center.'),
          findsOneWidget,
        );
        expect(find.textContaining('urgent medical concerns'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'Archive/restore UI preserves sessions and excludes archived Patients from normal list',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = StaffStore(memoryOnly: true);
      addTearDown(store.dispose);
      final person = store.patients.first, count = store.sessions.length;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PatientsScreen(store: store)),
        ),
      );
      await tester.tap(find.byTooltip('Archive ${person.name}'));
      await tester.pumpAndSettle();
      expect(find.text('Archive Patient?'), findsOneWidget);
      await tester.tap(find.text('Archive Patient'));
      await tester.pumpAndSettle();
      expect(store.patientFor(person.id).archived, isTrue);
      expect(store.sessions.length, count);
      final pending = store.sessions
          .where((s) => s.patientId == person.id)
          .first;
      await expectLater(
        store.sendReminder(pending.id, recipientIds: {person.id}),
        throwsStateError,
      );
      expect(find.text(person.name), findsNothing);
      await expectLater(
        store.addSchedule(person, DateTime(2026, 12, 5), 'Batch A'),
        throwsStateError,
      );
      await tester.tap(find.text('Archived Patients'));
      await tester.pumpAndSettle();
      expect(find.text(person.name), findsOneWidget);
      await tester.tap(find.byTooltip('Restore ${person.name}'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore Patient'));
      await tester.pumpAndSettle();
      expect(store.patientFor(person.id).archived, isFalse);
      expect(store.sessions.length, count);
      expect(store.patients.where((p) => p.id == person.id).length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('diagnostics contain only the fixed technical allow-list', () {
    final text = safeDiagnostics(
      application: 'Staff',
      timestamp: DateTime.utc(2026, 10, 19),
    );
    expect(text, contains('Application Version: 1.0.0+1'));
    expect(text, contains('2026-10-19T00:00:00.000Z'));
    for (final secret in [
      'Anna Marie',
      'Robert',
      'DC-001',
      'REL-001',
      'password',
      'token',
      'apiKey',
      'medicalNotes',
    ]) {
      expect(text, isNot(contains(secret)));
    }
    expect(text.split('\n').length, 6);
  });
}
