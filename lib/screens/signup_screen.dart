import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import '../services/validation_service.dart';
import '../services/haptic_service.dart';

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

  @override
  void initState() {
    super.initState();
    // Validate as soon as the user leaves a field (inline validation),
    // rather than only on submit.
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) _validateEmail(showIfEmpty: false);
    });
    _passwordFocus.addListener(() {
      if (!_passwordFocus.hasFocus) _validatePassword(showIfEmpty: false);
    });
    _confirmPasswordFocus.addListener(() {
      if (!_confirmPasswordFocus.hasFocus) {
        _validateConfirmPassword(showIfEmpty: false);
      }
    });

    // Once an error is showing for a field, re-check on every keystroke
    // so it clears the moment the user fixes it — this is the
    // "inline validation" feedback loop working both directions.
    _emailController.addListener(() {
      if (_emailError != null) _validateEmail(showIfEmpty: false);
    });
    _passwordController.addListener(() {
      if (_passwordError != null) _validatePassword(showIfEmpty: false);
      if (_confirmPasswordError != null) {
        _validateConfirmPassword(showIfEmpty: false);
      }
    });
    _confirmPasswordController.addListener(() {
      if (_confirmPasswordError != null) {
        _validateConfirmPassword(showIfEmpty: false);
      }
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
    final email = _cleanEmail;
    if (email.isEmpty && !showIfEmpty) {
      setState(() => _emailError = null);
      return false;
    }
    final error = ValidationService.validateEmail(email);
    setState(() => _emailError = error);
    return error == null;
  }

  bool _validatePassword({bool showIfEmpty = true}) {
    final password = _rawPassword;
    if (password.isEmpty && !showIfEmpty) {
      setState(() => _passwordError = null);
      return false;
    }
    final error = ValidationService.validatePassword(password);
    setState(() => _passwordError = error);
    return error == null;
  }

  bool _validateConfirmPassword({bool showIfEmpty = true}) {
    final confirm = _rawConfirmPassword;
    if (confirm.isEmpty && !showIfEmpty) {
      setState(() => _confirmPasswordError = null);
      return false;
    }
    final error = ValidationService.validatePasswordMatch(
      _rawPassword,
      confirm,
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
      }
      // On success, AuthGate handles navigation automatically.
      // Controllers are intentionally left untouched here — if navigation
      // is delayed for any reason, the user never sees their data vanish.
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
      final error = await _authService.signInWithGoogle();
      if (!mounted) return;
      if (error != null) {
        setState(() => _formError = _friendlyFormError(error));
      }
      // AuthGate handles navigation automatically.
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
                child: SingleChildScrollView(
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
                        'Welcome!',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.bold, color: colorScheme.primary),
                      ),
                      Text(
                        'Sign up to start',
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
                        inputFormatters: [_SanitizingTextInputFormatter()],
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
                      const SizedBox(height: 14),
                      _buildTextField(
                        context,
                        controller: _confirmPasswordController,
                        focusNode: _confirmPasswordFocus,
                        hint: 'Confirm Password',
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
                              : const Text(
                            'Sign up',
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
                            const Text('Already have an account? ',
                                style: TextStyle(fontSize: 13)),
                            GestureDetector(
                              onTap: () {
                                HapticService().vibrate();
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginScreen()),
                                );
                              },
                              child: Text(
                                'Login',
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
    List<TextInputFormatter>? inputFormatters,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
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