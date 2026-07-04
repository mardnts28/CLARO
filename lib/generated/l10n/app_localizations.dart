import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tl'),
  ];

  /// Greeting with user name
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}! 👋'**
  String greeting(Object name);

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @homeTagline.
  ///
  /// In en, this message translates to:
  /// **'Make smarter shopping decisions today.'**
  String get homeTagline;

  /// No description provided for @scanCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan a product'**
  String get scanCardTitle;

  /// No description provided for @scanCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Point your camera at any instant noodles or canned food.'**
  String get scanCardSubtitle;

  /// No description provided for @scanNow.
  ///
  /// In en, this message translates to:
  /// **'Scan now'**
  String get scanNow;

  /// No description provided for @labelIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Understand your labels'**
  String get labelIntroTitle;

  /// No description provided for @labelIntroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'With CLARO, it’s easier to read labels and choose healthier options.'**
  String get labelIntroSubtitle;

  /// No description provided for @healthGradeTitle.
  ///
  /// In en, this message translates to:
  /// **'Food health rating'**
  String get healthGradeTitle;

  /// No description provided for @healthGradeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Overall nutrition quality of the product.'**
  String get healthGradeSubtitle;

  /// No description provided for @healthGradeValue0.
  ///
  /// In en, this message translates to:
  /// **'Best – highly nutritious'**
  String get healthGradeValue0;

  /// No description provided for @healthGradeValue1.
  ///
  /// In en, this message translates to:
  /// **'Recommended choice'**
  String get healthGradeValue1;

  /// No description provided for @healthGradeValue2.
  ///
  /// In en, this message translates to:
  /// **'Acceptable in moderation'**
  String get healthGradeValue2;

  /// No description provided for @healthGradeValue3.
  ///
  /// In en, this message translates to:
  /// **'Limit consumption'**
  String get healthGradeValue3;

  /// No description provided for @healthGradeValue4.
  ///
  /// In en, this message translates to:
  /// **'Avoid frequent intake'**
  String get healthGradeValue4;

  /// No description provided for @ecoGradeTitle.
  ///
  /// In en, this message translates to:
  /// **'Environment-friendly rating'**
  String get ecoGradeTitle;

  /// No description provided for @ecoGradeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The product’s impact on the planet.'**
  String get ecoGradeSubtitle;

  /// No description provided for @ecoGradeValue0.
  ///
  /// In en, this message translates to:
  /// **'Excellent environmental impact'**
  String get ecoGradeValue0;

  /// No description provided for @ecoGradeValue1.
  ///
  /// In en, this message translates to:
  /// **'Good for the environment'**
  String get ecoGradeValue1;

  /// No description provided for @ecoGradeValue2.
  ///
  /// In en, this message translates to:
  /// **'Moderate environmental impact'**
  String get ecoGradeValue2;

  /// No description provided for @ecoGradeValue3.
  ///
  /// In en, this message translates to:
  /// **'Consider other options'**
  String get ecoGradeValue3;

  /// No description provided for @ecoGradeValue4.
  ///
  /// In en, this message translates to:
  /// **'High environmental harm'**
  String get ecoGradeValue4;

  /// No description provided for @processGradeTitle.
  ///
  /// In en, this message translates to:
  /// **'Food processing level'**
  String get processGradeTitle;

  /// No description provided for @processGradeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How much processing the product has gone through.'**
  String get processGradeSubtitle;

  /// No description provided for @processGroupFirst.
  ///
  /// In en, this message translates to:
  /// **'First grade'**
  String get processGroupFirst;

  /// No description provided for @processGroupFourth.
  ///
  /// In en, this message translates to:
  /// **'Fourth grade'**
  String get processGroupFourth;

  /// No description provided for @processLabel0.
  ///
  /// In en, this message translates to:
  /// **'Unprocessed or lightly processed'**
  String get processLabel0;

  /// No description provided for @processLabel1.
  ///
  /// In en, this message translates to:
  /// **'Processed culinary ingredients'**
  String get processLabel1;

  /// No description provided for @processLabel2.
  ///
  /// In en, this message translates to:
  /// **'Processed food'**
  String get processLabel2;

  /// No description provided for @processLabel3.
  ///
  /// In en, this message translates to:
  /// **'Ultra-processed food'**
  String get processLabel3;

  /// No description provided for @bestLabel.
  ///
  /// In en, this message translates to:
  /// **'Most recommended'**
  String get bestLabel;

  /// No description provided for @worstLabel.
  ///
  /// In en, this message translates to:
  /// **'Least recommended'**
  String get worstLabel;

  /// No description provided for @scanTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scanTabTitle;

  /// No description provided for @scanTabSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan your product from here.'**
  String get scanTabSubtitle;

  /// No description provided for @historyTabTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTabTitle;

  /// No description provided for @historyTabSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your scan history will appear here.'**
  String get historyTabSubtitle;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get welcomeBack;

  /// No description provided for @loginToContinue.
  ///
  /// In en, this message translates to:
  /// **'Login to continue'**
  String get loginToContinue;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @orContinueWith.
  ///
  /// In en, this message translates to:
  /// **'or continue with'**
  String get orContinueWith;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get chooseLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @tagalog.
  ///
  /// In en, this message translates to:
  /// **'Tagalog'**
  String get tagalog;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @invalidEmailOrPassword.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get invalidEmailOrPassword;

  /// No description provided for @unableSendVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Unable to send the verification code. Please try again.'**
  String get unableSendVerificationCode;

  /// No description provided for @personalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInfo;

  /// No description provided for @preference.
  ///
  /// In en, this message translates to:
  /// **'Preference'**
  String get preference;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @suggestion.
  ///
  /// In en, this message translates to:
  /// **'Suggestion'**
  String get suggestion;

  /// No description provided for @aboutClaro.
  ///
  /// In en, this message translates to:
  /// **'About CLARO'**
  String get aboutClaro;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSaved.
  ///
  /// In en, this message translates to:
  /// **'Theme saved'**
  String get themeSaved;

  /// No description provided for @themeSaveError.
  ///
  /// In en, this message translates to:
  /// **'Unable to save theme'**
  String get themeSaveError;

  /// No description provided for @themeDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get themeDefault;

  /// No description provided for @themeDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get themeDarkMode;

  /// No description provided for @themeDefaultDescription.
  ///
  /// In en, this message translates to:
  /// **'The standard Claro look'**
  String get themeDefaultDescription;

  /// No description provided for @themeDarkModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Dark background for low-light places.'**
  String get themeDarkModeDescription;

  /// No description provided for @multiFactorAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Multi-factor authentication'**
  String get multiFactorAuthentication;

  /// No description provided for @voiceAssistant.
  ///
  /// In en, this message translates to:
  /// **'Voice Assistant'**
  String get voiceAssistant;

  /// No description provided for @darkModeSetting.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkModeSetting;

  /// No description provided for @mfaSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save MFA setting'**
  String get mfaSaveError;

  /// No description provided for @preferenceSaveError.
  ///
  /// In en, this message translates to:
  /// **'Unable to save preference'**
  String get preferenceSaveError;

  /// No description provided for @preferenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Preference'**
  String get preferenceTitle;

  /// No description provided for @voiceSoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice & sound'**
  String get voiceSoundTitle;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get selectLanguage;

  /// No description provided for @speechRate.
  ///
  /// In en, this message translates to:
  /// **'Speech rate'**
  String get speechRate;

  /// No description provided for @previewAudio.
  ///
  /// In en, this message translates to:
  /// **'Tap for audio preview'**
  String get previewAudio;

  /// No description provided for @vibrationFeedback.
  ///
  /// In en, this message translates to:
  /// **'Vibration feedback'**
  String get vibrationFeedback;

  /// No description provided for @vibrateDescription.
  ///
  /// In en, this message translates to:
  /// **'Vibrate on scan, alerts, and reads'**
  String get vibrateDescription;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// No description provided for @previewAudioShort.
  ///
  /// In en, this message translates to:
  /// **'Preview audio'**
  String get previewAudioShort;

  /// No description provided for @signUpWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get signUpWelcome;

  /// No description provided for @signUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign up to start'**
  String get signUpSubtitle;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// No description provided for @resetPasswordInfo.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we will send you a link to reset your password.'**
  String get resetPasswordInfo;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @emailSent.
  ///
  /// In en, this message translates to:
  /// **'Email sent'**
  String get emailSent;

  /// No description provided for @checkYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkYourEmail;

  /// No description provided for @followLink.
  ///
  /// In en, this message translates to:
  /// **'Follow the link in your email to reset your password.'**
  String get followLink;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get backToLogin;

  /// No description provided for @rememberYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Remember your password?'**
  String get rememberYourPassword;

  /// No description provided for @verifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get verifyEmail;

  /// No description provided for @verificationSentInfo.
  ///
  /// In en, this message translates to:
  /// **'A verification code has been sent to your email.'**
  String get verificationSentInfo;

  /// No description provided for @enterCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter 6-digit code'**
  String get enterCodeHint;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @resendInSeconds.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds} s'**
  String resendInSeconds(Object seconds);

  /// No description provided for @canResendNow.
  ///
  /// In en, this message translates to:
  /// **'You can resend now'**
  String get canResendNow;

  /// No description provided for @attemptsUsed.
  ///
  /// In en, this message translates to:
  /// **'Attempts used: {used}/5'**
  String attemptsUsed(Object used);

  /// No description provided for @tooManyFailedAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Please log in again.'**
  String get tooManyFailedAttempts;

  /// No description provided for @unableToResend.
  ///
  /// In en, this message translates to:
  /// **'Unable to resend the verification code.'**
  String get unableToResend;

  /// No description provided for @verificationCodeSent.
  ///
  /// In en, this message translates to:
  /// **'A new verification code has been sent.'**
  String get verificationCodeSent;

  /// No description provided for @onboardingNamePrompt.
  ///
  /// In en, this message translates to:
  /// **'What should we call you?'**
  String get onboardingNamePrompt;

  /// No description provided for @onboardingNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get onboardingNameHint;

  /// No description provided for @onboardingNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name.'**
  String get onboardingNameEmpty;

  /// No description provided for @onboardingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Clear. Local. Trusted.'**
  String get onboardingHeadline;

  /// No description provided for @onboardingSubheadline.
  ///
  /// In en, this message translates to:
  /// **'Your AI helper for healthier shopping.'**
  String get onboardingSubheadline;

  /// No description provided for @featureScan.
  ///
  /// In en, this message translates to:
  /// **'Scan product'**
  String get featureScan;

  /// No description provided for @featureNutrition.
  ///
  /// In en, this message translates to:
  /// **'Product nutrition'**
  String get featureNutrition;

  /// No description provided for @featureHealth.
  ///
  /// In en, this message translates to:
  /// **'Health guidance'**
  String get featureHealth;

  /// No description provided for @featureCompare.
  ///
  /// In en, this message translates to:
  /// **'Product comparison'**
  String get featureCompare;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @onboardingInstructions.
  ///
  /// In en, this message translates to:
  /// **'Answer the questions below for safer, more personalized recommendations.'**
  String get onboardingInstructions;

  /// No description provided for @conditionsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Do you have any health conditions?'**
  String get conditionsQuestion;

  /// No description provided for @chooseAllThatApply.
  ///
  /// In en, this message translates to:
  /// **'Choose all that apply.'**
  String get chooseAllThatApply;

  /// No description provided for @profileChangeNote.
  ///
  /// In en, this message translates to:
  /// **'You can change this later in your profile settings.'**
  String get profileChangeNote;

  /// No description provided for @allergensQuestion.
  ///
  /// In en, this message translates to:
  /// **'Are there any allergens to avoid?'**
  String get allergensQuestion;

  /// No description provided for @safetyPriorityTitle.
  ///
  /// In en, this message translates to:
  /// **'We prioritize your safety'**
  String get safetyPriorityTitle;

  /// No description provided for @safetyPriorityMessage.
  ///
  /// In en, this message translates to:
  /// **'We use this information to provide health insights and safer recommendations.'**
  String get safetyPriorityMessage;

  /// No description provided for @suggestionIntro.
  ///
  /// In en, this message translates to:
  /// **'We want to hear your feedback.'**
  String get suggestionIntro;

  /// No description provided for @rateYourExperience.
  ///
  /// In en, this message translates to:
  /// **'Rate your experience'**
  String get rateYourExperience;

  /// No description provided for @shareImprovement.
  ///
  /// In en, this message translates to:
  /// **'Share how we can improve'**
  String get shareImprovement;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sending;

  /// No description provided for @suggestionSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Feedback sent!'**
  String get suggestionSentTitle;

  /// No description provided for @suggestionSentBody.
  ///
  /// In en, this message translates to:
  /// **'Thank you! Your feedback has been submitted successfully.'**
  String get suggestionSentBody;

  /// No description provided for @backLabel.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backLabel;

  /// No description provided for @needSignInToSubmit.
  ///
  /// In en, this message translates to:
  /// **'Please sign in before submitting suggestion.'**
  String get needSignInToSubmit;

  /// No description provided for @submitError.
  ///
  /// In en, this message translates to:
  /// **'Error sending feedback'**
  String get submitError;

  /// No description provided for @aboutClaroHeading.
  ///
  /// In en, this message translates to:
  /// **'Learn about us!'**
  String get aboutClaroHeading;

  /// No description provided for @aboutClaroDescription.
  ///
  /// In en, this message translates to:
  /// **'CLARO is an AI-powered mobile app that helps grocery shoppers understand nutrition information for local canned foods. By scanning a product, users see simplified nutrition summaries, health advisories, allergen warnings, product comparisons, and accessibility features such as voice assistance to make smarter and healthier buying decisions.'**
  String get aboutClaroDescription;

  /// No description provided for @aboutDevelopers.
  ///
  /// In en, this message translates to:
  /// **'About the developers'**
  String get aboutDevelopers;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tl':
      return AppLocalizationsTl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
