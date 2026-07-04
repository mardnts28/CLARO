import 'package:flutter/material.dart';
import '../generated/l10n/app_localizations.dart';
import 'signup_screen.dart';
import 'onboarding_screen.dart';
import 'otp_verification_screen.dart';
import 'home_screen.dart';
import 'forgot_password_screen.dart';
import '../services/auth_service.dart';
import '../services/validation_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _showPassword = false;
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Validate email
    final emailError = ValidationService.validateEmail(email);
    if (emailError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emailError)),
      );
      return;
    }

    // Validate password is not empty
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.passwordRequired)),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final error = await _authService.login(
        email: email,
        password: password,
      );
      if (!mounted) return;

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.invalidEmailOrPassword)),
        );
        return;
      }

      final requiresMfa = await _authService.isMfaEnabledForCurrentUser();
      if (!mounted) return;
      if (requiresMfa) {
        final otpData = await _authService.buildOtpChallenge(email: email, password: password);
        if (!mounted) return;
        if (otpData == null || otpData['code'] == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to send the verification code. Please try again.')));
          return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              email: email,
              password: password,
            ),
          ),
        );
        return;
      }

      final hasCompleted = await _authService.hasCompletedOnboarding();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              hasCompleted ? const HomeScreen() : const OnboardingScreen(),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final error = await _authService.signInWithGoogle();
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    } else {
      // Check if user has completed onboarding
      final hasCompleted = await _authService.hasCompletedOnboarding();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              hasCompleted ? const HomeScreen() : const OnboardingScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
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
                AppLocalizations.of(context)!.welcomeBack,
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold, color: colorScheme.primary),
              ),
              Text(
                AppLocalizations.of(context)!.loginToContinue,
                style: TextStyle(fontSize: 13, color: colorScheme.primary),
              ),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _emailController,
                hint: AppLocalizations.of(context)!.email,
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 14),
              _buildTextField(
                controller: _passwordController,
                hint: AppLocalizations.of(context)!.password,
                icon: Icons.lock_outline,
                obscure: !_showPassword,
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
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen()),
                  ),
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
                      : Text(
                    AppLocalizations.of(context)!.login,
                    style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildDivider(),
              const SizedBox(height: 16),
              _buildGoogleButton(),
              const SizedBox(height: 24),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(AppLocalizations.of(context)!.dontHaveAccount + ' ',
                        style: const TextStyle(fontSize: 13)),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SignupScreen()),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.signUp,
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        suffixIcon: suffix,
        contentPadding:
        const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD9A0A0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF8B1A1A)),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Colors.grey)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(AppLocalizations.of(context)!.orContinueWith,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        const Expanded(child: Divider(color: Colors.grey)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFD9A0A0)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        icon: Image.asset('assets/images/google.png', height: 20),
        label: Text(
          AppLocalizations.of(context)!.continueWithGoogle,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
        ),
        onPressed: _isLoading ? null : _handleGoogleSignIn,
      ),
    );
  }
}