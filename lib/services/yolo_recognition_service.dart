import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

import 'package:camera/camera.dart';
import '../models/product_model.dart';

/// Service for YOLOv8 object detection using tflite_flutter.
///
/// Design notes:
/// - Singleton so the model is loaded once and shared across the app.
/// - `initialize()` is idempotent and race-safe via `_isInitializing`.
/// - Live camera frames are processed entirely off the main thread:
///   preprocessing (YUV→RGB, letterbox, normalize) AND inference both
///   run inside a `compute()` isolate via `Interpreter.fromAddress()`.
/// - The isolate uses a single contiguous `Float32List` for the input
///   tensor instead of deeply nested `List<List<List<double>>>`. This
///   eliminates ~1.2M individual Dart object allocations per frame and
///   stops the GC-drop storm.
/// - GPU delegate is enabled on Android for hardware acceleration.
/// - Unconditional Sigmoid is applied to class score logits (`1 / (1 + e^-x)`).
class YoloRecognitionService {
  static final YoloRecognitionService _instance =
      YoloRecognitionService._internal();
  factory YoloRecognitionService() => _instance;
  YoloRecognitionService._internal();

  bool _isModelLoaded = false;
  bool _isInitializing = false;
  bool get isModelLoaded => _isModelLoaded;

  Interpreter? _interpreter;
  List<String> _labels = [];
  List<int> get inputShape => _inputShape;
  List<int> get outputShape => _outputShape;

  // Detection thresholds — tuned for real-world live camera recognition
  double confidenceThreshold = 0.10;
  double iouThreshold = 0.45;

  // Cached tensor metadata
  List<int> _inputShape = [];
  List<int> _outputShape = [];
  bool _isNCHW = false;

  // ── Initialize ─────────────────────────────────────────────────────────────

  /// Loads the TFLite model and labels. Safe to call multiple times;
  /// subsequent calls are no-ops once the model is loaded.
  Future<void> initialize() async {
    if (_isModelLoaded || _isInitializing) return;
    _isInitializing = true;
    try {
      debugPrint('YOLOv8: Loading model from assets/model/best-3.tflite …');

      // ── Hardware acceleration ──────────────────────────────────────────
      // Standard multi-threaded CPU execution (threads = 4) for FP32 model
      final options = InterpreterOptions()..threads = 4;
      String delegateName = 'CPU (Standard Multi-Threaded, Threads=4)';

      _interpreter = await Interpreter.fromAsset(
        'assets/model/best-3.tflite',
        options: options,
      );
      _interpreter!.allocateTensors();

      final labelsString =
          await rootBundle.loadString('assets/model/labels.json');
      final List<dynamic> jsonList = jsonDecode(labelsString);
      _labels = jsonList
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();

      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;
      // NCHW: [1, 3, H, W]  vs  NHWC: [1, H, W, 3]
      _isNCHW = _inputShape.length == 4 && _inputShape[1] == 3;

      // Diagnostic dump so we can verify tensor shapes in logs
      for (int i = 0; i < _interpreter!.getInputTensors().length; i++) {
        final t = _interpreter!.getInputTensor(i);
        debugPrint('  Input[$i]: shape=${t.shape}, type=${t.type}');
      }
      for (int i = 0; i < _interpreter!.getOutputTensors().length; i++) {
        final t = _interpreter!.getOutputTensor(i);
        debugPrint('  Output[$i]: shape=${t.shape}, type=${t.type}');
      }

      _isModelLoaded = true;
      debugPrint(
          'YOLOv8: Ready — ${_labels.length} classes, input=$_inputShape, '
          'output=$_outputShape, NCHW=$_isNCHW, delegate=$delegateName');
    } catch (e) {
      debugPrint('YOLOv8: Failed to load model — $e');
      _isModelLoaded = false;
    } finally {
      _isInitializing = false;
    }
  }

  // ── Public detection API ────────────────────────────────────────────────────

  /// Detect products in a still image (JPEG/PNG file on disk).
  Future<List<DetectionResult>> detectProducts(String imagePath) async {
    if (_interpreter == null) return [];
    try {
      final file = File(imagePath);
      if (!await file.exists()) return [];
      final bytes = await file.readAsBytes();
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) return [];
      decoded = img.bakeOrientation(decoded);

      List<DetectionResult> results = _runInference(decoded);
      if (results.isEmpty && decoded.width > decoded.height) {
        results = _runInference(img.copyRotate(decoded, angle: 90));
      }
      return results;
    } catch (e) {
      debugPrint('YOLOv8 detectProducts error: $e');
      return [];
    }
  }

  bool _isInferring = false;

  /// Detect products directly from a live camera frame.
  ///
  /// Preprocessing (YUV→RGB conversion, letterbox resize, normalization)
  /// runs off the main thread inside a `compute()` isolate. Inference runs on
  /// the main thread interpreter instance to preserve intermediate tensor state
  /// for quantized models.
  Future<List<DetectionResult>> detectProductsFromCameraImage(
    CameraImage cameraImage, [
    int sensorOrientation = 90,
  ]) async {
    if (_interpreter == null || _isInferring) {
      return [];
    }
    try {
      final fmt = cameraImage.format.group;
      if (fmt != ImageFormatGroup.yuv420 || cameraImage.planes.length < 3) {
        debugPrint('YOLOv8: unsupported camera format: $fmt');
        return [];
      }

      // Copy plane bytes synchronously BEFORE the first await — the native
      // CameraImage buffer is recycled the moment this callback returns.
      final yBuf = Uint8List.fromList(cameraImage.planes[0].bytes);
      final uBuf = Uint8List.fromList(cameraImage.planes[1].bytes);
      final vBuf = Uint8List.fromList(cameraImage.planes[2].bytes);

      final int targetW = _isNCHW ? _inputShape[3] : _inputShape[2];
      final int targetH = _isNCHW ? _inputShape[2] : _inputShape[1];
      final int dim1 = _outputShape.length >= 2 ? _outputShape[1] : 61;
      final int dim2 = _outputShape.length >= 3 ? _outputShape[2] : 8400;

      // 1. Run YUV->RGB preprocessing in a compute() isolate
      final prepData = await compute(_preprocessFrameIsolate, <String, dynamic>{
        'w': cameraImage.width,
        'h': cameraImage.height,
        'sensorOrientation': sensorOrientation,
        'yBuf': yBuf,
        'uBuf': uBuf,
        'vBuf': vBuf,
        'yStride': cameraImage.planes[0].bytesPerRow,
        'uvStride': cameraImage.planes[1].bytesPerRow,
        'uvPixStep': cameraImage.planes[1].bytesPerPixel ?? 1,
        'isNCHW': _isNCHW,
        'targetW': targetW,
        'targetH': targetH,
      });

      if (_interpreter == null) return [];

      _isInferring = true;
      try {
        final Float32List inputBuffer = prepData['inputBuffer'] as Float32List;
        final int newW = prepData['newW'] as int;
        final int newH = prepData['newH'] as int;
        final int padX = prepData['padX'] as int;
        final int padY = prepData['padY'] as int;

        // Defensive check: Verify input buffer element count matches expected tensor shape
        final int expectedElements = _inputShape.reduce((a, b) => a * b);
        if (inputBuffer.length != expectedElements) {
          debugPrint(
            'YOLOv8 FATAL: Tensor size mismatch! Expected $expectedElements elements '
            '($_inputShape), but got ${inputBuffer.length} elements.',
          );
          return [];
        }

        // Ensure tensors are allocated before copying data and running inference
        if (!_interpreter!.isAllocated) {
          _interpreter!.allocateTensors();
        }

        // Copy input data directly into Tensor 0 buffer to prevent "lacks data" / unallocated memory errors
        _interpreter!.getInputTensor(0).copyFrom(inputBuffer);

        // Execute native C++ TFLite engine directly
        _isInferring = true;
        _interpreter!.invoke();
        _isInferring = false;

        // Extract output float data directly from C++ Output Tensor 0 pointer
        final outputTensor = _interpreter!.getOutputTensor(0);
        final Float32List outputBuffer = outputTensor.data.buffer.asFloat32List(
          outputTensor.data.offsetInBytes,
          outputTensor.numElements(),
        );

        // Reconstruct output structure for _decodeOutput compatibility
        final outputTensorData = List.generate(
          1,
          (_) => List.generate(
            dim1,
            (r) => List<double>.generate(
              dim2,
              (c) => outputBuffer[r * dim2 + c],
            ),
          ),
        );

        return _decodeOutput(
          output: outputTensorData,
          dim1: dim1,
          dim2: dim2,
          targetW: targetW,
          targetH: targetH,
          newW: newW,
          newH: newH,
          padX: padX,
          padY: padY,
        );
      } catch (e, stack) {
        debugPrint('YOLOv8 Live Frame Precondition Error: $e\n$stack');
        return [];
      } finally {
        _isInferring = false;
      }
    } catch (e) {
      debugPrint('YOLO live frame error: $e');
      _isInferring = false;
      return [];
    }
  }

  // ── Still-image inference pipeline ──────────────────────────────────────────

  List<DetectionResult> _runInference(img.Image source) {
    if (_interpreter == null) return [];

    final int targetW = _inputShape.length == 4 ? (_isNCHW ? _inputShape[3] : _inputShape[2]) : 800;
    final int targetH = _inputShape.length == 4 ? (_isNCHW ? _inputShape[2] : _inputShape[1]) : 800;

    final double scale = min(targetW / source.width, targetH / source.height);
    final int newW = (source.width * scale).round();
    final int newH = (source.height * scale).round();
    final int padX = (targetW - newW) ~/ 2;
    final int padY = (targetH - newH) ~/ 2;

    final resized = img.copyResize(source, width: newW, height: newH);
    final letterboxed = img.Image(width: targetW, height: targetH);
    img.fill(letterboxed, color: img.ColorRgb8(114, 114, 114));
    img.compositeImage(letterboxed, resized, dstX: padX, dstY: padY);

    // Primary pass: normalized [0, 1] input
    List<DetectionResult> results = _inferencePass(
      letterboxed: letterboxed,
      divisor: 255.0,
      targetW: targetW,
      targetH: targetH,
      newW: newW,
      newH: newH,
      padX: padX,
      padY: padY,
    );

    // Fallback pass: raw [0, 255]
    if (results.isEmpty) {
      results = _inferencePass(
        letterboxed: letterboxed,
        divisor: 1.0,
        targetW: targetW,
        targetH: targetH,
        newW: newW,
        newH: newH,
        padX: padX,
        padY: padY,
      );
    }

    return results;
  }

  List<DetectionResult> _inferencePass({
    required img.Image letterboxed,
    required double divisor,
    required int targetW,
    required int targetH,
    required int newW,
    required int newH,
    required int padX,
    required int padY,
  }) {
    final int tW = targetW;
    final int tH = targetH;

    final Float32List flatInput = Float32List(1 * 3 * tH * tW);
    int idx = 0;
    if (_isNCHW) {
      for (int c = 0; c < 3; c++) {
        for (int y = 0; y < tH; y++) {
          for (int x = 0; x < tW; x++) {
            final p = letterboxed.getPixel(x, y);
            final v = c == 0 ? p.r : c == 1 ? p.g : p.b;
            flatInput[idx++] = v.toDouble() / divisor;
          }
        }
      }
    } else {
      for (int y = 0; y < tH; y++) {
        for (int x = 0; x < tW; x++) {
          final p = letterboxed.getPixel(x, y);
          flatInput[idx++] = p.r.toDouble() / divisor;
          flatInput[idx++] = p.g.toDouble() / divisor;
          flatInput[idx++] = p.b.toDouble() / divisor;
        }
      }
    }

    if (!_interpreter!.isAllocated) {
      _interpreter!.allocateTensors();
    }
    _interpreter!.getInputTensor(0).copyFrom(flatInput);
    _interpreter!.invoke();

    final int dim1 = _outputShape.length >= 2 ? _outputShape[1] : 61;
    final int dim2 = _outputShape.length >= 3 ? _outputShape[2] : 8400;

    final outputTensor = _interpreter!.getOutputTensor(0);
    final Float32List outputBuffer = outputTensor.data.buffer.asFloat32List(
      outputTensor.data.offsetInBytes,
      outputTensor.numElements(),
    );

    final output = List.generate(
      1,
      (_) => List.generate(
        dim1,
        (r) => List<double>.generate(
          dim2,
          (c) => outputBuffer[r * dim2 + c],
        ),
      ),
    );
    return _decodeOutput(
      output: output,
      dim1: dim1,
      dim2: dim2,
      targetW: targetW,
      targetH: targetH,
      newW: newW,
      newH: newH,
      padX: padX,
      padY: padY,
    );
  }

  List<DetectionResult> _decodeOutput({
    required List<dynamic> output,
    required int dim1,
    required int dim2,
    required int targetW,
    required int targetH,
    required int newW,
    required int newH,
    required int padX,
    required int padY,
  }) {
    final int numClasses = _labels.length;
    final int numBoxes = dim2;
    final List<_RawCandidate> candidates = [];

    double applyConfidence(double raw) {
      if (raw > 1.0 || raw < 0.0) {
        // YOLOv8 exports output raw logits; apply Sigmoid activation to get 0.0 - 1.0 probability
        return 1.0 / (1.0 + exp(-raw));
      }
      return raw;
    }

    final bool isTransposed = dim1 == (4 + numClasses);
    double globalMaxRawScore = -1e9;

    if (isTransposed) {
      // Auto-detect coordinate format: peek at the first box with a
      // reasonable score. If cx/cy values are > 1.5, coordinates are
      // absolute pixel values; otherwise they are normalized [0,1].
      bool coordsAreAbsolute = false;
      for (int col = 0; col < min(numBoxes, 100); col++) {
        final double peekCx = output[0][0][col];
        final double peekCy = output[0][1][col];
        if (peekCx > 1.5 || peekCy > 1.5) {
          coordsAreAbsolute = true;
          break;
        }
      }

      for (int col = 0; col < numBoxes; col++) {
        final double cx = output[0][0][col];
        final double cy = output[0][1][col];
        final double bw = output[0][2][col];
        final double bh = output[0][3][col];

        double maxScore = -1e9;
        int bestClass = 0;
        for (int c = 0; c < numClasses; c++) {
          final s = output[0][4 + c][col];
          if (s > maxScore) {
            maxScore = s;
            bestClass = c;
          }
        }
        if (maxScore > globalMaxRawScore) {
          globalMaxRawScore = maxScore;
        }

        final double conf = applyConfidence(maxScore);
        if (conf < confidenceThreshold) continue;

        final double cxPx = coordsAreAbsolute ? cx : cx * targetW.toDouble();
        final double cyPx = coordsAreAbsolute ? cy : cy * targetH.toDouble();
        final double bwPx = coordsAreAbsolute ? bw : bw * targetW.toDouble();
        final double bhPx = coordsAreAbsolute ? bh : bh * targetH.toDouble();

        final x1 = ((cxPx - bwPx / 2.0 - padX) / newW).clamp(0.0, 1.0);
        final y1 = ((cyPx - bhPx / 2.0 - padY) / newH).clamp(0.0, 1.0);
        final x2 = ((cxPx + bwPx / 2.0 - padX) / newW).clamp(0.0, 1.0);
        final y2 = ((cyPx + bhPx / 2.0 - padY) / newH).clamp(0.0, 1.0);

        if (x2 <= x1 || y2 <= y1) continue;

        candidates.add(_RawCandidate(
          classId: bestClass,
          score: conf,
          box: Rect.fromLTRB(x1, y1, x2, y2),
        ));
      }
    } else {
      // Auto-detect coordinate format for non-transposed layout
      bool coordsAreAbsolute = false;
      for (int row = 0; row < min(numBoxes, 100); row++) {
        final double peekCx = output[0][row][0];
        final double peekCy = output[0][row][1];
        if (peekCx > 1.5 || peekCy > 1.5) {
          coordsAreAbsolute = true;
          break;
        }
      }

      for (int row = 0; row < numBoxes; row++) {
        final double cx = output[0][row][0];
        final double cy = output[0][row][1];
        final double bw = output[0][row][2];
        final double bh = output[0][row][3];

        double maxScore = -1e9;
        int bestClass = 0;
        for (int c = 0; c < numClasses; c++) {
          final s = output[0][row][4 + c];
          if (s > maxScore) {
            maxScore = s;
            bestClass = c;
          }
        }
        if (maxScore > globalMaxRawScore) {
          globalMaxRawScore = maxScore;
        }

        final double conf = applyConfidence(maxScore);
        if (conf < confidenceThreshold) continue;

        final double cxPx = coordsAreAbsolute ? cx : cx * targetW.toDouble();
        final double cyPx = coordsAreAbsolute ? cy : cy * targetH.toDouble();
        final double bwPx = coordsAreAbsolute ? bw : bw * targetW.toDouble();
        final double bhPx = coordsAreAbsolute ? bh : bh * targetH.toDouble();

        final x1 = ((cxPx - bwPx / 2.0 - padX) / newW).clamp(0.0, 1.0);
        final y1 = ((cyPx - bhPx / 2.0 - padY) / newH).clamp(0.0, 1.0);
        final x2 = ((cxPx + bwPx / 2.0 - padX) / newW).clamp(0.0, 1.0);
        final y2 = ((cyPx + bhPx / 2.0 - padY) / newH).clamp(0.0, 1.0);

        if (x2 <= x1 || y2 <= y1) continue;

        candidates.add(_RawCandidate(
          classId: bestClass,
          score: conf,
          box: Rect.fromLTRB(x1, y1, x2, y2),
        ));
      }
    }

    final double maxSigmoid = applyConfidence(globalMaxRawScore);
    debugPrint(
      'YOLO Decode: Checked $numBoxes boxes. Max raw logit=${globalMaxRawScore.toStringAsFixed(2)}, '
      'Sigmoid conf=${maxSigmoid.toStringAsFixed(3)}, Candidates above threshold=${candidates.length}',
    );

    return _applyNMSStatic(candidates, _labels, iouThreshold);
  }
}

// ── Internal candidate ────────────────────────────────────────────────────────

class _RawCandidate {
  final int classId;
  final double score;
  final Rect box;
  const _RawCandidate(
      {required this.classId, required this.score, required this.box});
}

// ── Static NMS (callable from both instance methods and isolates) ──────────

List<DetectionResult> _applyNMSStatic(
    List<_RawCandidate> candidates, List<String> labels, double iouThreshold) {
  final Map<int, List<_RawCandidate>> byClass = {};
  for (final c in candidates) {
    byClass.putIfAbsent(c.classId, () => []).add(c);
  }

  final List<DetectionResult> out = [];
  for (final entry in byClass.entries) {
    final list = entry.value..sort((a, b) => b.score.compareTo(a.score));
    final kept = <_RawCandidate>[];
    for (final cand in list) {
      if (kept.any((k) => _iouStatic(cand.box, k.box) > iouThreshold)) {
        continue;
      }
      kept.add(cand);
    }
    final label = (entry.key >= 0 && entry.key < labels.length)
        ? labels[entry.key]
        : 'class_${entry.key}';
    for (final k in kept) {
      out.add(
          DetectionResult(label: label, confidence: k.score, boundingBox: k.box));
    }
  }
  return out;
}

double _iouStatic(Rect a, Rect b) {
  final l = max(a.left, b.left);
  final t = max(a.top, b.top);
  final r = min(a.right, b.right);
  final bt = min(a.bottom, b.bottom);
  if (r <= l || bt <= t) return 0.0;
  final inter = (r - l) * (bt - t);
  final union = a.width * a.height + b.width * b.height - inter;
  return union > 0 ? inter / union : 0.0;
}

// ── Combined Isolate: preprocess + inference + decode + NMS ───────────────────

Map<String, dynamic> _preprocessFrameIsolate(Map<String, dynamic> args) {
  final int srcW = args['w'];
  final int srcH = args['h'];
  final int sensorOrientation = args['sensorOrientation'] ?? 90;
  final Uint8List yBuf = args['yBuf'];
  final Uint8List uBuf = args['uBuf'];
  final Uint8List vBuf = args['vBuf'];
  final int yStride = args['yStride'];
  final int uvStride = args['uvStride'];
  final int uvPixStep = args['uvPixStep'];
  final bool isNCHW = args['isNCHW'];
  final int targetW = args['targetW'];
  final int targetH = args['targetH'];

  final double divisor = (args['divisor'] as num?)?.toDouble() ?? 255.0;

  // ── Step 1: Sensor-Aware YUV→RGB Rotation + Letterbox + Normalize ─────────
  final bool rotate = srcW > srcH;
  final int realW = rotate ? srcH : srcW;
  final int realH = rotate ? srcW : srcH;

  final double scale =
      min(targetW.toDouble() / realW, targetH.toDouble() / realH);
  final int newW = (realW * scale).round();
  final int newH = (realH * scale).round();
  final int padX = (targetW - newW) ~/ 2;
  final int padY = (targetH - newH) ~/ 2;

  final int totalElements = isNCHW
      ? 3 * targetH * targetW
      : targetH * targetW * 3;
  final Float32List inputBuffer = Float32List(totalElements);
  final double gray = 114.0 / divisor;

  final int maxYIdx = yBuf.length - 1;
  final int maxUvIdx = min(uBuf.length, vBuf.length) - 1;

  if (isNCHW) {
    for (int c = 0; c < 3; c++) {
      final int cOffset = c * targetH * targetW;
      for (int y = 0; y < targetH; y++) {
        final int yOffset = cOffset + y * targetW;
        for (int x = 0; x < targetW; x++) {
          if (x >= padX && x < padX + newW && y >= padY && y < padY + newH) {
            final int rx = ((x - padX) / scale).floor().clamp(0, realW - 1);
            final int ry = ((y - padY) / scale).floor().clamp(0, realH - 1);

            int sx, sy;
            if (sensorOrientation == 270) {
              sx = rotate ? (srcW - 1 - ry) : rx;
              sy = rotate ? rx : ry;
            } else if (sensorOrientation == 90) {
              sx = rotate ? ry : rx;
              sy = rotate ? (srcH - 1 - rx) : ry;
            } else {
              sx = rx;
              sy = ry;
            }

            final int yIdx = (sy * yStride + sx).clamp(0, maxYIdx);
            final int uvIdx =
                ((sy ~/ 2) * uvStride + (sx ~/ 2) * uvPixStep).clamp(0, maxUvIdx);

            final int yp = yBuf[yIdx];
            final int up = uBuf[uvIdx] - 128;
            final int vp = vBuf[uvIdx] - 128;

            double value;
            if (c == 0) {
              value = (yp + 1.402 * vp).clamp(0, 255).toDouble() / divisor;
            } else if (c == 1) {
              value =
                  (yp - 0.344136 * up - 0.714136 * vp).clamp(0, 255).toDouble() /
                      divisor;
            } else {
              value = (yp + 1.772 * up).clamp(0, 255).toDouble() / divisor;
            }
            inputBuffer[yOffset + x] = value;
          } else {
            inputBuffer[yOffset + x] = gray;
          }
        }
      }
    }
  } else {
    for (int y = 0; y < targetH; y++) {
      for (int x = 0; x < targetW; x++) {
        final int baseIdx = (y * targetW + x) * 3;
        if (x >= padX && x < padX + newW && y >= padY && y < padY + newH) {
          final int rx = ((x - padX) / scale).floor().clamp(0, realW - 1);
          final int ry = ((y - padY) / scale).floor().clamp(0, realH - 1);

          int sx, sy;
          if (sensorOrientation == 270) {
            sx = rotate ? (srcW - 1 - ry) : rx;
            sy = rotate ? rx : ry;
          } else if (sensorOrientation == 90) {
            sx = rotate ? ry : rx;
            sy = rotate ? (srcH - 1 - rx) : ry;
          } else {
            sx = rx;
            sy = ry;
          }

          final int yIdx = (sy * yStride + sx).clamp(0, maxYIdx);
          final int uvIdx =
              ((sy ~/ 2) * uvStride + (sx ~/ 2) * uvPixStep).clamp(0, maxUvIdx);

          final int yp = yBuf[yIdx];
          final int up = uBuf[uvIdx] - 128;
          final int vp = vBuf[uvIdx] - 128;

          inputBuffer[baseIdx] =
              (yp + 1.402 * vp).clamp(0, 255).toDouble() / divisor;
          inputBuffer[baseIdx + 1] =
              (yp - 0.344136 * up - 0.714136 * vp).clamp(0, 255).toDouble() /
                  divisor;
          inputBuffer[baseIdx + 2] =
              (yp + 1.772 * up).clamp(0, 255).toDouble() / divisor;
        } else {
          inputBuffer[baseIdx] = gray;
          inputBuffer[baseIdx + 1] = gray;
          inputBuffer[baseIdx + 2] = gray;
        }
      }
    }
  }

  return {
    'inputBuffer': inputBuffer,
    'newW': newW,
    'newH': newH,
    'padX': padX,
    'padY': padY,
  };
}

/// Extension on [Tensor] to provide safe, direct buffer copying without
/// triggering dynamic resizing or leaving native memory uninitialized.
extension TensorCopyExtension on Tensor {
  /// Safely copies input data (Float32List, Uint8List, ByteBuffer, or Object)
  /// into the allocated native C++ TFLite tensor buffer.
  void copyFrom(Object input) {
    if (input is Float32List) {
      setTo(input.buffer.asUint8List(input.offsetInBytes, input.lengthInBytes));
    } else if (input is ByteBuffer) {
      setTo(input.asUint8List());
    } else {
      setTo(input);
    }
  }
}
