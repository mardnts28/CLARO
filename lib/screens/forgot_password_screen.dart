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

    final emailError = ValidationService.validateEmail(email, loc);

    if (emailError != null) {
      setState(() => _emailError = emailError);
      return;
    }

    setState(() => _emailError = null);
    setState(() => _isLoading = true);

    final error = await _authService.sendPasswordResetEmail(
      email: email,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _emailSent = true);

    SuccessFeedbackUtils.showSuccessSnackBar(
      context,
      loc.emailSent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F3F1),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF8B1A1A),
          onPrimary: Colors.white,
          secondary: Color(0xFFD32F2F),
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF1A1A1A),
          error: Color(0xFFD32F2F),
          onError: Colors.white,
          surfaceContainerHighest: Color(0xFFE8E3E1),
          outlineVariant: Color(0xFFD1CAC7),
          onSurfaceVariant: Color(0xFF6F6967),
        ),
      ),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final mediaQuery = MediaQuery.of(context);

          final screenWidth = mediaQuery.size.width;
          final screenHeight = mediaQuery.size.height;

          final isSmallPhone = screenWidth < 360;
          final isTablet = screenWidth >= 600;

          final horizontalPadding = isSmallPhone
              ? 16.0
              : isTablet
                  ? 32.0
                  : 20.0;

          final contentMaxWidth = isTablet ? 520.0 : 480.0;

          final topSpacing = screenHeight < 650
              ? 12.0
              : isTablet
                  ? 28.0
                  : 20.0;

          final logoSize = isSmallPhone
              ? 62.0
              : isTablet
                  ? 82.0
                  : 72.0;

          final titleSize = isSmallPhone
              ? 23.0
              : isTablet
                  ? 29.0
                  : 26.0;

          final bodySize = isSmallPhone ? 12.5 : 13.5;

          return Scaffold(
            backgroundColor: colorScheme.surface,
            resizeToAvoidBottomInset: true,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableHeight = constraints.maxHeight;

                  final compactVerticalLayout = availableHeight < 620;

                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      topSpacing,
                      horizontalPadding,
                      24,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: contentMaxWidth,
                          minHeight: availableHeight - topSpacing - 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildBackButton(
                              context,
                              colorScheme,
                              compactVerticalLayout,
                            ),

                            SizedBox(
                              height: compactVerticalLayout ? 16 : 24,
                            ),

                            _buildHeader(
                              context,
                              colorScheme,
                              logoSize: logoSize,
                              titleSize: titleSize,
                              compact: compactVerticalLayout,
                            ),

                            SizedBox(
                              height: compactVerticalLayout ? 20 : 30,
                            ),

                            _buildFormCard(
                              context,
                              colorScheme,
                              bodySize: bodySize,
                              compact: compactVerticalLayout,
                            ),

                            SizedBox(
                              height: compactVerticalLayout ? 16 : 20,
                            ),

                            _buildBackToLoginButton(
                              context,
                              colorScheme,
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

  Widget _buildBackButton(
    BuildContext context,
    ColorScheme colorScheme,
    bool compact,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticService().vibrate();
            Navigator.pop(context);
          },
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.arrow_back_rounded,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme colorScheme, {
    required double logoSize,
    required double titleSize,
    required bool compact,
  }) {
    return Column(
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: logoSize,
          height: logoSize,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: logoSize,
              height: logoSize,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_reset_rounded,
                size: logoSize * 0.48,
                color: colorScheme.primary,
              ),
            );
          },
        ),

        SizedBox(height: compact ? 4 : 8),

        Text(
          'CLARO',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 19 : 21,
            fontWeight: FontWeight.w800,
            color: colorScheme.primary,
            letterSpacing: 3.2,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(
    BuildContext context,
    ColorScheme colorScheme, {
    required double bodySize,
    required bool compact,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 20 : 24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Reset Password',
            style: TextStyle(
              fontSize: compact ? 24 : 27,
              fontWeight: FontWeight.w800,
              height: 1.15,
              color: colorScheme.primary,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            'Enter your email address and we will send you a link to reset your password.',
            style: TextStyle(
              fontSize: bodySize,
              height: 1.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),

          SizedBox(height: compact ? 18 : 24),

          _buildTextField(
            context,
            controller: _emailController,
            hint: 'Email',
            icon: Icons.email_outlined,
            enabled: !_emailSent,
            keyboardType: TextInputType.emailAddress,
          ),

          SizedBox(height: compact ? 16 : 20),

          _buildSubmitButton(
            context,
            colorScheme,
            compact: compact,
          ),

          if (_emailSent) ...[
            SizedBox(height: compact ? 16 : 20),
            _buildSuccessMessage(
              context,
              colorScheme,
              compact: compact,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmitButton(
    BuildContext context,
    ColorScheme colorScheme, {
    required bool compact,
  }) {
    return SizedBox(
      width: double.infinity,
      height: compact ? 48 : 52,
      child: ElevatedButton(
        onPressed: _isLoading || _emailSent
            ? null
            : _handlePasswordReset,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: colorScheme.primary,
          disabledBackgroundColor:
              colorScheme.primary.withValues(alpha: 0.45),
          foregroundColor: colorScheme.onPrimary,
          disabledForegroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _emailSent ? 'Email Sent' : 'Send Reset Link',
                  key: ValueKey(
                    _emailSent ? 'sent' : 'send',
                  ),
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSuccessMessage(
    BuildContext context,
    ColorScheme colorScheme, {
    required bool compact,
  }) {
    final successColor = Colors.green.shade700;
    final successBackground = Colors.green.shade50;
    final successBorder = Colors.green.shade200;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 16,
        vertical: compact ? 14 : 16,
      ),
      decoration: BoxDecoration(
        color: successBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: successBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              size: 21,
              color: successColor,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Check your email',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: successColor,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Follow the link in your email to reset your password.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackToLoginButton(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return TextButton(
      onPressed: () => Navigator.pop(context),
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        _emailSent
            ? 'Back to Login'
            : 'Remember your password? Back to Login',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool enabled = true,
    String? errorText,
    TextInputType? keyboardType,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return CustomTextField(
      controller: controller,
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: colorScheme.onSurfaceVariant,
        size: 20,
      ),
      enabled: enabled,
      errorText: errorText ?? _emailError,
      keyboardType: keyboardType,
      onChanged: (value) {
        if (_emailError != null && value.trim().isNotEmpty) {
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
