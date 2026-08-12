import 'package:flutter/material.dart';
import '../widgets/custom_text_field.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/validation_service.dart';
import '../core/utils/success_feedback_utils.dart';
import '../services/haptic_service.dart';
import '../services/voice_assistant_service.dart';
import '../widgets/voice_assistant_fab.dart';
import '../generated/l10n/app_localizations.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  static const Color _primaryRed = Color(0xFF8B1A1A);
  static const Color _lightRed = Color(0xFFFDF0F0);

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;

  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;

  Future<void> _handleChangePassword() async {
    HapticService().vibrate();
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final loc = AppLocalizations.of(context)!;

    setState(() {
      _currentPasswordError = null;
      _newPasswordError = null;
      _confirmPasswordError = null;
    });

    if (currentPassword.isEmpty) {
      setState(() => _currentPasswordError = loc.errorCurrentPassword);
      return;
    }

    if (newPassword.isEmpty) {
      setState(() => _newPasswordError = loc.errorNewPassword);
      return;
    }

    final newPassValidation = ValidationService.validatePassword(newPassword, loc);
    if (newPassValidation != null) {
      setState(() => _newPasswordError = newPassValidation);
      return;
    }

    if (confirmPassword.isEmpty) {
      setState(() => _confirmPasswordError = loc.errorConfirmPassword);
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() => _confirmPasswordError = loc.errorPasswordsNotMatch);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user == null) {
        _showError(loc.errorNotAuthenticated);
        return;
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      // updatePassword() issues a fresh ID token. Firestore's security
      // rules can take a brief moment to recognize that new token, so a
      // read made right after this (e.g. PersonalInfoScreen reloading
      // its data on return) can momentarily fail with permission-denied
      // even though nothing is actually wrong — the same race condition
      // AuthService already retries around in isSessionValid() and
      // _checkMfaEnabled(). Forcing a token refresh here, before we pop
      // back, gets ahead of that window instead of leaving the next
      // screen to hit it cold.
      try {
        await user.getIdToken(true);
      } catch (_) {
        // Non-fatal — the password change itself already succeeded.
        // PersonalInfoScreen's own retry logic is the real safety net.
      }

      setState(() => _isLoading = false);

      if (mounted) {
        SuccessFeedbackUtils.showSuccessSnackBar(context, loc.passwordChanged);
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      _showError(e.message ?? loc.errorChangingPassword);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(loc.unexpectedError);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme, loc),
              const SizedBox(height: 24),
              _buildDescriptionBox(theme, loc),
              const SizedBox(height: 24),
              _buildPasswordField(
                controller: _currentPasswordController,
                hint: loc.currentPassword,
                showPassword: _showCurrentPassword,
                theme: theme,
                errorText: _currentPasswordError,
                onToggle: () => setState(() => _showCurrentPassword = !_showCurrentPassword),
                onChanged: (val) {
                  if (_currentPasswordError != null && val.trim().isNotEmpty) {
                    setState(() => _currentPasswordError = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                controller: _newPasswordController,
                hint: loc.newPassword,
                showPassword: _showNewPassword,
                theme: theme,
                errorText: _newPasswordError,
                onToggle: () => setState(() => _showNewPassword = !_showNewPassword),
                onChanged: (val) {
                  if (_newPasswordError != null && val.trim().isNotEmpty) {
                    setState(() => _newPasswordError = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                controller: _confirmPasswordController,
                hint: loc.confirmPassword,
                showPassword: _showConfirmPassword,
                theme: theme,
                errorText: _confirmPasswordError,
                onToggle: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                onChanged: (val) {
                  if (_confirmPasswordError != null && val.trim().isNotEmpty) {
                    setState(() => _confirmPasswordError = null);
                  }
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isLoading ? null : _handleChangePassword,
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : Text(
                    loc.changePassword,
                    style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: const VoiceAssistantFab(),
    );
  }

  Widget _buildHeader(ThemeData theme, AppLocalizations loc) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            HapticService().vibrate();
            Navigator.pop(context);
          },
          child: Icon(Icons.arrow_back, color: theme.colorScheme.primary, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            loc.changePassword,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionBox(ThemeData theme, AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        loc.passwordRequirements,
        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface, height: 1.6),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool showPassword,
    required ThemeData theme,
    String? errorText,
    required VoidCallback onToggle,
    ValueChanged<String>? onChanged,
  }) {
    return CustomTextField(
      controller: controller,
      hintText: hint,
      obscureText: !showPassword,
      errorText: errorText,
      onChanged: onChanged,
      suffixIcon: IconButton(
        icon: Icon(
          showPassword ? Icons.visibility : Icons.visibility_off,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onPressed: onToggle,
      ),
    );
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}