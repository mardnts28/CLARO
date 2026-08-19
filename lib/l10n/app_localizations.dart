// FILE LOCATION: lib/l10n/app_localizations.dart
// (Not the one imported by the app -- see lib/generated/l10n/app_localizations.dart)

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

  /// No description provided for @infoFdaTitle.
  ///
  /// In en, this message translates to:
  /// **'Read the label'**
  String get infoFdaTitle;

  /// No description provided for @infoFdaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'FDA guide'**
  String get infoFdaSubtitle;

  /// No description provided for @infoWhoTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily limit'**
  String get infoWhoTitle;

  /// No description provided for @infoWhoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'WHO guide'**
  String get infoWhoSubtitle;

  /// No description provided for @infoFdaSheetHeading.
  ///
  /// In en, this message translates to:
  /// **'How to read the nutrition label'**
  String get infoFdaSheetHeading;

  /// No description provided for @infoFdaSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Based on FDA guidance (fda.gov)'**
  String get infoFdaSheetSubtitle;

  /// No description provided for @infoFdaSheetStep1.
  ///
  /// In en, this message translates to:
  /// **'Check serving size and servings per package. All nutrient amounts on the label are based on this, not the whole package.'**
  String get infoFdaSheetStep1;

  /// No description provided for @infoFdaSheetStep2.
  ///
  /// In en, this message translates to:
  /// **'Review calories. 2,000 calories per day is a general guide, but your needs may vary by age, sex, and activity level.'**
  String get infoFdaSheetStep2;

  /// No description provided for @infoFdaSheetStep3.
  ///
  /// In en, this message translates to:
  /// **'Use % Daily Value (%DV): 5% or less is considered low; 20% or more is considered high.'**
  String get infoFdaSheetStep3;

  /// No description provided for @infoWhoSheetHeading.
  ///
  /// In en, this message translates to:
  /// **'Daily nutrient limits'**
  String get infoWhoSheetHeading;

  /// No description provided for @infoWhoSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Based on WHO guidance for a 2,000 kcal diet'**
  String get infoWhoSheetSubtitle;

  /// No description provided for @infoWhoSheetLimitSugar.
  ///
  /// In en, this message translates to:
  /// **'Sugar (free sugars)'**
  String get infoWhoSheetLimitSugar;

  /// No description provided for @infoWhoSheetLimitSalt.
  ///
  /// In en, this message translates to:
  /// **'Salt (sodium)'**
  String get infoWhoSheetLimitSalt;

  /// No description provided for @infoWhoSheetLimitSaturatedFat.
  ///
  /// In en, this message translates to:
  /// **'Saturated fat'**
  String get infoWhoSheetLimitSaturatedFat;

  /// No description provided for @infoWhoSheetLimitTransFat.
  ///
  /// In en, this message translates to:
  /// **'Trans fat'**
  String get infoWhoSheetLimitTransFat;

  /// No description provided for @infoWhoSheetLimitSugarValue.
  ///
  /// In en, this message translates to:
  /// **'< 50g (10% of calories)'**
  String get infoWhoSheetLimitSugarValue;

  /// No description provided for @infoWhoSheetLimitSaltValue.
  ///
  /// In en, this message translates to:
  /// **'< 2g sodium (< 5g salt)'**
  String get infoWhoSheetLimitSaltValue;

  /// No description provided for @infoWhoSheetLimitSaturatedFatValue.
  ///
  /// In en, this message translates to:
  /// **'< 10% of calories'**
  String get infoWhoSheetLimitSaturatedFatValue;

  /// No description provided for @infoWhoSheetLimitTransFatValue.
  ///
  /// In en, this message translates to:
  /// **'< 1% of calories'**
  String get infoWhoSheetLimitTransFatValue;

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

  /// No description provided for @learnMoreTitle.
  ///
  /// In en, this message translates to:
  /// **'LEARN MORE'**
  String get learnMoreTitle;

  /// No description provided for @learnMoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Trusted guides to help you understand nutrition better.'**
  String get learnMoreSubtitle;

  /// No description provided for @fdaCardTitle.
  ///
  /// In en, this message translates to:
  /// **'How to Read Nutrition Labels'**
  String get fdaCardTitle;

  /// No description provided for @fdaCardSource.
  ///
  /// In en, this message translates to:
  /// **'by FDA'**
  String get fdaCardSource;

  /// No description provided for @whoCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Nutrient Limit Guidelines'**
  String get whoCardTitle;

  /// No description provided for @whoCardSource.
  ///
  /// In en, this message translates to:
  /// **'by WHO'**
  String get whoCardSource;

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
  /// **'App Review'**
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
  /// **'Voice Assistant Settings'**
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

  /// No description provided for @enableVoiceAssistant.
  ///
  /// In en, this message translates to:
  /// **'Enable Voice Assistant'**
  String get enableVoiceAssistant;

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

  /// No description provided for @accountCreatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account created'**
  String get accountCreatedTitle;

  /// No description provided for @accountCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account has been created successfully.'**
  String get accountCreatedMessage;

  /// No description provided for @okayButton.
  ///
  /// In en, this message translates to:
  /// **'Okay'**
  String get okayButton;

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

  /// No description provided for @onboardingBasicInfoIntro.
  ///
  /// In en, this message translates to:
  /// **'Please enter your information to use the app'**
  String get onboardingBasicInfoIntro;

  /// No description provided for @onboardingAgeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your age.'**
  String get onboardingAgeEmpty;

  /// No description provided for @nextButton.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextButton;

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

  /// No description provided for @profileUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdateSuccess;

  /// No description provided for @profileUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Unable to save updates'**
  String get profileUpdateError;

  /// No description provided for @editName.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get editName;

  /// No description provided for @editAge.
  ///
  /// In en, this message translates to:
  /// **'Edit age'**
  String get editAge;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @ageLabel.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get ageLabel;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @healthConditions.
  ///
  /// In en, this message translates to:
  /// **'Health Conditions'**
  String get healthConditions;

  /// No description provided for @allergensLabel.
  ///
  /// In en, this message translates to:
  /// **'Allergens'**
  String get allergensLabel;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountSettings;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @passwordRequirements.
  ///
  /// In en, this message translates to:
  /// **'Your password must be at least six characters with a combination of numbers, letters, and special characters (!@#%)'**
  String get passwordRequirements;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password successfully changed!'**
  String get passwordChanged;

  /// No description provided for @errorCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your current password'**
  String get errorCurrentPassword;

  /// No description provided for @errorNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your new password'**
  String get errorNewPassword;

  /// No description provided for @errorConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your new password'**
  String get errorConfirmPassword;

  /// No description provided for @errorPasswordsNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get errorPasswordsNotMatch;

  /// No description provided for @errorPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get errorPasswordTooShort;

  /// No description provided for @errorNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'User not authenticated'**
  String get errorNotAuthenticated;

  /// No description provided for @errorChangingPassword.
  ///
  /// In en, this message translates to:
  /// **'Error changing password'**
  String get errorChangingPassword;

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred'**
  String get unexpectedError;

  /// No description provided for @selectAllergen.
  ///
  /// In en, this message translates to:
  /// **'Select Allergen'**
  String get selectAllergen;

  /// No description provided for @conditionDiabetes.
  ///
  /// In en, this message translates to:
  /// **'Diabetes'**
  String get conditionDiabetes;

  /// No description provided for @conditionHypertension.
  ///
  /// In en, this message translates to:
  /// **'Hypertension'**
  String get conditionHypertension;

  /// No description provided for @conditionHeartCondition.
  ///
  /// In en, this message translates to:
  /// **'Heart condition'**
  String get conditionHeartCondition;

  /// No description provided for @conditionLowVision.
  ///
  /// In en, this message translates to:
  /// **'Low vision'**
  String get conditionLowVision;

  /// No description provided for @conditionNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get conditionNone;

  /// No description provided for @allergenFish.
  ///
  /// In en, this message translates to:
  /// **'Fish'**
  String get allergenFish;

  /// No description provided for @allergenMilk.
  ///
  /// In en, this message translates to:
  /// **'Milk/Dairy'**
  String get allergenMilk;

  /// No description provided for @allergenEggs.
  ///
  /// In en, this message translates to:
  /// **'Eggs'**
  String get allergenEggs;

  /// No description provided for @allergenSoy.
  ///
  /// In en, this message translates to:
  /// **'Soy'**
  String get allergenSoy;

  /// No description provided for @allergenWheat.
  ///
  /// In en, this message translates to:
  /// **'Wheat'**
  String get allergenWheat;

  /// No description provided for @allergenShellfish.
  ///
  /// In en, this message translates to:
  /// **'Shellfish'**
  String get allergenShellfish;

  /// No description provided for @allergenPeanuts.
  ///
  /// In en, this message translates to:
  /// **'Peanuts'**
  String get allergenPeanuts;

  /// No description provided for @filterConditionTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter ranking by condition'**
  String get filterConditionTitle;

  /// No description provided for @conditionOverall.
  ///
  /// In en, this message translates to:
  /// **'Overall (all conditions)'**
  String get conditionOverall;

  /// No description provided for @filterProductTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Product Type'**
  String get filterProductTypeTitle;

  /// No description provided for @filterFlavorTitle.
  ///
  /// In en, this message translates to:
  /// **'Flavor'**
  String get filterFlavorTitle;

  /// No description provided for @spicyLabel.
  ///
  /// In en, this message translates to:
  /// **'Spicy'**
  String get spicyLabel;

  /// No description provided for @nonSpicyLabel.
  ///
  /// In en, this message translates to:
  /// **'Non-Spicy'**
  String get nonSpicyLabel;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @ratePrompt.
  ///
  /// In en, this message translates to:
  /// **'Please select a rating between 1 and 5.'**
  String get ratePrompt;

  /// No description provided for @suggestionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your suggestion before submitting.'**
  String get suggestionEmpty;

  /// No description provided for @suggestionTooLong.
  ///
  /// In en, this message translates to:
  /// **'Suggestion must be 500 characters or less.'**
  String get suggestionTooLong;

  /// No description provided for @suggestionHint.
  ///
  /// In en, this message translates to:
  /// **'Write your suggestion here...'**
  String get suggestionHint;

  /// No description provided for @clearAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear All?'**
  String get clearAllTitle;

  /// No description provided for @clearAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'All scan history will be deleted. This cannot be undone.'**
  String get clearAllConfirm;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchHint;

  /// No description provided for @tabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get tabAll;

  /// No description provided for @tabFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get tabFavorites;

  /// No description provided for @tabCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get tabCompare;

  /// No description provided for @tabReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get tabReports;

  /// No description provided for @emptyFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorite products yet. Tap ❤️ to save.'**
  String get emptyFavorites;

  /// No description provided for @emptyComparisons.
  ///
  /// In en, this message translates to:
  /// **'No product comparisons yet.'**
  String get emptyComparisons;

  /// No description provided for @noSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String noSearchResults(String query);

  /// No description provided for @emptyHistory.
  ///
  /// In en, this message translates to:
  /// **'No scan history yet. Scan a product to start!'**
  String get emptyHistory;

  /// No description provided for @historyToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get historyToday;

  /// No description provided for @historyYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get historyYesterday;

  /// No description provided for @historyLastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last Week'**
  String get historyLastWeek;

  /// No description provided for @historyLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last Month'**
  String get historyLastMonth;

  /// No description provided for @resultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get resultsTitle;

  /// No description provided for @rankedBySuitability.
  ///
  /// In en, this message translates to:
  /// **'Ranked based on suitability'**
  String get rankedBySuitability;

  /// No description provided for @profileFeatureSoon.
  ///
  /// In en, this message translates to:
  /// **'Profile features coming soon!'**
  String get profileFeatureSoon;

  /// No description provided for @fdaExpiredWarning.
  ///
  /// In en, this message translates to:
  /// **'WARNING: This product has an EXPIRED FDA registration. It may not be safe.'**
  String get fdaExpiredWarning;

  /// No description provided for @fdaUnverifiedWarning.
  ///
  /// In en, this message translates to:
  /// **'This product has not yet been verified by FDA Philippines.'**
  String get fdaUnverifiedWarning;

  /// No description provided for @ageRequirementBadge.
  ///
  /// In en, this message translates to:
  /// **'3+ yrs old'**
  String get ageRequirementBadge;

  /// No description provided for @safeToConsume.
  ///
  /// In en, this message translates to:
  /// **'SAFE TO CONSUME'**
  String get safeToConsume;

  /// No description provided for @safeToConsumeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Best eaten in moderation as it is higher in fat and calories.'**
  String get safeToConsumeSubtitle;

  /// No description provided for @reminderLabel.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminderLabel;

  /// No description provided for @diabetesSafeReminder.
  ///
  /// In en, this message translates to:
  /// **'Suitable for diabetics, but frequent consumption may not be ideal for those controlling cholesterol or calorie intake.'**
  String get diabetesSafeReminder;

  /// No description provided for @containsAllergens.
  ///
  /// In en, this message translates to:
  /// **'Contains {list}'**
  String containsAllergens(String list);

  /// No description provided for @personalHealthWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'🩺 Health Profile Warning'**
  String get personalHealthWarningTitle;

  /// No description provided for @servingRecommendation.
  ///
  /// In en, this message translates to:
  /// **'½–¾ can (90–135g) per meal, up to 2–3 times a week.'**
  String get servingRecommendation;

  /// No description provided for @moreDetailsLink.
  ///
  /// In en, this message translates to:
  /// **'More details'**
  String get moreDetailsLink;

  /// No description provided for @totalNutritionTitle.
  ///
  /// In en, this message translates to:
  /// **'Total Nutrition'**
  String get totalNutritionTitle;

  /// No description provided for @nutritionDataUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Nutrient data unavailable'**
  String get nutritionDataUnavailable;

  /// No description provided for @nutriCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get nutriCalories;

  /// No description provided for @nutriCarbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get nutriCarbs;

  /// No description provided for @nutriSodium.
  ///
  /// In en, this message translates to:
  /// **'Sodium'**
  String get nutriSodium;

  /// No description provided for @nutriSugar.
  ///
  /// In en, this message translates to:
  /// **'Sugar'**
  String get nutriSugar;

  /// No description provided for @nutriProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get nutriProtein;

  /// No description provided for @nutriTotalFat.
  ///
  /// In en, this message translates to:
  /// **'Total Fat'**
  String get nutriTotalFat;

  /// No description provided for @nutriSatFat.
  ///
  /// In en, this message translates to:
  /// **'Sat. Fat'**
  String get nutriSatFat;

  /// No description provided for @nutriTransFat.
  ///
  /// In en, this message translates to:
  /// **'Trans Fat'**
  String get nutriTransFat;

  /// No description provided for @nutriFiber.
  ///
  /// In en, this message translates to:
  /// **'Fiber'**
  String get nutriFiber;

  /// No description provided for @nutriPotassium.
  ///
  /// In en, this message translates to:
  /// **'Potassium'**
  String get nutriPotassium;

  /// No description provided for @nutriCalcium.
  ///
  /// In en, this message translates to:
  /// **'Calcium'**
  String get nutriCalcium;

  /// No description provided for @nutriIron.
  ///
  /// In en, this message translates to:
  /// **'Iron'**
  String get nutriIron;

  /// No description provided for @scoresTitle.
  ///
  /// In en, this message translates to:
  /// **'Scores'**
  String get scoresTitle;

  /// No description provided for @scoreNutrition.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get scoreNutrition;

  /// No description provided for @scoreNutritionDesc.
  ///
  /// In en, this message translates to:
  /// **'Good source of protein but higher in fat and calories.'**
  String get scoreNutritionDesc;

  /// No description provided for @scoreEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get scoreEnvironment;

  /// No description provided for @scoreEnvironmentDesc.
  ///
  /// In en, this message translates to:
  /// **'Moderate environmental impact.'**
  String get scoreEnvironmentDesc;

  /// No description provided for @scoreProcess.
  ///
  /// In en, this message translates to:
  /// **'Process'**
  String get scoreProcess;

  /// No description provided for @scoreProcessDesc.
  ///
  /// In en, this message translates to:
  /// **'Processed food with relatively simple ingredients.'**
  String get scoreProcessDesc;

  /// No description provided for @compareButton.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get compareButton;

  /// No description provided for @similarProductsTitle.
  ///
  /// In en, this message translates to:
  /// **'Product Ranking'**
  String get similarProductsTitle;

  /// No description provided for @productCount.
  ///
  /// In en, this message translates to:
  /// **'{count} products'**
  String productCount(int count);

  /// No description provided for @noProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get noProductsFound;

  /// No description provided for @noSearchMatchDesc.
  ///
  /// In en, this message translates to:
  /// **'No products matched your search.'**
  String get noSearchMatchDesc;

  /// No description provided for @seeMore.
  ///
  /// In en, this message translates to:
  /// **'See More'**
  String get seeMore;

  /// No description provided for @scanGuideText.
  ///
  /// In en, this message translates to:
  /// **'Align product label to scan'**
  String get scanGuideText;

  /// No description provided for @productCapturedBadge.
  ///
  /// In en, this message translates to:
  /// **'Product Captured!'**
  String get productCapturedBadge;

  /// No description provided for @tapToScanHint.
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere to scan'**
  String get tapToScanHint;

  /// No description provided for @productNotRecognizedTitle.
  ///
  /// In en, this message translates to:
  /// **'Product Not Recognized'**
  String get productNotRecognizedTitle;

  /// No description provided for @productNotRecognizedDesc.
  ///
  /// In en, this message translates to:
  /// **'The product could not be identified. Would you like to submit it for review?'**
  String get productNotRecognizedDesc;

  /// No description provided for @tryAgainButton.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgainButton;

  /// No description provided for @submitLabel.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submitLabel;

  /// No description provided for @submitSkuHeader.
  ///
  /// In en, this message translates to:
  /// **'SUBMIT UNKNOWN SKU'**
  String get submitSkuHeader;

  /// No description provided for @trainModelHeadline.
  ///
  /// In en, this message translates to:
  /// **'Help Train Our Model'**
  String get trainModelHeadline;

  /// No description provided for @trainModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If a product isn\'t detected by our camera, upload its photo and info. Our engine uses this data to refine label mapping.'**
  String get trainModelSubtitle;

  /// No description provided for @imageCaptureSuccess.
  ///
  /// In en, this message translates to:
  /// **'Mock product image captured successfully!'**
  String get imageCaptureSuccess;

  /// No description provided for @imageRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Please capture or upload a product label photo first.'**
  String get imageRequiredError;

  /// No description provided for @submissionReceivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Submission Received'**
  String get submissionReceivedTitle;

  /// No description provided for @submissionReceivedDesc.
  ///
  /// In en, this message translates to:
  /// **'Thank you! Our AI team will verify this product label and update the on-device YOLOv8 database model within 24 hours.'**
  String get submissionReceivedDesc;

  /// No description provided for @returnToScanner.
  ///
  /// In en, this message translates to:
  /// **'Return to Scanner'**
  String get returnToScanner;

  /// No description provided for @labelImageAttached.
  ///
  /// In en, this message translates to:
  /// **'Label Image Attached'**
  String get labelImageAttached;

  /// No description provided for @tapToReplace.
  ///
  /// In en, this message translates to:
  /// **'Tap to replace photo'**
  String get tapToReplace;

  /// No description provided for @captureProductLabel.
  ///
  /// In en, this message translates to:
  /// **'Capture Product Label (Front/Rear)'**
  String get captureProductLabel;

  /// No description provided for @ensureReadableNote.
  ///
  /// In en, this message translates to:
  /// **'Ensure text/nutrition facts are readable'**
  String get ensureReadableNote;

  /// No description provided for @productNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Product Name / Description'**
  String get productNameLabel;

  /// No description provided for @productNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter product name'**
  String get productNameEmpty;

  /// No description provided for @brandNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Brand Name (e.g. Century, Ligo, Lucky Me)'**
  String get brandNameLabel;

  /// No description provided for @brandNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter brand name'**
  String get brandNameEmpty;

  /// No description provided for @productVariantLabel.
  ///
  /// In en, this message translates to:
  /// **'Product Variant (e.g. Hot & Spicy, Sweet & Sour)'**
  String get productVariantLabel;

  /// No description provided for @productVariantEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter product variant'**
  String get productVariantEmpty;

  /// No description provided for @productCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Product Category'**
  String get productCategoryLabel;

  /// No description provided for @ingredientsListLabel.
  ///
  /// In en, this message translates to:
  /// **'Ingredients List (Optional)'**
  String get ingredientsListLabel;

  /// No description provided for @submitTrainingButton.
  ///
  /// In en, this message translates to:
  /// **'SUBMIT FOR TRAINING'**
  String get submitTrainingButton;

  /// No description provided for @bestLabelShort.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get bestLabelShort;

  /// No description provided for @worstLabelShort.
  ///
  /// In en, this message translates to:
  /// **'Worst'**
  String get worstLabelShort;

  /// No description provided for @analysisBasisTitle.
  ///
  /// In en, this message translates to:
  /// **'Analysis Basis'**
  String get analysisBasisTitle;

  /// No description provided for @analysisBasisSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Based on WHO daily limit, per 1 serving ({servingSize})'**
  String analysisBasisSubtitle(String servingSize);

  /// No description provided for @bpSodiumLabel.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure - Sodium'**
  String get bpSodiumLabel;

  /// No description provided for @diabetesSugarsLabel.
  ///
  /// In en, this message translates to:
  /// **'Diabetes - Total sugars'**
  String get diabetesSugarsLabel;

  /// No description provided for @heartSatFatLabel.
  ///
  /// In en, this message translates to:
  /// **'Heart disease - Saturated fats'**
  String get heartSatFatLabel;

  /// No description provided for @dailySuffix.
  ///
  /// In en, this message translates to:
  /// **'daily'**
  String get dailySuffix;

  /// No description provided for @ofWhoLimit.
  ///
  /// In en, this message translates to:
  /// **'of WHO limit'**
  String get ofWhoLimit;

  /// No description provided for @allergenDetectedBadge.
  ///
  /// In en, this message translates to:
  /// **'Allergen Detected'**
  String get allergenDetectedBadge;

  /// No description provided for @allergenWarningNote.
  ///
  /// In en, this message translates to:
  /// **'Automatically alerts if this is your saved allergen.'**
  String get allergenWarningNote;

  /// No description provided for @suitableLegend.
  ///
  /// In en, this message translates to:
  /// **'Suitable ≤5%'**
  String get suitableLegend;

  /// No description provided for @moderateLegend.
  ///
  /// In en, this message translates to:
  /// **'Moderate 6-20%'**
  String get moderateLegend;

  /// No description provided for @cautionLegend.
  ///
  /// In en, this message translates to:
  /// **'Caution >20%'**
  String get cautionLegend;

  /// No description provided for @forMoreDetails.
  ///
  /// In en, this message translates to:
  /// **'For more details'**
  String get forMoreDetails;

  /// No description provided for @moreDetailsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'More Details'**
  String get moreDetailsScreenTitle;

  /// No description provided for @ingredientsTitle.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get ingredientsTitle;

  /// No description provided for @containsAllergenPrefix.
  ///
  /// In en, this message translates to:
  /// **'Contains {allergen} - allergen'**
  String containsAllergenPrefix(String allergen);

  /// No description provided for @storageTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage Method'**
  String get storageTitle;

  /// No description provided for @storageTipCool.
  ///
  /// In en, this message translates to:
  /// **'Store in a cool and dry place before opening.'**
  String get storageTipCool;

  /// No description provided for @storageTipRefrigerate.
  ///
  /// In en, this message translates to:
  /// **'Transfer to a sealed container and refrigerate once opened.'**
  String get storageTipRefrigerate;

  /// No description provided for @storageTipConsume.
  ///
  /// In en, this message translates to:
  /// **'Consume within 2-3 days after opening.'**
  String get storageTipConsume;

  /// No description provided for @notFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'No product found'**
  String get notFoundTitle;

  /// No description provided for @notFoundBody.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t identify this product.'**
  String get notFoundBody;

  /// No description provided for @notFoundHint.
  ///
  /// In en, this message translates to:
  /// **'You can scan again or report this product.'**
  String get notFoundHint;

  /// No description provided for @scanAgainButton.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get scanAgainButton;

  /// No description provided for @reportProductButton.
  ///
  /// In en, this message translates to:
  /// **'Report the product'**
  String get reportProductButton;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report unidentified product'**
  String get reportTitle;

  /// No description provided for @reportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can help us by providing details about this product.'**
  String get reportSubtitle;

  /// No description provided for @reportProductPhoto.
  ///
  /// In en, this message translates to:
  /// **'Product Photo'**
  String get reportProductPhoto;

  /// No description provided for @reportFrontPhoto.
  ///
  /// In en, this message translates to:
  /// **'Front Photo'**
  String get reportFrontPhoto;

  /// No description provided for @reportBackPhoto.
  ///
  /// In en, this message translates to:
  /// **'Back Photo (Nutrition Label)'**
  String get reportBackPhoto;

  /// No description provided for @reportBackPhotoHint.
  ///
  /// In en, this message translates to:
  /// **'Take a clear photo of the nutrition facts and ingredients list on the back of the package.'**
  String get reportBackPhotoHint;

  /// No description provided for @reportAddBackPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add Photo'**
  String get reportAddBackPhoto;

  /// No description provided for @reportBackPhotoRequired.
  ///
  /// In en, this message translates to:
  /// **'Please add a photo of the back label before submitting.'**
  String get reportBackPhotoRequired;

  /// No description provided for @reportChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change Photo'**
  String get reportChangePhoto;

  /// No description provided for @reportProductName.
  ///
  /// In en, this message translates to:
  /// **'Product Name'**
  String get reportProductName;

  /// No description provided for @reportAdditionalBackPhotos.
  ///
  /// In en, this message translates to:
  /// **'Additional Back Photos (Optional)'**
  String get reportAdditionalBackPhotos;

  /// No description provided for @reportAdditionalBackPhotosHint.
  ///
  /// In en, this message translates to:
  /// **'Add more photos of the back label if needed (ingredients, nutrition facts, etc.)'**
  String get reportAdditionalBackPhotosHint;

  /// No description provided for @reportAddAnotherBackPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add Another Back Photo'**
  String get reportAddAnotherBackPhoto;

  /// No description provided for @reportProductNameHint.
  ///
  /// In en, this message translates to:
  /// **'Kindly state the brand, name, and flavor (eg. Purefoods Corned Beef).'**
  String get reportProductNameHint;

  /// No description provided for @reportProductNameFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Enter product name'**
  String get reportProductNameFieldHint;

  /// No description provided for @reportProductDescription.
  ///
  /// In en, this message translates to:
  /// **'Product Description'**
  String get reportProductDescription;

  /// No description provided for @reportEditButton.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get reportEditButton;

  /// No description provided for @reportInfoNote.
  ///
  /// In en, this message translates to:
  /// **'Your report will help us add more products and provide better information for everyone.'**
  String get reportInfoNote;

  /// No description provided for @reportSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get reportSubmitButton;

  /// No description provided for @reportSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Report sent!'**
  String get reportSuccessTitle;

  /// No description provided for @reportSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Thank you! Your report has been successfully submitted.'**
  String get reportSuccessBody;

  /// No description provided for @reportGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go back to Home'**
  String get reportGoHome;
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