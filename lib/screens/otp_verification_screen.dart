import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.password,
    required this.uid,
    this.otpCode,
    this.emailSent = true,
  });

  final String email;
  final String password;
  final String uid;
  final String? otpCode;
  final bool emailSent;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _authService = AuthService();
  final _otpController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  int _remainingSeconds = 60;
  int _attempts = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _remainingSeconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _verifyOtp() async {
    HapticService().vibrate();
    final code = _otpController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the 6-digit verification code.')));
      return;
    }

    if (!mounted) return;
    setState(() => _isVerifying = true);
    try {
      final message = await _authService.verifyOtp(uid: widget.uid, code: code);
      if (!mounted) return;
      if (message == null) {
        await _authService.clearOtpChallenge(uid: widget.uid);
        await _authService.finishMfaLogin();
        // AuthGate will now navigate to Home automatically.
        return;
      }

      setState(() => _attempts++);
      if (_attempts >= 5) {
        if (!mounted) return;

        AuthService.pendingMfaChallenge.value = null;
        AuthService.isAuthenticating.value = false;
        await _authService.signOut();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Too many failed attempts. Please log in again.'),
          ),
        );

        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendCode() async {
    HapticService().vibrate();
    if (_isResending || _remainingSeconds > 0) return;
    if (!mounted) return;
    setState(() => _isResending = true);
    try {
      // Re-runs the full challenge (re-verifies credentials, issues a new
      // uid-keyed OTP). Note: this generates a NEW uid-keyed doc for the
      // same uid, overwriting the old one, so widget.uid stays valid.
      final otpData = await _authService.buildOtpChallenge(email: widget.email, password: widget.password);
      if (!mounted) return;
      if (otpData == null || otpData['code'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to resend the verification code.')));
        return;
      }
      _startTimer();
      final resendEmailSent = otpData['emailSent'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resendEmailSent
                ? 'A new verification code has been sent.'
                : 'We couldn\'t send the code to your email. Please try again in a moment.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Force Light Mode for OTP Verification Screen
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
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.noScaling,
            ),
            child: Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              appBar: AppBar(
                backgroundColor: colorScheme.surface,
                elevation: 0,
                title: Text('Verify your email', style: TextStyle(color: colorScheme.primary)),
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: colorScheme.primary),
                  onPressed: () async {
                    HapticService().vibrate();
                    AuthService.pendingMfaChallenge.value = null;
                    AuthService.isAuthenticating.value = false;
                    await _authService.signOut();
                  },
                ),
              ),
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verify your email',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.emailSent
                          ? 'A verification code has been sent to your email.'
                          : 'We couldn\'t send the code to your email right now. Please tap "Resend Code" below to try again.',
                      style: TextStyle(fontSize: 15, color: colorScheme.onSurfaceVariant),
                    ),
                    // NOTE: the OTP code is intentionally never rendered on
                    // screen, even as a fallback when email delivery fails.
                    // Displaying it here would defeat the purpose of MFA —
                    // anyone with access to the device (or a screenshot)
                    // could complete the login without ever touching the
                    // user's inbox. If email delivery is unreliable, fix
                    // the delivery path (see AuthService._sendOtpEmail)
                    // rather than exposing the code in the UI.
                    const SizedBox(height: 24),
                    TextField(
                      controller: _otpController,
                      style: TextStyle(color: colorScheme.onSurface),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'Enter 6-digit code',
                        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.outlineVariant)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                        onPressed: _isVerifying ? null : _verifyOtp,
                        child: _isVerifying
                            ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                            : const Text('Verify'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _isResending || _remainingSeconds > 0
                              ? null
                              : _resendCode,
                          child: Text('Resend Code', style: TextStyle(color: colorScheme.primary)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _remainingSeconds > 0
                              ? 'Resend in $_remainingSeconds s'
                              : 'You can resend now',
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Attempts used: $_attempts/5', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}