import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a product report submitted by the user.
///
/// Fields match the Firestore `reports` collection deliverables schema.
class ReportModel {
  final String id;
  final DateTime dateSubmitted;
  final String productDescription;
  final String productName;
  final String reportedBy;
  final String status;
  final String userEmail;
  final String userName;

  ReportModel({
    required this.id,
    required this.dateSubmitted,
    required this.productDescription,
    required this.productName,
    required this.reportedBy,
    required this.status,
    required this.userEmail,
    required this.userName,
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
      reportedBy: data['reportedBy'] ?? '',
      status: data['status'] ?? 'Pending',
      userEmail: data['userEmail'] ?? '',
      userName: data['userName'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dateSubmitted': FieldValue.serverTimestamp(),
      'productDescription': productDescription,
      'productName': productName,
      'reportedBy': reportedBy,
      'status': status,
      'userEmail': userEmail,
      'userName': userName,
    };
  }
}
