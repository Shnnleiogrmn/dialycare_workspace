import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dialycare_staff/main.dart';
import 'package:core_shared/core_shared.dart';
import 'package:dialycare_staff/services/staff_store.dart';

import 'session_management_test.dart' show sessionFixture;

void main() {
  testWidgets(
    'refined dashboard, two configured batches and private pause controls render responsively',
    (tester) async {
      await (FontLoader('Arial')..addFont(
            Future.value(
              ByteData.sublistView(
                File('C:/Windows/Fonts/arial.ttf').readAsBytesSync(),
              ),
            ),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final store = sessionFixture();
      store.actorUid = 'verification-staff';
      store.sessions = store.sessions
          .map(
            (s) => s.batch == 'Batch B'
                ? SessionRecord.fromJson({
                    ...s.toJson(),
                    'start': s.start
                        .copyWith(hour: 12)
                        .toUtc()
                        .toIso8601String(),
                  })
                : s,
          )
          .toList();
      store.sessions.removeWhere((s) => s.batch == 'Batch C');
      store.batchConfigurations = [
        for (final name in ['Batch A', 'Batch B'])
          {
            'id': name,
            'name': name,
            'startMinute': name == 'Batch A' ? 480 : 720,
            'endMinute': name == 'Batch A' ? 720 : 960,
            'capacity': null,
            'active': true,
          },
      ];
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: DialyCareApp(
            store: store,
            now: DateTime.now().copyWith(hour: 9),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final gender in ['male', 'female']) {
          await precacheImage(
            AssetImage(
              'assets/patient-avatar-$gender.png',
              package: 'core_shared',
            ),
            key.currentContext!,
          );
        }
      });
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('verification/screens/refined-$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> tap(String label) async {
        final f = find.text(label).last;
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      expect(find.textContaining('registered Patients'), findsNothing);
      expect(find.text('Ready for Pick Up'), findsOneWidget);
      await capture('dashboard');
      await tap('Schedules');
      expect(find.text('Batch C'), findsNothing);
      expect(find.text('Add Patients'), findsNWidgets(2));
      await capture('schedule-batches');
      await tester.tap(find.text('Add Patients').first);
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsOneWidget);
      await capture('eligible-patients');
      await store.changeSessionStatus('A1', SessionStatus.inProgress);
      await tap('Sessions');
      await tester.tap(find.byKey(const ValueKey('manage-A1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('session-status-selector')));
      await tester.pumpAndSettle();
      await tap('Paused');
      await tap('Update Status');
      expect(find.text('Select an operational reason.'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tap('Machine/Equipment Issue');
      await tap('Update Status');
      await tap('Confirm');
      expect(
        store.sessions.firstWhere((s) => s.id == 'A1').status,
        SessionStatus.paused,
      );
      await capture('paused');
      await tester.tap(find.byKey(const ValueKey('manage-A1')));
      await tester.pumpAndSettle();
      await capture('private-history');
      await tap('Cancel');
      tester.view.physicalSize = const Size(390, 700);
      await tester.pumpAndSettle();
      await capture('narrow-sessions');
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
