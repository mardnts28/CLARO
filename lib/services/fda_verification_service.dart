import 'package:cloud_firestore/cloud_firestore.dart';

enum FdaStatus { active, expired, unverified }

class FdaVerificationResult {
  final FdaStatus status;
  final String cprNumber;
  final String validityDate;
  final String manufacturer;
  final String productName;
  final String brand;

  const FdaVerificationResult({
    required this.status,
    this.cprNumber = '',
    this.validityDate = '',
    this.manufacturer = '',
    this.productName = '',
    this.brand = '',
  });

  bool get isActive => status == FdaStatus.active;
  bool get isExpired => status == FdaStatus.expired;
  bool get isUnverified => status == FdaStatus.unverified;

  /// Human-readable label for display
  String get statusLabel {
    switch (status) {
      case FdaStatus.active:
        return 'ACTIVE';
      case FdaStatus.expired:
        return 'EXPIRED';
      case FdaStatus.unverified:
        return 'UNVERIFIED';
    }
  }
}

class FdaVerificationService {
  static final FdaVerificationService _instance =
      FdaVerificationService._internal();
  factory FdaVerificationService() => _instance;
  FdaVerificationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Verify by CPR / Registration Number ────────────────────────────────
  Future<FdaVerificationResult> verifyByCprNumber(String cprNumber) async {
    if (cprNumber.isEmpty) {
      return const FdaVerificationResult(status: FdaStatus.unverified);
    }
    try {
      // fda_products documents use auto-generated IDs, not the CPR number --
      // cpr_number is a regular field, so this has to be a query, not a
      // direct .doc() lookup.
      final query = await _db
          .collection('fda_products')
          .where('cpr_number', isEqualTo: cprNumber)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return FdaVerificationResult(
          status: FdaStatus.unverified,
          cprNumber: cprNumber,
        );
      }
      return _buildResult(query.docs.first.data());
    } catch (_) {
      return const FdaVerificationResult(status: FdaStatus.unverified);
    }
  }

  // ─── Verify by product name (fuzzy match) ───────────────────────────────
  Future<FdaVerificationResult> verifyByProductName(
      String productName) async {
    if (productName.isEmpty) {
      return const FdaVerificationResult(status: FdaStatus.unverified);
    }
    try {
      // Exact match first
      final exact = await _db
          .collection('fda_products')
          .where('product_name', isEqualTo: productName)
          .limit(1)
          .get();

      if (exact.docs.isNotEmpty) {
        return _buildResult(exact.docs.first.data());
      }

      // Partial match: search by brand name prefix
      final words = productName.trim().split(' ');
      if (words.isEmpty) {
        return const FdaVerificationResult(status: FdaStatus.unverified);
      }
      final firstWord = words.first;
      final partial = await _db
          .collection('fda_products')
          .where('product_name',
              isGreaterThanOrEqualTo: firstWord)
          .where('product_name',
              isLessThanOrEqualTo: '$firstWord\uf8ff')
          .limit(5)
          .get();

      if (partial.docs.isNotEmpty) {
        return _buildResult(partial.docs.first.data());
      }

      return const FdaVerificationResult(status: FdaStatus.unverified);
    } catch (_) {
      return const FdaVerificationResult(status: FdaStatus.unverified);
    }
  }

  FdaVerificationResult _buildResult(Map<String, dynamic> data) {
    // registration_status can be a bool (true/false) OR a String
    // ("verified", "ACTIVE", "active", "registered") depending on how
    // documents were added to Firestore. Handle both gracefully.
    final rawStatus = data['registration_status'];
    final bool isRegistered;
    if (rawStatus is bool) {
      isRegistered = rawStatus;
    } else if (rawStatus is String) {
      final s = rawStatus.toLowerCase().trim();
      isRegistered = s == 'verified' || s == 'active' || s == 'registered' || s == 'true';
    } else {
      isRegistered = false;
    }

    final validityTimestamp = data['validity_date'] as Timestamp?;
    final validUntil = validityTimestamp?.toDate();

    // registration_status: true means the product is actively verified/
    // registered, so status is 'active' unless validity_date has already
    // passed, in which case it's 'expired'. registration_status: false
    // covers unverified, expired-in-FDA's-own-records, and pending all at
    // once (the source data doesn't distinguish between them), so it maps
    // to 'unverified' -- the label that doesn't claim more than the data
    // actually tells us.
    FdaStatus status;
    if (isRegistered) {
      if (validUntil != null && DateTime.now().isAfter(validUntil)) {
        status = FdaStatus.expired;
      } else {
        status = FdaStatus.active;
      }
    } else {
      status = FdaStatus.unverified;
    }

    return FdaVerificationResult(
      status: status,
      cprNumber: data['cpr_number'] as String? ?? '',
      // Kept as a String on FdaVerificationResult for backward compatibility
      // with existing callers; formatted here rather than passing the raw
      // Timestamp through.
      validityDate: validUntil != null ? _formatDate(validUntil) : '',
      manufacturer: data['manufacturer'] as String? ?? '',
      productName: data['product_name'] as String? ?? '',
      brand: data['brand'] as String? ?? '',
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}