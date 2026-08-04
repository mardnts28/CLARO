import 'dart:convert';
import 'dart:io';
import 'dart:math';
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
  List<String> get labels => _labels;

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
      debugPrint('YOLOv8: Loading model from assets/model/best.tflite …');

      // ── Hardware acceleration ──────────────────────────────────────────
      final options = InterpreterOptions();
      String delegateName = 'CPU';

      if (Platform.isAndroid) {
        try {
          options.addDelegate(GpuDelegateV2());
          delegateName = 'GPU';
        } catch (e) {
          debugPrint('YOLOv8: GPU delegate unavailable ($e), using CPU/XNNPack');
        }
      }

      _interpreter = await Interpreter.fromAsset(
        'assets/model/best.tflite',
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

  /// Detect products directly from a live camera frame.
  ///
  /// The entire pipeline (YUV→RGB conversion, letterbox resize,
  /// normalization, TFLite inference, output decode, NMS) runs off
  /// the main thread inside a `compute()` isolate.
  Future<List<DetectionResult>> detectProductsFromCameraImage(
    CameraImage cameraImage, [
    int sensorOrientation = 90,
  ]) async {
    if (_interpreter == null) {
      debugPrint('YOLOv8: interpreter not ready, skipping frame');
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

      // Run preprocessing + inference + decode + NMS entirely off
      // the main thread in a single compute() isolate.
      final results = await compute(_processFrameIsolate, <String, dynamic>{
        'interpreterAddress': _interpreter!.address,
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
        'dim1': dim1,
        'dim2': dim2,
        'numClasses': _labels.length,
        'confidenceThreshold': confidenceThreshold,
        'iouThreshold': iouThreshold,
        'labels': _labels,
      });

      return results;
    } catch (e) {
      debugPrint('YOLO live frame error: $e');
      return [];
    }
  }

  // ── Still-image inference pipeline ──────────────────────────────────────────

  List<DetectionResult> _runInference(img.Image source) {
    if (_interpreter == null) return [];

    const int targetW = 640;
    const int targetH = 640;

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
    required int newW,
    required int newH,
    required int padX,
    required int padY,
  }) {
    const int tW = 640;
    const int tH = 640;

    final Object input;
    if (_isNCHW) {
      input = [
        List.generate(
          3,
          (c) => List.generate(
            tH,
            (y) => List.generate(tW, (x) {
              final p = letterboxed.getPixel(x, y);
              final v = c == 0 ? p.r : c == 1 ? p.g : p.b;
              return v.toDouble() / divisor;
            }),
          ),
        ),
      ];
    } else {
      input = [
        List.generate(
          tH,
          (y) => List.generate(tW, (x) {
            final p = letterboxed.getPixel(x, y);
            return [
              p.r.toDouble() / divisor,
              p.g.toDouble() / divisor,
              p.b.toDouble() / divisor,
            ];
          }),
        ),
      ];
    }

    final int dim1 = _outputShape.length >= 2 ? _outputShape[1] : 61;
    final int dim2 = _outputShape.length >= 3 ? _outputShape[2] : 8400;
    final output = List.generate(
        1, (_) => List.generate(dim1, (_) => List<double>.filled(dim2, 0.0)));

    _interpreter!.run(input, output);
    return _decodeOutput(
      output: output,
      dim1: dim1,
      dim2: dim2,
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
    required int newW,
    required int newH,
    required int padX,
    required int padY,
  }) {
    final int numClasses = _labels.length;
    final int numBoxes = dim2;
    final List<_RawCandidate> candidates = [];

    double applyConfidence(double raw) {
      return raw;
    }

    final bool isTransposed = dim1 == (4 + numClasses);

    if (isTransposed) {
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

        final double conf = applyConfidence(maxScore);
        if (conf < confidenceThreshold) continue;

        final double cxPx = cx * 640.0;
        final double cyPx = cy * 640.0;
        final double bwPx = bw * 640.0;
        final double bhPx = bh * 640.0;

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

        final double conf = applyConfidence(maxScore);
        if (conf < confidenceThreshold) continue;

        final double cxPx = cx * 640.0;
        final double cyPx = cy * 640.0;
        final double bwPx = bw * 640.0;
        final double bhPx = bh * 640.0;

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

List<DetectionResult> _processFrameIsolate(Map<String, dynamic> args) {
  final int interpreterAddress = args['interpreterAddress'];
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
  final int dim1 = args['dim1'];
  final int dim2 = args['dim2'];
  final int numClasses = args['numClasses'];
  final double confidenceThreshold = args['confidenceThreshold'];
  final double iouThreshold = args['iouThreshold'];
  final List<String> labels = (args['labels'] as List).cast<String>();

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
  const double gray = 114.0 / 255.0;

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
              value = (yp + 1.402 * vp).clamp(0, 255).toDouble() / 255.0;
            } else if (c == 1) {
              value =
                  (yp - 0.344136 * up - 0.714136 * vp).clamp(0, 255).toDouble() /
                      255.0;
            } else {
              value = (yp + 1.772 * up).clamp(0, 255).toDouble() / 255.0;
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
              (yp + 1.402 * vp).clamp(0, 255).toDouble() / 255.0;
          inputBuffer[baseIdx + 1] =
              (yp - 0.344136 * up - 0.714136 * vp).clamp(0, 255).toDouble() /
                  255.0;
          inputBuffer[baseIdx + 2] =
              (yp + 1.772 * up).clamp(0, 255).toDouble() / 255.0;
        } else {
          inputBuffer[baseIdx] = gray;
          inputBuffer[baseIdx + 1] = gray;
          inputBuffer[baseIdx + 2] = gray;
        }
      }
    }
  }

  // ── Step 2: Run inference in this isolate ─────────────────────────────────
  final interpreter = Interpreter.fromAddress(interpreterAddress);

  final inputTensor = isNCHW
      ? inputBuffer.reshape([1, 3, targetH, targetW])
      : inputBuffer.reshape([1, targetH, targetW, 3]);

  final outputTensor = Float32List(dim1 * dim2).reshape([1, dim1, dim2]);

  interpreter.run(inputTensor, outputTensor);

  // ── Step 3: Decode output → bounding boxes ────────────────────────────────
  final int numBoxes = dim2; // 8400
  final List<_RawCandidate> candidates = [];

  double applyConfidence(double raw) {
    return raw;
  }

  final bool isTransposed = dim1 == (4 + numClasses); // [1, 61, 8400]

  double absoluteMaxLogit = -1e9;
  int absoluteMaxClass = 0;

  if (isTransposed) {
    for (int col = 0; col < numBoxes; col++) {
      final double cx = (outputTensor[0][0][col] as num).toDouble();
      final double cy = (outputTensor[0][1][col] as num).toDouble();
      final double bw = (outputTensor[0][2][col] as num).toDouble();
      final double bh = (outputTensor[0][3][col] as num).toDouble();

      double maxScore = -1e9;
      int bestClass = 0;
      for (int c = 0; c < numClasses; c++) {
        final double s = (outputTensor[0][4 + c][col] as num).toDouble();
        if (s > maxScore) {
          maxScore = s;
          bestClass = c;
        }
      }

      if (maxScore > absoluteMaxLogit) {
        absoluteMaxLogit = maxScore;
        absoluteMaxClass = bestClass;
      }

      final double conf = applyConfidence(maxScore);
      if (conf < confidenceThreshold) continue;

      final double cxPx = cx * 640.0;
      final double cyPx = cy * 640.0;
      final double bwPx = bw * 640.0;
      final double bhPx = bh * 640.0;

      final x1 = ((cxPx - bwPx / 2.0 - padX) / newW).clamp(0.0, 1.0);
      final y1 = ((cyPx - bhPx / 2.0 - padY) / newH).clamp(0.0, 1.0);
      final x2 = ((cxPx + bwPx / 2.0 - padX) / newW).clamp(0.0, 1.0);
      final y2 = ((cyPx + bhPx / 2.0 - padY) / newH).clamp(0.0, 1.0);

      if (x2 <= x1 || y2 <= y1) {
        continue;
      }

      candidates.add(_RawCandidate(
        classId: bestClass,
        score: conf,
        box: Rect.fromLTRB(x1, y1, x2, y2),
      ));
    }
  } else {
    for (int row = 0; row < numBoxes; row++) {
      final double cx = (outputTensor[0][row][0] as num).toDouble();
      final double cy = (outputTensor[0][row][1] as num).toDouble();
      final double bw = (outputTensor[0][row][2] as num).toDouble();
      final double bh = (outputTensor[0][row][3] as num).toDouble();

      double maxScore = -1e9;
      int bestClass = 0;
      for (int c = 0; c < numClasses; c++) {
        final double s = (outputTensor[0][row][4 + c] as num).toDouble();
        if (s > maxScore) {
          maxScore = s;
          bestClass = c;
        }
      }

      if (maxScore > absoluteMaxLogit) {
        absoluteMaxLogit = maxScore;
        absoluteMaxClass = bestClass;
      }

      final double conf = applyConfidence(maxScore);
      if (conf < confidenceThreshold) continue;

      final double cxPx = cx * 640.0;
      final double cyPx = cy * 640.0;
      final double bwPx = bw * 640.0;
      final double bhPx = bh * 640.0;

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

  // ── Step 4: NMS ────────────────────────────────────────────────────────────
  final double maxProb = applyConfidence(absoluteMaxLogit);
  final String maxLabel = (absoluteMaxClass >= 0 && absoluteMaxClass < labels.length)
      ? labels[absoluteMaxClass]
      : 'class_$absoluteMaxClass';
  debugPrint('YOLO Isolate Frame: Max raw logit=$absoluteMaxLogit (probability=${(maxProb * 100).toStringAsFixed(1)}%, label=$maxLabel)');

  return _applyNMSStatic(candidates, labels, iouThreshold);
}
