import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/staff_portal.dart'; // Ito yung hinahanap niyang file

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ibinalik natin ang Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const DialyCareApp());
}

class DialyCareApp extends StatelessWidget {
  const DialyCareApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DialyCare Staff',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, fontFamily: 'Arial'),
    home: const StaffPortal(),
  );
}
