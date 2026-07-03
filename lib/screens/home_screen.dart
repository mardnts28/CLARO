import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _primaryRed = Color(0xFF8B1A1A);
  static const _lightRed = Color(0xFFFCE7E7);
  static const _lightGray = Color(0xFFF3F3F3);
  int _selectedIndex = 0;

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(
              index: _selectedIndex,
              children: [
                _buildHomeContent(),
                _buildScanPage(),
                _buildHistoryPage(),
                _buildProfilePage(),
              ],
            ),
            if (_selectedIndex == 0) _buildVoiceButton(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
        selectedItemColor: _primaryRed,
        unselectedItemColor: Colors.grey.shade500,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner_outlined),
            activeIcon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildScanCard(),
          const SizedBox(height: 22),
          _buildLabelIntro(),
          const SizedBox(height: 18),
          _buildHealthCard(),
          const SizedBox(height: 12),
          _buildEcoCard(),
          const SizedBox(height: 12),
          _buildProcessCard(),
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kumusta, Clara! 👋',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Gawing mas matalino ang pamimili ngayon.',
          style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildScanCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _primaryRed,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primaryRed.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'I-scan ang produkto',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Itapat ang iyong camera sa anumang de-latang pagkain.',
                  style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {},
                    child: const Text(
                      'I-scan Na',
                      style: TextStyle(
                        color: _primaryRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Icon(
                Icons.camera_alt_outlined,
                color: Colors.white,
                size: 42,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelIntro() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Kilalain ang iyong mga Label',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Sa tulong ng CLARO, mas madaling maunawaan ang mga label na ito at makagawa ng mas malusog na desisyon.',
                style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _lightGray,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Image.asset(
              'assets/images/cart.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHealthCard() {
    return _buildArrowInfoCard(
      title: 'Sukat ng Kalusugan ng Pagkain',
      subtitle: 'Kabuuang kalidad ng nutrisyon ng produkto.',
      values: const [
        'Pinaka-mahusay',
        'Rekomendadong pagpipili',
        'Katamtamang tapang sa kalusugan',
        'Limitahan ang pagkonsumo',
        'Iwasan ang mataas na panganib',
      ],
      activeIndex: 0,
      colors: const [
        Color(0xFF69A64A),
        Color(0xFF8FDB42),
        Color(0xFFF4B840),
        Color(0xFFF26C3C),
        Color(0xFFEA3F2D),
      ],
    );
  }

  Widget _buildEcoCard() {
    return _buildArrowInfoCard(
      title: 'Grado ng Pagiging Maka-Kalikasan',
      subtitle: 'Epekto ng produkto sa kalikasan.',
      values: const [
        'Mababa ang epekto sa kapaligiran',
        'Katamtamang epekto sa kapaligiran',
        'Isang-daan ang mataas ang epekto',
        'May malaking epekto',
        'Masyadong nakasasama',
      ],
      activeIndex: 1,
      colors: const [
        Color(0xFF69A64A),
        Color(0xFF8FDB42),
        Color(0xFFF4B840),
        Color(0xFFF26C3C),
        Color(0xFFEA3F2D),
      ],
    );
  }

  Widget _buildArrowInfoCard({
    required String title,
    required String subtitle,
    required List<String> values,
    required int activeIndex,
    required List<Color> colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 16),
          Column(
            children: List.generate(values.length, (index) {
              return _buildArrowRow(
                label: values[index],
                color: colors[index],
                isActive: index == activeIndex,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildArrowRow({
    required String label,
    required Color color,
    bool isActive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.14) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? color : Colors.grey.shade300,
          width: isActive ? 1.3 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.black87 : Colors.black54,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isActive ? color : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: isActive ? Colors.white : Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildProcessCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Klase ng Pagpoproseso ng Pagkain',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          const Text(
            'Antas ng pagproseso na ginawa sa produkto.',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (index) {
              final level = index + 1;
              final isActive = level == 2;
              return CircleAvatar(
                radius: 18,
                backgroundColor: isActive ? _primaryRed : Colors.grey.shade200,
                child: Text(
                  '$level',
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Unang Grupo', style: TextStyle(fontSize: 11, color: Colors.black54)),
              Text('Ika-apat na Grupo', style: TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceButton() {
    return Positioned(
      bottom: 92,
      right: 24,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _primaryRed,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _primaryRed.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.mic, color: Colors.white),
          onPressed: () {},
        ),
      ),
    );
  }

  Widget _buildScanPage() {
    return _buildPlaceholderPage('Scan', 'I-scan ang iyong produkto mula rito.');
  }

  Widget _buildHistoryPage() {
    return _buildPlaceholderPage('History', 'Makikita mo rito ang iyong scan history.');
  }

  Widget _buildProfilePage() {
    return _buildPlaceholderPage('Profile', 'Pamahalaan ang iyong profile at health preferences.');
  }

  Widget _buildPlaceholderPage(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
