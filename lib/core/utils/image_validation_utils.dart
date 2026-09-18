import 'dart:io';
import 'package:flutter/material.dart';

/// Utility class for validating image files before upload.
/// 
/// Validates:
/// - File type (png, jpg, heic, webp)
/// - File size (maximum 5MB)
class ImageValidationUtils {
  /// Maximum allowed file size in bytes (5MB)
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB

  /// Allowed file extensions for image uploads
  static const List<String> allowedExtensions = ['png', 'jpg', 'jpeg', 'heic', 'webp'];

  /// Validates an image file based on type and size.
  /// 
  /// Returns a validation result containing:
  /// - isValid: true if the file passes all checks
  /// - errorMessage: null if valid, otherwise a user-friendly error message
  static ValidationResult validateImageFile(File file) {
    // Check file existence
    if (!file.existsSync()) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'File does not exist',
      );
    }

    // Check file size
    final fileSize = file.lengthSync();
    if (fileSize > maxFileSize) {
      final sizeInMB = (fileSize / (1024 * 1024)).toStringAsFixed(1);
      return ValidationResult(
        isValid: false,
        errorMessage: 'File size ($sizeInMB MB) exceeds the 5MB limit',
      );
    }

    // Check file extension
    final extension = file.path.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Invalid file type. Allowed: PNG, JPG, HEIC, WEBP',
      );
    }

    return ValidationResult(isValid: true, errorMessage: null);
  }

  /// Shows a snackbar with the validation error message.
  static void showValidationError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Result of image validation.
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  ValidationResult({required this.isValid, this.errorMessage});
}
