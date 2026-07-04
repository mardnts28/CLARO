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
  String get home => 'Home';

  @override
  String get scan => 'Scan';

  @override
  String get history => 'History';

  @override
  String get profile => 'Profile';

  @override
  String get homeTagline => 'Make smarter shopping decisions today.';

  @override
  String get scanCardTitle => 'Scan a product';

  @override
  String get scanCardSubtitle =>
      'Point your camera at any instant noodles or canned food.';

  @override
  String get scanNow => 'Scan now';

  @override
  String get labelIntroTitle => 'Understand your labels';

  @override
  String get labelIntroSubtitle =>
      'With CLARO, it’s easier to read labels and choose healthier options.';

  @override
  String get healthGradeTitle => 'Food health rating';

  @override
  String get healthGradeSubtitle => 'Overall nutrition quality of the product.';

  @override
  String get healthGradeValue0 => 'Best – highly nutritious';

  @override
  String get healthGradeValue1 => 'Recommended choice';

  @override
  String get healthGradeValue2 => 'Acceptable in moderation';

  @override
  String get healthGradeValue3 => 'Limit consumption';

  @override
  String get healthGradeValue4 => 'Avoid frequent intake';

  @override
  String get ecoGradeTitle => 'Environment-friendly rating';

  @override
  String get ecoGradeSubtitle => 'The product’s impact on the planet.';

  @override
  String get ecoGradeValue0 => 'Excellent environmental impact';

  @override
  String get ecoGradeValue1 => 'Good for the environment';

  @override
  String get ecoGradeValue2 => 'Moderate environmental impact';

  @override
  String get ecoGradeValue3 => 'Consider other options';

  @override
  String get ecoGradeValue4 => 'High environmental harm';

  @override
  String get processGradeTitle => 'Food processing level';

  @override
  String get processGradeSubtitle =>
      'How much processing the product has gone through.';

  @override
  String get processGroupFirst => 'First grade';

  @override
  String get processGroupFourth => 'Fourth grade';

  @override
  String get processLabel0 => 'Unprocessed or lightly processed';

  @override
  String get processLabel1 => 'Processed culinary ingredients';

  @override
  String get processLabel2 => 'Processed food';

  @override
  String get processLabel3 => 'Ultra-processed food';

  @override
  String get bestLabel => 'Most recommended';

  @override
  String get worstLabel => 'Least recommended';

  @override
  String get scanTabTitle => 'Scan';

  @override
  String get scanTabSubtitle => 'Scan your product from here.';

  @override
  String get historyTabTitle => 'History';

  @override
  String get historyTabSubtitle => 'Your scan history will appear here.';

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
  String get passwordRequired => 'Password is required';

  @override
  String get invalidEmailOrPassword => 'Invalid email or password';

  @override
  String get unableSendVerificationCode =>
      'Unable to send the verification code. Please try again.';

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

  @override
  String get theme => 'Theme';

  @override
  String get themeSaved => 'Theme saved';

  @override
  String get themeSaveError => 'Unable to save theme';

  @override
  String get themeDefault => 'Default';

  @override
  String get themeDarkMode => 'Dark Mode';

  @override
  String get themeDefaultDescription => 'The standard Claro look';

  @override
  String get themeDarkModeDescription =>
      'Dark background for low-light places.';

  @override
  String get multiFactorAuthentication => 'Multi-factor authentication';

  @override
  String get voiceAssistant => 'Voice Assistant';

  @override
  String get darkModeSetting => 'Dark Mode';

  @override
  String get mfaSaveError => 'Could not save MFA setting';

  @override
  String get preferenceSaveError => 'Unable to save preference';

  @override
  String get preferenceTitle => 'Preference';

  @override
  String get voiceSoundTitle => 'Voice & sound';

  @override
  String get selectLanguage => 'Select language';

  @override
  String get speechRate => 'Speech rate';

  @override
  String get previewAudio => 'Tap for audio preview';

  @override
  String get vibrationFeedback => 'Vibration feedback';

  @override
  String get vibrateDescription => 'Vibrate on scan, alerts, and reads';

  @override
  String get textSize => 'Text size';

  @override
  String get previewAudioShort => 'Preview audio';

  @override
  String get signUpWelcome => 'Welcome!';

  @override
  String get signUpSubtitle => 'Sign up to start';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get resetPasswordInfo =>
      'Enter your email address and we will send you a link to reset your password.';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get emailSent => 'Email sent';

  @override
  String get checkYourEmail => 'Check your email';

  @override
  String get followLink =>
      'Follow the link in your email to reset your password.';

  @override
  String get backToLogin => 'Back to login';

  @override
  String get rememberYourPassword => 'Remember your password?';

  @override
  String get verifyEmail => 'Verify your email';

  @override
  String get verificationSentInfo =>
      'A verification code has been sent to your email.';

  @override
  String get enterCodeHint => 'Enter 6-digit code';

  @override
  String get verify => 'Verify';

  @override
  String get resendCode => 'Resend code';

  @override
  String resendInSeconds(Object seconds) {
    return 'Resend in $seconds s';
  }

  @override
  String get canResendNow => 'You can resend now';

  @override
  String attemptsUsed(Object used) {
    return 'Attempts used: $used/5';
  }

  @override
  String get tooManyFailedAttempts =>
      'Too many failed attempts. Please log in again.';

  @override
  String get unableToResend => 'Unable to resend the verification code.';

  @override
  String get verificationCodeSent => 'A new verification code has been sent.';

  @override
  String get onboardingNamePrompt => 'What should we call you?';

  @override
  String get onboardingNameHint => 'Name';

  @override
  String get onboardingNameEmpty => 'Please enter your name.';

  @override
  String get onboardingHeadline => 'Clear. Local. Trusted.';

  @override
  String get onboardingSubheadline => 'Your AI helper for healthier shopping.';

  @override
  String get featureScan => 'Scan product';

  @override
  String get featureNutrition => 'Product nutrition';

  @override
  String get featureHealth => 'Health guidance';

  @override
  String get featureCompare => 'Product comparison';

  @override
  String get getStarted => 'Get started';

  @override
  String get onboardingInstructions =>
      'Answer the questions below for safer, more personalized recommendations.';

  @override
  String get conditionsQuestion => 'Do you have any health conditions?';

  @override
  String get chooseAllThatApply => 'Choose all that apply.';

  @override
  String get profileChangeNote =>
      'You can change this later in your profile settings.';

  @override
  String get allergensQuestion => 'Are there any allergens to avoid?';

  @override
  String get safetyPriorityTitle => 'We prioritize your safety';

  @override
  String get safetyPriorityMessage =>
      'We use this information to provide health insights and safer recommendations.';

  @override
  String get suggestionIntro => 'We want to hear your feedback.';

  @override
  String get rateYourExperience => 'Rate your experience';

  @override
  String get shareImprovement => 'Share how we can improve';

  @override
  String get submit => 'Submit';

  @override
  String get sending => 'Sending...';

  @override
  String get suggestionSentTitle => 'Feedback sent!';

  @override
  String get suggestionSentBody =>
      'Thank you! Your feedback has been submitted successfully.';

  @override
  String get backLabel => 'Back';

  @override
  String get needSignInToSubmit =>
      'Please sign in before submitting suggestion.';

  @override
  String get submitError => 'Error sending feedback';

  @override
  String get aboutClaroHeading => 'Learn about us!';

  @override
  String get aboutClaroDescription =>
      'CLARO is an AI-powered mobile app that helps grocery shoppers understand nutrition information for local canned foods. By scanning a product, users see simplified nutrition summaries, health advisories, allergen warnings, product comparisons, and accessibility features such as voice assistance to make smarter and healthier buying decisions.';

  @override
  String get aboutDevelopers => 'About the developers';
}
