import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/custom_text_field.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';
import 'otp_verification_screen.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/validation_service.dart';
import '../services/haptic_service.dart';

// NOTE ON LANGUAGE: the headline text, field hints, and primary buttons on
// this screen now follow the app-wide selected language (see
// LoginScreen's header comment for background on why this changed). The
// live password/email "requirements" checklist and the detailed
// backend-error copy in _friendlyFormError() are intentionally left in
// English for now -- translating that fine-grained validation microcopy
// accurately is a separate follow-up, not part of this pass.

/// Strips leading/trailing whitespace and blocks newline / control
/// characters from ever entering the field in the first place.
/// This is cheap "strict typing" for free-text inputs: whatever is in
/// the controller is guaranteed to be a single-line, trimmable string.
class _SanitizingTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final sanitized = newValue.text.replaceAll(RegExp(r'[\r\n\t]'), '');
    if (sanitized == newValue.text) return newValue;
    final delta = newValue.text.length - sanitized.length;
    final newOffset = (newValue.selection.end - delta).clamp(0, sanitized.length);
    return TextEditingValue(
      text: sanitized,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}

/// A single, checkable password/email requirement shown in the live
/// "requirements panel" beneath a field while it's focused.
class _Requirement {
  final String label;
  final bool Function(String value) isMet;
  const _Requirement(this.label, this.isMet);
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  final _authService = AuthService();

  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;

  // Inline, per-field error state. Null = no error shown.
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  // Top-level error for failures that aren't tied to one field
  // (e.g. "email already in use", network failure, Google sign-in).
  String? _formError;

  // ---- Live requirements panel definitions ----

  List<_Requirement> get _emailRequirements {
    final loc = AppLocalizations.of(context)!;
    return [
      _Requirement(loc.validEmailHint,
              (v) => ValidationService.validateEmail(v.trim().toLowerCase(), loc) == null),
    ];
  }

  final List<_Requirement> _passwordRequirements = [
    _Requirement('At least 8 characters', (v) => v.length >= 8),
    _Requirement('One uppercase letter', (v) => RegExp(r'[A-Z]').hasMatch(v)),
    _Requirement('One lowercase letter', (v) => RegExp(r'[a-z]').hasMatch(v)),
    _Requirement('One number', (v) => RegExp(r'[0-9]').hasMatch(v)),
    _Requirement('One special character (!@#\$%^&* etc.)',
            (v) => RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(v)),
  ];

  List<_Requirement> get _confirmPasswordRequirements => [
    _Requirement('Matches the password above',
            (v) => v.isNotEmpty && v == _rawPassword),
  ];

  @override
  void initState() {
    super.initState();

    // Validate as soon as the user leaves a field (inline validation),
    // rather than only on submit. We also rebuild on focus GAIN so the
    // live requirements panel can appear the moment the field is tapped,
    // and rebuild on focus LOSS so the panel disappears/updates.
    _emailFocus.addListener(() {
      setState(() {});
      if (!_emailFocus.hasFocus) _validateEmail(showIfEmpty: false);
    });
    _passwordFocus.addListener(() {
      setState(() {});
      if (!_passwordFocus.hasFocus) _validatePassword(showIfEmpty: false);
    });
    _confirmPasswordFocus.addListener(() {
      setState(() {});
      if (!_confirmPasswordFocus.hasFocus) {
        _validateConfirmPassword(showIfEmpty: false);
      }
    });

    // Once an error is showing for a field, re-check on every keystroke
    // so it clears the moment the user fixes it — this is the
    // "inline validation" feedback loop working both directions.
    // We also rebuild on every keystroke so the live requirements panel
    // ticks items off in real time while the user types.
    _emailController.addListener(() {
      if (_emailError != null) _validateEmail(showIfEmpty: false);
      setState(() {});
    });
    _passwordController.addListener(() {
      if (_passwordError != null) _validatePassword(showIfEmpty: false);
      if (_confirmPasswordError != null) {
        _validateConfirmPassword(showIfEmpty: false);
      }
      setState(() {});
    });
    _confirmPasswordController.addListener(() {
      if (_confirmPasswordError != null) {
        _validateConfirmPassword(showIfEmpty: false);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  /// Sanitize: trim whitespace and normalize casing for the email so
  /// "  Foo@Bar.com " and "foo@bar.com" are treated identically both
  /// for validation and for what gets sent to the backend.
  String get _cleanEmail => _emailController.text.trim().toLowerCase();
  String get _rawPassword => _passwordController.text; // do not trim passwords' interior
  String get _rawConfirmPassword => _confirmPasswordController.text;

  bool _validateEmail({bool showIfEmpty = true}) {
    final loc = AppLocalizations.of(context)!;
    final email = _cleanEmail;
    if (email.isEmpty && !showIfEmpty) {
      setState(() => _emailError = null);
      return false;
    }
    final error = ValidationService.validateEmail(email, loc);
    setState(() => _emailError = error);
    return error == null;
  }

  bool _validatePassword({bool showIfEmpty = true}) {
    final loc = AppLocalizations.of(context)!;
    final password = _rawPassword;
    if (password.isEmpty && !showIfEmpty) {
      setState(() => _passwordError = null);
      return false;
    }
    final error = ValidationService.validatePassword(password, loc);
    setState(() => _passwordError = error);
    return error == null;
  }

  bool _validateConfirmPassword({bool showIfEmpty = true}) {
    final loc = AppLocalizations.of(context)!;
    final confirm = _rawConfirmPassword;
    if (confirm.isEmpty && !showIfEmpty) {
      setState(() => _confirmPasswordError = null);
      return false;
    }
    final error = ValidationService.validatePasswordMatch(
      _rawPassword,
      confirm,
      loc,
    );
    setState(() => _confirmPasswordError = error);
    return error == null;
  }

  /// Maps a raw/unexpected error (exception message, backend code, etc.)
  /// to a clear, actionable sentence. Never surfaces raw exception text.
  String _friendlyFormError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('email-already-in-use') || lower.contains('already in use')) {
      return 'That email is already registered. Try logging in instead.';
    }
    if (lower.contains('network')) {
      return 'No internet connection. Check your network and try again.';
    }
    if (lower.contains('weak-password')) {
      return 'That password is too weak. Use at least 8 characters, including a number.';
    }
    if (lower.contains('invalid-email')) {
      return 'That email address looks invalid. Double-check it and try again.';
    }
    // Fall back to the service-provided message if it already reads like
    // a sentence meant for a human; otherwise use a generic actionable one.
    if (raw.trim().endsWith('.') || raw.trim().endsWith('!')) {
      return raw;
    }
    return 'Something went wrong while creating your account. Please try again.';
  }

  /// Resets the whole form back to its initial empty state. Used by the
  /// pull-to-refresh gesture on the signup page.
  Future<void> _refreshForm() async {
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    setState(() {
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _formError = null;
    });
    HapticService().vibrate();
  }

  /// Shows a blocking "account created" confirmation dialog. Navigation
  /// only proceeds once the user taps "Okay".
  Future<void> _showAccountCreatedDialog() async {
    if (!mounted) return;
    final loc = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text(loc.accountCreatedTitle),
          content: Text(loc.accountCreatedMessage),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(loc.okayButton),
            ),
          ],
        );
      },
    );
  }

  /// Sends the signed-in user to Onboarding or Home, clearing the nav
  /// stack so they can't swipe/back into the auth screens again.
  Future<void> _routeAfterAuth() async {
    final onboarded = await _authService.hasCompletedOnboarding();
    if (!mounted) return;
    // Dismiss the keyboard/field focus before navigating away -- see
    // LoginScreen._routeAfterAuth for why this matters.
    FocusScope.of(context).unfocus();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => onboarded ? const HomeScreen() : const OnboardingScreen(),
      ),
          (route) => false,
    );
  }

  /// Navigates explicitly to the OTP screen when a Google sign-in comes
  /// back with MFA required. This screen is reached via
  /// Navigator.pushReplacement, which means AuthGate isn't mounted here
  /// — the same root cause as the earlier "stuck on signup" bug — so we
  /// can't rely on it to swap in OtpVerificationScreen on its own. We
  /// use the full challenge AuthService already stored in
  /// AuthService.pendingMfaChallenge (uid, code, emailSent, email; no
  /// password for a Google-originated challenge).
  void _navigateToOtpScreen() {
    final challenge = AuthService.pendingMfaChallenge.value;
    if (!mounted || challenge == null) return;
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

  Future<void> _handleSignUp() async {
    // Re-run all validators together on submit so every relevant field
    // shows its error at once (inline), instead of one snackbar at a time.
    final emailOk = _validateEmail();
    final passwordOk = _validatePassword();
    final confirmOk = _validateConfirmPassword();

    if (!emailOk || !passwordOk || !confirmOk) {
      HapticService().vibrate();
      return; // Nothing is cleared — user's input is preserved as-is.
    }

    setState(() {
      _formError = null;
      _isLoading = true;
    });
    HapticService().vibrate();

    try {
      final error = await _authService.signUp(
        email: _cleanEmail,
        password: _rawPassword,
      );

      if (!mounted) return;

      if (error != null) {
        setState(() => _formError = _friendlyFormError(error));
        return;
      }

      // Success: confirm with the user, then route to Onboarding
      // (brand-new signups have never completed onboarding).
      setState(() => _isLoading = false);
      await _showAccountCreatedDialog();
      if (!mounted) return;
      // Dismiss the keyboard/field focus before navigating away -- see
      // LoginScreen._routeAfterAuth for why this matters. Signed-up
      // users go straight to OnboardingScreen, which now opens on the
      // Basic Information page.
      FocusScope.of(context).unfocus();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
            (route) => false,
      );
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _formError = _friendlyFormError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        // Google sign-in succeeded, no MFA required. Previously this
        // relied on AuthGate to notice the auth-state change and
        // redirect automatically, but this screen is reached via
        // Navigator.pushReplacement from LoginScreen — meaning it lives
        // OUTSIDE AuthGate's widget tree, so nothing was listening and
        // the user got stuck here even though Firebase had already
        // logged them in. We now navigate explicitly instead of
        // waiting on AuthGate.
        await _routeAfterAuth();
        return;
      }

      if (result is String) {
        setState(() => _formError = _friendlyFormError(result));
        return;
      }

      // MFA_REQUIRED map: the signed-in Google account has MFA enabled.
      // Navigate to the OTP screen explicitly (see _navigateToOtpScreen
      // doc — AuthGate can't be relied on here).
      _navigateToOtpScreen();
    } catch (e) {
      if (!mounted) return;
      setState(() => _formError = _friendlyFormError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Force Light Mode for Signup Screen
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
                            loc.signUpWelcome,
                            style: TextStyle(
                                fontSize: 26, fontWeight: FontWeight.bold, color: colorScheme.primary),
                          ),
                          Text(
                            loc.signUpSubtitle,
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
                            inputFormatters: [_SanitizingTextInputFormatter()],
                            textInputAction: TextInputAction.next,
                          ),
                          _buildRequirementsPanel(
                            visible: _emailFocus.hasFocus,
                            requirements: _emailRequirements,
                            value: _cleanEmail,
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
                            inputFormatters: [_SanitizingTextInputFormatter()],
                            textInputAction: TextInputAction.next,
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
                          _buildRequirementsPanel(
                            visible: _passwordFocus.hasFocus,
                            requirements: _passwordRequirements,
                            value: _rawPassword,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            context,
                            controller: _confirmPasswordController,
                            focusNode: _confirmPasswordFocus,
                            hint: loc.confirmPassword,
                            icon: Icons.lock_outline,
                            obscure: !_showConfirmPassword,
                            errorText: _confirmPasswordError,
                            inputFormatters: [_SanitizingTextInputFormatter()],
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _handleSignUp(),
                            suffix: IconButton(
                              icon: Icon(
                                _showConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                size: 20,
                                color: Colors.grey,
                              ),
                              onPressed: () => setState(
                                      () => _showConfirmPassword = !_showConfirmPassword),
                            ),
                          ),
                          _buildRequirementsPanel(
                            visible: _confirmPasswordFocus.hasFocus,
                            requirements: _confirmPasswordRequirements,
                            value: _rawConfirmPassword,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _isLoading ? null : _handleSignUp,
                              child: _isLoading
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                                  : Text(
                                loc.signUp,
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
                                Text('${loc.alreadyHaveAccount} ',
                                    style: const TextStyle(fontSize: 13)),
                                GestureDetector(
                                  onTap: () {
                                    HapticService().vibrate();
                                    FocusScope.of(context).unfocus();
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const LoginScreen()),
                                    );
                                  },
                                  child: Text(
                                    loc.login,
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
      ),
    );
  }

  /// Live requirements checklist shown beneath a field while it's
  /// focused. Ticks items off in real time and collapses away once every
  /// requirement is satisfied (or the field loses focus).
  Widget _buildRequirementsPanel({
    required bool visible,
    required List<_Requirement> requirements,
    required String value,
  }) {
    final allMet = requirements.every((r) => r.isMet(value));
    final show = visible && !allMet;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: !show
          ? const SizedBox(width: double.infinity)
          : Builder(
        builder: (context) {
          final colorScheme = Theme.of(context).colorScheme;
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: requirements.map((r) {
                final met = r.isMet(value);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        met ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 14,
                        color: met ? Colors.green : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          r.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: met ? Colors.green : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
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
        List<TextInputFormatter>? inputFormatters,
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
      inputFormatters: inputFormatters,
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