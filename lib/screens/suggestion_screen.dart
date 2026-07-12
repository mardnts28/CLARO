import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import '../generated/l10n/app_localizations.dart';
import '../widgets/voice_assistant_fab.dart';
import 'review_history_screen.dart';

class SuggestionScreen extends StatefulWidget {
  const SuggestionScreen({super.key});

  @override
  State<SuggestionScreen> createState() => _SuggestionScreenState();
}

class _SuggestionScreenState extends State<SuggestionScreen> {
  final _authService = AuthService();
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// Looks up the current user's display name from their profile document,
  /// so it can be stored alongside the review. Falls back to an empty
  /// string if it can't be read — the review is still submitted either way.
  Future<String> _fetchUserName(String uid) async {
    try {
      final userDoc = await _authService.db.collection('users').doc(uid).get();
      final data = userDoc.data();
      final name = data?['name'];
      if (name is String && name.trim().isNotEmpty) {
        return name.trim();
      }
    } catch (e) {
      debugPrint('Error fetching user name for suggestion: $e');
    }
    return '';
  }

  Future<void> _submit() async {
    HapticService().vibrate();
    if (_submitting) return;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    final text = _commentController.text.trim();
    if (_rating < 1) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.ratePrompt)));
      return;
    }
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.suggestionEmpty)));
      return;
    }
    if (text.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.suggestionTooLong)));
      return;
    }

    setState(() => _submitting = true);
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.needSignInToSubmit)));
        return;
      }

      final userName = await _fetchUserName(uid);

      // Auto-generated document ID (instead of .doc(uid)) so each
      // submission is its own record and past reviews are never
      // overwritten by a later one.
      await _authService.db.collection('suhestiyon').add({
        'uid': uid,
        'userName': userName,
        'starNumber': _rating,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.suggestionSentTitle, style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
              const SizedBox(height: 8),
              Text(loc.suggestionSentBody, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurfaceVariant)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.backLabel, style: TextStyle(color: colorScheme.primary)),
            ),
          ],
        ),
      );

      // clear form
      setState(() {
        _rating = 0;
        _commentController.clear();
      });
    } catch (e) {
      debugPrint('Error submitting feedback: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.submitError)));
    } finally {
      setState(() => _submitting = false);
    }
  }

  Widget _buildStars() {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final index = i + 1;
        return IconButton(
          onPressed: () {
            HapticService().vibrate();
            setState(() => _rating = index);
          },
          icon: Icon(
            index <= _rating ? Icons.star : Icons.star_border,
            color: colorScheme.primary,
            size: 28,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    final bodyLarge = theme.textTheme.bodyLarge;
    final bodyMedium = theme.textTheme.bodyMedium;
    final bodySmall = theme.textTheme.bodySmall;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.primary),
        title: Text(loc.suggestion, style: TextStyle(color: colorScheme.primary)),
        actions: [
          IconButton(
            // TODO(l10n): add loc.reviewHistoryTooltip and use it here
            tooltip: 'My review history',
            icon: Icon(Icons.history, color: colorScheme.primary),
            onPressed: () {
              HapticService().vibrate();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReviewHistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(loc.suggestionIntro, style: bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.cardColor,
                  border: Border.all(color: theme.dividerColor),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)]),
              child: Column(
                children: [
                  Align(alignment: Alignment.centerLeft, child: Text(loc.rateYourExperience, style: bodyMedium?.copyWith(fontSize: 14, color: colorScheme.onSurface))),
                  const SizedBox(height: 8),
                  _buildStars(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.cardColor,
                  border: Border.all(color: theme.dividerColor),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.shareImprovement, style: bodyMedium?.copyWith(fontSize: 14, color: colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentController,
                    minLines: 5,
                    maxLines: 8,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: loc.suggestionHint,
                      hintStyle: bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.dividerColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.dividerColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colorScheme.primary)),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(_submitting ? loc.sending : loc.submit, style: TextStyle(fontSize: 16, color: colorScheme.onPrimary)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      floatingActionButton: const VoiceAssistantFab(),
    );
  }
}