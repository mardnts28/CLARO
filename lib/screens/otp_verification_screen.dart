import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key, required this.email, required this.password});

  final String email;
  final String password;

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
    final code = _otpController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the 6-digit verification code.')));
      return;
    }

    if (!mounted) return;
    setState(() => _isVerifying = true);
    try {
      final message = await _authService.verifyOtp(code: code);
      if (!mounted) return;
      if (message == null) {
        await _authService.clearOtpChallenge();
        final hasCompleted = await _authService.hasCompletedOnboarding();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => hasCompleted ? const HomeScreen() : const OnboardingScreen()),
        );
        return;
      }

      setState(() => _attempts++);
      if (_attempts >= 5) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Too many failed attempts. Please log in again.')));
        Navigator.pop(context);
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
    if (_isResending || _remainingSeconds > 0) return;
    if (!mounted) return;
    setState(() => _isResending = true);
    try {
      final otpData = await _authService.buildOtpChallenge(email: widget.email, password: widget.password);
      if (!mounted) return;
      if (otpData == null || otpData['code'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to resend the verification code.')));
        return;
      }
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A new verification code has been sent.')));
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Verify your email', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('A verification code has been sent to your email.', style: TextStyle(fontSize: 15)),
            const SizedBox(height: 24),
            TextField(
              controller: _otpController,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: 'Enter 6-digit code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verifyOtp,
                child: _isVerifying
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Verify'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: _isResending || _remainingSeconds > 0 ? null : _resendCode,
                  child: const Text('Resend Code'),
                ),
                const SizedBox(width: 8),
                Text(_remainingSeconds > 0 ? 'Resend in $_remainingSeconds s' : 'You can resend now'),
              ],
            ),
            const SizedBox(height: 12),
            Text('Attempts used: $_attempts/5'),
          ],
        ),
      ),
    );
  }
}
