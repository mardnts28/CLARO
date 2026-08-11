import '../generated/l10n/app_localizations.dart';

class ValidationService {
  /// Validates email format
  static String? validateEmail(String email, AppLocalizations loc) {
    if (email.isEmpty) {
      return loc.emailRequired;
    }
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(email)) {
      return loc.invalidEmail;
    }
    
    return null;
  }

  /// Validates password strength
  static String? validatePassword(String password, AppLocalizations loc) {
    if (password.isEmpty) {
      return loc.passwordRequired;
    }
    
    if (password.length < 8) {
      return loc.errorPasswordTooShort;
    }
    
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return loc.errorPasswordUppercase;
    }
    
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return loc.errorPasswordLowercase;
    }
    
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return loc.errorPasswordNumber;
    }
    
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return loc.errorPasswordSpecial;
    }
    
    return null;
  }

  /// Validates that passwords match
  static String? validatePasswordMatch(String password, String confirmPassword, AppLocalizations loc) {
    if (confirmPassword.isEmpty) {
      return loc.errorConfirmPassword;
    }
    
    if (password != confirmPassword) {
      return loc.errorPasswordsNotMatch;
    }
    
    return null;
  }

  /// Gets a generic error message for login failures
  static String getGenericLoginError(AppLocalizations loc) {
    return loc.invalidEmailOrPassword;
  }
}
