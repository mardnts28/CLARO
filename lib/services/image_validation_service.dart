import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageQualityResult {
  final bool isValid;
  final bool isTooDark;
  final bool isBlurry;
  final String message;
  final double brightnessScore;
  final double sharpnessScore;

  ImageQualityResult({
    required this.isValid,
    required this.isTooDark,
    required this.isBlurry,
    required this.message,
    required this.brightnessScore,
    required this.sharpnessScore,
  });
}

class ImageValidationService {
  static final ImageValidationService _instance = ImageValidationService._internal();
  factory ImageValidationService() => _instance;
  ImageValidationService._internal();

  // Validate the image quality off the main UI thread
  Future<ImageQualityResult> validateImageQuality(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return ImageQualityResult(
          isValid: false,
          isTooDark: false,
          isBlurry: false,
          message: "File not found.",
          brightnessScore: 0,
          sharpnessScore: 0,
        );
      }

      // Read image bytes
      final bytes = await file.readAsBytes();
      
      // Offload image decode and calculation to background isolate to avoid ANR
      return await compute(_validateImageQualityIsolate, bytes);
    } catch (e) {
      return ImageQualityResult(
        isValid: false,
        isTooDark: false,
        isBlurry: false,
        message: "Quality validation error: ${e.toString()}",
        brightnessScore: 50.0,
        sharpnessScore: 50.0,
      );
    }
  }
}

ImageQualityResult _validateImageQualityIsolate(Uint8List bytes) {
  try {
    final image = img.decodeImage(bytes);
    if (image == null) {
      return ImageQualityResult(
        isValid: false,
        isTooDark: false,
        isBlurry: false,
        message: "Unable to decode image.",
        brightnessScore: 0,
        sharpnessScore: 0,
      );
    }

    // 1. Calculate Average Brightness (sampling every 16th pixel for speed)
    double totalLuminance = 0;
    int pixelCount = 0;

    for (int y = 0; y < image.height; y += 16) {
      for (int x = 0; x < image.width; x += 16) {
        final pixel = image.getPixel(x, y);
        final luminance = (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114);
        totalLuminance += luminance;
        pixelCount++;
      }
    }

    final avgBrightness = pixelCount > 0 ? (totalLuminance / pixelCount) : 0.0;

    // 2. Sharpness check: Calculate gradient variance
    double totalDiff = 0;
    double squaredDiffSum = 0;
    int diffCount = 0;

    for (int y = 0; y < image.height - 16; y += 32) {
      for (int x = 0; x < image.width - 16; x += 32) {
        final p1 = image.getPixel(x, y);
        final p2 = image.getPixel(x + 8, y);

        final lum1 = (p1.r * 0.299 + p1.g * 0.587 + p1.b * 0.114);
        final lum2 = (p2.r * 0.299 + p2.g * 0.587 + p2.b * 0.114);

        final diff = (lum1 - lum2).abs();
        totalDiff += diff;
        squaredDiffSum += (diff * diff);
        diffCount++;
      }
    }

    final meanDiff = diffCount > 0 ? (totalDiff / diffCount) : 0.0;
    final variance = diffCount > 0 ? ((squaredDiffSum / diffCount) - (meanDiff * meanDiff)) : 0.0;

    final brightnessScore = (avgBrightness / 2.55).clamp(0.0, 100.0);
    final sharpnessScore = (variance * 10).clamp(0.0, 100.0);

    final bool isTooDark = brightnessScore < 12.0;
    final bool isBlurry = sharpnessScore < 8.0;

    String message = "Image quality is optimal.";
    bool isValid = true;

    if (isTooDark && isBlurry) {
      message = "Too dark and blurry. Turn on your flashlight and hold still.";
      isValid = false;
    } else if (isTooDark) {
      message = "Too dark. Please move to a brighter area or turn on flash.";
      isValid = false;
    } else if (isBlurry) {
      message = "Image blurry. Hold your phone steady and let the camera focus.";
      isValid = false;
    }

    return ImageQualityResult(
      isValid: isValid,
      isTooDark: isTooDark,
      isBlurry: isBlurry,
      message: message,
      brightnessScore: brightnessScore,
      sharpnessScore: sharpnessScore,
    );
  } catch (e) {
    return ImageQualityResult(
      isValid: false,
      isTooDark: false,
      isBlurry: false,
      message: "Quality validation error: ${e.toString()}",
      brightnessScore: 50.0,
      sharpnessScore: 50.0,
    );
  }
}
