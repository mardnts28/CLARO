// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String greeting(Object name) {
    return 'Hello, $name! 👋';
  }

  @override
  String get scanProduct => 'Scan a product';

  @override
  String get welcomeBack => 'Welcome back!';

  @override
  String get loginToContinue => 'Login to continue';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get login => 'Login';

  @override
  String get orContinueWith => 'or continue with';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get signUp => 'Sign up';

  @override
  String get chooseLanguage => 'Choose language';

  @override
  String get english => 'English';

  @override
  String get tagalog => 'Tagalog';

  @override
  String get profile => 'Profile';

  @override
  String get personalInfo => 'Personal Information';

  @override
  String get preference => 'Preference';

  @override
  String get language => 'Language';

  @override
  String get suggestion => 'Suggestion';

  @override
  String get aboutClaro => 'About CLARO';

  @override
  String get logout => 'Logout';
}
