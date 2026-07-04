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
    setState(() => _submitting = true);
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) {
        // Require sign-in for submitting suggestions
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mangyaring mag-sign in bago magpadala ng suhestiyon')));
        return;
      }

      await _authService.db.collection('suggestions').add({
        'uid': uid,
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF8B1A1A)),
        title: const Text('Suhestiyon', style: TextStyle(color: Color(0xFF8B1A1A))),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text('Gusto naming marinig ang iyong opinyon.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 6)]),
              child: Column(
                children: [
                  const Align(alignment: Alignment.centerLeft, child: Text('I-rate ang iyong karanasan', style: TextStyle(color: Colors.black87))),
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
                  const Text('Ibahagi kung ano ang maaari naming i-improve', style: TextStyle(color: Colors.black87)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentController,
                    minLines: 5,
                    maxLines: 8,
                    decoration: InputDecoration(
                      hintText: 'Isulat ang iyong mungkahi dito...',
                      hintStyle: TextStyle(color: Colors.black45),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                    style: const TextStyle(color: Colors.black87),
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
                  backgroundColor: const Color(0xFF8B1A1A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(_submitting ? 'Sending...' : 'Submit', style: const TextStyle(fontSize: 16, color: Colors.white)),
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
