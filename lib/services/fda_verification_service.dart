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
      final doc =
          await _db.collection('fda_products').doc(cprNumber).get();
      if (!doc.exists) {
        return FdaVerificationResult(
          status: FdaStatus.unverified,
          cprNumber: cprNumber,
        );
      }
      return _buildResult(doc.data()!);
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
    final statusStr =
        (data['registration_status'] as String? ?? '').toUpperCase();
    final validityStr = data['validity_date'] as String? ?? '';

    FdaStatus status;
    if (statusStr == 'ACTIVE') {
      // Also check validity date hasn't passed
      final validUntil = DateTime.tryParse(validityStr);
      if (validUntil != null && DateTime.now().isAfter(validUntil)) {
        status = FdaStatus.expired;
      } else {
        status = FdaStatus.active;
      }
    } else if (statusStr == 'EXPIRED') {
      status = FdaStatus.expired;
    } else {
      status = FdaStatus.unverified;
    }

    return FdaVerificationResult(
      status: status,
      cprNumber: data['cpr_number'] as String? ?? '',
      validityDate: validityStr,
      manufacturer: data['manufacturer'] as String? ?? '',
      productName: data['product_name'] as String? ?? '',
      brand: data['brand'] as String? ?? '',
    );
  }
}
