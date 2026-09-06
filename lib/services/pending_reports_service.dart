import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/success_feedback_utils.dart';
import '../data/services/backend_locator.dart';
import '../models/report_model.dart';

/// Manages offline-queued product reports and handles automatic upload/sync
/// when network connectivity is restored.
class PendingReportsService {
  static const String _storageKey = 'pending_unknown_product_reports';
  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);
  bool _isFlushing = false;

  PendingReportsService() {
    _initCount();
  }

  Future<void> _initCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_storageKey) ?? [];
      pendingCountNotifier.value = list.length;
    } catch (e) {
      debugPrint('PendingReportsService init count error: $e');
    }
  }

  /// Queues a pending report when offline.
  Future<void> queueReport({
    required String productName,
    required String category,
    required String reportedBy,
    required String userEmail,
    required String userName,
    String? frontImagePath,
    required String backImagePath,
    List<String> additionalBackImagePaths = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_storageKey) ?? [];

    final item = {
      'id': '${reportedBy}_${DateTime.now().millisecondsSinceEpoch}',
      'productName': productName,
      'category': category,
      'reportedBy': reportedBy,
      'userEmail': userEmail,
      'userName': userName,
      'frontImagePath': frontImagePath,
      'backImagePath': backImagePath,
      'additionalBackImagePaths': additionalBackImagePaths,
      'queuedAt': DateTime.now().toIso8601String(),
    };

    list.add(jsonEncode(item));
    await prefs.setStringList(_storageKey, list);
    pendingCountNotifier.value = list.length;
    debugPrint('PendingReportsService: queued report for "$productName". Total pending: ${list.length}');
  }

  /// Attempts to upload and submit any pending reports if internet connection is available.
  Future<int> flushPendingReports() async {
    if (_isFlushing) return 0;
    _isFlushing = true;

    try {
      final hasInternet = await SuccessFeedbackUtils.hasInternetConnection();
      if (!hasInternet) {
        debugPrint('PendingReportsService: cannot flush, no internet connection.');
        return 0;
      }

      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_storageKey) ?? [];
      if (list.isEmpty) return 0;

      debugPrint('PendingReportsService: flushing ${list.length} pending reports...');
      final remaining = <String>[];
      int flushedCount = 0;

      for (final raw in list) {
        bool success = false;
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          final uid = map['reportedBy'] as String? ?? 'anonymous';
          final email = map['userEmail'] as String? ?? '';
          final name = map['userName'] as String? ?? 'Anonymous';
          final productName = map['productName'] as String? ?? '';
          final category = map['category'] as String? ?? 'others';
          final frontPath = map['frontImagePath'] as String?;
          final backPath = map['backImagePath'] as String?;
          final additionalPaths = (map['additionalBackImagePaths'] as List?)
                  ?.cast<String>() ??
              const <String>[];

          // Read bytes from local files
          Uint8List frontBytes = Uint8List(0);
          if (frontPath != null && frontPath.isNotEmpty) {
            final file = File(frontPath);
            if (await file.exists()) {
              frontBytes = await file.readAsBytes();
            }
          }

          Uint8List backBytes = Uint8List(0);
          if (backPath != null && backPath.isNotEmpty) {
            final file = File(backPath);
            if (await file.exists()) {
              backBytes = await file.readAsBytes();
            }
          }

          final List<Uint8List> additionalBytesList = [];
          final List<Future<String?>> additionalUploads = [];
          for (int i = 0; i < additionalPaths.length; i++) {
            final file = File(additionalPaths[i]);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              additionalBytesList.add(bytes);
              additionalUploads.add(
                BackendLocator.cloudinaryUploadService.upload(
                  bytes,
                  filename: '${uid}_back_additional_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg',
                ),
              );
            }
          }

          // Upload images to Cloudinary
          final uploads = await Future.wait([
            frontBytes.isNotEmpty
                ? BackendLocator.cloudinaryUploadService.upload(
                    frontBytes,
                    filename: '${uid}_front_${DateTime.now().millisecondsSinceEpoch}.jpg',
                  )
                : Future<String?>.value(''),
            backBytes.isNotEmpty
                ? BackendLocator.cloudinaryUploadService.upload(
                    backBytes,
                    filename: '${uid}_back_${DateTime.now().millisecondsSinceEpoch}.jpg',
                  )
                : Future<String?>.value(''),
            ...additionalUploads,
          ]);

          final frontUrl = uploads[0] ?? '';
          final backUrl = uploads[1] ?? '';
          final additionalBackUrls = uploads
              .skip(2)
              .where((url) => url != null && url.isNotEmpty)
              .cast<String>()
              .toList();

          final report = ReportModel(
            id: '',
            dateSubmitted: DateTime.now(),
            productDescription: '',
            productName: productName,
            category: category,
            reportedBy: uid,
            status: 'Pending',
            userEmail: email,
            userName: name,
            frontImageUrl: frontUrl,
            backImageUrl: backUrl,
            additionalBackImageUrls: additionalBackUrls,
            extractedData: const {},
          );

          final docRef = await FirebaseFirestore.instance
              .collection('reports')
              .add(report.toMap());

          success = true;
          flushedCount++;
          debugPrint('PendingReportsService: successfully flushed report ${docRef.id} ($productName)');

          // Trigger background extraction
          if (frontBytes.isNotEmpty || backBytes.isNotEmpty || additionalBytesList.isNotEmpty) {
            unawaited(() async {
              try {
                final result = await BackendLocator.productExtractionService.extract(
                  frontImageBytes: frontBytes,
                  backImageBytes: backBytes,
                  additionalBackImageBytes: additionalBytesList,
                );
                await FirebaseFirestore.instance
                    .collection('reports')
                    .doc(docRef.id)
                    .update({
                  'extractedData': result.toReportExtractedDataMap(),
                });
              } catch (e) {
                debugPrint('PendingReportsService: background extraction warning: $e');
              }
            }());
          }
        } catch (e) {
          debugPrint('PendingReportsService: failed to flush report item: $e');
          success = false;
        }

        if (!success) {
          remaining.add(raw);
        }
      }

      await prefs.setStringList(_storageKey, remaining);
      pendingCountNotifier.value = remaining.length;
      return flushedCount;
    } finally {
      _isFlushing = false;
    }
  }
}
