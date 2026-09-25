import 'package:flutter/material.dart';

class AccountRequiredGate extends StatelessWidget {
  const AccountRequiredGate({
    super.key,
    required this.message,
    required this.onLogin,
    required this.onCreateAccount,
  });

  final String message;
  final VoidCallback onLogin;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: 'Account required. $message',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary.withValues(alpha: 0.16),
                      colors.primary.withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 34,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    backgroundColor: colors.primary,
                    elevation: 0,
                  ),
                  onPressed: onLogin,
                  child: const Text(
                    'Log in',
                    style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.1),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  style: TextButton.styleFrom(
                    shape: const StadiumBorder(),
                    backgroundColor: colors.primary.withValues(alpha: 0.08),
                    foregroundColor: colors.primary,
                  ),
                  onPressed: onCreateAccount,
                  child: const Text(
                    'Create an account',
                    style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}