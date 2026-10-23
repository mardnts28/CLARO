// lib/services/yolo_recognition_service_web.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import '../models/product_model.dart';

/// Web target implementation of [YoloRecognitionService].
///
/// Because `tflite_flutter` relies on native FFI (`dart:ffi`) which is unavailable
/// in browser JavaScript environments, this implementation provides a web-compatible
/// adapter so web targets compile cleanly without FFI errors.
class YoloRecognitionService {
  static final YoloRecognitionService _instance =
      YoloRecognitionService._internal();
  factory YoloRecognitionService() => _instance;
  YoloRecognitionService._internal();

  bool _isModelLoaded = false;
  bool get isModelLoaded => _isModelLoaded;

  List<int> get inputShape => const [1, 640, 640, 3];
  List<int> get outputShape => const [1, 61, 8400];

  double confidenceThreshold = 0.40;
  double iouThreshold = 0.45;

  bool get isInferring => false;

  Future<void> initialize() async {
    debugPrint(
      'YoloRecognitionService: Running on web platform. '
      'Native TFLite FFI is bypassed; web mock/server fallback mode active.',
    );
    _isModelLoaded = true;
  }

  Future<List<DetectionResult>> detectProducts(String imagePath) async {
    debugPrint('YoloRecognitionService (Web): Local detection requested for $imagePath');
    return [];
  }

  Future<List<DetectionResult>> detectProductsFromCameraImage(
    CameraImage cameraImage,
    int sensorOrientation,
  ) async {
    return [];
  }

  void dispose() {
    _isModelLoaded = false;
  }

  double applyConfidence(double raw) => raw;
}
