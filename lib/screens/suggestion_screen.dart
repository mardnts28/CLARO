import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

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

  Future<void> _submit() async {
    if (_submitting) return;
    final text = _commentController.text.trim();
    if (_rating < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a rating between 1 and 5.')));
      return;
    }
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your suggestion before submitting.')));
      return;
    }
    if (text.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Suggestion must be 500 characters or less.')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mangyaring mag-sign in bago magpadala ng suhestiyon')));
        return;
      }

      await _authService.db.collection('suhestiyon').doc(uid).set({
        'uid': uid,
        'starNumber': _rating,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('Naipadala na ang Feedback!', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Maraming Salamat!\nMatagumpay na naipadala ang iyong Feedback.', textAlign: TextAlign.center),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Bumalik', style: TextStyle(color: Color(0xFF8B1A1A))),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('May error sa pagpapadala')));
    } finally {
      setState(() => _submitting = false);
    }
  }

  Widget _buildStars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final index = i + 1;
        return IconButton(
          onPressed: () => setState(() => _rating = index),
          icon: Icon(
            index <= _rating ? Icons.star : Icons.star_border,
            color: const Color(0xFF8B1A1A),
            size: 28,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyLarge = theme.textTheme.bodyLarge;
    final bodyMedium = theme.textTheme.bodyMedium;
    final bodySmall = theme.textTheme.bodySmall;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.primary),
        title: Text('Suhestiyon', style: TextStyle(color: theme.colorScheme.primary)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('Gusto naming marinig ang iyong opinyon.', style: bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 6)]),
              child: Column(
                children: [
                  Align(alignment: Alignment.centerLeft, child: Text('I-rate ang iyong karanasan', style: bodyMedium?.copyWith(fontSize: 14))),
                  const SizedBox(height: 8),
                  _buildStars(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 6)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ibahagi kung ano ang maaari naming i-improve', style: bodyMedium?.copyWith(fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentController,
                    minLines: 5,
                    maxLines: 8,
                    decoration: InputDecoration(
                      hintText: 'Isulat ang iyong mungkahi dito...',
                      hintStyle: bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.dividerColor)),
                    ),
                    style: bodyMedium?.copyWith(fontSize: 14),
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
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(_submitting ? 'Sending...' : 'Submit', style: TextStyle(fontSize: 16, color: theme.colorScheme.onPrimary)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      // FloatingActionButton removed: global mic overlay is used instead.
    );
  }
}
