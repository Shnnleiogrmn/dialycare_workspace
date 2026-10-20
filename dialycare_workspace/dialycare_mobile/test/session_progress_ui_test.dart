import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_shared/core_shared.dart';
import 'package:dialycare_mobile/main.dart';
import 'package:dialycare_mobile/mobile_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show TestApi;

class ProgressApi extends TestApi {
  final started = DateTime.now().subtract(
    const Duration(hours: 2, minutes: 17),
  );
  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    final response = await super.call(action, data);
    response['notifications'] = [
      {
        'id': 'progress-schedule',
        'type': 'scheduleCreated',
        'title': 'Schedule Created',
        'message': 'Your center scheduled this dialysis session.',
        'createdAt': started
            .subtract(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
        'readAt': null,
      },
    ];
    (response['profile'] as Map)['scheduleGroup'] = 'MWF';
    response['sessions'] = [
      SessionRecord(
        id: 'progress-demo',
        patientId: 'DC-TEST',
        start: started.subtract(const Duration(minutes: 7)),
        room: 'Room 01',
        batch: 'Batch A',
        status: SessionStatus.inProgress,
        actualStartedAt: started,
        plannedDurationMinutes: 240,
        scheduleGroup: ScheduleGroup.mwf,
      ).toJson(),
    ];
    return response;
  }
}

void main() {
  for (final role in ['patient', 'relative']) {
    testWidgets(
      '$role sees locally ticking progress without another fetch; reopen preserves start',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
        if (File('C:/Windows/Fonts/arial.ttf').existsSync()) {
          await (FontLoader('Roboto')..addFont(
                Future.value(
                  ByteData.sublistView(
                    File('C:/Windows/Fonts/arial.ttf').readAsBytesSync(),
                  ),
                ),
              ))
              .load();
        }
        final api = ProgressApi()..role = role;
        final connected = MobileStore(testApi: api)..role = role;
        await connected.refresh();
        addTearDown(connected.dispose);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: DialyCareMobile(store: connected),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(SessionProgress));
        await tester.pumpAndSettle();
        expect(find.textContaining('Elapsed: 02:17:'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        final fetches = api.fetches;
        await tester.pump(const Duration(seconds: 3));
        expect(api.fetches, fetches);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('verification').create(recursive: true);
          await File('verification/$role-session-progress.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(DialyCareMobile(store: connected));
        await tester.pumpAndSettle();
        expect(connected.sessions.single.actualStartedAt, api.started);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
