import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/encryption_service.dart';
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

  Future<void> _loadUserData() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        late DocumentSnapshot userDoc;
        try {
          userDoc = await _authService.db.collection('users').doc(uid).get(GetOptions(source: Source.server));
        } catch (_) {
          userDoc = await _authService.db.collection('users').doc(uid).get();
        }
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>?;
          if (data != null) {
            setState(() {
              final rawName = data['name'] ?? '';
              final rawAge = data['age'] ?? '';
              _userName = EncryptionService.decryptText(rawName, uid);
              if (_userName.isEmpty) _userName = 'User';
              _nameController.text = _userName;

              _userAge = EncryptionService.decryptText(rawAge, uid);
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

              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveUserName(String newName) async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) return;
      setState(() => _isSavingName = true);
      final ok = await _authService.updateUserData({'name': newName});
      setState(() => _isSavingName = false);
      if (ok) {
        await _loadUserData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pangalan na-update')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hindi ma-save ang pangalan')));
      }
    } catch (e) {
      debugPrint('Error saving user name: $e');
      setState(() => _isSavingName = false);
    }
  }

  Future<void> _saveUserAge(String newAge) async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) return;
      setState(() => _isSavingAge = true);
      final ok = await _authService.updateUserData({'age': newAge});
      setState(() => _isSavingAge = false);
      if (ok) {
        await _loadUserData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edad na-update')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hindi ma-save ang edad')));
      }
    } catch (e) {
      debugPrint('Error saving user age: $e');
      setState(() => _isSavingAge = false);
    }
  }

  void _showEditNameDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final dialogTheme = Theme.of(context);
        return AlertDialog(
          backgroundColor: dialogTheme.cardColor,
          title: Text('I-edit ang pangalan', style: TextStyle(color: dialogTheme.colorScheme.onSurface)),
          content: TextField(
            controller: _nameController,
            decoration: InputDecoration(hintText: 'Pangalan', hintStyle: TextStyle(color: dialogTheme.colorScheme.onSurfaceVariant)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kanselahin')),
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
                  : const Text('I-save'),
            ),
          ],
        );
      },
    );
  }

  void _showEditAgeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final dialogTheme = Theme.of(context);
        return AlertDialog(
          backgroundColor: dialogTheme.cardColor,
          title: Text('I-edit ang edad', style: TextStyle(color: dialogTheme.colorScheme.onSurface)),
          content: TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: 'Edad', hintStyle: TextStyle(color: dialogTheme.colorScheme.onSurfaceVariant)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kanselahin')),
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
                  : const Text('I-save'),
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
            : SingleChildScrollView(
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
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, color: _primaryRed, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Personal na Impormasyon',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(ThemeData theme) {
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
                Text('Pangalan: $_userName', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
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
                Text('Edad: ${_userAge.isEmpty ? "Wala" : _userAge}', style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface)),
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
              Icon(Icons.favorite_outline, color: _primaryRed, size: 20),
              const SizedBox(width: 8),
              Text('Kondisyon sa Kalusugan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 12),
          ..._conditions.entries.map((entry) {
            if (entry.key == 'Wala') return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.favorite, color: _primaryRed, size: 18),
                  const SizedBox(width: 12),
                  Expanded(child: Text(entry.key, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface))),
                  Switch(
                    value: entry.value,
                    onChanged: (value) {
                      setState(() => _conditions[entry.key] = value);
                      _updateConditions();
                    },
                    activeThumbColor: _primaryRed,
                    activeTrackColor: _primaryRed.withAlpha(120),
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
                  Icon(Icons.warning_outlined, color: _primaryRed, size: 20),
                  const SizedBox(width: 8),
                  Text('Allergens', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                ],
              ),
              GestureDetector(onTap: () => _showAllergenSelector(), child: Icon(Icons.add, color: _primaryRed, size: 24)),
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
                  color: _lightRed,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _primaryRed),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(allergen, style: const TextStyle(fontSize: 13, color: _primaryRed)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        setState(() => _allergens[allergen] = false);
                        _updateAllergens();
                      },
                      child: const Icon(Icons.close, size: 16, color: _primaryRed),
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
                Icon(Icons.settings_outlined, color: _primaryRed, size: 20),
                const SizedBox(width: 12),
                Text('Account Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
              ],
            ),
          ),
          Divider(height: 0, color: theme.dividerColor),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, color: _primaryRed, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Baguhin ang password', style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface))),
                  Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant, size: 20),
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
              Text('Pumili ng Allergen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: sheetTheme.colorScheme.onSurface)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allergens.entries.map((entry) {
                  final isSelected = entry.value;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _allergens[entry.key] = !entry.value);
                      _updateAllergens();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? _primaryRed : _lightRed,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _primaryRed, width: isSelected ? 2 : 1),
                      ),
                      child: Text(entry.key, style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : _primaryRed)),
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
