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
  // True while an account-deletion request is in flight. Drives an
  // in-place loading overlay in build() below -- deliberately NOT a
  // separate dialog/route, so there's nothing left over to race against
  // AuthGate's reactive teardown of this whole screen once the Auth
  // account is actually deleted. See _performAccountDeletion for why.
  bool _isDeletingAccount = false;
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

    return Stack(
      children: [
        RefreshIndicator(
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
        ),
        // Deliberately an in-place overlay within THIS screen's own
        // subtree, not a separate showDialog()/Route. A separate route
        // would sit on top of HomeScreen in the Navigator while
        // AuthGate reactively swaps HomeScreen for LoginScreen out from
        // under it -- the same kind of teardown race that caused the
        // _dependents.isEmpty assertion. Because this overlay lives
        // inside ProfileScreen's own widget tree, it tears down
        // atomically with the rest of this screen when AuthGate
        // replaces it, instead of racing it.
        if (_isDeletingAccount)
          Positioned.fill(
            child: ColoredBox(
              color: colorScheme.surface.withOpacity(0.7),
              child: Center(
                child: CircularProgressIndicator(color: primaryColor),
              ),
            ),
          ),
      ],
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

    // The phrase the user must type is derived from their current
    // username/name (e.g. "DELETE-john"), not a static "DELETE". Captured
    // once when the dialog opens so it stays stable for the lifetime of
    // the dialog even if _userName were to change underneath it.
    final String requiredDeletePhrase = 'DELETE-$_userName';

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
                    'Type "$requiredDeletePhrase" to confirm:',
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
                      hintText: requiredDeletePhrase,
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
                    // NOTE: no longer forcing TextCapitalization.characters.
                    // The required phrase now embeds the user's name in its
                    // original case (e.g. "DELETE-John") and the comparison
                    // below is case-sensitive, so nudging the keyboard
                    // toward all-caps input would make it harder, not
                    // easier, for users to type a matching phrase.
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    HapticService().vibrate();
                    deleteController.dispose();
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (deleteController.text.trim() != requiredDeletePhrase) {
                      setState(() {
                        errorMessage =
                            'Please type $requiredDeletePhrase to confirm account deletion.';
                      });
                      return;
                    }

                    // Close the dialog RIGHT NOW, synchronously, before any
                    // async work starts -- do not wait for
                    // _authService.deleteAccount() first.
                    //
                    // deleteAccount() ends by deleting the Firebase Auth
                    // user, and this app's root widget (AuthGate in
                    // main.dart) wraps HomeScreen/ProfileScreen in a
                    // StreamBuilder on FirebaseAuth.authStateChanges().
                    // That stream can emit `null` -- and AuthGate can
                    // react by tearing HomeScreen down and swapping in
                    // LoginScreen -- before control even returns to this
                    // callback from the `await` below. If this dialog's
                    // route were still open when that happens, it would
                    // be a second, independent teardown of HomeScreen's
                    // subtree racing the one AuthGate is already doing,
                    // which is exactly what threw "Failed assertion:
                    // '_dependents.isEmpty'": an InheritedElement
                    // unmounted while a dependent element from the
                    // still-open dialog route hadn't detached yet. Popping
                    // the dialog first, before deletion even begins,
                    // means there's no dialog route left to race against
                    // that rebuild.
                    deleteController.dispose();
                    Navigator.of(dialogContext).pop();

                    _performAccountDeletion();
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
          },
        );
      },
    );
  }

  /// Runs the actual account deletion after the confirmation dialog has
  /// already been dismissed (see _showDeleteAccountDialog for why the
  /// dialog must be closed first).
  ///
  /// Progress is shown via `_isDeletingAccount`, an in-place overlay
  /// inside THIS screen's own build() -- not a separate dialog/route --
  /// so that if AuthGate swaps this whole screen out for LoginScreen
  /// partway through (which happens automatically, reactively, the
  /// moment the Firebase Auth account is actually deleted), the overlay
  /// tears down atomically along with everything else instead of being
  /// left dangling on top of a torn-down tree.
  Future<void> _performAccountDeletion() async {
    if (!mounted) return;
    setState(() {
      _isDeletingAccount = true;
    });

    final error = await _authService.deleteAccount();

    // If this screen is gone by the time we get here, AuthGate has
    // already reacted to the Auth account being deleted and replaced it
    // with LoginScreen -- deletion succeeded and there is nothing further
    // to do.
    if (!mounted) return;

    if (error != null) {
      // Deletion failed (and, per deleteAccount's Firestore-first
      // ordering, nothing was actually deleted), and AuthGate never
      // touched this screen -- so it's safe to update our own state and
      // show the error normally.
      setState(() {
        _isDeletingAccount = false;
      });
      final theme = Theme.of(context);
      final deleteColor = theme.brightness == Brightness.dark
          ? Colors.red
          : const Color(0xFF8B1A1A);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: deleteColor,
        ),
      );
      return;
    }

    // Success, but this screen hasn't been torn down yet (AuthGate's
    // rebuild hasn't landed this frame) -- leave _isDeletingAccount as
    // true so the overlay stays up. AuthGate will swap in LoginScreen
    // momentarily; there's nothing else for this screen to do.
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