import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/locale_service.dart';
import '../services/haptic_service.dart';
import '../services/voice_assistant_service.dart';
import '../services/home_tab_controller.dart';
import '../generated/l10n/app_localizations.dart';
import 'personal_info_screen.dart';
import 'preference_screen.dart';
import 'suggestion_screen.dart';

// Placeholder URLs - replace with actual CLARO website URLs when available
const String claroWebsiteUrl = 'https://example.com/about-claro';
const String privacyPolicyUrl = 'https://example.com/privacy-policy';
const String termsConditionsUrl = 'https://example.com/terms-and-conditions';
const String userGuideUrl = 'https://example.com/user-guide';

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
  String _selectedLanguageCode = 'en';
  double _speechRate = 0.5;
  double _speechVolume = 0.7;
  bool _vibrationFeedback = false;
  double _textSize = 1.0; // 0.8 - 1.4 range for example


  @override
  void initState() {
    super.initState();
    HomeTabController.tabNotifier.addListener(_handleTabChange);
    _announceIfVisible();
    _loadUserData();
    // Listen to the shared name notifier so this header updates
    // instantly if the name is changed elsewhere (e.g.
    // PersonalInfoScreen), without requiring a manual refresh.
    //
    // Previously, ProfileScreen and HomeScreen are sibling tabs kept
    // alive inside HomeScreen's IndexedStack — editing the name on
    // PersonalInfoScreen (pushed on top) only updated Firestore, and
    // returning here never recreated this widget or told it anything
    // had changed, so the old name stayed on screen until a manual
    // pull-to-refresh.
    AuthService.userNameNotifier.addListener(_handleNameChanged);
  }

  void _handleTabChange() {
    _announceIfVisible();
  }

  void _announceIfVisible() {
    if (HomeTabController.tabNotifier.value == 3 &&
        _authService.currentUser != null &&
        VoiceAssistantService.instance.isEnabled) {
      VoiceAssistantService.instance.announcePage('profile');
    }
  }

  @override
  void dispose() {
    HomeTabController.tabNotifier.removeListener(_handleTabChange);
    AuthService.userNameNotifier.removeListener(_handleNameChanged);
    super.dispose();
  }

  void _handleNameChanged() {
    if (!mounted) return;
    setState(() => _userName = AuthService.userNameNotifier.value);
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
                _selectedLanguageCode = code;
                _speechRate = (data['speechRate'] != null) ? (data['speechRate'] as num).toDouble() : 0.5;
                _speechVolume = (data['speechVolume'] != null) ? (data['speechVolume'] as num).toDouble() : 0.7;
                _vibrationFeedback = data['vibrationFeedback'] ?? false;
                _textSize = (data['textSize'] != null) ? (data['textSize'] as num).toDouble() : 1.0;
              });
              setAppThemeMode(parseThemeMode(themeString));
              // Keep the shared notifier in sync so HomeScreen's
              // greeting reflects whatever this screen just loaded.
              AuthService.userNameNotifier.value = _userName;
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
              _selectedLanguageCode = code;
              _speechRate = (data['speechRate'] != null) ? (data['speechRate'] as num).toDouble() : 0.5;
              _speechVolume = (data['speechVolume'] != null) ? (data['speechVolume'] as num).toDouble() : 0.7;
              _vibrationFeedback = data['vibrationFeedback'] ?? false;
              _textSize = (data['textSize'] != null) ? (data['textSize'] as num).toDouble() : 1.0;
            });
            setAppThemeMode(parseThemeMode(themeString));
            AuthService.userNameNotifier.value = _userName;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  /// Pull-to-refresh handler. Forces a fresh server read of the user's
  /// profile/settings and gives light haptic feedback so the pull gesture
  /// feels responsive even while the network call is in flight.
  Future<void> _onRefresh() async {
    HapticService().vibrate();
    await _loadUserData();
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
    final loc = AppLocalizations.of(context)!;

    return RefreshIndicator(
      color: colorScheme.primary,
      onRefresh: _onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.profile,
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
      ),
    );
  }

  Widget _buildProfileCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _userName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _userEmail,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onPrimaryContainer.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context)!;

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
            label: loc.personalInfo,
            onTap: () async {
              HapticService().vibrate();
              // Await the push and reload afterwards. Previously this
              // navigated without awaiting, so any name/age/conditions/
              // allergens edits made on PersonalInfoScreen never
              // refreshed here on return — the old values stayed on
              // screen until a manual pull-to-refresh. The name itself
              // is also kept in sync live via AuthService.userNameNotifier,
              // but this reload covers everything else shown on this
              // screen too.
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
              );
              if (mounted) await _loadUserData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context)!;

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
            label: loc.preference,
            onTap: () {
              HapticService().vibrate();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PreferenceScreen()),
              );
            },
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
            label: loc.language,
            trailing: Text(
              _selectedLanguageCode == 'tl' ? loc.tagalog : loc.english,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            onTap: () {
              HapticService().vibrate();
              _showLanguageChooser();
            },
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
            onPressed: () {
              HapticService().vibrate();
              Navigator.pop(ctx, 'en');
            },
            child: Text(loc.english),
          ),
          SimpleDialogOption(
            onPressed: () {
              HapticService().vibrate();
              Navigator.pop(ctx, 'tl');
            },
            child: Text(loc.tagalog),
          ),
        ],
      ),
    );

    if (choice != null) {
      if (choice != _selectedLanguageCode) {
        setState(() => _selectedLanguageCode = choice);
        // Persist language code (e.g., 'en' or 'tl') to Firestore so server-side reads match locale codes.
        await _updateUserPreference('language', choice);
        await LocaleService.setAppLocale(choice);
      }
    }
  }

  Widget _buildMoreSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context)!;

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
            label: loc.suggestion,
            onTap: () {
              HapticService().vibrate();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SuggestionScreen()),
              );
            },
          ),
          Divider(height: 0, color: colorScheme.outlineVariant),
          _buildMenuItemWithArrow(
            icon: Icons.info_outline,
            label: loc.aboutClaro,
            onTap: () {
              HapticService().vibrate();
              _launchUrl(claroWebsiteUrl);
            },
          ),
          Divider(height: 0, color: colorScheme.outlineVariant),
          _buildMenuItemWithArrow(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            onTap: () {
              HapticService().vibrate();
              _launchUrl(privacyPolicyUrl);
            },
          ),
          Divider(height: 0, color: colorScheme.outlineVariant),
          _buildMenuItemWithArrow(
            icon: Icons.description_outlined,
            label: 'Terms & Conditions',
            onTap: () {
              HapticService().vibrate();
              _launchUrl(termsConditionsUrl);
            },
          ),
          Divider(height: 0, color: colorScheme.outlineVariant),
          _buildMenuItemWithArrow(
            icon: Icons.menu_book_outlined,
            label: 'User Guide',
            onTap: () {
              HapticService().vibrate();
              _launchUrl(userGuideUrl);
            },
          ),
          Divider(height: 0, color: colorScheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  HapticService().vibrate();
                  await _authService.signOut();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/');
                  }
                },
                child: Text(
                  loc.logout,
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

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      final bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open the website.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open the website.'),
          ),
        );
      }
    }
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
          const SizedBox(width: 12),
          Switch(
            value: _darkModeEnabled,
            onChanged: (value) async {
              HapticService().vibrate();
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
    final loc = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.security_outlined, color: colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loc.multiFactorAuthentication,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: _mfaEnabled,
            onChanged: (value) async {
              HapticService().vibrate();
              final previous = _mfaEnabled;
              setState(() => _mfaEnabled = value);
              try {
                await _authService.setMfaEnabled(enabled: value);
              } catch (_) {
                setState(() => _mfaEnabled = previous);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.mfaSaveError)));
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
    final loc = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.mic_outlined, color: colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loc.voiceAssistant,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: _voiceAssistantEnabled,
            onChanged: (value) async {
              HapticService().vibrate();
              final previous = _voiceAssistantEnabled;
              setState(() => _voiceAssistantEnabled = value);
              await VoiceAssistantService.instance.updateEnabled(value);
              final ok = await _updateUserPreference('voiceAssistant', value);
              if (!ok) {
                // revert and inform
                setState(() => _voiceAssistantEnabled = previous);
                await VoiceAssistantService.instance.updateEnabled(previous);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.preferenceSaveError)));
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