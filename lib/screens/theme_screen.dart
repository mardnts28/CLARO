import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';

class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key});

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  static const _primaryRed = Color(0xFF8B1A1A);
  String _selected = 'Default';
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        // Try to get the latest server value first
        try {
          final userDoc = await _authService.db.collection('users').doc(uid).get(GetOptions(source: Source.server));
          final data = userDoc.data() as Map<String, dynamic>?;
          if (data != null) {
            setState(() => _selected = (data['theme'] ?? 'Default').toString());
            setAppThemeMode(parseThemeMode(_selected));
            return;
          }
        } catch (_) {}

        // Fallback to cache if server read fails
        final userDoc = await _authService.db.collection('users').doc(uid).get();
        final data = userDoc.data() as Map<String, dynamic>?;
        if (data != null) {
          setState(() => _selected = (data['theme'] ?? 'Default').toString());
          setAppThemeMode(parseThemeMode(_selected));
        }
      }
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  Future<void> _choose(String theme) async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) return;
      final ok = await _authService.updateUserData({'theme': theme});
      if (ok) {
        // reload server value to be sure
        await _load();
        setAppThemeMode(parseThemeMode(theme));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tema na-save')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hindi ma-save ang tema')));
      }
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }

  Widget _option(String label, String asset) {
    final selected = _selected.toLowerCase() == label.toLowerCase();
    return Expanded(
      child: GestureDetector(
        onTap: () => _choose(label),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFCE7E7) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _primaryRed : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Image.asset(asset, height: 100, fit: BoxFit.contain),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: selected ? _primaryRed : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _primaryRed),
        title: const Text('Tema', style: TextStyle(color: _primaryRed)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildCardOption(
              label: 'Default',
              asset: 'assets/images/default.png',
              description: 'Karaniwang hitsura na may CLARO na kulay',
              selected: _selected.toLowerCase() == 'default',
              onTap: () => _choose('Default'),
            ),
            const SizedBox(height: 12),
            _buildCardOption(
              label: 'Dark Mode',
              asset: 'assets/images/dark.png',
              description: 'Madilim na background para sa mga lugar na may mababang ilaw.',
              selected: _selected.toLowerCase() == 'dark' || _selected.toLowerCase() == 'dark mode',
              onTap: () => _choose('Dark Mode'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardOption({
    required String label,
    required String asset,
    required String description,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _primaryRed : Colors.grey.shade300, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(asset, fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: selected ? _primaryRed : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        selected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: selected ? _primaryRed : Colors.grey,
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
