import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dialycare_mobile/main.dart';
import 'package:dialycare_mobile/mobile_store.dart';

void main() {
  for (final role in ['patient', 'relative']) {
    testWidgets(
      '$role More History shows canonical ID and safe historical details',
      (tester) async {
        final store =
            MobileStore(
                testHistory: CallbackHistoryService(
                  () async => [
                    const HistoryItem(
                      category: 'Sessions',
                      title: 'Completed',
                      patient: 'Synthetic Patient • DP-2026-001',
                      timestamp: '2026-10-21T08:00:00Z',
                      details: 'Batch A; active duration: 210 minutes',
                    ),
                    const HistoryItem(
                      category: 'Feedback & Concerns',
                      title: 'Resolved schedule question',
                      patient: 'Synthetic Patient • DP-2026-001',
                      timestamp: '2026-10-22T08:00:00Z',
                      details: 'Resolved; original records retained',
                      status: 'Resolved',
                    ),
                  ],
                ),
              )
              ..role = role
              ..profile = {
                'name': 'Synthetic User',
                'accountId': role == 'patient' ? 'DP-2026-001' : 'R-000001',
                'patientId': 'DP-2026-001',
                'patientName': 'Synthetic Patient',
              };
        addTearDown(store.dispose);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(home: MobileShell(store: store)));
        await tester.pumpAndSettle();
        await tester.tap(find.text('History').last);
        await tester.pumpAndSettle();
        expect(find.byType(ActivityHistoryPage), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.text('Completed'), findsOneWidget);
        expect(find.textContaining('DP-2026-001'), findsWidgets);
        await tester.tap(find.text('Completed'));
        await tester.pumpAndSettle();
        expect(find.textContaining('210 minutes'), findsOneWidget);
        expect(find.textContaining('actorUid'), findsNothing);
        expect(find.text('Send Response'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
