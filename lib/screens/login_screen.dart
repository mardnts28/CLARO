import 'package:flutter/material.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';
import 'otp_verification_screen.dart';
import '../services/auth_service.dart';
import '../services/validation_service.dart';
import '../services/haptic_service.dart';

/// NOTE ON LANGUAGE: this screen intentionally hardcodes every string in
/// English rather than calling AppLocalizations.of(context) -- it must
/// NOT follow the app-wide language toggle (Settings > Language), the
/// same way SignupScreen and OnboardingScreen are hardcoded. Previously
/// this screen used AppLocalizations for welcomeBack/email/password/etc,
/// which meant switching the app to Tagalog also flipped the login
/// screen -- inconsistent with Signup, which was already English-only.
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
        final email = _emailController.text.trim();
        if (email.isNotEmpty) {
          setState(() => _emailError = ValidationService.validateEmail(email));
        }
      }
    });
    _emailController.addListener(() {
      if (_emailError != null) {
        setState(() => _emailError = ValidationService.validateEmail(_emailController.text.trim()));
      }
    });
    _passwordController.addListener(() {
      if (_passwordError != null && _passwordController.text.isNotEmpty) {
        setState(() => _passwordError = null);
      }
    });
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
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Validate inline, under each field, instead of a bottom snackbar.
    final emailError = ValidationService.validateEmail(email);
    final passwordError = password.isEmpty ? 'Password is required' : null;

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
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF8B1A1A),
          onPrimary: Colors.white,
          secondary: Color(0xFFD32F2F),
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF1A1A1A),
          error: Colors.redAccent,
          onError: Colors.white,
          surfaceContainerHighest: Color(0xFFE0E0E0),
          outlineVariant: Color(0xFFBDBDBD),
          onSurfaceVariant: Color(0xFF757575),
        ),
        useMaterial3: true,
      ),
      child: Builder(
          builder: (context) {
            final colorScheme = Theme.of(context).colorScheme;

            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.noScaling,
              ),
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
                                Image.asset('assets/images/logo.png', height: 90),
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
                            'Welcome back!',
                            style: TextStyle(
                                fontSize: 26, fontWeight: FontWeight.bold, color: colorScheme.primary),
                          ),
                          Text(
                            'Login to continue',
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
                            hint: 'Email',
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
                            hint: 'Password',
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
                                'Forgot password?',
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
                                  : const Text(
                                'Login',
                                style: TextStyle(
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
                                const Text("Don't have an account? ",
                                    style: TextStyle(fontSize: 13)),
                                GestureDetector(
                                  onTap: () {
                                    HapticService().vibrate();
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const SignupScreen()),
                                    );
                                  },
                                  child: Text(
                                    'Sign up',
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
          }
      ),
    );
  }

  Widget _buildFormErrorBanner(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
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
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        prefixIcon: Icon(icon, color: colorScheme.onSurfaceVariant, size: 20),
        suffixIcon: suffix,
        errorText: errorText,
        errorMaxLines: 2,
        contentPadding:
        const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Divider(color: colorScheme.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('or continue with',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
        ),
        Expanded(child: Divider(color: colorScheme.outlineVariant)),
      ],
    );
  }

  Widget _buildGoogleButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
          'Continue with Google',
          style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
        ),
        onPressed: _isLoading ? null : _handleGoogleSignIn,
      ),
    );
  }
}