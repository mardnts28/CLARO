import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/locale_service.dart';
import '../generated/l10n/app_localizations.dart';
import 'personal_info_screen.dart';
import 'preference_screen.dart';
import 'suggestion_screen.dart';
import 'about_claro_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  String _userName = 'User';
  String _userEmail = '';
  bool _voiceAssistantEnabled = false;
  bool _mfaEnabled = false;
  bool _darkModeEnabled = false;
  String _selectedLanguage = 'English';
  double _speechRate = 0.5;
  double _speechVolume = 0.7;
  bool _vibrationFeedback = false;
  double _textSize = 1.0; // 0.8 - 1.4 range for example
  

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        // try server first
        try {
          final userDoc = await _authService.db.collection('users').doc(uid).get(GetOptions(source: Source.server));
          if (userDoc.exists) {
            final data = userDoc.data();
            if (data != null) {
              final themeString = data['theme'] ?? 'Default';
              setState(() {
                _userName = data['name'] ?? 'User';
                _userEmail = data['email'] ?? '';
                _voiceAssistantEnabled = data['voiceAssistant'] ?? false;
                _mfaEnabled = data['mfaEnabled'] ?? false;
                _darkModeEnabled = themeString.toString().toLowerCase().contains('dark');
                // `language` stored as language code ('en'|'tl'). Convert to human label for UI.
                final code = data['language'] ?? 'en';
                _selectedLanguage = (code == 'tl') ? 'Tagalog' : 'English';
                _speechRate = (data['speechRate'] != null) ? (data['speechRate'] as num).toDouble() : 0.5;
                _speechVolume = (data['speechVolume'] != null) ? (data['speechVolume'] as num).toDouble() : 0.7;
                _vibrationFeedback = data['vibrationFeedback'] ?? false;
                _textSize = (data['textSize'] != null) ? (data['textSize'] as num).toDouble() : 1.0;
              });
              setAppThemeMode(parseThemeMode(themeString));
            }
            return;
          }
        } catch (_) {}

        // fallback to cache
        final userDoc = await _authService.db.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
            if (data != null) {
            final themeString = data['theme'] ?? 'Default';
            setState(() {
              _userName = data['name'] ?? 'User';
              _userEmail = data['email'] ?? '';
              _voiceAssistantEnabled = data['voiceAssistant'] ?? false;
              _mfaEnabled = data['mfaEnabled'] ?? false;
              _darkModeEnabled = themeString.toString().toLowerCase().contains('dark');
                final code = data['language'] ?? 'en';
                _selectedLanguage = (code == 'tl') ? 'Tagalog' : 'English';
              _speechRate = (data['speechRate'] != null) ? (data['speechRate'] as num).toDouble() : 0.5;
              _speechVolume = (data['speechVolume'] != null) ? (data['speechVolume'] as num).toDouble() : 0.7;
              _vibrationFeedback = data['vibrationFeedback'] ?? false;
              _textSize = (data['textSize'] != null) ? (data['textSize'] as num).toDouble() : 1.0;
            });
            setAppThemeMode(parseThemeMode(themeString));
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<bool> _updateUserPreference(String key, dynamic value) async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        final ok = await _authService.updateUserData({key: value});
        if (ok) {
          // reload to get server-confirmed values
          await _loadUserData();
        }
        return ok;
      }
    } catch (e) {
      debugPrint('Error updating preference: $e');
    }
    return false;
  }

  

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.profile,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: colorScheme.secondaryContainer,
            child: Icon(
              Icons.person,
              size: 40,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userEmail,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onPrimaryContainer.withOpacity(0.8),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          _buildMenuItemWithArrow(
            icon: Icons.person_outline,
            label: AppLocalizations.of(context)!.personalInfo,
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          _buildMenuItemWithArrow(
            icon: Icons.settings_outlined,
            label: AppLocalizations.of(context)!.preference,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PreferenceScreen()),
            ),
          ),
          Divider(height: 0, color: colorScheme.outlineVariant),
          _buildVoiceAssistantToggle(),
          Divider(height: 0, color: colorScheme.outlineVariant),
          _buildMfaToggle(),
          Divider(height: 0, color: colorScheme.outlineVariant),
          _buildDarkModeToggle(),
          Divider(height: 0, color: colorScheme.outlineVariant),
          _buildMenuItemWithArrow(
            icon: Icons.language,
            label: AppLocalizations.of(context)!.language,
            trailing: Text(_selectedLanguage, style: TextStyle(color: colorScheme.onSurfaceVariant)),
            onTap: () => _showLanguageChooser(),
          ),
        ],
      ),
    );
  }

  void _showLanguageChooser() async {
    final loc = AppLocalizations.of(context)!;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(loc.chooseLanguage),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'en'),
            child: Text(loc.english),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'tl'),
            child: Text(loc.tagalog),
          ),
        ],
      ),
    );

    if (choice != null) {
      final selectedLabel = choice == 'en' ? AppLocalizations.of(context)!.english : AppLocalizations.of(context)!.tagalog;
      if (selectedLabel != _selectedLanguage) {
        setState(() => _selectedLanguage = selectedLabel);
        // Persist language code (e.g., 'en' or 'tl') to Firestore so server-side reads match locale codes.
        await _updateUserPreference('language', choice);
        await LocaleService.setAppLocale(choice);
      }
    }
  }

  Widget _buildMoreSection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          _buildMenuItemWithArrow(
            icon: Icons.lightbulb_outline,
            label: AppLocalizations.of(context)!.suggestion,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SuggestionScreen()),
            ),
          ),
          Divider(height: 0, color: colorScheme.outlineVariant),
          _buildMenuItemWithArrow(
            icon: Icons.info_outline,
            label: AppLocalizations.of(context)!.aboutClaro,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutClaroScreen()),
            ),
          ),
          Divider(height: 0, color: colorScheme.outlineVariant),
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
                child: Text(
                  AppLocalizations.of(context)!.logout,
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.primary,
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
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: colorScheme.outline, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDarkModeToggle() {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.dark_mode_outlined, color: colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Dark Mode',
              style: TextStyle(fontSize: 15, color: colorScheme.onSurface),
            ),
          ),
          Switch(
            value: _darkModeEnabled,
            onChanged: (value) async {
              final theme = value ? 'Dark Mode' : 'Default';
              setState(() => _darkModeEnabled = value);
              await setAppThemeMode(parseThemeMode(theme));
              await _authService.updateUserData({'theme': theme});
            },
            activeColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildMfaToggle() {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.security_outlined, color: colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Multi-Factor Authentication',
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Switch(
            value: _mfaEnabled,
            onChanged: (value) async {
              final previous = _mfaEnabled;
              setState(() => _mfaEnabled = value);
              try {
                await _authService.setMfaEnabled(enabled: value);
              } catch (_) {
                setState(() => _mfaEnabled = previous);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hindi ma-save ang MFA setting')));
                }
              }
            },
            activeColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceAssistantToggle() {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.mic_outlined, color: colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Voice Assistant',
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Switch(
            value: _voiceAssistantEnabled,
            onChanged: (value) async {
              final previous = _voiceAssistantEnabled;
              setState(() => _voiceAssistantEnabled = value);
              final ok = await _updateUserPreference('voiceAssistant', value);
              if (!ok) {
                // revert and inform
                setState(() => _voiceAssistantEnabled = previous);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hindi ma-save ang preference')));
                }
              }
            },
            activeColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }
}
