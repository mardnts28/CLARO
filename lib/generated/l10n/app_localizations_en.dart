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
  String get infoFdaTitle => 'Read the label';

  @override
  String get infoFdaSubtitle => 'FDA guide';

  @override
  String get infoWhoTitle => 'Daily limit';

  @override
  String get infoWhoSubtitle => 'WHO guide';

  @override
  String get infoFdaSheetHeading => 'How to read the nutrition label';

  @override
  String get infoFdaSheetSubtitle => 'Based on FDA guidance (fda.gov)';

  @override
  String get infoFdaSheetStep1 =>
      'Check serving size and servings per package. All nutrient amounts on the label are based on this, not the whole package.';

  @override
  String get infoFdaSheetStep2 =>
      'Review calories. 2,000 calories per day is a general guide, but your needs may vary by age, sex, and activity level.';

  @override
  String get infoFdaSheetStep3 =>
      'Use % Daily Value (%DV): 5% or less is considered low; 20% or more is considered high.';

  @override
  String get infoWhoSheetHeading => 'Daily nutrient limits';

  @override
  String get infoWhoSheetSubtitle =>
      'Based on WHO guidance for a 2,000 kcal diet';

  @override
  String get infoWhoSheetLimitSugar => 'Sugar (free sugars)';

  @override
  String get infoWhoSheetLimitSalt => 'Salt (sodium)';

  @override
  String get infoWhoSheetLimitSaturatedFat => 'Saturated fat';

  @override
  String get infoWhoSheetLimitTransFat => 'Trans fat';

  @override
  String get infoWhoSheetLimitSugarValue => '< 50g (10% of calories)';

  @override
  String get infoWhoSheetLimitSaltValue => '< 2g sodium (< 5g salt)';

  @override
  String get infoWhoSheetLimitSaturatedFatValue => '< 10% of calories';

  @override
  String get infoWhoSheetLimitTransFatValue => '< 1% of calories';

  @override
  String get labelIntroTitle => 'Understand your labels';

  @override
  String get labelIntroSubtitle =>
      'With CLARO, it’s easier to read labels and choose healthier options.';

  @override
  String get learnMoreTitle => 'LEARN MORE';

  @override
  String get learnMoreSubtitle =>
      'Trusted guides to help you understand nutrition better.';

  @override
  String get fdaCardTitle => 'How to Read Nutrition Labels';

  @override
  String get fdaCardSource => 'by FDA';

  @override
  String get whoCardTitle => 'Daily Nutrient Limit Guidelines';

  @override
  String get whoCardSource => 'by WHO';

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
  String get suggestion => 'App Review';

  @override
  String get aboutClaro => 'About CLARO';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsConditions => 'Terms & Conditions';

  @override
  String get userGuide => 'User Guide';

  @override
  String get productName => 'Product Name';

  @override
  String get category => 'Category';

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
  String get accountCreatedTitle => 'Account created';

  @override
  String get accountCreatedMessage =>
      'Your account has been created successfully.';

  @override
  String get okayButton => 'Okay';

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
  String get onboardingBasicInfoIntro =>
      'Please enter your information to use the app';

  @override
  String get onboardingAgeEmpty => 'Please enter your age.';

  @override
  String get nextButton => 'Next';

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
  String get getStartedTagline => 'Clear. Local. Trusted.';

  @override
  String get getStartedSubtitle => 'Your AI helper for healthier shopping.';

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

  @override
  String get profileUpdateSuccess => 'Profile updated';

  @override
  String get profileUpdateError => 'Unable to save updates';

  @override
  String get editName => 'Edit name';

  @override
  String get editAge => 'Edit age';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get ageLabel => 'Age';

  @override
  String get none => 'None';

  @override
  String get healthConditions => 'Health Conditions';

  @override
  String get allergensLabel => 'Allergens';

  @override
  String get accountSettings => 'Account Settings';

  @override
  String get changePassword => 'Change password';

  @override
  String get currentPassword => 'Current Password';

  @override
  String get newPassword => 'New Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get passwordRequirements =>
      'Your password must be at least six characters with a combination of numbers, letters, and special characters (!@#%)';

  @override
  String get passwordChanged => 'Password successfully changed!';

  @override
  String get errorCurrentPassword => 'Please enter your current password';

  @override
  String get errorNewPassword => 'Please enter your new password';

  @override
  String get errorConfirmPassword => 'Please confirm your new password';

  @override
  String get errorPasswordsNotMatch => 'Passwords do not match';

  @override
  String get errorPasswordTooShort => 'Password must be at least 8 characters';

  @override
  String get errorPasswordUppercase =>
      'Password must contain at least one uppercase letter';

  @override
  String get errorPasswordLowercase =>
      'Password must contain at least one lowercase letter';

  @override
  String get errorPasswordNumber => 'Password must contain at least one number';

  @override
  String get errorPasswordSpecial =>
      'Password must contain at least one special character';

  @override
  String get errorNotAuthenticated => 'User not authenticated';

  @override
  String get errorChangingPassword => 'Error changing password';

  @override
  String get unexpectedError => 'An unexpected error occurred';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get invalidEmail => 'Please enter a valid email address';

  @override
  String get validEmailHint => 'A valid email address (e.g. name@example.com)';

  @override
  String get selectAllergen => 'Select Allergen';

  @override
  String get conditionDiabetes => 'Diabetes';

  @override
  String get conditionHypertension => 'Hypertension';

  @override
  String get conditionHeartCondition => 'Heart condition';

  @override
  String get conditionLowVision => 'Low vision';

  @override
  String get conditionNone => 'None';

  @override
  String get allergenFish => 'Fish';

  @override
  String get allergenMilk => 'Milk/Dairy';

  @override
  String get allergenEggs => 'Eggs';

  @override
  String get allergenSoy => 'Soy';

  @override
  String get allergenWheat => 'Wheat';

  @override
  String get allergenShellfish => 'Shellfish';

  @override
  String get allergenPeanuts => 'Peanuts';

  @override
  String get filterConditionTitle => 'Filter ranking by condition';

  @override
  String get conditionOverall => 'Overall (all conditions)';

  @override
  String get filterProductTypeTitle => 'Product Type';

  @override
  String get filterFlavorTitle => 'Flavor';

  @override
  String get spicyLabel => 'Spicy';

  @override
  String get nonSpicyLabel => 'Non-Spicy';

  @override
  String get apply => 'Apply';

  @override
  String get ratePrompt => 'Please select a rating between 1 and 5.';

  @override
  String get suggestionEmpty =>
      'Please enter your suggestion before submitting.';

  @override
  String get suggestionTooLong => 'Suggestion must be 500 characters or less.';

  @override
  String get suggestionHint => 'Write your suggestion here...';

  @override
  String get clearAllTitle => 'Clear All?';

  @override
  String get clearAllConfirm =>
      'All scan history will be deleted. This cannot be undone.';

  @override
  String get clear => 'Clear';

  @override
  String get clearAll => 'Clear All';

  @override
  String get searchHint => 'Search';

  @override
  String get tabAll => 'All';

  @override
  String get tabFavorites => 'Favorites';

  @override
  String get tabCompare => 'Compare';

  @override
  String get tabReports => 'Reports';

  @override
  String get emptyFavorites => 'No favorite products yet. Tap ❤️ to save.';

  @override
  String get emptyComparisons => 'No product comparisons yet.';

  @override
  String noSearchResults(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get emptyHistory => 'No scan history yet. Scan a product to start!';

  @override
  String get historyToday => 'Today';

  @override
  String get historyYesterday => 'Yesterday';

  @override
  String get historyLastWeek => 'Last Week';

  @override
  String get historyLastMonth => 'Last Month';

  @override
  String get resultsTitle => 'Results';

  @override
  String get rankedBySuitability => 'Ranked based on suitability';

  @override
  String get profileFeatureSoon => 'Profile features coming soon!';

  @override
  String get fdaExpiredWarning =>
      'WARNING: This product has an EXPIRED FDA registration. It may not be safe.';

  @override
  String get fdaUnverifiedWarning =>
      'This product has not yet been verified by FDA Philippines.';

  @override
  String get ageRequirementBadge => '3+ yrs old';

  @override
  String get safeToConsume => 'SAFE TO CONSUME';

  @override
  String get safeToConsumeSubtitle =>
      'Best eaten in moderation as it is higher in fat and calories.';

  @override
  String get reminderLabel => 'Reminder';

  @override
  String get diabetesSafeReminder =>
      'Suitable for diabetics, but frequent consumption may not be ideal for those controlling cholesterol or calorie intake.';

  @override
  String containsAllergens(String list) {
    return 'Contains $list';
  }

  @override
  String get personalHealthWarningTitle => '🩺 Health Profile Warning';

  @override
  String get servingRecommendation =>
      '½–¾ can (90–135g) per meal, up to 2–3 times a week.';

  @override
  String get moreDetailsLink => 'More details';

  @override
  String get totalNutritionTitle => 'Total Nutrition';

  @override
  String get nutritionDataUnavailable => 'Nutrient data unavailable';

  @override
  String get nutriCalories => 'Calories';

  @override
  String get nutriCarbs => 'Carbs';

  @override
  String get nutriSodium => 'Sodium';

  @override
  String get nutriSugar => 'Sugar';

  @override
  String get nutriProtein => 'Protein';

  @override
  String get nutriTotalFat => 'Total Fat';

  @override
  String get nutriSatFat => 'Sat. Fat';

  @override
  String get nutriTransFat => 'Trans Fat';

  @override
  String get nutriFiber => 'Fiber';

  @override
  String get nutriPotassium => 'Potassium';

  @override
  String get nutriCalcium => 'Calcium';

  @override
  String get nutriIron => 'Iron';

  @override
  String get scoresTitle => 'Scores';

  @override
  String get scoreNutrition => 'Nutrition';

  @override
  String get scoreNutritionDesc =>
      'Good source of protein but higher in fat and calories.';

  @override
  String get scoreEnvironment => 'Environment';

  @override
  String get scoreEnvironmentDesc => 'Moderate environmental impact.';

  @override
  String get scoreProcess => 'Process';

  @override
  String get scoreProcessDesc =>
      'Processed food with relatively simple ingredients.';

  @override
  String get compareButton => 'Compare';

  @override
  String get similarProductsTitle => 'Product Ranking';

  @override
  String productCount(int count) {
    return '$count products';
  }

  @override
  String get noProductsFound => 'No products found';

  @override
  String get noSearchMatchDesc => 'No products matched your search.';

  @override
  String get seeMore => 'See More';

  @override
  String get scanGuideText => 'Align product label to scan';

  @override
  String get productCapturedBadge => 'Product Captured!';

  @override
  String get tapToScanHint => 'Tap anywhere to scan';

  @override
  String get productNotRecognizedTitle => 'Product Not Recognized';

  @override
  String get productNotRecognizedDesc =>
      'The product could not be identified. Would you like to submit it for review?';

  @override
  String get tryAgainButton => 'Try Again';

  @override
  String get submitLabel => 'Submit';

  @override
  String get submitSkuHeader => 'SUBMIT UNKNOWN SKU';

  @override
  String get trainModelHeadline => 'Help Train Our Model';

  @override
  String get trainModelSubtitle =>
      'If a product isn\'t detected by our camera, upload its photo and info. Our engine uses this data to refine label mapping.';

  @override
  String get imageCaptureSuccess => 'Mock product image captured successfully!';

  @override
  String get imageRequiredError =>
      'Please capture or upload a product label photo first.';

  @override
  String get submissionReceivedTitle => 'Submission Received';

  @override
  String get submissionReceivedDesc =>
      'Thank you! Our AI team will verify this product label and update the on-device YOLOv8 database model within 24 hours.';

  @override
  String get returnToScanner => 'Return to Scanner';

  @override
  String get labelImageAttached => 'Label Image Attached';

  @override
  String get tapToReplace => 'Tap to replace photo';

  @override
  String get captureProductLabel => 'Capture Product Label (Front/Rear)';

  @override
  String get ensureReadableNote => 'Ensure text/nutrition facts are readable';

  @override
  String get productNameLabel => 'Product Name / Description';

  @override
  String get productNameEmpty => 'Please enter product name';

  @override
  String get brandNameLabel => 'Brand Name (e.g. Century, Ligo, Lucky Me)';

  @override
  String get brandNameEmpty => 'Please enter brand name';

  @override
  String get productVariantLabel =>
      'Product Variant (e.g. Hot & Spicy, Sweet & Sour)';

  @override
  String get productVariantEmpty => 'Please enter product variant';

  @override
  String get productCategoryLabel => 'Product Category';

  @override
  String get ingredientsListLabel => 'Ingredients List (Optional)';

  @override
  String get submitTrainingButton => 'SUBMIT FOR TRAINING';

  @override
  String get bestLabelShort => 'Best';

  @override
  String get worstLabelShort => 'Worst';

  @override
  String get analysisBasisTitle => 'Analysis Basis';

  @override
  String analysisBasisSubtitle(String servingSize) {
    return 'Based on WHO daily limit, per 1 serving ($servingSize)';
  }

  @override
  String get bpSodiumLabel => 'Blood pressure - Sodium';

  @override
  String get diabetesSugarsLabel => 'Diabetes - Total sugars';

  @override
  String get heartSatFatLabel => 'Heart disease - Saturated fats';

  @override
  String get dailySuffix => 'daily';

  @override
  String get ofWhoLimit => 'of WHO limit';

  @override
  String get allergenDetectedBadge => 'Allergen Detected';

  @override
  String get allergenWarningNote =>
      'Automatically alerts if this is your saved allergen.';

  @override
  String get suitableLegend => 'Suitable ≤5%';

  @override
  String get moderateLegend => 'Moderate 6-20%';

  @override
  String get cautionLegend => 'Caution >20%';

  @override
  String get howToUnderstandTitle => 'How to understand:';

  @override
  String get legendSuitableDesc => 'Low impact on health risk.';

  @override
  String get legendModerateDesc => 'Consume in moderation.';

  @override
  String get legendCautionDesc => 'High impact on health risk. Limit intake.';

  @override
  String get forMoreDetails => 'For more details';

  @override
  String get moreDetailsScreenTitle => 'More Details';

  @override
  String get ingredientsTitle => 'Ingredients';

  @override
  String containsAllergenPrefix(String allergen) {
    return 'Contains $allergen - allergen';
  }

  @override
  String get storageTitle => 'Storage Method';

  @override
  String get storageTipCool => 'Store in a cool and dry place before opening.';

  @override
  String get storageTipRefrigerate =>
      'Transfer to a sealed container and refrigerate once opened.';

  @override
  String get storageTipConsume => 'Consume within 2-3 days after opening.';

  @override
  String get notFoundTitle => 'No product found';

  @override
  String get notFoundBody => 'We couldn\'t identify this product.';

  @override
  String get notFoundHint => 'You can scan again or report this product.';

  @override
  String get scanAgainButton => 'Scan again';

  @override
  String get reportProductButton => 'Report the product';

  @override
  String get reportTitle => 'Report unidentified product';

  @override
  String get reportSubtitle =>
      'You can help us by providing details about this product.';

  @override
  String get reportProductPhoto => 'Product Photo';

  @override
  String get reportFrontPhoto => 'Front Photo';

  @override
  String get reportBackPhoto => 'Back Photo (Nutrition Label)';

  @override
  String get reportBackPhotoHint =>
      'Take a clear photo of the nutrition facts and ingredients list on the back of the package.';

  @override
  String get reportAddBackPhoto => 'Add Photo';

  @override
  String get reportBackPhotoRequired =>
      'Please add a photo of the back label before submitting.';

  @override
  String get reportChangePhoto => 'Change Photo';

  @override
  String get reportProductName => 'Product Name';

  @override
  String get reportAdditionalBackPhotos => 'Additional Back Photos (Optional)';

  @override
  String get reportAdditionalBackPhotosHint =>
      'Add more photos of the back label if needed (ingredients, nutrition facts, etc.)';

  @override
  String get reportAddAnotherBackPhoto => 'Add Another Back Photo';

  @override
  String get reportProductNameHint =>
      'Kindly state the brand, name, and flavor (eg. Purefoods Corned Beef).';

  @override
  String get reportProductNameFieldHint => 'Enter product name';

  @override
  String get reportProductDescription => 'Product Description';

  @override
  String get reportEditButton => 'Edit';

  @override
  String get reportInfoNote =>
      'Your report will help us add more products and provide better information for everyone.';

  @override
  String get reportSubmitButton => 'Submit';

  @override
  String get reportSuccessTitle => 'Report sent!';

  @override
  String get reportSuccessBody =>
      'Thank you! Your report has been successfully submitted.';

  @override
  String get reportGoHome => 'Go back to Home';

  @override
  String get dateOfBirth => 'Date of Birth';

  @override
  String get january => 'January';

  @override
  String get february => 'February';

  @override
  String get march => 'March';

  @override
  String get april => 'April';

  @override
  String get may => 'May';

  @override
  String get june => 'June';

  @override
  String get july => 'July';

  @override
  String get august => 'August';

  @override
  String get september => 'September';

  @override
  String get october => 'October';

  @override
  String get november => 'November';

  @override
  String get december => 'December';

  @override
  String get invalidDateOfBirth => 'Please select a valid date of birth';

  @override
  String get under18Error =>
      'You must be at least 18 years old to use this app';

  @override
  String get enterDigitCode => 'Enter 6-digit code';

  @override
  String get pleaseEnterProductName => 'Please enter a product name';
}
