import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import '../core/utils/success_feedback_utils.dart';
import '../widgets/avatar_picker.dart';

// NOTE: "Health Group" / "Join a Group" used to be entry points here
// (Phase 3 / Phase 4). They've moved to their own "Group" bottom nav tab
// (see home_screen.dart) so the group feature no longer routes through
// this screen at all.

const String claroWebsiteUrl = 'https://claro-52ia.onrender.com/';
const String privacyPolicyUrl =
    'https://claro-52ia.onrender.com/privacy-policy';
const String termsConditionsUrl =
    'https://claro-52ia.onrender.com/terms-and-conditions';
const String userGuideUrl =
    'https://claro-52ia.onrender.com/user-guide';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();

  String _userName = 'User';
  String _userEmail = '';
  String? _avatar;
  bool _voiceAssistantEnabled = false;
  bool _mfaEnabled = false;

  bool _isDeletingAccount = false;
  bool _darkModeEnabled = false;
  String _selectedLanguageCode = 'en';

  @override
  void initState() {
    super.initState();

    HomeTabController.tabNotifier.addListener(_handleTabChange);
    _announceIfVisible();
    _loadUserData();

    AuthService.userNameNotifier.addListener(_handleNameChanged);
    themeModeNotifier.addListener(_handleThemeChanged);
    AuthService.mfaNotifier.addListener(_handleMfaChanged);
    VoiceAssistantService.isEnabledNotifier
        .addListener(_handleVoiceAssistantChanged);
    LocaleService.localeNotifier.addListener(_onLocaleChanged);
  }

  void _handleTabChange() {
    _announceIfVisible();
  }

  void _announceIfVisible() {
    if (HomeTabController.tabNotifier.value == 4 &&
        _authService.currentUser != null &&
        VoiceAssistantService.instance.isEnabled &&
        !VoiceAssistantService.isSpeakingNotifier.value) {
      VoiceAssistantService.instance.announcePage('profile');
    }
  }

  void _onLocaleChanged() {
    if (!mounted) return;

    setState(() {
      _selectedLanguageCode =
          LocaleService.localeNotifier.value.languageCode;
    });
  }

  @override
  void dispose() {
    HomeTabController.tabNotifier.removeListener(_handleTabChange);
    AuthService.userNameNotifier.removeListener(_handleNameChanged);
    themeModeNotifier.removeListener(_handleThemeChanged);
    AuthService.mfaNotifier.removeListener(_handleMfaChanged);
    VoiceAssistantService.isEnabledNotifier
        .removeListener(_handleVoiceAssistantChanged);
    LocaleService.localeNotifier.removeListener(_onLocaleChanged);

    super.dispose();
  }

  void _handleNameChanged() {
    if (!mounted) return;

    setState(() {
      _userName = AuthService.userNameNotifier.value;
    });
  }

  void _handleThemeChanged() {
    if (!mounted) return;

    final isDark = themeModeNotifier.value == ThemeMode.dark;

    if (_darkModeEnabled != isDark) {
      setState(() {
        _darkModeEnabled = isDark;
      });
    }
  }

  void _handleMfaChanged() {
    if (!mounted) return;

    if (_mfaEnabled != AuthService.mfaNotifier.value) {
      setState(() {
        _mfaEnabled = AuthService.mfaNotifier.value;
      });
    }
  }

  void _handleVoiceAssistantChanged() {
    if (!mounted) return;

    if (_voiceAssistantEnabled !=
        VoiceAssistantService.isEnabledNotifier.value) {
      setState(() {
        _voiceAssistantEnabled =
            VoiceAssistantService.isEnabledNotifier.value;
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      final uid = _authService.currentUser?.uid;

      if (uid != null) {
        try {
          final userDoc = await _authService.db
              .collection('users')
              .doc(uid)
              .get(
                GetOptions(source: Source.server),
              );

          if (userDoc.exists) {
            final data = userDoc.data();

            if (data != null) {
              final themeString = data['theme'] ?? 'Default';
              final mfaVal = data['mfaEnabled'] ?? false;
              final voiceVal = data['voiceAssistant'] ?? false;

              setState(() {
                _userName = data['name'] ?? 'User';
                _userEmail = data['email'] ?? '';

                _avatar =
                    (data['avatar'] as String?)?.isNotEmpty == true
                        ? data['avatar'] as String
                        : null;

                _voiceAssistantEnabled = voiceVal;
                _mfaEnabled = mfaVal;

                _darkModeEnabled = themeString
                    .toString()
                    .toLowerCase()
                    .contains('dark');

                final code = data['language'] ?? 'en';
                _selectedLanguageCode = code;
              });

              AuthService.mfaNotifier.value = mfaVal;
              VoiceAssistantService.isEnabledNotifier.value = voiceVal;

              setAppThemeMode(parseThemeMode(themeString));
              AuthService.userNameNotifier.value = _userName;
            }

            return;
          }
        } catch (_) {}

        final userDoc =
            await _authService.db.collection('users').doc(uid).get();

        if (userDoc.exists) {
          final data = userDoc.data();

          if (data != null) {
            final themeString = data['theme'] ?? 'Default';
            final mfaVal = data['mfaEnabled'] ?? false;
            final voiceVal = data['voiceAssistant'] ?? false;

            setState(() {
              _userName = data['name'] ?? 'User';
              _userEmail = data['email'] ?? '';

              _avatar =
                  (data['avatar'] as String?)?.isNotEmpty == true
                      ? data['avatar'] as String
                      : null;

              _voiceAssistantEnabled = voiceVal;
              _mfaEnabled = mfaVal;

              _darkModeEnabled = themeString
                  .toString()
                  .toLowerCase()
                  .contains('dark');

              final code = data['language'] ?? 'en';
              _selectedLanguageCode = code;
            });

            AuthService.mfaNotifier.value = mfaVal;
            VoiceAssistantService.isEnabledNotifier.value = voiceVal;

            setAppThemeMode(parseThemeMode(themeString));
            AuthService.userNameNotifier.value = _userName;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _onRefresh() async {
    HapticService().vibrate();
    await _loadUserData();
  }

  Future<bool> _updateUserPreference(
    String key,
    dynamic value,
  ) async {
    try {
      final uid = _authService.currentUser?.uid;

      if (uid != null) {
        final ok = await _authService.updateUserData({
          key: value,
        });

        if (ok) {
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    final primaryColor =
        theme.brightness == Brightness.dark
            ? Colors.red
            : colorScheme.primary;

    return Stack(
      children: [
        RefreshIndicator(
          color: primaryColor,
          onRefresh: _onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
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
        ),

        if (_isDeletingAccount)
          Positioned.fill(
            child: ColoredBox(
              color: colorScheme.surface.withOpacity(0.7),
              child: Center(
                child: CircularProgressIndicator(
                  color: primaryColor,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showAvatarDialog() async {
    HapticService().vibrate();

    final tl =
        Localizations.localeOf(context).languageCode == 'tl';

    String? picked = _avatar;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            tl ? 'Pumili ng avatar' : 'Choose your avatar',
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: AvatarPicker(
                selected: picked,
                allowClear: false,
                onChanged: (a) {
                  setDialogState(() {
                    picked = a;
                  });
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                tl ? 'Kanselahin' : 'Cancel',
              ),
            ),
            TextButton(
              onPressed: picked == null || picked == _avatar
                  ? null
                  : () => Navigator.pop(ctx, picked),
              child: Text(
                tl ? 'I-save' : 'Save',
              ),
            ),
          ],
        ),
      ),
    );

    if (result == null || result == _avatar || !mounted) {
      return;
    }

    final previous = _avatar;

    setState(() {
      _avatar = result;
    });

    final ok = await _authService.updateUserData({
      'avatar': result,
    });

    if (!ok && mounted) {
      setState(() {
        _avatar = previous;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tl
                ? 'Hindi na-save ang avatar. Subukan muli.'
                : "Couldn't save your avatar. Please try again.",
          ),
        ),
      );
    }
  }

  Widget _buildProfileCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),

        // Visible soft elevation instead of an outline.
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.18),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.06),
            blurRadius: 5,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: 'Change avatar',
            child: GestureDetector(
              onTap: _showAvatarDialog,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: colorScheme.surface,
                    backgroundImage:
                        _avatar != null
                            ? AssetImage(_avatar!)
                            : null,
                    onBackgroundImageError:
                        _avatar != null ? (_, __) {} : null,
                    child:
                        _avatar == null
                            ? Icon(
                                Icons.person_outline,
                                size: 36,
                                color:
                                    colorScheme.onSurfaceVariant,
                              )
                            : null,
                  ),

                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,

                        // Removed the visible outline.
                        // Replaced with a soft floating shadow.
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withOpacity(0.22),
                            blurRadius: 7,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.edit,
                        size: 12,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

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
              color:
                  colorScheme.onPrimaryContainer.withOpacity(0.8),
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

        // Soft visible elevation.
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.18),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.06),
            blurRadius: 5,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItemWithArrow(
            icon: Icons.person_outline,
            label: loc.personalInfo,
            onTap: () async {
              HapticService().vibrate();

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const PersonalInfoScreen(),
                ),
              );

              if (mounted) {
                await _loadUserData();
              }
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

        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.18),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.06),
            blurRadius: 5,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
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
                MaterialPageRoute(
                  builder: (_) => const PreferenceScreen(),
                ),
              );
            },
          ),

          Divider(
            height: 0,
            color: colorScheme.outlineVariant,
          ),

          _buildVoiceAssistantToggle(),

          Divider(
            height: 0,
            color: colorScheme.outlineVariant,
          ),

          _buildMfaToggle(),

          Divider(
            height: 0,
            color: colorScheme.outlineVariant,
          ),

          _buildDarkModeToggle(),

          Divider(
            height: 0,
            color: colorScheme.outlineVariant,
          ),

          _buildMenuItemWithArrow(
            icon: Icons.language,
            label: loc.language,
            trailing:
                ValueListenableBuilder<Locale>(
              valueListenable:
                  LocaleService.localeNotifier,
              builder: (context, locale, _) {
                final isTl =
                    locale.languageCode == 'tl';

                return Text(
                  isTl ? loc.tagalog : loc.english,
                  style: TextStyle(
                    color:
                        colorScheme.onSurfaceVariant,
                  ),
                );
              },
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
        setState(() {
          _selectedLanguageCode = choice;
        });

        await _updateUserPreference(
          'language',
          choice,
        );

        await LocaleService.setAppLocale(choice);
      }
    }
  }

  Widget _buildMoreSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),

        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.18),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.06),
            blurRadius: 5,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
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
                MaterialPageRoute(
                  builder: (_) => const SuggestionScreen(),
                ),
              );
            },
          ),

          Divider(
            height: 0,
            color: colorScheme.outlineVariant,
          ),

          _buildMenuItemWithArrow(
            icon: Icons.info_outline,
            label: loc.aboutClaro,
            onTap: () {
              HapticService().vibrate();
              _launchUrl(claroWebsiteUrl);
            },
          ),

          Divider(
            height: 0,
            color: colorScheme.outlineVariant,
          ),

          _buildMenuItemWithArrow(
            icon: Icons.privacy_tip_outlined,
            label: loc.privacyPolicy,
            onTap: () {
              HapticService().vibrate();
              _launchUrl(privacyPolicyUrl);
            },
          ),

          Divider(
            height: 0,
            color: colorScheme.outlineVariant,
          ),

          _buildMenuItemWithArrow(
            icon: Icons.description_outlined,
            label: loc.termsConditions,
            onTap: () {
              HapticService().vibrate();
              _launchUrl(termsConditionsUrl);
            },
          ),

          Divider(
            height: 0,
            color: colorScheme.outlineVariant,
          ),

          _buildMenuItemWithArrow(
            icon: Icons.menu_book_outlined,
            label: loc.userGuide,
            onTap: () {
              HapticService().vibrate();
              _launchUrl(userGuideUrl);
            },
          ),

          Divider(
            height: 0,
            color: colorScheme.outlineVariant,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12,
            ),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  HapticService().vibrate();
                  _showDeleteAccountDialog();
                },
                child: Text(
                  'Delete Account',
                  style: TextStyle(
                    fontSize: 15,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          Divider(
            height: 0,
            color: colorScheme.outlineVariant,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12,
            ),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  HapticService().vibrate();

                  HomeTabController.switchToTab(0);

                  await _authService.signOut();

                  if (mounted) {
                    Navigator.pushReplacementNamed(
                      context,
                      '/',
                    );
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
            content: Text(
              'Unable to open the website.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open the website.',
            ),
          ),
        );
      }
    }
  }

  void _showDeleteAccountDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final String uid =
        _authService.currentUser?.uid ?? '';

    final String uidSuffix =
        uid.length >= 5
            ? uid.substring(uid.length - 5)
            : uid;

    final String requiredDeletePhrase =
        '$uidSuffix-$_userName';

    showDialog(
      context: context,
      builder: (dialogContext) =>
          _DeleteAccountDialogContent(
        requiredPhrase: requiredDeletePhrase,
        colorScheme: colorScheme,
        deleteColor: colorScheme.primary,
        onConfirmed: _performAccountDeletion,
      ),
    );
  }

  Future<void> _performAccountDeletion({
    AuthCredential? credential,
  }) async {
    if (!mounted) return;

    setState(() {
      _isDeletingAccount = true;
    });

    final result =
        await _authService.deleteAccount(
      credential: credential,
    );

    if (!mounted) return;

    switch (result.status) {
      case DeleteAccountStatus.success:
        Navigator.of(context)
            .pushReplacementNamed('/');
        return;

      case DeleteAccountStatus.error:
        setState(() {
          _isDeletingAccount = false;
        });

        final theme = Theme.of(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message!),
            backgroundColor:
                theme.colorScheme.primary,
          ),
        );

        return;

      case DeleteAccountStatus.reauthRequired:
        setState(() {
          _isDeletingAccount = false;
        });

        _showReauthDialog(
          result.providerIds ?? const [],
        );

        return;
    }
  }

  void _showReauthDialog(
    List<String> providerIds,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isGoogleAccount =
        providerIds.contains(
      GoogleAuthProvider.PROVIDER_ID,
    );

    showDialog(
      context: context,
      builder: (dialogContext) =>
          _ReauthDialogContent(
        isGoogleAccount: isGoogleAccount,
        colorScheme: colorScheme,
        accentColor: colorScheme.primary,
        authService: _authService,
        onCredentialObtained:
            (credential) {
          _performAccountDeletion(
            credential: credential,
          );
        },
      ),
    );
  }

  Widget _buildMenuItemWithArrow({
    required IconData icon,
    required String label,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final primaryColor =
        theme.brightness == Brightness.dark
            ? Colors.red
            : colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: GestureDetector(
        onTap: () {
          HapticService().vibrate();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Icon(
              icon,
              color: primaryColor,
              size: 20,
            ),

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

            Icon(
              Icons.chevron_right,
              color: colorScheme.outline,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDarkModeToggle() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final primaryColor =
        theme.brightness == Brightness.dark
            ? Colors.red
            : colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: Row(
        children: [
          Icon(
            Icons.dark_mode_outlined,
            color: primaryColor,
            size: 20,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              'Dark Mode',
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurface,
              ),
            ),
          ),

          const SizedBox(width: 12),

          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (context, mode, _) {
              final isDark =
                  mode == ThemeMode.dark;

              return Switch(
                value: isDark,
                onChanged: (value) async {
                  HapticService().vibrate();

                  final theme =
                      value ? 'Dark Mode' : 'Default';

                  setState(() {
                    _darkModeEnabled = value;
                  });

                  await setAppThemeMode(
                    parseThemeMode(theme),
                  );

                  await _authService.updateUserData({
                    'theme': theme,
                  });
                },
                activeColor: primaryColor,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMfaToggle() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    final primaryColor =
        theme.brightness == Brightness.dark
            ? Colors.red
            : colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: Row(
        children: [
          Icon(
            Icons.security_outlined,
            color: primaryColor,
            size: 20,
          ),

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

          ValueListenableBuilder<bool>(
            valueListenable:
                AuthService.mfaNotifier,
            builder: (
              context,
              mfaEnabled,
              _,
            ) {
              return Switch(
                value: mfaEnabled,
                onChanged: (value) async {
                  HapticService().vibrate();

                  final hasInternet =
                      await SuccessFeedbackUtils
                          .hasInternetConnection();

                  if (!hasInternet) {
                    if (mounted) {
                      await SuccessFeedbackUtils
                          .showOfflineNoticeDialog(
                        context,
                        title:
                            loc.noInternetTitle,
                        message:
                            loc.noInternetActionMessage,
                        buttonText: loc.gotIt,
                      );
                    }

                    return;
                  }

                  setState(() {
                    _mfaEnabled = value;
                  });

                  try {
                    await _authService.setMfaEnabled(
                      enabled: value,
                    );
                  } catch (_) {
                    setState(() {
                      _mfaEnabled = !value;
                    });

                    if (mounted) {
                      await SuccessFeedbackUtils
                          .showOfflineNoticeDialog(
                        context,
                        title:
                            loc.noInternetTitle,
                        message:
                            loc.noInternetActionMessage,
                        buttonText: loc.gotIt,
                      );
                    }
                  }
                },
                activeColor: primaryColor,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceAssistantToggle() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    final primaryColor =
        theme.brightness == Brightness.dark
            ? Colors.red
            : colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: Row(
        children: [
          Icon(
            Icons.mic_outlined,
            color: primaryColor,
            size: 20,
          ),

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

          ValueListenableBuilder<bool>(
            valueListenable:
                VoiceAssistantService
                    .isEnabledNotifier,
            builder: (
              context,
              isVoiceEnabled,
              _,
            ) {
              return Switch(
                value: isVoiceEnabled,
                onChanged: (value) async {
                  HapticService().vibrate();

                  final previous =
                      isVoiceEnabled;

                  setState(() {
                    _voiceAssistantEnabled =
                        value;
                  });

                  await VoiceAssistantService
                      .instance
                      .updateEnabled(value);

                  final ok =
                      await _updateUserPreference(
                    'voiceAssistant',
                    value,
                  );

                  if (!ok) {
                    setState(() {
                      _voiceAssistantEnabled =
                          previous;
                    });

                    await VoiceAssistantService
                        .instance
                        .updateEnabled(
                      previous,
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        SnackBar(
                          content: Text(
                            loc.preferenceSaveError,
                          ),
                        ),
                      );
                    }
                  }
                },
                activeColor: primaryColor,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Content of the "Delete Account?" confirmation dialog.
class _DeleteAccountDialogContent
    extends StatefulWidget {
  const _DeleteAccountDialogContent({
    required this.requiredPhrase,
    required this.colorScheme,
    required this.deleteColor,
    required this.onConfirmed,
  });

  final String requiredPhrase;
  final ColorScheme colorScheme;
  final Color deleteColor;
  final VoidCallback onConfirmed;

  @override
  State<_DeleteAccountDialogContent> createState() =>
      _DeleteAccountDialogContentState();
}

class _DeleteAccountDialogContentState
    extends State<_DeleteAccountDialogContent> {
  late final TextEditingController _controller;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;
    final deleteColor = widget.deleteColor;
    final requiredDeletePhrase =
        widget.requiredPhrase;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.warning_rounded,
            color: deleteColor,
            size: 24,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              'Delete Account?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: deleteColor,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'This action will permanently delete your account and associated profile data. This cannot be undone.',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'Type "$requiredDeletePhrase" to confirm:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: deleteColor,
            ),
          ),

          const SizedBox(height: 8),

          TextField(
            controller: _controller,
            onChanged: (value) {
              if (_errorMessage != null) {
                setState(() {
                  _errorMessage = null;
                });
              }
            },
            style: TextStyle(
              color: colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: requiredDeletePhrase,
              hintStyle: TextStyle(
                color: colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.5),
              ),
              border: InputBorder.none,
              errorText: _errorMessage,
              errorStyle: TextStyle(
                color: deleteColor,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            HapticService().vibrate();
            Navigator.of(context).pop();
          },
          child: Text(
            'Cancel',
            style: TextStyle(
              color:
                  colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        TextButton(
          onPressed: () {
            if (_controller.text.trim() !=
                requiredDeletePhrase) {
              setState(() {
                _errorMessage =
                    'Please type $requiredDeletePhrase to confirm account deletion.';
              });

              return;
            }

            Navigator.of(context).pop();
            widget.onConfirmed();
          },
          child: Text(
            'Confirm',
            style: TextStyle(
              color: deleteColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown when deleteAccount() reports `reauthRequired`.
class _ReauthDialogContent
    extends StatefulWidget {
  const _ReauthDialogContent({
    required this.isGoogleAccount,
    required this.colorScheme,
    required this.accentColor,
    required this.authService,
    required this.onCredentialObtained,
  });

  final bool isGoogleAccount;
  final ColorScheme colorScheme;
  final Color accentColor;
  final AuthService authService;
  final void Function(
    AuthCredential credential,
  ) onCredentialObtained;

  @override
  State<_ReauthDialogContent> createState() =>
      _ReauthDialogContentState();
}

class _ReauthDialogContentState
    extends State<_ReauthDialogContent> {
  late final TextEditingController
      _passwordController;

  String? _errorMessage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _passwordController =
        TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleReauth() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final credential =
        await widget.authService
            .buildGoogleReauthCredential();

    if (!mounted) return;

    if (credential == null) {
      setState(() {
        _isProcessing = false;
        _errorMessage =
            'Google sign-in was cancelled. Please try again.';
      });

      return;
    }

    Navigator.of(context).pop();

    widget.onCredentialObtained(
      credential,
    );
  }

  void _handleEmailReauth() {
    final password =
        _passwordController.text;

    if (password.isEmpty) {
      setState(() {
        _errorMessage =
            'Please enter your password.';
      });

      return;
    }

    final credential =
        widget.authService
            .buildEmailReauthCredential(
      password,
    );

    if (credential == null) {
      setState(() {
        _errorMessage =
            'Could not verify your account. Please try again.';
      });

      return;
    }

    Navigator.of(context).pop();

    widget.onCredentialObtained(
      credential,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;
    final accentColor = widget.accentColor;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.lock_clock_rounded,
            color: accentColor,
            size: 24,
          ),

          const SizedBox(width: 8),

          const Expanded(
            child: Text(
              'Confirm It\'s You',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'For security, please verify your identity again before we permanently delete your account.',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 20),

          if (widget.isGoogleAccount) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : _handleGoogleReauth,
                icon: _isProcessing
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accentColor,
                        ),
                      )
                    : Icon(
                        Icons.login_rounded,
                        color: accentColor,
                      ),
                label: Text(
                  _isProcessing
                      ? 'Verifying...'
                      : 'Continue with Google',
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: accentColor,
                  backgroundColor:
                      colorScheme.surface,

                  // Visible shadow instead of an outline.
                  elevation: 3,
                  shadowColor: colorScheme.shadow
                      .withOpacity(0.22),

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),

                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ] else ...[
            TextField(
              controller: _passwordController,
              obscureText: true,
              onChanged: (value) {
                if (_errorMessage != null) {
                  setState(() {
                    _errorMessage = null;
                  });
                }
              },
              style: TextStyle(
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: TextStyle(
                  color: colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.5),
                ),
                border: InputBorder.none,
                errorText: _errorMessage,
                errorStyle: TextStyle(
                  color: accentColor,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            HapticService().vibrate();
            Navigator.of(context).pop();
          },
          child: Text(
            'Cancel',
            style: TextStyle(
              color:
                  colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        if (!widget.isGoogleAccount)
          TextButton(
            onPressed: _handleEmailReauth,
            child: Text(
              'Confirm',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}