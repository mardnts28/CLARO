// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tagalog (`tl`).
class AppLocalizationsTl extends AppLocalizations {
  AppLocalizationsTl([String locale = 'tl']) : super(locale);

  @override
  String greeting(Object name) {
    return 'Kumusta, $name! 👋';
  }

  @override
  String get scanProduct => 'I-scan ang produkto';

  @override
  String get welcomeBack => 'Welcome back!';

  @override
  String get loginToContinue => 'Login to continue';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get forgotPassword => 'Nakalimutan ang password?';

  @override
  String get login => 'Mag-login';

  @override
  String get orContinueWith => 'or continue with';

  @override
  String get continueWithGoogle => 'Magpatuloy gamit ang Google';

  @override
  String get dontHaveAccount => 'Wala pang account?';

  @override
  String get signUp => 'Mag-sign up';

  @override
  String get chooseLanguage => 'Piliin ang Lenggwuahe';

  @override
  String get english => 'English';

  @override
  String get tagalog => 'Tagalog';

  @override
  String get profile => 'Profile';

  @override
  String get personalInfo => 'Personal na Impormasyon';

  @override
  String get preference => 'Preference';

  @override
  String get language => 'Lenggwuahe';

  @override
  String get suggestion => 'Sugestiyon';

  @override
  String get aboutClaro => 'Tungkol sa CLARO';

  @override
  String get logout => 'Logout';
}
