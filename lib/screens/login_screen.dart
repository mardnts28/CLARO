import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/custom_text_field.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';
import 'otp_verification_screen.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/validation_service.dart';
import '../services/haptic_service.dart';

/// NOTE ON LANGUAGE: this screen now follows the app-wide selected
/// language (Select Language screen on first launch / Settings >
/// Language afterwards), same as SignupScreen, BasicInfo, and Health
/// Profile. It previously hardcoded everything to English -- that was
/// intentional at the time, but the onboarding flow now asks the user to
/// choose a language *before* they ever reach this screen, so the login
/// screen needs to actually honor that choice instead of always showing
/// English.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  final _authService = AuthService();
  bool _showPassword = false;
  bool _isLoading = false;

  // Inline, per-field error state — shown directly under each field
  // instead of a bottom snackbar.
  String? _emailError;
  String? _passwordError;

  // Top-level error for failures not tied to a single field (wrong
  // credentials, network issues, Google sign-in problems, etc.).
  String? _formError;

  @override
  void initState() {
    super.initState();

    // Validate on blur (matches the inline-validation pattern used on
    // the signup screen), and clear a field's error the moment the user
    // starts fixing it.
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) {
        _validateEmail();
      }
    });
    _emailController.addListener(() {
      if (_emailError != null) {
        _validateEmail();
      }
    });
    _passwordController.addListener(() {
      if (_passwordError != null && _passwordController.text.isNotEmpty) {
        setState(() => _passwordError = null);
      }
    });
  }

  void _validateEmail() {
    if (!mounted) return;
    final loc = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    if (email.isNotEmpty) {
      setState(() => _emailError = ValidationService.validateEmail(email, loc));
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Resets the form back to its initial empty state. Used by the
  /// pull-to-refresh gesture on the login page.
  Future<void> _refreshForm() async {
    _emailController.clear();
    _passwordController.clear();
    setState(() {
      _emailError = null;
      _passwordError = null;
      _formError = null;
    });
    HapticService().vibrate();
  }

  /// Sends the signed-in user to Onboarding or Home, clearing the nav
  /// stack so they can't swipe/back into the auth screens again.
  ///
  /// NOTE: this screen (and SignupScreen) is reached via
  /// Navigator.pushReplacement, which places it OUTSIDE AuthGate's
  /// widget tree. That means AuthGate's authStateChanges() listener is
  /// no longer mounted once the user is here, so it can't react to a
  /// successful login/sign-in on its own — we have to navigate
  /// explicitly instead of waiting for AuthGate to notice.
  Future<void> _routeAfterAuth() async {
    final onboarded = await _authService.hasCompletedOnboarding();
    if (!mounted) return;
    // Dismiss the keyboard/field focus before navigating away -- carrying
    // focus over to the next screen (which may not have a matching text
    // field under the cursor position) is what caused the
    // "BOTTOM OVERFLOWED" layout error previously seen when this screen
    // used to sit right before Get Started.
    FocusScope.of(context).unfocus();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => onboarded ? const HomeScreen() : const OnboardingScreen(),
      ),
          (route) => false,
    );
  }

  /// Navigates explicitly to the OTP screen when MFA is required.
  ///
  /// This screen is reached via Navigator.pushReplacement, which means
  /// AuthGate (and its authStateChanges/pendingMfaChallenge listeners)
  /// is no longer mounted once we're here — the same root cause as the
  /// earlier "stuck on signup after Google sign-in" bug. So rather than
  /// assuming AuthGate will notice pendingMfaChallenge and swap in
  /// OtpVerificationScreen on its own, we navigate to it directly using
  /// the full challenge data AuthService already stored in
  /// AuthService.pendingMfaChallenge (uid, code, emailSent, email, and
  /// password — the latter is null for a Google-originated challenge).
  void _navigateToOtpScreen() {
    final challenge = AuthService.pendingMfaChallenge.value;
    if (!mounted || challenge == null) return;
    // Dismiss the keyboard/field focus before navigating away -- see
    // _routeAfterAuth for why.
    FocusScope.of(context).unfocus();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          email: challenge['email']?.toString() ?? '',
          password: challenge['password'] as String?,
          uid: challenge['uid'].toString(),
          otpCode: challenge['code']?.toString(),
          emailSent: challenge['emailSent'] == true,
        ),
      ),
          (route) => false,
    );
  }

  Future<void> _handleLogin() async {
    final loc = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Validate inline, under each field, instead of a bottom snackbar.
    final emailError = ValidationService.validateEmail(email, loc);
    final passwordError = password.isEmpty ? loc.passwordRequired : null;

    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });

    if (emailError != null || passwordError != null) {
      HapticService().vibrate();
      return;
    }

    HapticService().vibrate();
    if (!mounted) return;
    setState(() {
      _formError = null;
      _isLoading = true;
    });

    try {
      final result = await _authService.login(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (result != null) {
        // Either an error message (String) or an MFA challenge (Map).
        if (result is String) {
          setState(() => _formError = result);
          return;
        }
        // MFA_REQUIRED case — navigate explicitly (see
        // _navigateToOtpScreen doc for why we can't rely on AuthGate).
        _navigateToOtpScreen();
        return;
      } else {
        // Successful login, no MFA needed — route explicitly instead of
        // relying on AuthGate to notice (see _routeAfterAuth doc above).
        await _routeAfterAuth();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    HapticService().vibrate();
    setState(() {
      _formError = null;
      _isLoading = true;
    });
    try {
      final result = await _authService.signInWithGoogle();
      if (!mounted) return;

      if (result == null) {
        // Success, no MFA — route explicitly (see _routeAfterAuth doc).
        await _routeAfterAuth();
        return;
      }

      if (result is String) {
        setState(() => _formError = result);
        return;
      }

      // MFA_REQUIRED map: previously signInWithGoogle() never checked
      // MFA at all, so a user with MFA enabled would sail straight
      // through to Home. Now we navigate to the OTP screen explicitly.
      _navigateToOtpScreen();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Force Light Mode for Login Screen
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF8B1A1A),
        scaffoldBackgroundColor: const Color(0xFFF5F0EE),
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF8B1A1A),
          onPrimary: Colors.white,
          secondary: const Color(0xFFD32F2F),
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: const Color(0xFF1A1A1A),
          error: Colors.redAccent,
          onError: Colors.white,
          surfaceContainerHighest: const Color(0xFFE0E0E0),
          outlineVariant: const Color(0xFFBDBDBD),
          onSurfaceVariant: const Color(0xFF757575),
        ),
        useMaterial3: true,
      ),
      child: Builder(
          builder: (context) {
            final colorScheme = Theme.of(context).colorScheme;
            final loc = AppLocalizations.of(context)!;

            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.dark,
              child: Scaffold(
                backgroundColor: colorScheme.surface,
                body: SafeArea(
                  child: RefreshIndicator(
                    color: colorScheme.primary,
                    onRefresh: _refreshForm,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/images/logo.png',
                                  height: 90,
                                  cacheHeight: (90 * MediaQuery.devicePixelRatioOf(context)).round(),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'CLARO',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            loc.welcomeBack,
                            style: TextStyle(
                                fontSize: 26, fontWeight: FontWeight.bold, color: colorScheme.primary),
                          ),
                          Text(
                            loc.loginToContinue,
                            style: TextStyle(fontSize: 13, color: colorScheme.primary),
                          ),
                          const SizedBox(height: 24),

                          if (_formError != null) ...[
                            _buildFormErrorBanner(context, _formError!),
                            const SizedBox(height: 14),
                          ],

                          _buildTextField(
                            context,
                            controller: _emailController,
                            focusNode: _emailFocus,
                            hint: loc.email,
                            icon: Icons.email_outlined,
                            errorText: _emailError,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            context,
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            hint: loc.password,
                            icon: Icons.lock_outline,
                            obscure: !_showPassword,
                            errorText: _passwordError,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _handleLogin(),
                            suffix: IconButton(
                              icon: Icon(
                                _showPassword ? Icons.visibility : Icons.visibility_off,
                                size: 20,
                                color: Colors.grey,
                              ),
                              onPressed: () =>
                                  setState(() => _showPassword = !_showPassword),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () {
                                HapticService().vibrate();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const ForgotPasswordScreen()),
                                );
                              },
                              child: Text(
                                loc.forgotPassword,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _isLoading ? null : _handleLogin,
                              child: _isLoading
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                                  : Text(
                                loc.login,
                                style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildDivider(context),
                          const SizedBox(height: 16),
                          _buildGoogleButton(context),
                          const SizedBox(height: 24),
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('${loc.dontHaveAccount} ',
                                    style: const TextStyle(fontSize: 13)),
                                GestureDetector(
                                  onTap: () {
                                    HapticService().vibrate();
                                    // Dismiss keyboard/focus before leaving
                                    // this screen (see _routeAfterAuth).
                                    FocusScope.of(context).unfocus();
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const SignupScreen()),
                                    );
                                  },
                                  child: Text(
                                    loc.signUp,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
  }

  Widget _buildFormErrorBanner(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      label: message,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 18, color: colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 13, color: colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      BuildContext context, {
        required TextEditingController controller,
        required FocusNode focusNode,
        required String hint,
        required IconData icon,
        bool obscure = false,
        Widget? suffix,
        String? errorText,
        TextInputType? keyboardType,
        TextInputAction? textInputAction,
        ValueChanged<String>? onSubmitted,
      }) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomTextField(
      controller: controller,
      focusNode: focusNode,
      hintText: hint,
      prefixIcon: Icon(icon, color: colorScheme.onSurfaceVariant, size: 20),
      suffixIcon: suffix,
      obscureText: obscure,
      errorText: errorText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
    );
  }

  Widget _buildDivider(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(child: Divider(color: colorScheme.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(loc.orContinueWith,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
        ),
        Expanded(child: Divider(color: colorScheme.outlineVariant)),
      ],
    );
  }

  Widget _buildGoogleButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        icon: Image.asset('assets/images/google.png', height: 20),
        label: Text(
          loc.continueWithGoogle,
          style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
        ),
        onPressed: _isLoading ? null : _handleGoogleSignIn,
      ),
    );
  }
}