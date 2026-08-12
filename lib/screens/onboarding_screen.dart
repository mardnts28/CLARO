import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import '../services/locale_service.dart';
import '../services/voice_assistant_service.dart';
import '../widgets/date_of_birth_picker.dart';
import 'home_screen.dart';

/// NOTE ON LANGUAGE: this screen's user-facing text now follows the
/// app-wide selected language (see LoginScreen's header comment for
/// background on why this changed for the auth/onboarding screens).
///
/// NOTE ON FLOW: this screen used to be a 3-page PageView (Basic Info →
/// Get Started → Health Profile) shown after login. "Get Started" has
/// since moved to its own standalone screen (GetStartedScreen) earlier
/// in the flow -- right after language selection and before Login/Sign
/// Up -- so this is now a 2-page flow: Basic Info → Health Profile.
///
/// IMPORTANT: the keys in _conditions / _allergens (e.g. 'Diabetes',
/// 'Alta-presyon', 'Isda') are NOT just UI labels -- they are the exact
/// values written to Firestore in saveOnboardingData() and read back by
/// the backend's health-advisory pipeline (see
/// firestore_label_mappings.dart, referenced from product_detail_screen
/// .dart). Renaming these keys would silently break condition/allergen
/// matching for any user who already completed onboarding under the old
/// keys. So those internal keys are left untouched; only the on-screen
/// *display* text is localized, via the _conditionDisplay*/
/// _allergenDisplay* maps below, which are purely cosmetic and never
/// written anywhere.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final _nameController = TextEditingController();
  String? _nameError;
  DateTime? _selectedDateOfBirth;
  final _authService = AuthService();
  int _currentPage = 0;
  bool _isLoading = false;

  static const _red = Color(0xFF8B1A1A);
  static const _lightRed = Color(0xFFFDF0F0);

  // Internal storage keys -- DO NOT translate these, see class doc above.
  final Map<String, bool> _conditions = {
    'Diabetes': false,
    'Alta-presyon': false,
    'Sakit sa puso': false,
    'Mababang Paningin': false,
    'Wala': false,
  };

  final Map<String, bool> _allergens = {
    'Isda': false,
    'Gatas': false,
    'Itlog': false,
    'Soya': false,
    'Trigo': false,
    'Lamang-Dagat': false,
    'Mani': false,
  };

  final Map<String, String> _conditionIcons = {
    'Diabetes': 'assets/images/diabetes.png',
    'Alta-presyon': 'assets/images/presyon.png',
    'Sakit sa puso': 'assets/images/puso.png',
    'Mababang Paningin': '',
    'Wala': '',
  };

  final Map<String, String> _allergenIcons = {
    'Isda': 'assets/images/isda.png',
    'Gatas': 'assets/images/gatas.png',
    'Itlog': 'assets/images/itlog.png',
    'Soya': 'assets/images/toyo.png',
    'Trigo': 'assets/images/trigo.png',
    'Lamang-Dagat': 'assets/images/lamang-dagat.png',
    'Mani': 'assets/images/mani.png',
  };

  // Cosmetic-only display labels for the internal keys above, built from
  // AppLocalizations so they follow the selected language -- the keys
  // themselves keep going to Firestore unchanged (see class doc above).
  Map<String, String> _conditionDisplay(AppLocalizations loc) => {
    'Diabetes': loc.conditionDiabetes,
    'Alta-presyon': loc.conditionHypertension,
    'Sakit sa puso': loc.conditionHeartCondition,
    'Mababang Paningin': loc.conditionLowVision,
    'Wala': loc.conditionNone,
  };

  Map<String, String> _allergenDisplay(AppLocalizations loc) => {
    'Isda': loc.allergenFish,
    'Gatas': loc.allergenMilk,
    'Itlog': loc.allergenEggs,
    'Soya': loc.allergenSoy,
    'Trigo': loc.allergenWheat,
    'Lamang-Dagat': loc.allergenShellfish,
    'Mani': loc.allergenPeanuts,
  };

  @override
  void initState() {
    super.initState();
    // Listen for language changes to refresh the UI with localized labels
    LocaleService.localeNotifier.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() {
    if (mounted) {
      setState(() {}); // Force rebuild to update localized labels
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    LocaleService.localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _previousPage() {
    HapticService().vibrate();
    FocusScope.of(context).unfocus();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _nextPage() async {
    HapticService().vibrate();
    final loc = AppLocalizations.of(context)!;
    if (_currentPage < 1) {
      // Validate name
      if (_nameController.text.trim().isEmpty) {
        setState(() {
          _nameError = loc.onboardingNameEmpty;
        });
        return;
      } else {
        if (_nameError != null) {
          setState(() {
            _nameError = null;
          });
        }
      }

      // Validate date of birth
      if (_selectedDateOfBirth == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.invalidDateOfBirth)),
        );
        return;
      }

      // Dismiss keyboard/focus before moving to the next page -- Basic
      // Info has text fields but Health Profile doesn't, so carrying
      // focus over serves no purpose and risks the same kind of overflow
      // issue fixed on the Login → Get Started transition.
      FocusScope.of(context).unfocus();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Validate name
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.onboardingNameEmpty)),
        );
        return;
      }

      // Validate date of birth
      if (_selectedDateOfBirth == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.invalidDateOfBirth)),
        );
        return;
      }

      // Calculate age from DOB
      final now = DateTime.now();
      int age = now.year - _selectedDateOfBirth!.year;
      // Adjust if birthday hasn't occurred yet this year
      if (now.month < _selectedDateOfBirth!.month ||
          (now.month == _selectedDateOfBirth!.month && now.day < _selectedDateOfBirth!.day)) {
        age--;
      }
      final ageString = age.toString();

      setState(() => _isLoading = true);

      final selectedConditions = _conditions.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      final selectedAllergens = _allergens.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      try {
        await _authService.saveOnboardingData(
          name: _nameController.text.trim(),
          age: ageString,
          dateOfBirth: _selectedDateOfBirth,
          conditions: selectedConditions,
          allergens: selectedAllergens,
        );

        if (selectedConditions.contains('Mababang Paningin')) {
          await VoiceAssistantService.instance.updateEnabled(true);
        }

        if (!mounted) return;
        FocusScope.of(context).unfocus();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }

      setState(() => _isLoading = false);
    }
  }

  void _toggleCondition(String key) {
    HapticService().vibrate();
    setState(() {
      if (key == 'Wala') {
        _conditions.forEach((k, v) => _conditions[k] = false);
        _conditions['Wala'] = true;
      } else {
        _conditions['Wala'] = false;
        _conditions[key] = !_conditions[key]!;
      }
    });
  }

  void _toggleAllergen(String key) {
    HapticService().vibrate();
    setState(() {
      _allergens[key] = !_allergens[key]!;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Force Light Mode for Onboarding Screen
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF8B1A1A),
        scaffoldBackgroundColor: const Color(0xFFF5F0EE),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF8B1A1A),
          onPrimary: Colors.white,
          secondary: Color(0xFFD32F2F),
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF1A1A1A),
          error: Colors.redAccent,
          onError: Colors.white,
          surfaceContainerHighest: Color(0xFFE0E0E0),
          outlineVariant: Color(0xFFBDBDBD),
          onSurfaceVariant: Color(0xFF757575),
        ),
        useMaterial3: true,
      ),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final loc = AppLocalizations.of(context)!;
          return PopScope(
            canPop: _currentPage == 0,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              if (_currentPage > 0) {
                _previousPage();
              }
            },
            child: Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              body: SafeArea(
                child: PageView(
                  controller: _pageController,
                  physics: _currentPage == 0
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _buildPage1(theme, loc),
                    _buildPage2(theme, loc),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPage1(ThemeData theme, AppLocalizations loc) {
    final colorScheme = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        children: [
          const SizedBox(height: 40),
          _buildLogo(theme),
          const SizedBox(height: 32),
          Text(
            loc.onboardingBasicInfoIntro,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: colorScheme.onSurface, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          Semantics(
            hint: _nameError != null ? 'Error: $_nameError' : null,
            child: TextField(
              controller: _nameController,
              onChanged: (val) {
                if (_nameError != null && val.trim().isNotEmpty) {
                  setState(() {
                    _nameError = null;
                  });
                }
              },
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: loc.onboardingNameHint,
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
                prefixIcon: Icon(Icons.person_outline, color: colorScheme.onSurfaceVariant, size: 20),
                errorText: _nameError,
                errorMaxLines: 2,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colorScheme.primary),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colorScheme.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colorScheme.error, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          DateOfBirthPicker(
            initialDate: _selectedDateOfBirth,
            requireAdult: true,
            onDateChanged: (date) {
              setState(() {
                _selectedDateOfBirth = date;
              });
            },
          ),
          const SizedBox(height: 32),
          _buildButton(
            loc.nextButton,
            _nextPage,
            theme,
            checkValidation: true,
            isFormValid: isBasicInfoValid,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPage2(ThemeData theme, AppLocalizations loc) {
    final colorScheme = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  color: colorScheme.primary,
                  onPressed: _previousPage,
                  tooltip: 'Back',
                ),
              ),
              _buildLogo(theme),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            loc.onboardingInstructions,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurface, height: 1.5),
          ),
          const SizedBox(height: 20),
          _buildSelectionCard(
            icon: Icons.favorite_border,
            title: loc.conditionsQuestion,
            subtitle: loc.chooseAllThatApply,
            note: loc.profileChangeNote,
            noteIcon: Icons.info_outline,
            child: _buildConditionsGrid(theme, loc),
          ),
          const SizedBox(height: 16),
          _buildSelectionCard(
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFB45309),
            title: loc.allergensQuestion,
            subtitle: loc.chooseAllThatApply,
            child: _buildAllergensGrid(theme, loc),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withAlpha(80),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: colorScheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.safetyPriorityTitle,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colorScheme.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loc.safetyPriorityMessage,
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurface, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildButton(
            loc.getStarted,
            _nextPage,
            theme,
            checkValidation: true,
            isFormValid: _isFormValid,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '...',
              style: TextStyle(
                  color: colorScheme.outlineVariant,
                  fontSize: 18,
                  letterSpacing: 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionsGrid(ThemeData theme, AppLocalizations loc) {
    final display = _conditionDisplay(loc);
    final keys = _conditions.keys.toList();
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 0.85,
      children: keys.map((key) {
        final selected = _conditions[key]!;
        final isWala = key == 'Wala';
        return GestureDetector(
          onTap: () => _toggleCondition(key),
          child: _buildToggleItem(
            label: display[key] ?? key,
            selected: selected,
            isWala: isWala,
            imagePath: isWala ? null : _conditionIcons[key],
            theme: theme,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAllergensGrid(ThemeData theme, AppLocalizations loc) {
    final display = _allergenDisplay(loc);
    final keys = _allergens.keys.toList();
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 0.85,
      children: keys.map((key) {
        final selected = _allergens[key]!;
        return GestureDetector(
          onTap: () => _toggleAllergen(key),
          child: _buildToggleItem(
            label: display[key] ?? key,
            selected: selected,
            imagePath: _allergenIcons[key],
            theme: theme,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildToggleItem({
    required String label,
    required bool selected,
    bool isWala = false,
    String? imagePath,
    required ThemeData theme,
  }) {
    final colorScheme = theme.colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? colorScheme.surfaceContainerHighest : theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isWala)
                  Icon(Icons.block, color: colorScheme.onSurfaceVariant, size: 28)
                else if (imagePath != null)
                  Image.asset(
                    imagePath,
                    height: 32,
                    width: 32,
                    errorBuilder: (_, __, ___) => Icon(
                        Icons.image_not_supported,
                        size: 28,
                        color: colorScheme.onSurfaceVariant),
                  )
                else
                  const SizedBox(height: 32),
                const SizedBox(height: 4),
                // Allow text wrapping for longer labels like "Mababang Paningin"
                // while keeping consistent font size across all options
                // softWrap ensures words wrap at word boundaries, not character boundaries
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 10,
                      color: selected ? colorScheme.primary : colorScheme.onSurface,
                      fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                    color: colorScheme.primary, shape: BoxShape.circle),
                child:
                const Icon(Icons.check, size: 10, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard({
    required IconData icon,
    Color? iconColor,
    required String title,
    required String subtitle,
    String? note,
    IconData? noteIcon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveIconColor = iconColor ?? colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: effectiveIconColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13, color: colorScheme.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.85))),
          const SizedBox(height: 12),
          child,
          if (note != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(noteIcon, size: 14, color: colorScheme.onSurface.withValues(alpha: 0.85)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(note,
                      style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.85))),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogo(ThemeData theme) {
    return Column(
      children: [
        Image.asset(
          'assets/images/logo.png',
          height: 80,
          cacheHeight: (80 * MediaQuery.devicePixelRatioOf(context)).round(),
        ),
        const SizedBox(height: 6),
        Text(
          'CLARO',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }

  bool isBasicInfoValid() {
    final hasName = _nameController.text.trim().isNotEmpty;
    final hasDob = _selectedDateOfBirth != null;
    return hasName && hasDob;
  }

  bool _isFormValid() {
    // At least one health condition must be selected
    final hasCondition = _conditions.values.any((selected) => selected);
    return hasCondition;
  }

  Widget _buildButton(
    String label,
    VoidCallback onTap,
    ThemeData theme, {
    bool checkValidation = false,
    bool Function()? isFormValid,
  }) {
    final colorScheme = theme.colorScheme;
    final enabledChecker = isFormValid ?? _isFormValid;
    final isButtonEnabled = checkValidation ? (enabledChecker() && !_isLoading) : !_isLoading;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isButtonEnabled ? colorScheme.primary : colorScheme.outlineVariant,
          foregroundColor: isButtonEnabled ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: isButtonEnabled ? onTap : null,
        child: _isLoading
            ? SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
              color: colorScheme.onPrimary, strokeWidth: 2),
        )
            : Text(
          label,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}