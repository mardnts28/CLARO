import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/signup_screen.dart';
import 'services/theme_service.dart';
import 'services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../generated/l10n/app_localizations.dart';
import 'services/locale_service.dart';

ThemeData _buildAppTheme(Brightness brightness) {
  final seedColor = const Color(0xFF8B1A1A);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  final isDark = brightness == Brightness.dark;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    primaryColor: seedColor,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F8F8),
    cardColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    dividerColor: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE5E7EB),
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      foregroundColor: colorScheme.onSurface,
      iconTheme: IconThemeData(color: colorScheme.primary),
      titleTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      elevation: 0,
    ),
    textTheme: isDark
        ? Typography.whiteMountainView.copyWith(
            bodyLarge: Typography.whiteMountainView.bodyLarge?.copyWith(color: const Color(0xFFEDEDED)),
            bodyMedium: Typography.whiteMountainView.bodyMedium?.copyWith(color: const Color(0xFFD1D5DB)),
            bodySmall: Typography.whiteMountainView.bodySmall?.copyWith(color: const Color(0xFF9CA3AF)),
          )
        : Typography.blackMountainView.copyWith(
            bodyLarge: Typography.blackMountainView.bodyLarge?.copyWith(color: const Color(0xFF111827)),
            bodyMedium: Typography.blackMountainView.bodyMedium?.copyWith(color: const Color(0xFF374151)),
            bodySmall: Typography.blackMountainView.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
          ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeThemeMode();
  await LocaleService.initializeLocale();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Firebase.apps.isNotEmpty ? AuthService() : null;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, child) {
        // Unauthenticated app
        if (authService == null) {
          return ValueListenableBuilder<Locale>(
            valueListenable: LocaleService.localeNotifier,
            builder: (context, locale, child) {
              return MaterialApp(
                title: 'Claro',
                debugShowCheckedModeBanner: false,
                themeMode: themeMode,
                locale: locale,
                localizationsDelegates: [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                theme: ThemeData(
                  useMaterial3: true,
                  brightness: Brightness.light,
                  primaryColor: const Color(0xFF8B1A1A),
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(0xFF8B1A1A),
                    brightness: Brightness.light,
                  ),
                ),
                darkTheme: ThemeData(
                  useMaterial3: true,
                  brightness: Brightness.dark,
                  primaryColor: const Color(0xFF8B1A1A),
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(0xFF8B1A1A),
                    brightness: Brightness.dark,
                  ),
                ),
                home: const SignupScreen(),
              );
            },
          );
        }

        // Authenticated app (listen to user doc for preferences)
        return ValueListenableBuilder<Locale>(
          valueListenable: LocaleService.localeNotifier,
          builder: (context, locale, child) {
            return MaterialApp(
              title: 'Claro',
              debugShowCheckedModeBanner: false,
              themeMode: themeMode,
              locale: locale,
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
                primaryColor: const Color(0xFF8B1A1A),
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF8B1A1A),
                  brightness: Brightness.light,
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                primaryColor: const Color(0xFF8B1A1A),
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF8B1A1A),
                  brightness: Brightness.dark,
                ),
              ),
              home: const SignupScreen(),
              builder: (context, child) {
                // Listen to auth state and then to the user's document for `voiceAssistant`.
                return StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  builder: (context, authSnap) {
                    if (!authSnap.hasData) return child!;
                    final user = authSnap.data!;

                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: authService!.db.collection('users').doc(user.uid).snapshots(),
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
      },
    );
  }
}