import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'personal_info_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _primaryRed = Color(0xFF8B1A1A);
  static const _lightRed = Color(0xFFFCE7E7);
  final _authService = AuthService();
  String _userName = 'User';
  String _userEmail = '';
  bool _voiceAssistantEnabled = false;
  String _selectedTheme = 'Default';
  String _selectedLanguage = 'English';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        final userDoc = await _authService.db
            .collection('users')
            .doc(uid)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data();
          if (data != null) {
            setState(() {
              _userName = data['name'] ?? 'User';
              _userEmail = data['email'] ?? '';
              _voiceAssistantEnabled = data['voiceAssistant'] ?? false;
              _selectedTheme = data['theme'] ?? 'Default';
              _selectedLanguage = data['language'] ?? 'English';
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _updateUserPreference(String key, dynamic value) async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        await _authService.db
            .collection('users')
            .doc(uid)
            .update({key: value});
      }
    } catch (e) {
      debugPrint('Error updating preference: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          _buildProfileCard(),
          const SizedBox(height: 24),
          _buildPersonalSection(),
          const SizedBox(height: 20),
          _buildPreferenceSection(),
          const SizedBox(height: 20),
          _buildMoreSection(),
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _lightRed,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.grey.shade400,
            child: const Icon(
              Icons.person,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userEmail,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildMenuItemWithArrow(
            icon: Icons.person_outline,
            label: 'Personal na Impormasyon',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.settings_outlined, color: _primaryRed, size: 20),
                const SizedBox(width: 12),
                const Text(
                  'Preference',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 0, color: Colors.grey.shade200),
          _buildVoiceAssistantToggle(),
          Divider(height: 0, color: Colors.grey.shade200),
          _buildMenuItemWithArrow(
            icon: Icons.palette_outlined,
            label: 'Tema',
            trailing: Text(
              _selectedTheme,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
            onTap: () {},
          ),
          Divider(height: 0, color: Colors.grey.shade200),
          _buildMenuItemWithArrow(
            icon: Icons.language_outlined,
            label: 'Lenguwahe',
            trailing: Text(
              _selectedLanguage,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildMoreSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildMenuItemWithArrow(
            icon: Icons.lightbulb_outline,
            label: 'Sugestiyon',
            onTap: () {},
          ),
          Divider(height: 0, color: Colors.grey.shade200),
          _buildMenuItemWithArrow(
            icon: Icons.info_outline,
            label: 'Tungkol sa CLARO',
            onTap: () {},
          ),
          Divider(height: 0, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  await _authService.signOut();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/');
                  }
                },
                child: const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 15,
                    color: _primaryRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemWithArrow({
    required IconData icon,
    required String label,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Icon(icon, color: _primaryRed, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceAssistantToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.mic_outlined, color: _primaryRed, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Voice Assistant',
              style: TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
          Switch(
            value: _voiceAssistantEnabled,
            onChanged: (value) {
              setState(() => _voiceAssistantEnabled = value);
              _updateUserPreference('voiceAssistant', value);
            },
            activeColor: _primaryRed,
          ),
        ],
      ),
    );
  }
}
