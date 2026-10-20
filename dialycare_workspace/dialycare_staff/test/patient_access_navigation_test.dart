import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_shared/core_shared.dart';
import 'package:dialycare_staff/main.dart';
import 'package:dialycare_staff/screens/patients/patient_form.dart';
import 'package:dialycare_staff/models/patient.dart';
import 'package:dialycare_staff/services/staff_store.dart';
import 'package:dialycare_staff/widgets/mobile_access_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// UI regression fixture; real PIN claims are separately covered by emulators.
class AccessFixture extends StaffStore {
  AccessFixture({
    super.issueActivation,
    super.cancelMobileAccess,
    super.changeMobileAccess,
  }) : super(memoryOnly: true, shared: true) {
    sessions.removeWhere((s) => s.patientId != 'DC-001');
    patients = [
      const Patient(
        id: 'DC-001',
        publicId: 'DC-000001',
        name: 'Anna Marie',
        age: 40,
        gender: 'Female',
        contact: '09000000001',
        companions: [
          Companion(
            id: 'REL-001',
            publicId: 'R-000001',
            name: 'Robert',
            relationship: 'Brother',
          ),
        ],
      ),
    ];
  }
  final states = <String, MobileAccount>{};
  @override
  Future<void> refreshShared() async {
    final p = patients.single.toJson();
    p['mobileAccount'] = (states['patient'] ?? const MobileAccount()).toJson();
    final r = (p['companions'] as List).single as Map<String, dynamic>;
    r['mobileAccount'] = (states['relative'] ?? const MobileAccount()).toJson();
    patients = [Patient.fromJson(p)];
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'Mobile Access tab remains reachable on a narrow Patient form and blocks unsaved identities',
    (tester) async {
      tester.view.physicalSize = const Size(390, 750);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = AccessFixture();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PatientForm(
              store: store,
              patient: store.patients.single,
              onDone: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mobile Access'));
      await tester.pumpAndSettle();
      expect(find.text('Patient Mobile Access'), findsOneWidget);
      expect(find.text('Designated Relative Mobile Access'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PatientForm(store: store, onDone: () {}),
          ),
        ),
      );
      await tester.tap(find.text('Mobile Access'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Save the Patient and designated Relative before creating Mobile Access.',
        ),
        findsOneWidget,
      );
      expect(find.text('Create Mobile Access'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Patients Edit exposes both access cards and one-time PINs, expiry, refresh and lifecycle controls',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (File('C:/Windows/Fonts/arial.ttf').existsSync()) {
        await (FontLoader('Arial')..addFont(
              Future.value(
                ByteData.sublistView(
                  File('C:/Windows/Fonts/arial.ttf').readAsBytesSync(),
                ),
              ),
            ))
            .load();
      }
      String? copiedPin;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedPin = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final generated = <String, String>{};
      final expires = DateTime(2026, 10, 20, 17, 15);
      late final AccessFixture store;
      store = AccessFixture(
        issueActivation: (role, pid, rid) async {
          expect(pid, 'DC-001');
          expect(rid, role == 'patient' ? 'DC-001' : 'REL-001');
          final pin = generateTemporaryPin();
          generated[role] = pin;
          store.states[role] = MobileAccount(
            status: MobileAccountStatus.activationPending,
            activationExpiresAt: expires,
          );
          return {'pin': pin, 'expiresAt': expires.toUtc().toIso8601String()};
        },
        cancelMobileAccess: (role, id) async {
          store.states[role] = const MobileAccount();
        },
        changeMobileAccess: (role, id, enabled) async {
          store.states[role] = MobileAccount(
            status: enabled
                ? MobileAccountStatus.active
                : MobileAccountStatus.disabled,
            activatedAt: DateTime(2026, 10, 19),
          );
        },
      );
      addTearDown(store.dispose);
      final boundary = GlobalKey();
      Future<void> capture(String name) async {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('verification/mobile-access-$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: DialyCareApp(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Patients').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit Anna Marie'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Patient'), findsOneWidget);
      await tester.tap(find.text('Mobile Access'));
      await tester.pumpAndSettle();
      expect(find.text('Patient Mobile Access'), findsOneWidget);
      expect(find.text('Designated Relative Mobile Access'), findsOneWidget);
      expect(find.text('Relative ID: R-000001'), findsOneWidget);
      expect(
        find.text('Linked Patient: Anna Marie / DC-000001'),
        findsOneWidget,
      );
      expect(find.text('Create Mobile Access'), findsNWidgets(2));
      await capture('tab');
      Finder card(String role) => find.byWidgetPredicate(
        (w) => w is MobileAccessDetails && w.recipient.type.name == role,
      );
      Future<void> click(String role, String label) async {
        final button = find.descendant(
          of: card(role),
          matching: find.widgetWithText(TextButton, label),
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      for (final role in ['patient', 'relative']) {
        await click(role, 'Create Mobile Access');
        expect(find.byType(CheckboxListTile), findsNothing);
        await tester.tap(
          find.widgetWithText(FilledButton, 'Create Mobile Access'),
        );
        await tester.pumpAndSettle();
        expect(find.text(generated[role]!), findsOneWidget);
        expect(find.textContaining('Expires:').last, findsOneWidget);
        await capture('$role-pin');
        await tester.tap(find.text('Copy Temporary PIN'));
        await tester.pumpAndSettle();
        expect(copiedPin, generated[role]);
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(find.text(generated[role]!), findsNothing);
        await click(role, 'Regenerate Temporary PIN');
        expect(find.text('Regenerate Temporary PIN?'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Regenerate'));
        await tester.pumpAndSettle();
        expect(find.text('New Temporary PIN'), findsOneWidget);
        expect(find.text(generated[role]!), findsOneWidget);
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        await click(role, 'Cancel Mobile Access');
        await tester.tap(
          find.widgetWithText(FilledButton, 'Cancel Mobile Access'),
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: card(role),
            matching: find.text('Account Status: Not Activated'),
          ),
          findsOneWidget,
        );
        // Simulate an external Mobile claim becoming visible via explicit refresh.
        store.states[role] = MobileAccount(
          status: MobileAccountStatus.active,
          activatedAt: DateTime(2026, 10, 19),
        );
        await tester.ensureVisible(find.text('Refresh status'));
        await tester.tap(find.text('Refresh status'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: card(role),
            matching: find.text('Account Status: Active'),
          ),
          findsOneWidget,
        );
        await click(role, 'Disable Mobile Access');
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();
        await click(role, 'Restore Mobile Access');
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();
        expect(store.patients.single.id, 'DC-001');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
