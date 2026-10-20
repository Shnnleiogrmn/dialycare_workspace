import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/cloud_workspace.dart';
import 'screens/staff_portal.dart';
import 'services/staff_store.dart';
import 'theme/staff_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DialyCareApp());
  // Authentication/Firestore use ID-token REST access; native Core is retained.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stackTrace) {
    debugPrint('Firebase initialization failed: $error\n$stackTrace');
  }
}

class DialyCareApp extends StatelessWidget {
  const DialyCareApp({super.key, this.store, this.now});
  final StaffStore? store;
  final DateTime? now;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DialyCare Staff',
    debugShowCheckedModeBanner: false,
    theme: StaffTheme.theme,
    home:
        const bool.fromEnvironment('DIALYCARE_CLOUD', defaultValue: true) &&
            store == null &&
            now == null
        ? const Scaffold(body: CloudWorkspace())
        : StaffPortal(store: store, now: now),
  );
}
