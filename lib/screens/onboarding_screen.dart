import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _authService = AuthService();
  int _currentPage = 0;
  bool _isLoading = false;

  static const _red = Color(0xFF8B1A1A);
  static const _lightRed = Color(0xFFFDF0F0);

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

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _nextPage() async {
    HapticService().vibrate();
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Validate name
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pakisulat ang iyong pangalan')),
        );
        return;
      }

      // Validate age
      if (_ageController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pakisulat ang iyong edad')),
        );
        return;
      }

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
          age: _ageController.text.trim(),
          conditions: selectedConditions,
          allergens: selectedAllergens,
        );
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
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.noScaling,
            ),
            child: Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              body: SafeArea(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _buildPage1(theme),
                    _buildPage2(theme),
                    _buildPage3(theme),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPage1(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        children: [
          const Spacer(),
          _buildLogo(theme),
          const SizedBox(height: 32),
          Text(
            'Pakilagay ang iyong impormasyon upang magamit ang app',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: colorScheme.onSurface, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Pangalan',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorScheme.outlineVariant)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Edad',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorScheme.outlineVariant)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
            ),
          ),
          const Spacer(),
          _buildButton('Sunod', _nextPage, theme),
        ],
      ),
    );
  }

  Widget _buildPage2(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        children: [
          const Spacer(),
          _buildLogo(theme),
          const SizedBox(height: 20),
          Text(
            'Malinaw. Lokal. Maaasahan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ang iyong AI na katulong\npara sa mas malusog na pamimili.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurface, height: 1.5),
          ),
          const SizedBox(height: 36),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.4,
            children: [
              _buildFeatureCard('assets/images/scan.png', 'I-scan ang Produkto', theme),
              _buildFeatureCard('assets/images/nutrisyon.png', 'Nutrisyon ng Produkto', theme),
              _buildFeatureCard('assets/images/gabay.png', 'Gabay sa Kalusugan', theme),
              _buildFeatureCard('assets/images/compare.png', 'Paghahambing ng Produkto', theme),
            ],
          ),
          const Spacer(),
          _buildButton('Magsimula', _nextPage, theme),
        ],
      ),
    );
  }

  Widget _buildPage3(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLogo(theme),
          const SizedBox(height: 12),
          Text(
            'Sagutan ang mga sumusunod para sa mas ligtas at mas angkop na rekomendasyon para sa iyo',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurface, height: 1.5),
          ),
          const SizedBox(height: 20),
          _buildSelectionCard(
            icon: Icons.favorite_border,
            title: 'May kondisyon ka ba sa kalusugan?',
            subtitle: 'Pumili ng lahat ng naaangkop sa iyo',
            note: 'Maaari mo itong baguhin sa iyong profile settings.',
            noteIcon: Icons.info_outline,
            child: _buildConditionsGrid(theme),
          ),
          const SizedBox(height: 16),
          _buildSelectionCard(
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFB45309),
            title: 'May mga allergen ba na dapat iwasan?',
            subtitle: 'Pumili ng lahat ng naaangkop sa iyo',
            child: _buildAllergensGrid(theme),
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
                        'Prayoridad namin ang iyong kaligtasan',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colorScheme.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gagamitin namin ang impormasyong ito upang magbigay ng health insights at mas ligtas na mga rekomendasyon.',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurface, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildButton('Magsimula', _nextPage, theme),
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

  Widget _buildConditionsGrid(ThemeData theme) {
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
            label: key,
            selected: selected,
            isWala: isWala,
            imagePath: isWala ? null : _conditionIcons[key],
            theme: theme,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAllergensGrid(ThemeData theme) {
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
            label: key,
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
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: selected ? colorScheme.primary : colorScheme.onSurface,
                    fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
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
              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          child,
          if (note != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(noteIcon, size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(note,
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureCard(String imagePath, String label, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            imagePath,
            height: 36,
            width: 36,
            errorBuilder: (_, __, ___) => const Icon(
                Icons.image_not_supported,
                size: 36,
                color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(ThemeData theme) {
    return Column(
      children: [
        Image.asset('assets/images/logo.png', height: 80),
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

  Widget _buildButton(String label, VoidCallback onTap, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: _isLoading ? null : onTap,
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