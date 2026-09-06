import 'package:flutter/material.dart';
import '../widgets/custom_text_field.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import '../services/validation_service.dart';
import '../core/utils/success_feedback_utils.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _emailSent = false;
  String? _emailError;

  Future<void> _handlePasswordReset() async {
    final loc = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();

    // Validate email
    final emailError = ValidationService.validateEmail(email, loc);
    if (emailError != null) {
      setState(() => _emailError = emailError);
      return;
    }
    setState(() => _emailError = null);

    setState(() => _isLoading = true);
    final error = await _authService.sendPasswordResetEmail(email: email);
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    } else {
      setState(() => _emailSent = true);
      SuccessFeedbackUtils.showSuccessSnackBar(context, loc.emailSent);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Force Light Mode for Forgot Password Screen
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

          return Scaffold(
            backgroundColor: colorScheme.surface,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth < 400
                      ? 20.0
                      : 28.0;

                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 24,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                HapticService().vibrate();
                                Navigator.pop(context);
                              },
                              child: Icon(
                                Icons.arrow_back,
                                color: colorScheme.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Center(
                              child: Column(
                                children: [
                                  Image.asset(
                                    'assets/images/logo.png',
                                    height: 80,
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
                              'Reset Password',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            Text(
                              'Enter your email address and we will send you a link to reset your password.',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildTextField(
                              context,
                              controller: _emailController,
                              hint: 'Email',
                              icon: Icons.email_outlined,
                              enabled: !_emailSent,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _isLoading || _emailSent
                                    ? null
                                    : _handlePasswordReset,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _emailSent
                                            ? 'Email Sent'
                                            : 'Send Reset Link',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            if (_emailSent) ...[
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green.shade300,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green.shade700,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Check your email',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Follow the link in your email to reset your password.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  _emailSent
                                      ? 'Back to Login'
                                      : 'Remember your password? Back to Login',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool enabled = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomTextField(
      controller: controller,
      hintText: hint,
      prefixIcon: Icon(icon, color: colorScheme.onSurfaceVariant, size: 20),
      enabled: enabled,
      errorText: _emailError,
      onChanged: (val) {
        if (_emailError != null && val.trim().isNotEmpty) {
          setState(() => _emailError = null);
        }
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}
