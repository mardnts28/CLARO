import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../core/utils/success_feedback_utils.dart';
import '../services/haptic_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.password,
    required this.uid,
    this.otpCode,
    this.emailSent = true,
    this.expiresAt,
  });

  final String email;

  /// Null when this challenge came from Google sign-in (there's no
  /// password to re-verify with). Non-null for email/password logins.
  /// The resend flow branches on this: with a password we can safely
  /// re-run buildOtpChallenge (sign out + back in); without one we use
  /// resendOtpForCurrentSession, which assumes the current Firebase
  /// session is still valid.
  final String? password;
  final String uid;
  final String? otpCode;
  final bool emailSent;
  final DateTime? expiresAt;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _authService = AuthService();
  final _otpController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  int _remainingSeconds = 180;
  int _resendCooldownSeconds = 15;
  int _attempts = 0;
  Timer? _timer;
  DateTime? _currentExpiresAt;

  @override
  void initState() {
    super.initState();
    _currentExpiresAt = widget.expiresAt;
    if (widget.emailSent) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();

    // Calculate remaining seconds from expiry time
    if (_currentExpiresAt != null) {
      final now = DateTime.now();
      final difference = _currentExpiresAt!.difference(now);
      _remainingSeconds = difference.inSeconds;
    } else {
      _remainingSeconds = 300;
    }
    _resendCooldownSeconds = 15;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        }
        if (_resendCooldownSeconds > 0) {
          _resendCooldownSeconds--;
        }
        if (_remainingSeconds == 0 && _resendCooldownSeconds == 0) {
          timer.cancel();
        }
      });
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
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
      // Email/password logins re-verify credentials via buildOtpChallenge
      // (sign out + back in). Google-originated challenges have no
      // password, so we instead re-send an OTP for the session that's
      // already signed in via resendOtpForCurrentSession.
      final Map<String, dynamic>? otpData = widget.password != null
          ? await _authService.buildOtpChallenge(
          email: widget.email, password: widget.password!)
          : await _authService.resendOtpForCurrentSession(
          uid: widget.uid, email: widget.email);

      if (!mounted) return;
      if (otpData == null || otpData['code'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to resend the verification code.')));
        return;
      }
      final resendEmailSent = otpData['emailSent'] == true;
      if (resendEmailSent) {
        // Update expiry time if provided
        if (otpData['expiresAt'] != null) {
          _currentExpiresAt = (otpData['expiresAt'] as DateTime);
        }
        _startTimer();
        SuccessFeedbackUtils.showSuccessSnackBar(context, 'A new verification code has been sent.');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('We couldn\'t send the code to your email. Please try again in a moment.'),
          ),
        );
      }
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
              body: SafeArea(
                child: SingleChildScrollView(
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
                      // OTP Expiry Countdown Timer
                      if (_remainingSeconds > 0)
                        Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _remainingSeconds <= 10
                              ? Colors.red.withOpacity(0.1)
                              : colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _remainingSeconds <= 10
                                ? Colors.red
                                : colorScheme.primary.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 18,
                              color: _remainingSeconds <= 10
                                  ? Colors.red
                                  : colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Code expires in ${_formatTime(_remainingSeconds)}',
                              style: TextStyle(
                                color: _remainingSeconds <= 10
                                    ? Colors.red
                                    : colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_remainingSeconds == 0)
                        Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.timer_off_outlined,
                              size: 18,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Code has expired',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                          hintText: AppLocalizations.of(context)!.enterDigitCode,
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
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _resendCooldownSeconds > 0
                                ? Colors.grey.shade400
                                : Colors.red,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade400,
                          ),
                          onPressed: _isResending || _resendCooldownSeconds > 0
                              ? null
                              : _resendCode,
                          child: _isResending
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _resendCooldownSeconds > 0
                                    ? 'Resend Code in ${_formatTime(_resendCooldownSeconds)}'
                                    : 'Resend Code',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Attempts used: $_attempts/5', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}