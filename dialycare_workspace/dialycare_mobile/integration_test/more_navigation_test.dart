import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:dialycare_mobile/main.dart';
import 'package:dialycare_mobile/mobile_store.dart';

import '../../core_shared/test/helpers/concern_fake.dart';

// Real device runner, production app/shell, fictional authenticated store.
// This checks visible navigation; it does not claim live Firebase login/delivery.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final role in ['patient', 'relative']) {
    testWidgets(
      '$role production app preserves all primary and Home secondary routes',
      (tester) async {
        final store =
            MobileStore(
                testConcerns: ConcernFake(role: role),
                testHistory: CallbackHistoryService(() async => []),
              )
              ..role = role
              ..profile = {
                'name': 'Synthetic user',
                'patientName': 'Synthetic Patient',
                'patientId': 'DP-2026-001',
                'accountId': role == 'patient' ? 'DP-2026-001' : 'R-000001',
              };
        addTearDown(store.dispose);
        await tester.pumpWidget(
          DialyCareMobile(key: ValueKey(role), store: store),
        );
        await tester.pumpAndSettle();
        final destinations = tester
            .widgetList<NavigationDestination>(
              find.byType(NavigationDestination),
            )
            .map((d) => d.label)
            .toList();
        expect(destinations, ['Home', 'Feedback', 'History', 'More']);
        Future<void> nav(String label) async {
          await tester.tap(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.text(label),
            ),
          );
          await tester.pumpAndSettle();
        }

        await tester.ensureVisible(find.text('View Schedule'));
        await tester.tap(find.text('View Schedule'));
        await tester.pumpAndSettle();
        expect(find.text('Schedule'), findsOneWidget);
        await tester.tap(find.text('All'));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byTooltip('Open notifications'),
          -250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(
          find.byTooltip('Open notifications').hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Open notifications'));
        await tester.pumpAndSettle();
        expect(find.text('Notifications'), findsOneWidget);
        await tester.tap(find.text('Session'));
        await tester.pumpAndSettle();
        expect(find.text('No notifications yet.'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await nav('Feedback');
        expect(find.byType(FeedbackConcernsPage), findsOneWidget);
        expect(find.text('Submit New Concern'), findsOneWidget);
        await nav('History');
        expect(find.byType(ActivityHistoryPage), findsOneWidget);
        await tester.tap(find.text('Date'));
        await tester.pumpAndSettle();
        final panel = find.byKey(const ValueKey('compact-range-panel'));
        expect(tester.getSize(panel).width, lessThanOrEqualTo(370));
        expect(tester.getSize(panel).height, lessThan(600));
        final today = DateTime.now();
        final day = find.byKey(
          ValueKey('range-day-${today.year}-${today.month}-${today.day}'),
        );
        await tester.tap(day);
        await tester.pumpAndSettle();
        await tester.tap(day);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(find.text('Clear dates'), findsOneWidget);
        expect(
          find.text('No historical records match these filters.'),
          findsOneWidget,
        );
        await nav('More');
        expect(find.text('Your Profile'), findsOneWidget);
        expect(find.widgetWithText(ListTile, 'History'), findsNothing);
        expect(
          find.widgetWithText(ListTile, 'Feedback & Concerns'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
