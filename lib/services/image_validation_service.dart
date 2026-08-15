import 'dart:io';
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

  // Validate the image quality
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
      
      // Decode image (use small representation to avoid memory overload)
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

      // 1. Calculate Average Brightness
      double totalLuminance = 0;
      int pixelCount = 0;

      // Downsample calculations for performance (sample every 8th pixel)
      for (int y = 0; y < image.height; y += 8) {
        for (int x = 0; x < image.width; x += 8) {
          final pixel = image.getPixel(x, y);
          // Standard relative luminance formula (r*0.299 + g*0.587 + b*0.114)
          final r = pixel.r;
          final g = pixel.g;
          final b = pixel.b;
          final luminance = (r * 0.299 + g * 0.587 + b * 0.114);
          totalLuminance += luminance;
          pixelCount++;
        }
      }

      final avgBrightness = pixelCount > 0 ? (totalLuminance / pixelCount) : 0.0;

      // 2. Sharpness check: Calculate gradient variance (adjacent pixel difference)
      double totalDiff = 0;
      double squaredDiffSum = 0;
      int diffCount = 0;

      for (int y = 0; y < image.height - 8; y += 16) {
        for (int x = 0; x < image.width - 8; x += 16) {
          final p1 = image.getPixel(x, y);
          final p2 = image.getPixel(x + 4, y); // check horizontal difference

          final lum1 = (p1.r * 0.299 + p1.g * 0.587 + p1.b * 0.114);
          final lum2 = (p2.r * 0.299 + p2.g * 0.587 + p2.b * 0.114);

          final diff = (lum1 - lum2).abs();
          totalDiff += diff;
          squaredDiffSum += (diff * diff);
          diffCount++;
        }
      }

      // Variance of gradients is a good indicator of high frequency details/sharpness.
      final meanDiff = diffCount > 0 ? (totalDiff / diffCount) : 0.0;
      final variance = diffCount > 0 ? ((squaredDiffSum / diffCount) - (meanDiff * meanDiff)) : 0.0;

      // Normalize scores for easy debugging/readout [0.0 - 100.0]
      final brightnessScore = (avgBrightness / 2.55).clamp(0.0, 100.0); // 0-255 mapped to 0-100
      final sharpnessScore = (variance * 10).clamp(0.0, 100.0); // scaled variance

      // Thresholds:
      // Too Dark: Avg Brightness Score < 12.0 (relaxed from 18.0)
      // Blurry: Sharpness Score < 8.0 (relaxed from 12.0)
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
}
