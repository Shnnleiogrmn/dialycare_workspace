import 'package:dialycare_staff/services/staff_store.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dialycare_staff/main.dart';
import 'package:dialycare_staff/models/session.dart';

import 'session_management_test.dart' show sessionFixture;

void main() {
  testWidgets('visual review compact header, all batches and status panels', (
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
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    final store = sessionFixture();
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
      for (final name in [
        'logo',
        'staff-avatar',
        'patient-avatar-male',
        'patient-avatar-female',
      ]) {
        await precacheImage(
          AssetImage('assets/images/$name.png'),
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
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        final file = File('verification/screens/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        img.dispose();
      });
    }

    Future<void> tap(String label) async {
      await tester.pumpAndSettle();
      final f = find.text(label).last;
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    await capture('compact-header-maximized');
    tester.view.physicalSize = const Size(1280, 720);
    await capture('compact-header-restored');
    tester.view.physicalSize = const Size(1920, 1080);
    await tester.pump();
    await tap('Sessions');
    await tap('Upcoming (7)');
    await capture('batches-upcoming-abc');
    await tester.ensureVisible(find.byKey(const ValueKey('manage-A1')));
    await tester.tap(find.byKey(const ValueKey('manage-A1')));
    await capture('manage-session-pending');
    await tester.tap(find.byKey(const ValueKey('session-status-selector')));
    await tester.pumpAndSettle();
    await tap('In Progress');
    await tap('Update Status');
    await capture('confirm-session-status');
    await tap('Confirm');
    await tap('Ongoing (1)');
    await capture('batches-ongoing');
    await store.changeSessionStatus('A1', SessionStatus.completed);
    await store.changeSessionStatus('A2', SessionStatus.missed);
    await tap('Completed (2)');
    await capture('batches-finished-completed-missed');
    await store.changeSessionStatus('A1', SessionStatus.readyForPickUp);
    await capture('batches-finished-ready-missed');
    await tap('Reports');
    await capture('reports-ready-missed');
    await tap('Sessions');
    await tap('Completed (2)');
    tester.view.physicalSize = const Size(900, 600);
    await capture('batches-small-desktop');
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
