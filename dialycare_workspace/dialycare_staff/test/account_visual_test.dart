import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dialycare_staff/screens/staff_login.dart';
import 'package:dialycare_staff/theme/staff_theme.dart';

void main() {
  for (final size in [
    const Size(835, 615),
    const Size(1280, 720),
    const Size(1920, 1080),
    const Size(1400, 900),
    const Size(390, 650),
  ]) {
    testWidgets('Staff login is usable and has no public signup at $size', (
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
      if (File('C:/Windows/Fonts/georgia.ttf').existsSync()) {
        final font = FontLoader('Georgia')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                File('C:/Windows/Fonts/georgia.ttf').readAsBytesSync(),
              ),
            ),
          );
        await font.load();
      }
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final email = TextEditingController(), password = TextEditingController();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: StaffTheme.theme,
            home: StaffLogin(
              email: email,
              password: password,
              busy: false,
              onLogin: () {},
              onRecovery: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/images/auth-logo.png'),
          boundary.currentContext!,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Welcome Back!'), findsOneWidget);
      expect(find.text('Sign Up'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('verification/staff-login-${size.width.toInt()}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      await tester.ensureVisible(find.text('Log In'));
      expect(find.text('Forgot password?'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      email.dispose();
      password.dispose();
    });
  }
}
