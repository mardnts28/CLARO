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

const String claroWebsiteUrl = 'https://claro-52ia.onrender.com/';
const String privacyPolicyUrl = 'https://claro-52ia.onrender.com/privacy-policy';
const String termsConditionsUrl = 'https://claro-52ia.onrender.com/terms-and-conditions';
const String userGuideUrl = 'https://claro-52ia.onrender.com/user-guide';

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    final primaryColor = theme.brightness == Brightness.dark
        ? Colors.red
        : colorScheme.primary;

    return RefreshIndicator(
      color: primaryColor,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
            label: loc.privacyPolicy,
            onTap: () {
              HapticService().vibrate();
              _launchUrl(privacyPolicyUrl);
            },
          ),
          Divider(height: 0, color: colorScheme.outlineVariant),
          _buildMenuItemWithArrow(
            icon: Icons.description_outlined,
            label: loc.termsConditions,
            onTap: () {
              HapticService().vibrate();
              _launchUrl(termsConditionsUrl);
            },
          ),
          Divider(height: 0, color: colorScheme.outlineVariant),
          _buildMenuItemWithArrow(
            icon: Icons.menu_book_outlined,
            label: loc.userGuide,
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
                onPressed: () {
                  HapticService().vibrate();
                  _showDeleteAccountDialog();
                },
                child: Text(
                  'Delete Account',
                  style: TextStyle(
                    fontSize: 15,
                    color: theme.brightness == Brightness.dark
                        ? Colors.red
                        : const Color(0xFF8B1A1A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
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
                    color: theme.brightness == Brightness.dark
                        ? Colors.red
                        : colorScheme.primary,
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

  void _showDeleteAccountDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final deleteColor = theme.brightness == Brightness.dark
        ? Colors.red
        : const Color(0xFF8B1A1A);
    String? errorMessage;
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        final TextEditingController deleteController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    'Type "DELETE" to confirm:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: deleteColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: deleteController,
                    onChanged: (value) {
                      setState(() {
                        errorMessage = null;
                      });
                    },
                    style: TextStyle(
                      color: colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'DELETE',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: deleteColor, width: 2),
                      ),
                      errorText: errorMessage,
                      errorStyle: TextStyle(
                        color: deleteColor,
                      ),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  if (isDeleting) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: CircularProgressIndicator(
                        color: deleteColor,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () {
                          HapticService().vibrate();
                          deleteController.dispose();
                          Navigator.of(dialogContext).pop();
                        },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDeleting
                          ? colorScheme.onSurfaceVariant.withOpacity(0.5)
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          if (deleteController.text.trim() != 'DELETE') {
                            setState(() {
                              errorMessage = 'Please type DELETE to confirm account deletion.';
                            });
                            return;
                          }

                          setState(() {
                            isDeleting = true;
                          });

                          final error = await _authService.deleteAccount();

                          if (!mounted) return;

                          if (error != null) {
                            // Deletion failed: just close the dialog and
                            // surface the error via a snackbar. Nothing
                            // else on the widget tree is torn down here,
                            // so the plain pop + post-frame snackbar is
                            // fine as before.
                            deleteController.dispose();
                            Navigator.of(dialogContext).pop();

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(error),
                                    backgroundColor: deleteColor,
                                  ),
                                );
                              }
                            });
                            return;
                          }

                          // Success path: dismiss the dialog AND redirect
                          // to Login in a single atomic Navigator
                          // transaction instead of popping the dialog and
                          // separately pushing a replacement afterward.
                          //
                          // Doing those as two separate operations raced
                          // the dialog route's pop/exit transition against
                          // the teardown of HomeScreen's much larger
                          // subtree (the IndexedStack tabs — including
                          // this very ProfileScreen — and everything that
                          // consumes Theme/MediaQuery/etc. inside it).
                          // That inconsistent teardown order is what threw
                          // "Failed assertion: '_dependents.isEmpty'":
                          // an InheritedElement further up the tree was
                          // unmounting before a dependent element from the
                          // still-animating-out dialog route had fully
                          // detached.
                          //
                          // pushNamedAndRemoveUntil on the ROOT navigator
                          // (the same one showDialog used) removes every
                          // route on the stack — the dialog's own route
                          // included — and pushes Login ('/') in one
                          // atomic step, so there's no in-between frame
                          // where the dialog is gone but HomeScreen isn't,
                          // or vice versa.
                          Navigator.of(context, rootNavigator: true)
                              .pushNamedAndRemoveUntil('/', (route) => false);

                          // Dispose the controller only after this frame's
                          // teardown has actually run, so the TextField's
                          // own dispose() (which calls removeListener on
                          // it) always runs before the controller itself
                          // is freed.
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            deleteController.dispose();
                          });
                        },
                  child: Text(
                    isDeleting ? 'Deleting...' : 'Confirm',
                    style: TextStyle(
                      color: isDeleting
                          ? deleteColor.withOpacity(0.5)
                          : deleteColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
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
    final primaryColor = theme.brightness == Brightness.dark
        ? Colors.red
        : colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Icon(icon, color: primaryColor, size: 20),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = theme.brightness == Brightness.dark
        ? Colors.red
        : colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.dark_mode_outlined, color: primaryColor, size: 20),
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
            activeColor: primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildMfaToggle() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    final primaryColor = theme.brightness == Brightness.dark
        ? Colors.red
        : colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.security_outlined, color: primaryColor, size: 20),
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
            activeColor: primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceAssistantToggle() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    final primaryColor = theme.brightness == Brightness.dark
        ? Colors.red
        : colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.mic_outlined, color: primaryColor, size: 20),
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
            activeColor: primaryColor,
          ),
        ],
      ),
    );
  }
}