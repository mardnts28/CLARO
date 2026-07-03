import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final _nameController = TextEditingController();
  final _authService = AuthService();
  int _currentPage = 0;
  bool _isLoading = false;

  static const _red = Color(0xFF8B1A1A);
  static const _lightRed = Color(0xFFFDF0F0);

  final Map<String, bool> _conditions = {
    'Diabetes': false,
    'Alta-presyon': false,
    'Sakit sa puso': false,
    'Wala': false,
  };

  final Map<String, bool> _allergens = {
    'Isda': false,
    'Gatas': false,
    'Itlog': false,
    'Toyo': false,
    'Trigo': false,
    'Lamong-sibuyas': false,
    'Mani': false,
  };

  final Map<String, String> _conditionIcons = {
    'Diabetes': 'assets/images/diabetes.png',
    'Alta-presyon': 'assets/images/presyon.png',
    'Sakit sa puso': 'assets/images/puso.png',
    'Wala': '',
  };

  final Map<String, String> _allergenIcons = {
    'Isda': 'assets/images/isda.png',
    'Gatas': 'assets/images/gatas.png',
    'Itlog': 'assets/images/itlog.png',
    'Toyo': 'assets/images/toyo.png',
    'Trigo': 'assets/images/trigo.png',
    'Lamong-sibuyas': 'assets/images/lamang-dagat.png',
    'Mani': 'assets/images/mani.png',
  };

  Future<void> _nextPage() async {
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
    setState(() {
      _allergens[key] = !_allergens[key]!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (i) => setState(() => _currentPage = i),
          children: [
            _buildPage1(),
            _buildPage2(),
            _buildPage3(),
          ],
        ),
      ),
    );
  }

  Widget _buildPage1() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        children: [
          const Spacer(),
          _buildLogo(),
          const SizedBox(height: 32),
          const Text(
            'Ano ang gusto mong itawag namin sa iyo?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'Pangalan',
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFD9A0A0)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF8B1A1A)),
              ),
            ),
          ),
          const Spacer(),
          _buildButton('Sunod', _nextPage),
        ],
      ),
    );
  }

  Widget _buildPage2() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        children: [
          const Spacer(),
          _buildLogo(),
          const SizedBox(height: 20),
          const Text(
            'Malinaw. Lokal. Maaasahan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _red,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ang iyong AI na katulong\npara sa mas malusog na pamimili.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
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
              _buildFeatureCard('assets/images/scan.png', 'I-scan ang Produkto'),
              _buildFeatureCard('assets/images/nutrisyon.png', 'Nutrisyon ng Produkto'),
              _buildFeatureCard('assets/images/gabay.png', 'Gabay sa Kalusugan'),
              _buildFeatureCard('assets/images/compare.png', 'Paghahambing ng Produkto'),
            ],
          ),
          const Spacer(),
          _buildButton('Magsimula', _nextPage),
        ],
      ),
    );
  }

  Widget _buildPage3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLogo(),
          const SizedBox(height: 12),
          const Text(
            'Sagutan ang mga sumusunod para sa mas ligtas at mas angkop na rekomendasyon para sa iyo',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
          ),
          const SizedBox(height: 20),
          _buildSelectionCard(
            icon: Icons.favorite_border,
            title: 'May kondisyon ka ba sa kalusugan?',
            subtitle: 'Pumili ng lahat ng naaangkop sa iyo',
            note: 'Maaari mo itong baguhin sa iyong profile settings.',
            noteIcon: Icons.info_outline,
            child: _buildConditionsGrid(),
          ),
          const SizedBox(height: 16),
          _buildSelectionCard(
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFB45309),
            title: 'May mga allergen ba na dapat iwasan?',
            subtitle: 'Pumili ng lahat ng naaangkop sa iyo',
            child: _buildAllergensGrid(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _lightRed,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD9A0A0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.shield_outlined, color: _red, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prayoridad namin ang iyong kaligtasan',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _red),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Gagamitin namin ang impormasyong ito upang magbigay ng health insights at mas ligtas na mga rekomendasyon.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.black87, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildButton('Magsimula', _nextPage),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '...',
              style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 18,
                  letterSpacing: 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionsGrid() {
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
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAllergensGrid() {
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
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFDF0F0) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? _red : const Color(0xFFD9A0A0),
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
                  const Icon(Icons.block, color: Colors.grey, size: 28)
                else if (imagePath != null)
                  Image.asset(
                    imagePath,
                    height: 32,
                    width: 32,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.image_not_supported,
                        size: 28,
                        color: Colors.grey),
                  )
                else
                  const SizedBox(height: 32),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: selected ? _red : Colors.black87,
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
                decoration: const BoxDecoration(
                    color: _red, shape: BoxShape.circle),
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
    Color iconColor = _red,
    required String title,
    required String subtitle,
    String? note,
    IconData? noteIcon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9A0A0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 12),
          child,
          if (note != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(noteIcon, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(note,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureCard(String imagePath, String label) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9A0A0)),
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
            style: const TextStyle(fontSize: 11, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Image.asset('assets/images/logo.png', height: 80),
        const SizedBox(height: 6),
        const Text(
          'CLARO',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _red,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _red,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: _isLoading ? null : onTap,
        child: _isLoading
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2),
        )
            : Text(
          label,
          style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}