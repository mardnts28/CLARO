import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/voice_assistant_service.dart';

/// Strongly-typed view of a single review document, so the rest of the
/// screen never touches raw, untyped Firestore map data directly.
/// Any malformed/missing field falls back to a safe default instead of
/// throwing at render time.
class _ReviewRecord {
  final String id;
  final int rating;
  final String text;
  final String status;
  final DateTime? createdAt;
  final String? adminReply;
  final DateTime? repliedAt;

  const _ReviewRecord({
    required this.id,
    required this.rating,
    required this.text,
    required this.status,
    required this.createdAt,
    required this.adminReply,
    required this.repliedAt,
  });

  factory _ReviewRecord.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final rawRating = data['starNumber'];
    final rating = rawRating is int
        ? rawRating
        : int.tryParse(rawRating?.toString() ?? '') ?? 0;

    final rawStatus = data['status'];
    final status = (rawStatus is String && rawStatus.trim().isNotEmpty)
        ? rawStatus.trim()
        : 'New';

    final rawText = data['text'];
    final text = rawText is String ? rawText : '';

    final rawReply = data['adminReply'];
    final adminReply = (rawReply is String && rawReply.trim().isNotEmpty)
        ? rawReply.trim()
        : null;

    return _ReviewRecord(
      id: doc.id,
      rating: rating.clamp(0, 5),
      text: text,
      status: status,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      adminReply: adminReply,
      repliedAt: (data['repliedAt'] is Timestamp)
          ? (data['repliedAt'] as Timestamp).toDate()
          : null,
    );
  }
}

class ReviewHistoryScreen extends StatefulWidget {
  const ReviewHistoryScreen({super.key});

  @override
  State<ReviewHistoryScreen> createState() => _ReviewHistoryScreenState();
}

class _ReviewHistoryScreenState extends State<ReviewHistoryScreen> {
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    if (_authService.currentUser != null && VoiceAssistantService.instance.isEnabled) {
      VoiceAssistantService.instance.announcePage('review_history');
    }
  }

  /// The list is already kept live by the underlying `.snapshots()`
  /// stream, so this doesn't need to manually splice new data in.
  /// Its job is just to force a round-trip to the server (bypassing any
  /// local cache), so a pull-to-refresh always reflects the latest
  /// admin status/reply even if the stream was paused — e.g. the app
  /// was backgrounded — and hasn't reconnected yet.
  Future<void> _handleRefresh() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    try {
      await _authService.db
          .collection('suhestiyon')
          .where('uid', isEqualTo: uid)
          .get(const GetOptions(source: Source.server));
    } catch (e) {
      debugPrint('Manual review refresh failed: $e');
    }
  }

  /// Wraps a centered message in a scrollable so RefreshIndicator's pull
  /// gesture still works on the error/empty states, not just the list.
  Widget _refreshableMessage(Widget message) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: Center(child: message),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _statusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'Resolved':
        return Colors.green;
      case 'In Progress':
        return Colors.orange;
      case 'New':
      default:
        return colorScheme.primary;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return DateFormat('MMM d, y • h:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final uid = _authService.currentUser?.uid;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.primary),
        // TODO(l10n): move to AppLocalizations, e.g. loc.reviewHistory
        title: Text('My Reviews', style: TextStyle(color: colorScheme.primary)),
      ),
      body: uid == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                // TODO(l10n): loc.needSignInToView (or similar)
                child: Text(
                  'Sign in to view your submitted reviews.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // Filter by uid only — sorting is done client-side below to
              // avoid requiring a composite Firestore index.
              stream: _authService.db
                  .collection('suhestiyon')
                  .where('uid', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _refreshableMessage(
                    Padding(
                      padding: const EdgeInsets.all(24),
                      // TODO(l10n): loc.loadReviewsError
                      child: Text(
                        'Could not load your reviews. Please try again later.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final records = snapshot.data!.docs
                    .map(_ReviewRecord.fromDoc)
                    .toList()
                  ..sort((a, b) {
                    final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                    final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                    return bDate.compareTo(aDate); // newest first
                  });

                if (records.isEmpty) {
                  return _refreshableMessage(
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.rate_review_outlined,
                              size: 40, color: colorScheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          // TODO(l10n): loc.noReviewsYet
                          Text(
                            'You haven\'t submitted a review yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: records.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildReviewCard(context, records[index]),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildReviewCard(BuildContext context, _ReviewRecord review) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = _statusColor(review.status, colorScheme);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    size: 18,
                    color: colorScheme.primary,
                  );
                }),
              ),
              _buildStatusBadge(review.status, statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.text.isEmpty ? '(No comment provided)' : review.text,
            style: TextStyle(
              color: review.text.isEmpty
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurface,
              fontStyle: review.text.isEmpty ? FontStyle.italic : FontStyle.normal,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatDate(review.createdAt),
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _buildReplySection(context, review),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildReplySection(BuildContext context, _ReviewRecord review) {
    final colorScheme = Theme.of(context).colorScheme;

    if (review.adminReply == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.hourglass_empty, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            // TODO(l10n): loc.awaitingResponse
            Text(
              'Awaiting response',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent, size: 14, color: colorScheme.primary),
              const SizedBox(width: 6),
              // TODO(l10n): loc.adminReplyLabel
              Text(
                'Response from support',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            review.adminReply!,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
          ),
          if (review.repliedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              _formatDate(review.repliedAt),
              style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}