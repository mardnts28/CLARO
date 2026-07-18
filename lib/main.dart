import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'generated/l10n/app_localizations.dart';
import 'services/theme_service.dart';
import 'services/locale_service.dart';
import 'services/auth_service.dart';
import 'services/haptic_service.dart';
import 'services/text_size_service.dart';
import 'services/voice_assistant_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/otp_verification_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loads .env (declared as an asset in pubspec.yaml) into dotenv.env so
  // BackendLocator can read GEMINI_API_KEY from it. Must happen before
  // anything touches dotenv.env -- see data/services/backend_locator.dart.
  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();
  final packageInfo = await PackageInfo.fromPlatform();
  final currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
  final lastRunVersion = prefs.getString('last_run_version');

  // Only force a sign-out when this launch follows an app UPDATE
  // (the recorded version/build differs from the current one). A
  // normal relaunch -- closing and reopening the app with no update --
  // must NOT sign the user out. Previously this ran unconditionally on
  // every cold start, which meant any time Android killed the
  // backgrounded process (common: low memory, long background time,
  // aggressive OEM battery managers) the user would be dumped back to
  // LoginScreen on reopen even though nothing about their session had
  // actually changed.
  //
  // Reinstall doesn't need explicit handling here: uninstalling wipes
  // this app's SharedPreferences AND Firebase Auth's local persistence
  // together, so a fresh install already starts with lastRunVersion ==
  // null and no logged-in user -- there's nothing to sign out of.
  if (lastRunVersion != null && lastRunVersion != currentVersion) {
    await AuthService().signOut();
  }
  await prefs.setString('last_run_version', currentVersion);

  await initializeThemeMode();
  await LocaleService.initializeLocale();
  await HapticService().init();
  await TextSizeService.initialize();
  await VoiceAssistantService.initialize();
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
            return ValueListenableBuilder<double>(
              valueListenable: TextSizeService.textSizeNotifier,
              builder: (context, textSize, _) {
                return MaterialApp(
                  title: 'CLARO',
                  debugShowCheckedModeBanner: false,
                  locale: locale,
                  localizationsDelegates: AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  themeMode: themeMode,
                  theme: _buildTheme(Brightness.light),
                  darkTheme: _buildTheme(Brightness.dark),
                  builder: (context, child) {
                    return MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(textSize),
                      ),
                      child: child!,
                    );
                  },
                  home: const AuthGate(),
                );
              },
            );
          },
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return ThemeData(
      brightness: brightness,
      primaryColor: _primaryRed,
      scaffoldBackgroundColor: isLight ? const Color(0xFFF5F0EE) : const Color(0xFF121212),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: _primaryRed,
        onPrimary: Colors.white,
        secondary: isLight ? const Color(0xFFD32F2F) : const Color(0xFFEF5350),
        onSecondary: Colors.white,
        surface: isLight ? Colors.white : const Color(0xFF1E1E1E),
        onSurface: isLight ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0E0),
        error: Colors.redAccent,
        onError: Colors.white,
        surfaceContainerHighest: isLight ? const Color(0xFFE0E0E0) : const Color(0xFF2C2C2C),
        outlineVariant: isLight ? const Color(0xFFBDBDBD) : const Color(0xFF424242),
        onSurfaceVariant: isLight ? const Color(0xFF757575) : const Color(0xFF9E9E9E),
      ),
      useMaterial3: true,
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

        return ValueListenableBuilder<bool>(
          valueListenable: AuthService.isAuthenticating,
          builder: (context, isAuthenticating, _) {
            // Only force LoginScreen if the user is truly null.
            // If they are authenticating but 'user' exists, show a loader
            // instead of snapping back to the LoginScreen.
            if (user == null) {
              return const LoginScreen();
            }

            if (isAuthenticating) {
              return ValueListenableBuilder<Map<String, dynamic>?>(
                valueListenable: AuthService.pendingMfaChallenge,
                builder: (context, challenge, __) {
                  if (challenge != null) {
                    return OtpVerificationScreen(
                      email: challenge['email'],
                      password: challenge['password'],
                      uid: challenge['uid'].toString(),
                      otpCode: challenge['code']?.toString(),
                      emailSent: challenge['emailSent'] == true,
                    );
                  }
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                },
              );
            }

            // Verify that this session is still the active one (Session Lockout)
            return FutureBuilder<bool>(
              future: AuthService().isSessionValid(user.uid),
              builder: (context, sessionSnap) {
                if (sessionSnap.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                // If there's an error (e.g. permission-denied), sign out and return to Login
                if (sessionSnap.hasError || sessionSnap.data == false) {
                  AuthService().signOut();
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

                    if (docSnap.hasError) {
                      AuthService().signOut();
                      return const LoginScreen();
                    }

                    if (docSnap.hasData && docSnap.data.exists) {
                      final data = docSnap.data.data() as Map<String, dynamic>?;

                      // Personalized haptic sync: Update service state from user profile
                      final hapticPref = data?['vibrationFeedback'] ?? false;
                      HapticService().updateEnabled(hapticPref);

                      // Personalized text size sync: Update service state from user profile
                      final textSizePref = (data?['textSize'] as num?)?.toDouble() ?? 1.0;
                      TextSizeService.textSizeNotifier.value = textSizePref;

                      // Personalized voice assistant sync
                      final voicePref = data?['voiceAssistant'] ?? false;
                      VoiceAssistantService.isEnabledNotifier.value = voicePref;

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
          },
        );
      },
    );
  }
}