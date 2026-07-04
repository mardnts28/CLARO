import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class PreferenceScreen extends StatefulWidget {
  const PreferenceScreen({super.key});

  @override
  State<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends State<PreferenceScreen> {
  static const _primaryRed = Color(0xFF8B1A1A);
  final _authService = AuthService();

  String _selectedLanguage = 'English';
  double _speechRate = 0.5;
  double _speechVolume = 0.7;
  bool _vibrationFeedback = false;
  double _textSize = 1.0;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        final doc = await _authService.db.collection('users').doc(uid).get();
        final data = doc.data();
        if (data != null) {
          setState(() {
            _selectedLanguage = data['language'] ?? 'English';
            _speechRate = (data['speechRate'] != null) ? (data['speechRate'] as num).toDouble() : 0.5;
            _speechVolume = (data['speechVolume'] != null) ? (data['speechVolume'] as num).toDouble() : 0.7;
            _vibrationFeedback = data['vibrationFeedback'] ?? false;
            _textSize = (data['textSize'] != null) ? (data['textSize'] as num).toDouble() : 1.0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }

  Future<bool> _savePref(String key, dynamic value) async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        final ok = await _authService.updateUserData({key: value});
        if (!ok) return false;

        // Try to reload fresh server data to avoid cache overwrites
        try {
          final doc = await _authService.db.collection('users').doc(uid).get(GetOptions(source: Source.server));
          final data = doc.data();
          if (data != null) {
            setState(() {
              _selectedLanguage = data['language'] ?? _selectedLanguage;
              _speechRate = (data['speechRate'] != null) ? (data['speechRate'] as num).toDouble() : _speechRate;
              _speechVolume = (data['speechVolume'] != null) ? (data['speechVolume'] as num).toDouble() : _speechVolume;
              _vibrationFeedback = data['vibrationFeedback'] ?? _vibrationFeedback;
              _textSize = (data['textSize'] != null) ? (data['textSize'] as num).toDouble() : _textSize;
            });
          }
        } catch (_) {
          // ignore server reload failures
        }
        return true;
      }
    } catch (e) {
      debugPrint('Error saving pref: $e');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _primaryRed),
        title: const Text('Preference', style: TextStyle(color: _primaryRed)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Boses at Tunog', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedLanguage,
                        items: const [
                          DropdownMenuItem(value: 'English', child: Text('English')),
                          DropdownMenuItem(value: 'Tagalog', child: Text('Tagalog')),
                        ],
                        onChanged: (v) async {
                          if (v == null) return;
                          setState(() => _selectedLanguage = v);
                          final ok = await _savePref('language', v);
                          if (!ok && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hindi ma-save ang preference')));
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Bilis Ng Pagsasalita', style: TextStyle(fontSize: 13, color: Colors.black87)),
                  Slider(
                    value: _speechRate,
                    min: 0.3,
                    max: 1.2,
                    divisions: 9,
                    onChanged: (v) async {
                      setState(() => _speechRate = v);
                      final ok = await _savePref('speechRate', v);
                      if (!ok && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hindi ma-save ang preference')));
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.volume_mute, color: Colors.black54),
                      Expanded(
                        child: Slider(
                          value: _speechVolume,
                          min: 0.0,
                          max: 1.0,
                          onChanged: (v) async {
                            setState(() => _speechVolume = v);
                            final ok = await _savePref('speechVolume', v);
                            if (!ok && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hindi ma-save ang preference')));
                            }
                          },
                        ),
                      ),
                      const Icon(Icons.volume_up, color: Colors.black54),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preview ng audio')));
                      },
                      icon: const Icon(Icons.play_arrow, color: Color(0xFF8B1A1A)),
                      label: const Text('I-tap para sa preview ng audio', style: TextStyle(color: Color(0xFF8B1A1A))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF8B1A1A)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pisikal na Tugon', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey.shade100),
                            child: const Icon(Icons.vibration_outlined, color: Color(0xFF8B1A1A)),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Vibration Feedback', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              const SizedBox(
                                width: 220,
                                child: Text('Vibrate on scan, alerts, and reads', style: TextStyle(fontSize: 12, color: Colors.black54)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _vibrationFeedback,
                        onChanged: (v) async {
                          setState(() => _vibrationFeedback = v);
                          final ok = await _savePref('vibrationFeedback', v);
                          if (!ok && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hindi ma-save ang preference')));
                          }
                        },
                        activeColor: _primaryRed,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Laki ng Teksto', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('A', style: TextStyle(fontSize: 16)),
                      Expanded(
                        child: Slider(
                          value: _textSize,
                          min: 0.8,
                          max: 1.4,
                          onChanged: (v) async {
                            setState(() => _textSize = v);
                            final ok = await _savePref('textSize', v);
                            if (!ok && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hindi ma-save ang preference')));
                            }
                          },
                        ),
                      ),
                      const Text('A', style: TextStyle(fontSize: 22)),
                    ],
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
