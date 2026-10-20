import 'package:core_shared/core_shared.dart';
import 'package:dialycare_mobile/main.dart';
import 'package:dialycare_mobile/mobile_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// UI-stage fixture only; PIN validity and claiming are tested against real Rules.
class PinScreenStore extends MobileStore {
  String? chosenPassword;
  @override
  Future<void> beginActivation(String id, String pin) async {
    activationPreview = {
      'displayName': role == 'patient' ? 'Anna Marie' : 'Robert',
      'patientId': 'DC-001',
      'patientPublicId': 'DC-000001',
      'publicId': id,
      'recipientId': id,
    };
    notifyListeners();
  }

  @override
  Future<void> completeActivation(String password) async {
    chosenPassword = password;
  }

  @override
  Future<void> cancelActivation() async {
    activationPreview = null;
  }
}

void main() {
  for (final role in ['patient', 'relative']) {
    testWidgets(
      '$role uses ID/PIN then password-only setup with read-only identity',
      (tester) async {
        tester.view.physicalSize = const Size(390, 650);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = PinScreenStore()..role = role;
        addTearDown(store.dispose);
        await tester.pumpWidget(MaterialApp(home: AuthScreen(store: store)));
        await tester.ensureVisible(find.text('Activate Account'));
        await tester.tap(find.text('Activate Account'));
        await tester.pumpAndSettle();
        final label = role == 'patient' ? 'Patient ID' : 'Relative ID';
        await tester.enterText(
          find.widgetWithText(TextFormField, label),
          role == 'patient' ? 'DC-000001' : 'R-000001',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Temporary PIN'),
          generateTemporaryPin(),
        );
        expect(find.text('Email Address'), findsNothing);
        expect(find.text('New Password'), findsNothing);
        await tester.ensureVisible(find.text('Verify Account'));
        await tester.tap(find.text('Verify Account'));
        await tester.pumpAndSettle();
        expect(find.text('Account Verified'), findsOneWidget);
        expect(
          find.text(role == 'patient' ? 'Anna Marie' : 'Robert'),
          findsOneWidget,
        );
        expect(find.widgetWithText(TextFormField, label), findsNothing);
        expect(find.text('Temporary PIN'), findsNothing);
        expect(find.text('Email Address'), findsNothing);
        expect(find.text('Full Name'), findsNothing);
        for (final entry in [
          ('View Terms of Use', 'DRAFT / CAPSTONE TERMS'),
          ('View Privacy Notice', 'DRAFT / CAPSTONE PRIVACY NOTICE'),
        ]) {
          await tester.ensureVisible(find.text(entry.$1));
          await tester.pumpAndSettle();
          await tester.tap(find.text(entry.$1));
          await tester.pumpAndSettle();
          expect(find.textContaining(entry.$2), findsOneWidget);
          await tester.tap(find.text('Close'));
          await tester.pumpAndSettle();
        }
        await tester.enterText(
          find.widgetWithText(TextFormField, 'New Password'),
          'Owner-pass12!',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm Password'),
          'Owner-pass12!',
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Activate Account'),
              )
              .onPressed,
          isNull,
        );
        for (final key in ['terms-agreement', 'privacy-acknowledgment']) {
          await tester.ensureVisible(find.byKey(ValueKey(key)));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(ValueKey(key)));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Activate Account'),
        );
        await tester.pumpAndSettle();
        expect(store.termsAccepted && store.privacyAcknowledged, isTrue);
        await tester.tap(find.widgetWithText(FilledButton, 'Activate Account'));
        await tester.pumpAndSettle();
        expect(store.chosenPassword, 'Owner-pass12!');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'account recovery contacts the center and offers no email reset',
    (tester) async {
      final store = PinScreenStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(MaterialApp(home: AuthScreen(store: store)));
      await tester.ensureVisible(find.text('Forgot Password?'));
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();
      expect(find.text('Account recovery'), findsOneWidget);
      expect(find.text('Send reset email'), findsNothing);
      expect(find.text('Registered email'), findsNothing);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
