import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_shared/core_shared.dart';
import 'package:dialycare_mobile/main.dart';
import 'package:dialycare_mobile/mobile_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_progress_ui_test.dart' show ProgressApi;

class InterruptedApi extends ProgressApi {
  SessionStatus state = SessionStatus.paused;
  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    final response = await super.call(action, data), t = started;
    if (role == 'patient') {
      (response['profile'] as Map)['gender'] = 'Female';
    } else {
      (response['profile'] as Map).remove('gender');
    }
    final raw = (response['sessions'] as List).single as Map;
    raw['status'] = state.label;
    raw['pauseSequence'] = 1;
    raw['pauseIntervals'] = {
      'p1': PauseInterval(
        pausedAt: t.add(const Duration(hours: 1)),
        resumedAt: state == SessionStatus.endedEarly
            ? t.add(const Duration(hours: 2))
            : null,
      ).toJson(),
    };
    if (state == SessionStatus.endedEarly) {
      raw['endedAt'] = t
          .add(const Duration(hours: 2))
          .toUtc()
          .toIso8601String();
    }
    return response;
  }
}

void main() {
  for (final role in ['patient', 'relative']) {
    for (final state in [SessionStatus.paused, SessionStatus.endedEarly]) {
      testWidgets('$role displays safe ${state.label} without timer writes', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await (FontLoader('Roboto')..addFont(
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
        final api = InterruptedApi()
              ..role = role
              ..state = state,
            store = MobileStore(testApi: api)..role = role;
        addTearDown(store.dispose);
        await store.refresh();
        expect(store.error, isNull);
        expect(store.profile, isNotNull);
        expect(store.sessions.single.status, state);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: DialyCareMobile(store: store),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => precacheImage(
            const AssetImage(
              'assets/patient-avatar-female.png',
              package: 'core_shared',
            ),
            key.currentContext!,
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byType(SessionProgress),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final before =
            find
                    .textContaining(
                      state == SessionStatus.paused
                          ? 'Elapsed:'
                          : 'Actual Duration:',
                    )
                    .evaluate()
                    .single
                    .widget
                as Text;
        final calls = api.fetches;
        await tester.pump(const Duration(seconds: 5));
        expect(api.fetches, calls);
        expect(find.text(before.data!), findsOneWidget);
        expect(find.text('Pause'), findsNothing);
        expect(find.text('End Early'), findsNothing);
        expect(find.textContaining('PRIVATE'), findsNothing);
        if (state == SessionStatus.paused) {
          expect(
            find.textContaining('Treatment is temporarily paused.'),
            findsOneWidget,
          );
        } else {
          expect(find.textContaining('Ended At:'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('verification/$role-${state.name}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
