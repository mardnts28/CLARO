import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a product report submitted by the user.
///
/// Fields match the Firestore `reports` collection schema. As of Phase 3,
/// a report carries front+back Cloudinary photo URLs (previously a single
/// local device file path, which meant nothing off-device -- admin
/// couldn't see submitted photos at all) plus the OCR + Gemini extraction
/// result (`extractedData`), so admin has structured, editable fields to
/// review instead of just a free-text name/description.
class ReportModel {
  final String id;
  final DateTime dateSubmitted;
  final String productDescription;
  final String productName;
  final String category;
  final String reportedBy;
  final String status;
  final String userEmail;
  final String userName;
  final String frontImageUrl;
  final String backImageUrl;

  /// Structured OCR + Gemini extraction output (brand, size, ingredients,
  /// nutrition, allergens, confidenceNotes) -- see
  /// ProductExtractionResult.toReportExtractedDataMap() for the exact
  /// shape. Empty map if extraction failed/timed out; admin review UI
  /// should treat that as "needs manual entry", not as verified data.
  final Map<String, dynamic> extractedData;

  ReportModel({
    required this.id,
    required this.dateSubmitted,
    required this.productDescription,
    required this.productName,
    required this.category,
    required this.reportedBy,
    required this.status,
    required this.userEmail,
    required this.userName,
    this.frontImageUrl = '',
    this.backImageUrl = '',
    this.extractedData = const {},
  });

  factory ReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle Timestamp parsing safely
    DateTime parsedDate;
    if (data['dateSubmitted'] is Timestamp) {
      parsedDate = (data['dateSubmitted'] as Timestamp).toDate();
    } else if (data['dateSubmitted'] is String) {
      parsedDate = DateTime.tryParse(data['dateSubmitted']) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return ReportModel(
      id: doc.id,
      dateSubmitted: parsedDate,
      productDescription: data['productDescription'] ?? '',
      productName: data['productName'] ?? '',
      category: data['category'] ?? 'others',
      reportedBy: data['reportedBy'] ?? '',
      status: data['status'] ?? 'Pending',
      userEmail: data['userEmail'] ?? '',
      userName: data['userName'] ?? '',
      frontImageUrl: data['frontImageUrl'] ?? '',
      backImageUrl: data['backImageUrl'] ?? '',
      extractedData: Map<String, dynamic>.from(data['extractedData'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dateSubmitted': FieldValue.serverTimestamp(),
      'productDescription': productDescription,
      'productName': productName,
      'category': category,
      'reportedBy': reportedBy,
      'status': status,
      'userEmail': userEmail,
      'userName': userName,
      'frontImageUrl': frontImageUrl,
      'backImageUrl': backImageUrl,
      'extractedData': extractedData,
    };
  }
}