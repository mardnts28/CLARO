import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/signup_screen.dart';
import 'services/theme_service.dart';
import 'services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, child) {
        final authService = AuthService();

        return MaterialApp(
          title: 'Claro',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: const Color(0xFF8B1A1A),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF8B1A1A),
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF8B1A1A),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF8B1A1A),
              brightness: Brightness.dark,
            ),
          ),
          themeMode: themeMode,
          home: const SignupScreen(),
          builder: (context, child) {
            // Listen to auth state and then to the user's document for `voiceAssistant`.
            return StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, authSnap) {
                if (!authSnap.hasData) return child!;
                final user = authSnap.data!;

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: authService.db.collection('users').doc(user.uid).snapshots(),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data();
                    // Apply theme if present in user doc
                    if (data != null && data['theme'] != null) {
                      try {
                        setAppThemeMode(parseThemeMode(data['theme'].toString()));
                      } catch (_) {}
                    }
                    final enabled = data != null && (data['voiceAssistant'] == true);
                    return Stack(
                      children: [
                        child!,
                        if (enabled)
                          Positioned(
                            right: 16,
                            bottom: MediaQuery.of(context).viewPadding.bottom + 80,
                            child: ClipOval(
                              child: Material(
                                color: const Color(0xFF8B1A1A),
                                elevation: 6,
                                child: InkWell(
                                  onTap: () {
                                    // TODO: wire voice assistant action
                                  },
                                  child: const SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: Center(child: Icon(Icons.mic, color: Colors.white)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}