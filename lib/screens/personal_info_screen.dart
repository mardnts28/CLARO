import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/custom_text_field.dart';
import '../core/utils/sanitizing_text_input_formatter.dart';
import '../core/utils/success_feedback_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import '../services/locale_service.dart';
import '../services/voice_assistant_service.dart';
import '../generated/l10n/app_localizations.dart';
import '../widgets/voice_assistant_fab.dart';
import '../data/services/backend_locator.dart';
import 'change_password_screen.dart';

// Base URL for the Cloudflare Worker that performs server-side encryption
// and decryption of health conditions/allergens. The key never lives on
// the client -- see health-data-worker/ for the Worker implementation.
const _workerUrl = 'https://health-data-worker.claro-app.workers.dev';
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _authService = AuthService();

  String _userName = 'User';
  final TextEditingController _nameController = TextEditingController();
  bool _isSavingName = false;
  Map<String, bool> _conditions = {};
  Map<String, bool> _allergens = {};
  bool _isLoading = true;

  // Date of birth is stored once during onboarding and never edited here.
  // Age is always derived from it at load time rather than stored/edited
  // directly, so it can never drift out of sync with the actual date.
  DateTime? _dateOfBirth;
  int? _age;

  /// Computes age in whole years from [dateOfBirth] as of "now", correctly
  /// accounting for whether the birthday has occurred yet this year.
  int _calculateAge(DateTime dateOfBirth) {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    final birthdayHasOccurredThisYear = (now.month > dateOfBirth.month) ||
        (now.month == dateOfBirth.month && now.day >= dateOfBirth.day);
    if (!birthdayHasOccurredThisYear) {
      age--;
    }
    return age;
  }

  /// Fetches the current user's decrypted conditions/allergens from the
  /// Cloudflare Worker. Returns null on failure (missing token, network
  /// error, non-200 response) so callers can fail gracefully rather than
  /// crash the whole screen load.
  Future<Map<String, dynamic>?> _fetchHealthData() async {
    try {
      final idToken = await _authService.currentUser?.getIdToken();
      if (idToken == null) return null;

      final res = await http.get(
        Uri.parse('$_workerUrl/health-profile'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      if (res.statusCode != 200) {
        debugPrint('Worker health-profile fetch failed: ${res.statusCode} ${res.body}');
        return null;
      }
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error fetching health data from Worker: $e');
      return null;
    }
  }

  /// Sends updated conditions/allergens to the Cloudflare Worker, which
  /// encrypts them server-side before writing to Firestore. Only the
  /// field(s) provided are updated -- pass null to leave a field
  /// unchanged.
  Future<bool> _pushHealthData({List<String>? conditions, List<String>? allergens}) async {
    try {
      final idToken = await _authService.currentUser?.getIdToken();
      if (idToken == null) return false;

      final res = await http.post(
        Uri.parse('$_workerUrl/health-profile'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          if (conditions != null) 'conditions': conditions,
          if (allergens != null) 'allergens': allergens,
        }),
      );
      if (res.statusCode != 200) {
        debugPrint('Worker health-profile update failed: ${res.statusCode} ${res.body}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error pushing health data to Worker: $e');
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    if (_authService.currentUser != null) {
      VoiceAssistantService.instance.announcePage('personal_info');
    }
    _loadUserData();
    // Listen for language changes to refresh the UI with localized labels
    LocaleService.localeNotifier.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() {
    if (mounted) {
      setState(() {}); // Force rebuild to update localized labels
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    LocaleService.localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  /// Loads the current user's profile (name, conditions,
  /// allergens), retrying on transient permission-denied errors for the
  /// Firestore-held plain fields.
  ///
  /// IMPORTANT: right after a password change, updatePassword() issues
  /// the user a fresh ID token. Firestore's security rules can take a
  /// brief moment to recognize that new token, so a read made shortly
  /// after can throw permission-denied even though the user is fully
  /// authenticated and the document is intact — the exact same race
  /// AuthService already retries around in isSessionValid() and
  /// _checkMfaEnabled(). This method retries a few times before giving
  /// up, matching the established pattern elsewhere in the app.
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

    // Conditions/allergens no longer live in this Firestore doc read at
    // all -- they're encrypted at rest, so they're fetched separately
    // through the Cloudflare Worker, which verifies this user's ID token
    // and decrypts server-side. Fetched in parallel with the Firestore
    // read finishing above since the two are independent.
    final healthData = await _fetchHealthData();

    if (userDoc != null && userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>?;
      if (data != null) {
        setState(() {
          _userName = data['name'] ?? 'User';
          if (_userName.isEmpty) _userName = 'User';
          _nameController.text = _userName;

          // dateOfBirth is stored as a Firestore Timestamp (see
          // AuthService.saveOnboardingData). Age is always recalculated
          // from it here rather than read from any stored "age" value, so
          // it stays accurate as time passes.
          final dobValue = data['dateOfBirth'];
          if (dobValue is Timestamp) {
            _dateOfBirth = dobValue.toDate();
            _age = _calculateAge(_dateOfBirth!);
          } else {
            _dateOfBirth = null;
            _age = null;
          }

          final conditionsList = List<String>.from(healthData?['conditions'] ?? []);
          _conditions = {
            'Diabetes': conditionsList.contains('Diabetes') || conditionsList.contains('Diabetes'),
            'Hypertension': conditionsList.contains('Hypertension') || conditionsList.contains('Alta-presyon'),
            'Heart condition': conditionsList.contains('Heart condition') || conditionsList.contains('Sakit sa puso'),
            'Low vision': conditionsList.contains('Low vision') || conditionsList.contains('Mababang Paningin'),
            'None': conditionsList.contains('None') || conditionsList.contains('Wala'),
          };

          final allergensList = List<String>.from(healthData?['allergens'] ?? []);
          _allergens = {
            'Fish': allergensList.contains('Fish') || allergensList.contains('Isda'),
            'Milk/Dairy': allergensList.contains('Milk/Dairy') || allergensList.contains('Gatas'),
            'Eggs': allergensList.contains('Eggs') || allergensList.contains('Itlog'),
            'Soy': allergensList.contains('Soy') || allergensList.contains('Soya'),
            'Wheat': allergensList.contains('Wheat') || allergensList.contains('Trigo'),
            'Shellfish': allergensList.contains('Shellfish') || allergensList.contains('Lamang-Dagat'),
            'Peanuts': allergensList.contains('Peanuts') || allergensList.contains('Mani'),
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
  /// conditions and allergens (server-first) and gives a short haptic
  /// tap for feedback while the refresh is in progress.
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
        if (mounted) SuccessFeedbackUtils.showSuccessSnackBar(context, loc.profileUpdateSuccess);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.profileUpdateError)));
      }
    } catch (e) {
      debugPrint('Error saving user name: $e');
      setState(() => _isSavingName = false);
    }
  }

  void _showEditNameDialog() {
    HapticService().vibrate();
    final loc = AppLocalizations.of(context)!;
    String? dialogNameError;
    showDialog(
      context: context,
      builder: (context) {
        final dialogTheme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              backgroundColor: dialogTheme.cardColor,
              title: Text(loc.editName, style: TextStyle(color: dialogTheme.colorScheme.onSurface)),
              content: CustomTextField(
                controller: _nameController,
                hintText: loc.onboardingNameHint,
                errorText: dialogNameError,
                autofocus: true,
                inputFormatters: [SanitizingTextInputFormatter()],
                onChanged: (val) {
                  if (dialogNameError != null && val.trim().isNotEmpty) {
                    dialogSetState(() => dialogNameError = null);
                  }
                },
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.cancel)),
                TextButton(
                  onPressed: _isSavingName
                      ? null
                      : () async {
                    final newName = _nameController.text.trim();
                    if (newName.isEmpty) {
                      dialogSetState(() => dialogNameError = loc.onboardingNameHint);
                      return;
                    }
                    setState(() => _isSavingName = true);
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
      },
    );
  }

  Future<void> _updateConditions() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        // Always save English versions for consistency. Encryption now
        // happens server-side inside the Cloudflare Worker -- this
        // client only ever handles plaintext in memory, never the key.
        final selectedConditions = _conditions.entries.where((e) => e.value).map((e) => e.key).toList();
        final ok = await _pushHealthData(conditions: selectedConditions);
        if (ok) {
          BackendLocator.userRepository.invalidateCache(uid);
          await _loadUserData();
        }
      }
    } catch (e) {
      debugPrint('Error updating conditions: $e');
    }
  }

  Future<void> _updateAllergens() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        // Always save English versions for consistency. Encryption now
        // happens server-side inside the Cloudflare Worker.
        final selectedAllergens = _allergens.entries.where((e) => e.value).map((e) => e.key).toList();
        final ok = await _pushHealthData(allergens: selectedAllergens);
        if (ok) {
          BackendLocator.userRepository.invalidateCache(uid);
          await _loadUserData();
        }
      }
    } catch (e) {
      debugPrint('Error updating allergens: $e');
    }
  }

  String _getLocalizedConditionLabel(String key, AppLocalizations loc) {
    switch (key) {
      case 'Diabetes':
        return loc.conditionDiabetes;
      case 'Hypertension':
        return loc.conditionHypertension;
      case 'Heart condition':
        return loc.conditionHeartCondition;
      case 'Low vision':
        return loc.conditionLowVision;
      case 'None':
        return loc.conditionNone;
      default:
        return key;
    }
  }

  String _getLocalizedAllergenLabel(String key, AppLocalizations loc) {
    switch (key) {
      case 'Fish':
        return loc.allergenFish;
      case 'Milk/Dairy':
        return loc.allergenMilk;
      case 'Eggs':
        return loc.allergenEggs;
      case 'Soy':
        return loc.allergenSoy;
      case 'Wheat':
        return loc.allergenWheat;
      case 'Shellfish':
        return loc.allergenShellfish;
      case 'Peanuts':
        return loc.allergenPeanuts;
      default:
        return key;
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
          GestureDetector(
            onTap: () => _showEditNameDialog(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    '${loc.onboardingNameHint}: $_userName',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                    textAlign: TextAlign.center,
                    maxLines: null,
                    overflow: TextOverflow.visible,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.edit, size: 18, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
          if (_age != null) ...[
            const SizedBox(height: 4),
            // Display-only: age is always derived from the stored date of
            // birth (see _calculateAge) and is never directly editable.
            Text(
              '${loc.ageLabel}: $_age',
              style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
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
            final conditionLabel = _getLocalizedConditionLabel(entry.key, loc);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.favorite, color: colorScheme.primary, size: 18),
                  const SizedBox(width: 12),
                  Expanded(child: Text(conditionLabel, style: TextStyle(fontSize: 14, color: colorScheme.onSurface))),
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
                  final allergenLabel = _getLocalizedAllergenLabel(entry.key, loc);
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
                      child: Text(allergenLabel, style: TextStyle(fontSize: 13, color: isSelected ? colorScheme.onPrimary : colorScheme.primary)),
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