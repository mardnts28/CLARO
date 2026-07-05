import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'generated/l10n/app_localizations.dart';
import 'services/theme_service.dart';
import 'services/locale_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeThemeMode();
  await LocaleService.initializeLocale();
  runApp(const ClaroApp());
}

class ClaroApp extends StatelessWidget {
  const ClaroApp({super.key});

  static const _primaryRed = Color(0xFF8B1A1A);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: LocaleService.localeNotifier,
          builder: (context, locale, _) {
            return MaterialApp(
              title: 'CLARO',
              debugShowCheckedModeBanner: false,
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              themeMode: themeMode,
              theme: ThemeData(
                brightness: Brightness.light,
                primaryColor: _primaryRed,
                scaffoldBackgroundColor: const Color(0xFFF5F0EE),
                colorScheme: const ColorScheme.light(
                  primary: _primaryRed,
                  secondary: Color(0xFFD32F2F),
                  surface: Colors.white,
                  onSurface: Color(0xFF1A1A1A),
                  surfaceContainerHighest: Color(0xFFE0E0E0),
                  outlineVariant: Color(0xFFBDBDBD),
                  onSurfaceVariant: Color(0xFF757575),
                  error: Colors.redAccent,
                ),
                useMaterial3: true,
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                primaryColor: _primaryRed,
                scaffoldBackgroundColor: const Color(0xFF121212),
                colorScheme: const ColorScheme.dark(
                  primary: _primaryRed,
                  secondary: Color(0xFFEF5350),
                  surface: Color(0xFF1E1E1E),
                  onSurface: Color(0xFFE0E0E0),
                  surfaceContainerHighest: Color(0xFF2C2C2C),
                  outlineVariant: Color(0xFF424242),
                  onSurfaceVariant: Color(0xFF9E9E9E),
                  error: Colors.redAccent,
                ),
                useMaterial3: true,
              ),
              home: const AuthGate(),
            );
          },
        );
      },
    );
  }
}

/// Routes users based on authentication state:
/// - Not logged in → LoginScreen
/// - Logged in but onboarding incomplete → OnboardingScreen
/// - Logged in and onboarded → HomeScreen
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        // Check if onboarding is complete
        return FutureBuilder(
          future: AuthService().db.collection('users').doc(user.uid).get(),
          builder: (context, AsyncSnapshot docSnap) {
            if (docSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (docSnap.hasData && docSnap.data.exists) {
              final data = docSnap.data.data() as Map<String, dynamic>?;
              final bool onboarded = data?['onboardingComplete'] ?? false;
              if (onboarded) {
                return const HomeScreen();
              }
            }

            return const OnboardingScreen();
          },
        );
      },
    );
  }
}
