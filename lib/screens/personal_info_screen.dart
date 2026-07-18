import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import '../generated/l10n/app_localizations.dart';
import '../widgets/voice_assistant_fab.dart';
import 'change_password_screen.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  static const _primaryRed = Color(0xFF8B1A1A);
  static const _lightRed = Color(0xFFFCE7E7);
  final _authService = AuthService();

  String _userName = 'User';
  String _userAge = '';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  bool _isSavingName = false;
  bool _isSavingAge = false;
  Map<String, bool> _conditions = {};
  Map<String, bool> _allergens = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  /// Loads the current user's profile (name, age, conditions,
  /// allergens) from Firestore, retrying on transient permission-denied
  /// errors.
  ///
  /// IMPORTANT: right after a password change, updatePassword() issues
  /// the user a fresh ID token. Firestore's security rules can take a
  /// brief moment to recognize that new token, so a read made shortly
  /// after can throw permission-denied even though the user is fully
  /// authenticated and the document is intact — the exact same race
  /// AuthService already retries around in isSessionValid() and
  /// _checkMfaEnabled(). Previously this method only tried the server
  /// once, fell back to a single plain .get() on any error, and if that
  /// SECOND read also hit the same propagation delay, the outer catch
  /// swallowed it — leaving name/age/conditions/allergens silently
  /// blank in the UI even though Firestore still had the data. This
  /// version retries a few times before giving up, matching the
  /// established pattern elsewhere in the app.
  Future<void> _loadUserData() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    DocumentSnapshot? userDoc;
    int retryCount = 0;
    while (retryCount < 3) {
      try {
        userDoc = await _authService.db
            .collection('users')
            .doc(uid)
            .get(const GetOptions(source: Source.server));
        break;
      } catch (e) {
        if (e.toString().contains('permission-denied')) {
          await Future.delayed(const Duration(milliseconds: 500));
          retryCount++;
          continue;
        }
        // Non-retryable error — fall back to whatever's cached locally
        // rather than giving up entirely.
        try {
          userDoc = await _authService.db.collection('users').doc(uid).get();
        } catch (e2) {
          debugPrint('Error loading user data (fallback failed): $e2');
        }
        break;
      }
    }

    if (userDoc == null) {
      debugPrint('Error loading user data: exhausted retries on permission-denied');
      // One last attempt against the cache before giving up, so a
      // transient server issue doesn't blank out data we already have
      // locally.
      try {
        userDoc = await _authService.db.collection('users').doc(uid).get();
      } catch (e) {
        debugPrint('Error loading user data (final fallback failed): $e');
      }
    }

    if (userDoc != null && userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>?;
      if (data != null) {
        setState(() {
          _userName = data['name'] ?? 'User';
          if (_userName.isEmpty) _userName = 'User';
          _nameController.text = _userName;

          _userAge = data['age'] ?? '';
          _ageController.text = _userAge;

          final conditionsList = data['conditions'] as List<dynamic>? ?? [];
          _conditions = {
            'Diabetes': conditionsList.contains('Diabetes'),
            'Alta-presyon': conditionsList.contains('Alta-presyon'),
            'Sakit sa puso': conditionsList.contains('Sakit sa puso'),
            'Mababang Paningin': conditionsList.contains('Mababang Paningin'),
            'Wala': conditionsList.contains('Wala'),
          };

          final allergensList = data['allergens'] as List<dynamic>? ?? [];
          _allergens = {
            'Isda': allergensList.contains('Isda'),
            'Gatas': allergensList.contains('Gatas'),
            'Itlog': allergensList.contains('Itlog'),
            'Soya': allergensList.contains('Soya'),
            'Trigo': allergensList.contains('Trigo'),
            'Lamang-Dagat': allergensList.contains('Lamang-Dagat'),
            'Mani': allergensList.contains('Mani'),
          };
        });
        // Keep the app-wide name notifier in sync so HomeScreen's
        // greeting and ProfileScreen's header reflect whatever this
        // screen just loaded, without needing a manual refresh.
        AuthService.userNameNotifier.value = _userName;
      }
    }

    // Always clear the loading flag, even if the doc didn't exist or
    // every read attempt failed — previously this was only set inside
    // the success branch, so a failed/empty read left the screen stuck
    // on its loading spinner indefinitely.
    if (mounted) setState(() => _isLoading = false);
  }

  /// Pull-to-refresh handler. Re-fetches the user's personal info,
  /// conditions and allergens from Firestore (server-first) and gives a
  /// short haptic tap for feedback while the refresh is in progress.
  Future<void> _onRefresh() async {
    HapticService().vibrate();
    await _loadUserData();
  }

  Future<void> _saveUserName(String newName) async {
    final loc = AppLocalizations.of(context)!;
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) return;
      setState(() => _isSavingName = true);
      final ok = await _authService.updateUserData({'name': newName});
      setState(() => _isSavingName = false);
      if (ok) {
        // Update the shared notifier immediately so HomeScreen's
        // greeting and ProfileScreen's header reflect the change right
        // away, rather than waiting on the Firestore round-trip below.
        AuthService.userNameNotifier.value = newName;
        await _loadUserData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.profileUpdateSuccess)));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.profileUpdateError)));
      }
    } catch (e) {
      debugPrint('Error saving user name: $e');
      setState(() => _isSavingName = false);
    }
  }

  Future<void> _saveUserAge(String newAge) async {
    final loc = AppLocalizations.of(context)!;
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) return;
      setState(() => _isSavingAge = true);
      final ok = await _authService.updateUserData({'age': newAge});
      setState(() => _isSavingAge = false);
      if (ok) {
        await _loadUserData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.profileUpdateSuccess)));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.profileUpdateError)));
      }
    } catch (e) {
      debugPrint('Error saving user age: $e');
      setState(() => _isSavingAge = false);
    }
  }

  void _showEditNameDialog() {
    HapticService().vibrate();
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        final dialogTheme = Theme.of(context);
        return AlertDialog(
          backgroundColor: dialogTheme.cardColor,
          title: Text(loc.editName, style: TextStyle(color: dialogTheme.colorScheme.onSurface)),
          content: TextField(
            controller: _nameController,
            decoration: InputDecoration(hintText: loc.onboardingNameHint, hintStyle: TextStyle(color: dialogTheme.colorScheme.onSurfaceVariant)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.cancel)),
            TextButton(
              onPressed: _isSavingName
                  ? null
                  : () async {
                final newName = _nameController.text.trim();
                if (newName.isEmpty) return;
                Navigator.pop(context);
                await _saveUserName(newName);
              },
              child: _isSavingName
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(loc.save),
            ),
          ],
        );
      },
    );
  }

  void _showEditAgeDialog() {
    HapticService().vibrate();
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        final dialogTheme = Theme.of(context);
        return AlertDialog(
          backgroundColor: dialogTheme.cardColor,
          title: Text(loc.editAge, style: TextStyle(color: dialogTheme.colorScheme.onSurface)),
          content: TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: loc.ageLabel, hintStyle: TextStyle(color: dialogTheme.colorScheme.onSurfaceVariant)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.cancel)),
            TextButton(
              onPressed: _isSavingAge
                  ? null
                  : () async {
                final newAge = _ageController.text.trim();
                if (newAge.isEmpty) return;
                Navigator.pop(context);
                await _saveUserAge(newAge);
              },
              child: _isSavingAge
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(loc.save),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateConditions() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        final selectedConditions = _conditions.entries.where((e) => e.value).map((e) => e.key).toList();
        final ok = await _authService.updateUserData({'conditions': selectedConditions});
        if (ok) await _loadUserData();
      }
    } catch (e) {
      debugPrint('Error updating conditions: $e');
    }
  }

  Future<void> _updateAllergens() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        final selectedAllergens = _allergens.entries.where((e) => e.value).map((e) => e.key).toList();
        final ok = await _authService.updateUserData({'allergens': selectedAllergens});
        if (ok) await _loadUserData();
      }
    } catch (e) {
      debugPrint('Error updating allergens: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: _onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme),
                const SizedBox(height: 24),
                _buildProfileCard(theme),
                const SizedBox(height: 20),
                _buildConditionsSection(theme),
                const SizedBox(height: 20),
                _buildAllergensSection(theme),
                const SizedBox(height: 20),
                _buildAccountSettings(theme),
                const SizedBox(height: 90),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: const VoiceAssistantFab(),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final loc = AppLocalizations.of(context)!;
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            HapticService().vibrate();
            Navigator.pop(context);
          },
          child: Icon(Icons.arrow_back, color: theme.colorScheme.primary, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            loc.personalInfo,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(ThemeData theme) {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.person, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showEditNameDialog(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${loc.onboardingNameHint}: $_userName', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                const SizedBox(width: 8),
                Icon(Icons.edit, size: 16, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _showEditAgeDialog(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${loc.ageLabel}: ${_userAge.isEmpty ? loc.none : _userAge}', style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface)),
                const SizedBox(width: 8),
                Icon(Icons.edit, size: 14, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionsSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_outline, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(loc.healthConditions, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 12),
          ..._conditions.entries.map((entry) {
            if (entry.key == 'Wala' || entry.key == 'None') return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.favorite, color: colorScheme.primary, size: 18),
                  const SizedBox(width: 12),
                  Expanded(child: Text(entry.key, style: TextStyle(fontSize: 14, color: colorScheme.onSurface))),
                  Switch(
                    value: entry.value,
                    onChanged: (value) {
                      HapticService().vibrate();
                      setState(() => _conditions[entry.key] = value);
                      _updateConditions();
                    },
                    activeThumbColor: colorScheme.primary,
                    activeTrackColor: colorScheme.primary.withAlpha(120),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAllergensSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    final selectedAllergens = _allergens.entries.where((e) => e.value).map((e) => e.key).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_outlined, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(loc.allergensLabel, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                ],
              ),
              GestureDetector(
                onTap: () {
                  HapticService().vibrate();
                  _showAllergenSelector();
                },
                child: Icon(Icons.add, color: colorScheme.primary, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedAllergens.map((allergen) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colorScheme.primary),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(allergen, style: TextStyle(fontSize: 13, color: colorScheme.primary)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        HapticService().vibrate();
                        setState(() => _allergens[allergen] = false);
                        _updateAllergens();
                      },
                      child: Icon(Icons.close, size: 16, color: colorScheme.primary),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSettings(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.settings_outlined, color: colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Text(loc.accountSettings, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
              ],
            ),
          ),
          Divider(height: 0, color: theme.dividerColor),
          GestureDetector(
            onTap: () async {
              HapticService().vibrate();
              // Await the push and reload afterwards. Under normal
              // circumstances this PersonalInfoScreen instance still
              // holds its previously-loaded state when we return, so
              // this reload is mostly a safety net — but it guarantees
              // the screen is always showing fresh data after a
              // password change, rather than relying on the instance
              // never having been recreated in between.
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
              if (mounted) await _loadUserData();
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(loc.changePassword, style: TextStyle(fontSize: 15, color: colorScheme.onSurface))),
                  Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAllergenSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final sheetTheme = Theme.of(context);
        final colorScheme = sheetTheme.colorScheme;
        final loc = AppLocalizations.of(context)!;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: sheetTheme.cardColor,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc.selectAllergen, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allergens.entries.map((entry) {
                  final isSelected = entry.value;
                  return GestureDetector(
                    onTap: () {
                      HapticService().vibrate();
                      setState(() => _allergens[entry.key] = !entry.value);
                      _updateAllergens();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? colorScheme.primary : colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colorScheme.primary, width: isSelected ? 2 : 1),
                      ),
                      child: Text(entry.key, style: TextStyle(fontSize: 13, color: isSelected ? colorScheme.onPrimary : colorScheme.primary)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}