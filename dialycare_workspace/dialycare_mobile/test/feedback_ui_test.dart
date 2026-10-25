import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dialycare_mobile/main.dart';
import 'package:dialycare_mobile/mobile_store.dart';

import '../../core_shared/test/helpers/concern_fake.dart';

void main() {
  for (final role in ['patient', 'relative']) {
    testWidgets(
      '$role More opens own concerns, validates submission, and displays Staff responses',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = ConcernFake(role: role);
        final store = MobileStore(testConcerns: service)
          ..role = role
          ..profile = {
            'name': 'Synthetic Owner',
            'accountId': 'DC-000001',
            'patientName': 'Synthetic Patient',
          };
        addTearDown(store.dispose);
        await tester.pumpWidget(MaterialApp(home: MobileShell(store: store)));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Feedback').last);
        await tester.pumpAndSettle();
        expect(find.text('Feedback & Concerns').hitTestable(), findsOneWidget);
        expect(find.text('History').hitTestable(), findsOneWidget);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Submit New Concern'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Submit Concern'));
        await tester.tap(find.text('Submit Concern'));
        await tester.pumpAndSettle();
        expect(find.text('Enter a subject.'), findsOneWidget);
        expect(service.records, isEmpty);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Subject'),
          'Schedule question',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Message / Description'),
          'Please review my schedule.',
        );
        await tester.ensureVisible(find.text('Submit Concern'));
        await tester.tap(find.text('Submit Concern'));
        await tester.pumpAndSettle();
        expect(service.records, hasLength(1));
        expect(find.text('Schedule question'), findsOneWidget);
        final id = service.records.single.id;
        await service.update(
          service.records.single,
          response: 'Your schedule has been reviewed.',
        );
        await tester.tap(find.byTooltip('Refresh concerns'));
        await tester.pumpAndSettle();
        expect(find.text('Under Review'), findsOneWidget);
        await tester.tap(find.text('View'));
        await tester.pumpAndSettle();
        expect(find.text('Please review my schedule.'), findsOneWidget);
        expect(find.text('Your schedule has been reviewed.'), findsOneWidget);
        expect(find.text('Send Response'), findsNothing);
        expect(find.text(id), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
