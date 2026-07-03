import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/camera_scanner_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ClaroApp());
}

class ClaroApp extends StatelessWidget {
  const ClaroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CLARO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00c6ff),
        scaffoldBackgroundColor: const Color(0xFF0C0E14),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00c6ff),
          secondary: Color(0xFF0072ff),
          surface: Color(0xFF161B26),
          error: Colors.redAccent,
        ),
        useMaterial3: true,
      ),
      home: const CameraScannerScreen(),
    );
  }
}
