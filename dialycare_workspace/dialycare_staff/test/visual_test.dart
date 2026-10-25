import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dialycare_staff/main.dart';
import 'package:dialycare_staff/services/staff_store.dart';

void main() {
  testWidgets('capture reference screens and form interactions', (
    tester,
  ) async {
    if (File('C:/Windows/Fonts/arial.ttf').existsSync()) {
      final font = FontLoader('Arial')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File('C:/Windows/Fonts/arial.ttf').readAsBytesSync(),
            ),
          ),
        );
      await font.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    tester.view.physicalSize = const Size(1500, 1067);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    final store = StaffStore(memoryOnly: true);
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
      for (final asset in [
        'logo',
        'staff-avatar',
        'patient-avatar-male',
        'patient-avatar-female',
      ]) {
        await precacheImage(
          AssetImage('assets/images/$asset.png'),
          key.currentContext!,
        );
      }
    });
    await tester.pump();
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: name);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await boundary.toImage(pixelRatio: 1);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        final file = File('verification/screens/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        img.dispose();
      });
    }

    Future<void> tap(String text) async {
      final item = (text == 'Cancel' || text == 'Send Reminder')
          ? find.text(text).last
          : find.text(text).first;
      await tester.ensureVisible(item);
      await tester.tap(item);
      await tester.pumpAndSettle();
    }

    await capture('dashboard');
    await tap('View');
    await capture('schedule-details');
    await tap('Send Reminder');
    await capture('send-reminder');
    await tap('Send Reminder');
    await capture('delivery-result');
    await tap('Close');
    await tap('View');
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    await tap('Patients');
    await capture('patients');
    await tap('+ Add Patient');
    await capture('patient-personal');
    await tester.tap(find.byKey(const ValueKey('patient-dob')));
    await capture('birth-date-picker');
    await tap('Cancel');
    await tap('Relative Info');
    await capture('patient-relative');
    await tap('Medical Info');
    await capture('patient-medical');
    await tap('--');
    await capture('blood-type-picker');
    await tap('Cancel');
    await tap('Cancel');
    await tap('Schedules');
    await capture('schedules');
    await tap('+ Add Schedule');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await capture('add-schedule');
    await tester.tap(find.textContaining('9:00 AM').first);
    await capture('schedule-date-time-picker');
    await tap('Cancel');
    await tap('Sessions');
    await capture('sessions-ongoing');
    await tap('Ongoing (2)');
    await capture('sessions-upcoming');
    await tap('Completed (4)');
    await capture('sessions-completed');
    await tap('Notification');
    await capture('notifications');
    await tap('Reports');
    await capture('reports');
    await tester.tap(find.text('All Batches').first);
    await capture('batch-picker');
    await tap('Cancel');
    await tap('Staff');
    await capture('profile');
    await tap('Help/Support');
    await capture('help');
    await tap('Close');
    await tap('Staff');
    await tap('Change Password');
    await capture('password');
    await tap('Cancel');
    await tap('Dashboard');
    tester.view.physicalSize = const Size(1920, 1080);
    await capture('dashboard-maximized');
    tester.view.physicalSize = const Size(900, 600);
    await capture('dashboard-small-desktop');
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
