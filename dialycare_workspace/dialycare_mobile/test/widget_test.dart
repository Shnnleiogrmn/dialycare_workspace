import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_shared/core_shared.dart';
import 'package:dialycare_mobile/main.dart';
import 'package:dialycare_mobile/mobile_store.dart';

class TestApi extends BackendClient {
  TestApi() : super(token: () async => null);
  String role = 'patient';
  int fetches = 0;
  bool failed = false;
  final reads = <String>[];
  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (failed) throw const BackendException('Offline');
    if (action == 'readNotification') {
      reads.add(data['id'] as String);
      return {};
    }
    fetches++;
    return {
      'profile': {
        'role': role,
        'name': role == 'patient' ? 'Test Patient' : 'Test Relative',
        'patientId': 'DC-000001',
        'accountId': role == 'patient' ? 'DC-000001' : 'R-000001',
        'contact': '09000000000',
        'relationship': role == 'relative' ? 'Brother' : '',
        'relativeName': role == 'patient' ? 'Test Relative' : '',
        'relativeRelationship': role == 'patient' ? 'Brother' : '',
        'patientName': 'Test Patient',
      },
      'sessions': [
        SessionRecord(
          id: 'S-1',
          patientId: 'DC-TEST',
          start: DateTime.now().copyWith(hour: 8),
          room: 'Room Test',
          batch: 'Batch Test',
          status: SessionStatus.readyForPickUp,
        ).toJson(),
      ],
      'notifications': [
        {
          'id': 'N-1',
          'type': 'pickup',
          'title': 'Ready for Pick Up',
          'message': 'Your care center has updated your session.',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'readAt': reads.contains('N-1') ? '2026-10-15T08:00:00Z' : null,
        },
      ],
    };
  }
}

void main() {
  test(
    'refresh, unread persistence, and network error retain authorized data',
    () async {
      final api = TestApi(), store = MobileStore(testApi: TestApi());
      store.dispose();
      final s = MobileStore(testApi: api);
      await s.refresh();
      expect(s.unread, 1);
      expect(s.sessions.single.status, SessionStatus.readyForPickUp);
      await s.readNotification('N-1');
      expect(s.unread, 0);
      api.failed = true;
      await s.refresh();
      expect(s.error, isNotNull);
      expect(s.sessions.length, 1);
      s.dispose();
    },
  );
  for (final role in ['patient', 'relative']) {
    testWidgets(
      '$role navigation, details, notification read and phone layouts',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = TestApi()..role = role;
        final store = MobileStore(testApi: api);
        store.role = role;
        await store.refresh();
        await tester.pumpWidget(DialyCareMobile(store: store));
        await tester.pumpAndSettle();
        expect(
          find.text(role == 'patient' ? 'Test Patient' : 'Test Relative'),
          findsWidgets,
        );
        final beforeRefresh = api.fetches;
        await tester.drag(find.byType(RefreshIndicator), const Offset(0, 300));
        await tester.pumpAndSettle();
        expect(api.fetches, greaterThan(beforeRefresh));
        await tester.tap(find.text('View Schedule'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('All'));
        await tester.pumpAndSettle();
        expect(find.text('Ready for Pick Up'), findsWidgets);
        await tester.tap(find.byType(ListTile).first);
        await tester.pumpAndSettle();
        expect(find.text('Dialysis Session'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Open notifications'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ready for Pick Up').last);
        await tester.pumpAndSettle();
        expect(api.reads, ['N-1']);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text('More'));
        await tester.pumpAndSettle();
        expect(find.text('Your Profile'), findsOneWidget);
        await tester.ensureVisible(find.text('Account & Security'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Account & Security'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Change Password'));
        await tester.pumpAndSettle();
        expect(find.text('Save Password'), findsOneWidget);
        for (final size in [const Size(320, 568), const Size(430, 932)]) {
          tester.view.physicalSize = size;
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
        store.dispose();
      },
    );
  }
  testWidgets(
    'opening design, role login and secure registration fit small phones',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = MobileStore(testApi: TestApi());
      await tester.pumpWidget(DialyCareMobile(store: s));
      await tester.pumpAndSettle();
      expect(find.byType(WaveBackground), findsOneWidget);
      await tester.ensureVisible(find.text('I am a Relative'));
      await tester.tap(find.text('I am a Relative'));
      await tester.pumpAndSettle();
      expect(find.text('Relative ID'), findsOneWidget);
      await tester.ensureVisible(find.text('Activate Account'));
      await tester.tap(find.text('Activate Account'));
      await tester.pumpAndSettle();
      expect(find.text('Temporary PIN'), findsOneWidget);
      expect(find.text('Patient ID'), findsNothing);
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Verify Account'));
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  testWidgets('visual review opening, authentication, and both roles', (
    tester,
  ) async {
    if (File('C:/Windows/Fonts/arial.ttf').existsSync()) {
      final font = FontLoader('Roboto')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File('C:/Windows/Fonts/arial.ttf').readAsBytesSync(),
            ),
          ),
        );
      await font.load();
    }
    if (File('C:/Windows/Fonts/georgia.ttf').existsSync()) {
      await (FontLoader('Georgia')..addFont(
            Future.value(
              ByteData.sublistView(
                File('C:/Windows/Fonts/georgia.ttf').readAsBytesSync(),
              ),
            ),
          ))
          .load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    final api = TestApi();
    final s = MobileStore(testApi: api);
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: DialyCareMobile(store: s),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/images/mobile-logo.png'),
        key.currentContext!,
      );
      await precacheImage(
        const AssetImage('assets/images/avatar.png'),
        key.currentContext!,
      );
    });
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: name);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('verification/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('opening');
    await tester.tap(find.text('I am a Patient'));
    await tester.pumpAndSettle();
    await capture('patient-login');
    await tester.tap(find.text('Activate Account'));
    await capture('patient-registration');
    Navigator.of(tester.element(find.byType(AuthScreen))).pop();
    await tester.pumpAndSettle();
    await s.refresh();
    await tester.pumpAndSettle();
    await capture('patient-home');
    await tester.tap(find.text('View Schedule'));
    await capture('patient-schedule');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open notifications'));
    await capture('patient-notifications');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('More').last);
    await capture('patient-more');
    api.role = 'relative';
    await s.refresh(validateRole: false);
    await tester.tap(find.text('Home').last);
    await capture('relative-home');
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
}
