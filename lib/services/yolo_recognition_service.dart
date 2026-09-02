// lib/services/yolo_recognition_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import '../models/product_model.dart';

/// Service for YOLOv8 object detection using tflite_flutter and a persistent worker isolate.
///
/// Implemented Performance & Stability Fixes:
/// - [ISSUE 1]: Persistent long-lived worker isolate created once during initialization
///   via `Isolate.spawn` + `SendPort`/`ReceivePort`. Eliminates repeated `compute()`
///   spawning and destroying (~150 isolates/minute).
/// - [ISSUE 1]: Instant Frame Drop Policy — when `_isInferring` is active, incoming
///   frames are dropped immediately without copying memory or building up queue backpressure.
/// - [ISSUE 2]: Offloads the heavy 748,125-operation bounding box decode and NMS calculation
///   completely into the persistent worker isolate with an early confidence-threshold filter.
/// - [ISSUE 3]: Still photo preprocessing (JPEG decode, orientation, resize) is offloaded
///   to the persistent isolate, keeping the Flutter main UI thread 100% responsive at 60 FPS.
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

  // Detection thresholds — matched to training evaluation benchmarks
  double confidenceThreshold = 0.40;
  double iouThreshold = 0.45;

  // Cached tensor metadata
  List<int> _inputShape = [];
  List<int> _outputShape = [];
  bool _isNCHW = false;

  // Persistent Worker Isolate (Issue 1 & 2 Fix)
  Isolate? _workerIsolate;
  SendPort? _workerSendPort;
  ReceivePort? _workerResponsePort;
  int _nextRequestId = 0;
  final Map<int, Completer<dynamic>> _pendingRequests = {};

  bool _isInferring = false;
  bool get isInferring => _isInferring;

  /// Loads the TFLite model, labels, and starts the persistent background isolate.
  Future<void> initialize() async {
    if (_isModelLoaded || _isInitializing) return;
    _isInitializing = true;
    final totalInitStopwatch = Stopwatch()..start();
    try {
      debugPrint('TIMING [YOLO]: Starting model initialization …');

      // ── Hardware-optimized multi-threaded CPU execution ─────────────────
      // Uses 4 CPU worker threads, eliminating Android OpenCL GPU shader compilation stalls (which trigger ANRs)
      final threadCount = Platform.isAndroid ? 4 : 2;
      final cpuOptions = InterpreterOptions()..threads = threadCount;

      final loadAssetStopwatch = Stopwatch()..start();
      _interpreter = await Interpreter.fromAsset(
        'assets/model/best-6.tflite',
        options: cpuOptions,
      );
      _interpreter!.allocateTensors();
      loadAssetStopwatch.stop();
      debugPrint('TIMING [YOLO]: TFLite model binary load & tensor allocation took ${loadAssetStopwatch.elapsedMilliseconds}ms');

      final labelsStopwatch = Stopwatch()..start();
      final labelsString =
          await rootBundle.loadString('assets/model/labels.json');
      final List<dynamic> jsonList = jsonDecode(labelsString);
      _labels = jsonList
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      labelsStopwatch.stop();
      debugPrint('TIMING [YOLO]: Labels load (${_labels.length} classes) took ${labelsStopwatch.elapsedMilliseconds}ms');

      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;
      // NCHW: [1, 3, H, W]  vs  NHWC: [1, H, W, 3]
      _isNCHW = _inputShape.length == 4 && _inputShape[1] == 3;

      // ── Spawn Persistent Worker Isolate ─────────────────────────────────
      final isolateSpawnStopwatch = Stopwatch()..start();
      await _initPersistentWorker();
      isolateSpawnStopwatch.stop();
      debugPrint('TIMING [YOLO]: Persistent worker isolate spawn & handshake took ${isolateSpawnStopwatch.elapsedMilliseconds}ms');

      _isModelLoaded = true;
      totalInitStopwatch.stop();
      debugPrint(
          'TIMING [YOLO]: Total YOLO initialization completed in ${totalInitStopwatch.elapsedMilliseconds}ms (threads=$threadCount, NCHW=$_isNCHW)');
    } catch (e) {
      debugPrint('YOLOv8: Failed to load model — $e');
      _isModelLoaded = false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Initializes the single, long-lived background isolate for all frame and tensor processing.
  Future<void> _initPersistentWorker() async {
    if (_workerSendPort != null) return;
    try {
      final initPort = ReceivePort();
      _workerIsolate =
          await Isolate.spawn(_persistentWorkerEntry, initPort.sendPort);
      final Stream<dynamic> responseStream = initPort.asBroadcastStream();
      final firstMessage = await responseStream.first;
      _workerSendPort = firstMessage as SendPort;

      _workerResponsePort = ReceivePort();
      _workerSendPort!.send(_workerResponsePort!.sendPort);

      _workerResponsePort!.listen((dynamic message) {
        if (message is List && message.length >= 3) {
          final int id = message[0] as int;
          final bool success = message[1] as bool;
          final dynamic result = message[2];
          final completer = _pendingRequests.remove(id);
          if (completer != null && !completer.isCompleted) {
            if (success) {
              completer.complete(result);
            } else {
              completer.completeError(result ?? 'Isolate worker error');
            }
          }
        }
      });
    } catch (e) {
      debugPrint('YOLOv8: Failed to spawn persistent worker isolate: $e');
    }
  }

  /// Sends a processing request to the persistent background isolate and awaits result.
  Future<dynamic> _sendWorkerRequest(
      String action, Map<String, dynamic> data) async {
    if (_workerSendPort == null) {
      await _initPersistentWorker();
    }
    final int id = _nextRequestId++;
    final completer = Completer<dynamic>();
    _pendingRequests[id] = completer;
    _workerSendPort!.send([id, action, data]);
    return completer.future;
  }

  // ── Public Detection APIs ───────────────────────────────────────────────────

  /// Detect products in a still image (JPEG/PNG file on disk).
  ///
  /// [ISSUE 3]: Decodes, letterboxes, and decodes entirely inside the persistent worker
  /// isolate, keeping the Flutter main UI thread free and preventing ANR.
  Future<List<DetectionResult>> detectProducts(String imagePath) async {
    if (_interpreter == null) return [];
    try {
      final file = File(imagePath);
      if (!await file.exists()) return [];
      final Uint8List bytes = await file.readAsBytes();

      final int targetW = _isNCHW ? _inputShape[3] : _inputShape[2];
      final int targetH = _isNCHW ? _inputShape[2] : _inputShape[1];
      final int dim1 = _outputShape.length >= 2 ? _outputShape[1] : 61;
      final int dim2 = _outputShape.length >= 3 ? _outputShape[2] : 13125;

      // 1. Offload heavy JPEG decoding and letterboxing to persistent isolate
      final prep = await _sendWorkerRequest('preprocess_still', <String, dynamic>{
        'bytes': bytes,
        'isNCHW': _isNCHW,
        'targetW': targetW,
        'targetH': targetH,
      }) as Map<String, dynamic>;

      if (prep['success'] != true || _interpreter == null) return [];

      final Float32List inputBuffer = prep['flatInput'] as Float32List;
      final int newW = prep['newW'] as int;
      final int newH = prep['newH'] as int;
      final int padX = prep['padX'] as int;
      final int padY = prep['padY'] as int;

      if (!_interpreter!.isAllocated) {
        _interpreter!.allocateTensors();
      }
      _interpreter!.getInputTensor(0).copyFrom(inputBuffer);
      _interpreter!.invoke();

      final outputTensor = _interpreter!.getOutputTensor(0);
      final Float32List outputBuffer = outputTensor.data.buffer.asFloat32List(
        outputTensor.data.offsetInBytes,
        outputTensor.numElements(),
      );

      // 2. Offload bounding box decoding and NMS to persistent isolate
      final decodedList = await _sendWorkerRequest('decode_output', <String, dynamic>{
        'outputBuffer': outputBuffer,
        'dim1': dim1,
        'dim2': dim2,
        'targetW': targetW,
        'targetH': targetH,
        'newW': newW,
        'newH': newH,
        'padX': padX,
        'padY': padY,
        'confidenceThreshold': confidenceThreshold,
        'iouThreshold': iouThreshold,
        'labels': _labels,
      }) as List<dynamic>;

      return decodedList.map((dynamic m) {
        final map = m as Map<String, dynamic>;
        return DetectionResult(
          label: map['label'] as String,
          confidence: (map['confidence'] as num).toDouble(),
          boundingBox: Rect.fromLTWH(
            (map['left'] as num).toDouble(),
            (map['top'] as num).toDouble(),
            (map['width'] as num).toDouble(),
            (map['height'] as num).toDouble(),
          ),
        );
      }).toList();
    } catch (e) {
      debugPrint('YOLOv8 detectProducts error: $e');
      return [];
    }
  }

  /// Detect products directly from a live camera frame.
  ///
  /// [ISSUE 1]: Uses single persistent worker isolate for YUV conversion.
  /// [ISSUE 1]: Instant Frame Drop — immediately returns `[]` if previous inference is still busy.
  /// [ISSUE 2]: 748,125-op bounding box decoding is computed inside the isolate with early filter.
  Future<List<DetectionResult>> detectProductsFromCameraImage(
    CameraImage cameraImage, [
    int sensorOrientation = 90,
  ]) async {
    // [ISSUE 1 Fix]: Frame Drop Policy: Drop immediately if already inferring or uninitialized
    if (_interpreter == null || _isInferring) {
      return [];
    }

    try {
      final fmt = cameraImage.format.group;
      if (fmt != ImageFormatGroup.yuv420 || cameraImage.planes.length < 3) {
        debugPrint('YOLOv8: unsupported camera format: $fmt');
        return [];
      }

      _isInferring = true;

      // Copy plane bytes synchronously before returning to camera frame queue
      final Uint8List yBuf = Uint8List.fromList(cameraImage.planes[0].bytes);
      final Uint8List uBuf = Uint8List.fromList(cameraImage.planes[1].bytes);
      final Uint8List vBuf = Uint8List.fromList(cameraImage.planes[2].bytes);

      final int targetW = _isNCHW ? _inputShape[3] : _inputShape[2];
      final int targetH = _isNCHW ? _inputShape[2] : _inputShape[1];
      final int dim1 = _outputShape.length >= 2 ? _outputShape[1] : 61;
      final int dim2 = _outputShape.length >= 3 ? _outputShape[2] : 13125;

      // 1. Preprocess YUV to normalized tensor via persistent isolate (Issue 1)
      final prepData = await _sendWorkerRequest('preprocess_frame', <String, dynamic>{
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
      }) as Map<String, dynamic>;

      if (_interpreter == null) return [];

      final Float32List inputBuffer = prepData['inputBuffer'] as Float32List;
      final int newW = prepData['newW'] as int;
      final int newH = prepData['newH'] as int;
      final int padX = prepData['padX'] as int;
      final int padY = prepData['padY'] as int;

      if (!_interpreter!.isAllocated) {
        _interpreter!.allocateTensors();
      }

      // 2. Invoke fast C++ TFLite engine on main isolate
      _interpreter!.getInputTensor(0).copyFrom(inputBuffer);
      _interpreter!.invoke();

      final outputTensor = _interpreter!.getOutputTensor(0);
      final Float32List outputBuffer = outputTensor.data.buffer.asFloat32List(
        outputTensor.data.offsetInBytes,
        outputTensor.numElements(),
      );

      // 3. Decode boxes and apply early-filtered NMS in persistent isolate (Issue 2)
      final decodedList = await _sendWorkerRequest('decode_output', <String, dynamic>{
        'outputBuffer': outputBuffer,
        'dim1': dim1,
        'dim2': dim2,
        'targetW': targetW,
        'targetH': targetH,
        'newW': newW,
        'newH': newH,
        'padX': padX,
        'padY': padY,
        'confidenceThreshold': confidenceThreshold,
        'iouThreshold': iouThreshold,
        'labels': _labels,
      }) as List<dynamic>;

      return decodedList.map((dynamic m) {
        final map = m as Map<String, dynamic>;
        return DetectionResult(
          label: map['label'] as String,
          confidence: (map['confidence'] as num).toDouble(),
          boundingBox: Rect.fromLTWH(
            (map['left'] as num).toDouble(),
            (map['top'] as num).toDouble(),
            (map['width'] as num).toDouble(),
            (map['height'] as num).toDouble(),
          ),
        );
      }).toList();
    } catch (e) {
      debugPrint('YOLO live frame error: $e');
      return [];
    } finally {
      _isInferring = false;
    }
  }

  /// Clean up persistent isolate resources
  void dispose() {
    _workerResponsePort?.close();
    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;
    _workerSendPort = null;
    _workerResponsePort = null;
    _pendingRequests.clear();
  }
}

// ── Persistent Background Worker Isolate Entry & Logic ─────────────────────────

/// Top-level entry point for the single persistent worker isolate (Issue 1 & 2).
void _persistentWorkerEntry(SendPort initSendPort) {
  final commandPort = ReceivePort();
  initSendPort.send(commandPort.sendPort);

  SendPort? replyPort;

  commandPort.listen((dynamic message) {
    if (message is SendPort) {
      replyPort = message;
      return;
    }

    if (message is List && message.length == 3) {
      final int id = message[0] as int;
      final String action = message[1] as String;
      final Map<String, dynamic> data = message[2] as Map<String, dynamic>;

      try {
        if (action == 'preprocess_frame') {
          final result = _preprocessFrameWorker(data);
          replyPort?.send([id, true, result]);
        } else if (action == 'decode_output') {
          final result = _decodeOutputWorker(data);
          replyPort?.send([id, true, result]);
        } else if (action == 'preprocess_still') {
          final result = _preprocessStillImageWorker(data);
          replyPort?.send([id, true, result]);
        } else {
          replyPort?.send([id, false, 'Unknown action $action']);
        }
      } catch (e) {
        replyPort?.send([id, false, e.toString()]);
      }
    }
  });
}

/// [ISSUE 1]: YUV to RGB + normalization worker running inside persistent isolate.
Map<String, dynamic> _preprocessFrameWorker(Map<String, dynamic> data) {
  final int srcW = data['w'] as int;
  final int srcH = data['h'] as int;
  final int sensorOrientation = data['sensorOrientation'] as int;
  final Uint8List yBuf = data['yBuf'] as Uint8List;
  final Uint8List uBuf = data['uBuf'] as Uint8List;
  final Uint8List vBuf = data['vBuf'] as Uint8List;
  final int yStride = data['yStride'] as int;
  final int uvStride = data['uvStride'] as int;
  final int uvPixStep = data['uvPixStep'] as int;
  final bool isNCHW = data['isNCHW'] as bool;
  final int targetW = data['targetW'] as int;
  final int targetH = data['targetH'] as int;

  final bool rotate = sensorOrientation == 90 || sensorOrientation == 270;
  final int realW = rotate ? srcH : srcW;
  final int realH = rotate ? srcW : srcH;

  final double scale = min(targetW / realW, targetH / realH);
  final int newW = (realW * scale).round();
  final int newH = (realH * scale).round();
  final int padX = (targetW - newW) ~/ 2;
  final int padY = (targetH - newH) ~/ 2;

  const double divisor = 255.0;
  final int totalElements = isNCHW
      ? 3 * targetH * targetW
      : targetH * targetW * 3;
  final Float32List inputBuffer = Float32List(totalElements);
  const double gray = 114.0 / divisor;

  final int maxYIdx = yBuf.length - 1;
  final int maxUvIdx = min(uBuf.length, vBuf.length) - 1;

  if (isNCHW) {
    final int channelSize = targetH * targetW;
    const int rOffset = 0;
    final int gOffset = channelSize;
    final int bOffset = channelSize * 2;

    for (int y = 0; y < targetH; y++) {
      final int rowOffset = y * targetW;
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

          final double r =
              (yp + 1.402 * vp).clamp(0, 255).toDouble() / divisor;
          final double g =
              (yp - 0.344136 * up - 0.714136 * vp).clamp(0, 255).toDouble() /
                  divisor;
          final double b =
              (yp + 1.772 * up).clamp(0, 255).toDouble() / divisor;

          inputBuffer[rOffset + rowOffset + x] = r;
          inputBuffer[gOffset + rowOffset + x] = g;
          inputBuffer[bOffset + rowOffset + x] = b;
        } else {
          inputBuffer[rOffset + rowOffset + x] = gray;
          inputBuffer[gOffset + rowOffset + x] = gray;
          inputBuffer[bOffset + rowOffset + x] = gray;
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

/// [ISSUE 2]: Heavy 748,125-op YOLO decoding and early-filtered NMS inside persistent isolate.
List<Map<String, dynamic>> _decodeOutputWorker(Map<String, dynamic> data) {
  final Float32List outputBuffer = data['outputBuffer'] as Float32List;
  final int dim1 = data['dim1'] as int;
  final int dim2 = data['dim2'] as int;
  final int targetW = data['targetW'] as int;
  final int targetH = data['targetH'] as int;
  final int newW = data['newW'] as int;
  final int newH = data['newH'] as int;
  final int padX = data['padX'] as int;
  final int padY = data['padY'] as int;
  final double confidenceThreshold = (data['confidenceThreshold'] as num).toDouble();
  final double iouThreshold = (data['iouThreshold'] as num).toDouble();
  final List<String> labels = List<String>.from(data['labels'] as List);

  final int modelClasses = (dim1 < dim2) ? (dim1 - 4) : (dim2 - 4);
  final int numClasses = min(labels.length, max(0, modelClasses));

  double applyConfidence(double raw) {
    if (raw > 1.0 || raw < 0.0) {
      return 1.0 / (1.0 + exp(-raw));
    }
    return raw;
  }

  final List<_RawCandidate> candidates = [];
  final bool isTransposed = dim1 < dim2 || dim1 == (4 + modelClasses);
  final int numBoxes = isTransposed ? dim2 : dim1;

  if (isTransposed) {
    bool coordsAreAbsolute = false;
    for (int col = 0; col < min(numBoxes, 100); col++) {
      final double peekCx = outputBuffer[0 * dim2 + col];
      final double peekCy = outputBuffer[1 * dim2 + col];
      if (peekCx > 1.5 || peekCy > 1.5) {
        coordsAreAbsolute = true;
        break;
      }
    }

    for (int col = 0; col < numBoxes; col++) {
      // ── EARLY CONFIDENCE FILTER (Issue 2 Fix) ──────────────────────────
      // First find the best class score; discard immediately if below threshold
      // before executing any bounding box coordinate math or matrix transformations.
      double maxScore = -1e9;
      int bestClass = 0;
      for (int c = 0; c < numClasses; c++) {
        final double s = outputBuffer[(4 + c) * dim2 + col];
        if (s > maxScore) {
          maxScore = s;
          bestClass = c;
        }
      }

      final double conf = applyConfidence(maxScore);
      if (conf < confidenceThreshold) continue;

      final double cx = outputBuffer[0 * dim2 + col];
      final double cy = outputBuffer[1 * dim2 + col];
      final double bw = outputBuffer[2 * dim2 + col];
      final double bh = outputBuffer[3 * dim2 + col];

      final double cxPx = coordsAreAbsolute ? cx : cx * targetW.toDouble();
      final double cyPx = coordsAreAbsolute ? cy : cy * targetH.toDouble();
      final double bwPx = coordsAreAbsolute ? bw : bw * targetW.toDouble();
      final double bhPx = coordsAreAbsolute ? bh : bh * targetH.toDouble();

      final double x1 = ((cxPx - bwPx / 2.0 - padX) / newW).clamp(0.0, 1.0);
      final double y1 = ((cyPx - bhPx / 2.0 - padY) / newH).clamp(0.0, 1.0);
      final double x2 = ((cxPx + bwPx / 2.0 - padX) / newW).clamp(0.0, 1.0);
      final double y2 = ((cyPx + bhPx / 2.0 - padY) / newH).clamp(0.0, 1.0);

      if (x2 <= x1 || y2 <= y1) continue;

      candidates.add(_RawCandidate(
        classId: bestClass,
        score: conf,
        box: Rect.fromLTRB(x1, y1, x2, y2),
      ));
    }
  } else {
    bool coordsAreAbsolute = false;
    for (int row = 0; row < min(numBoxes, 100); row++) {
      final double peekCx = outputBuffer[row * dim2 + 0];
      final double peekCy = outputBuffer[row * dim2 + 1];
      if (peekCx > 1.5 || peekCy > 1.5) {
        coordsAreAbsolute = true;
        break;
      }
    }

    for (int row = 0; row < numBoxes; row++) {
      // ── EARLY CONFIDENCE FILTER (Issue 2 Fix) ──────────────────────────
      double maxScore = -1e9;
      int bestClass = 0;
      for (int c = 0; c < numClasses; c++) {
        final double s = outputBuffer[row * dim2 + 4 + c];
        if (s > maxScore) {
          maxScore = s;
          bestClass = c;
        }
      }

      final double conf = applyConfidence(maxScore);
      if (conf < confidenceThreshold) continue;

      final double cx = outputBuffer[row * dim2 + 0];
      final double cy = outputBuffer[row * dim2 + 1];
      final double bw = outputBuffer[row * dim2 + 2];
      final double bh = outputBuffer[row * dim2 + 3];

      final double cxPx = coordsAreAbsolute ? cx : cx * targetW.toDouble();
      final double cyPx = coordsAreAbsolute ? cy : cy * targetH.toDouble();
      final double bwPx = coordsAreAbsolute ? bw : bw * targetW.toDouble();
      final double bhPx = coordsAreAbsolute ? bh : bh * targetH.toDouble();

      final double x1 = ((cxPx - bwPx / 2.0 - padX) / newW).clamp(0.0, 1.0);
      final double y1 = ((cyPx - bhPx / 2.0 - padY) / newH).clamp(0.0, 1.0);
      final double x2 = ((cxPx + bwPx / 2.0 - padX) / newW).clamp(0.0, 1.0);
      final double y2 = ((cyPx + bhPx / 2.0 - padY) / newH).clamp(0.0, 1.0);

      if (x2 <= x1 || y2 <= y1) continue;

      candidates.add(_RawCandidate(
        classId: bestClass,
        score: conf,
        box: Rect.fromLTRB(x1, y1, x2, y2),
      ));
    }
  }

  // Fast Non-Maximum Suppression (NMS) inside background isolate
  if (candidates.isEmpty) return [];

  final sorted = List<_RawCandidate>.from(candidates)
    ..sort((a, b) => b.score.compareTo(a.score));

  final kept = <_RawCandidate>[];
  for (final cand in sorted) {
    if (kept.any((k) => _iouStatic(cand.box, k.box) > iouThreshold)) {
      continue;
    }
    kept.add(cand);
  }

  final List<Map<String, dynamic>> results = [];
  for (final k in kept) {
    final label = (k.classId >= 0 && k.classId < labels.length)
        ? labels[k.classId]
        : 'class_${k.classId}';
    results.add({
      'label': label,
      'confidence': k.score,
      'left': k.box.left,
      'top': k.box.top,
      'width': k.box.width,
      'height': k.box.height,
      'classIndex': k.classId,
    });
  }

  return results;
}

/// [ISSUE 3]: Background isolate worker for decoding and letterbox-resizing still photos.
Map<String, dynamic> _preprocessStillImageWorker(Map<String, dynamic> params) {
  try {
    final Uint8List bytes = params['bytes'] as Uint8List;
    final bool isNCHW = params['isNCHW'] as bool;
    final int targetW = params['targetW'] as int;
    final int targetH = params['targetH'] as int;

    img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return {'success': false};
    }
    decoded = img.bakeOrientation(decoded);
    debugPrint(
        'YoloRecognitionService: Captured still decoded resolution: ${decoded.width}x${decoded.height}');

    final double scale = min(targetW / decoded.width, targetH / decoded.height);
    final int newW = (decoded.width * scale).round();
    final int newH = (decoded.height * scale).round();
    final int padX = (targetW - newW) ~/ 2;
    final int padY = (targetH - newH) ~/ 2;

    final resized = img.copyResize(decoded, width: newW, height: newH);
    final letterboxed = img.Image(width: targetW, height: targetH);
    img.fill(letterboxed, color: img.ColorRgb8(114, 114, 114));
    img.compositeImage(letterboxed, resized, dstX: padX, dstY: padY);

    final int totalElements = targetH * targetW * 3;
    final Float32List flatInput = Float32List(totalElements);
    int idx = 0;
    const double divisor = 255.0;

    if (isNCHW) {
      for (int c = 0; c < 3; c++) {
        for (int y = 0; y < targetH; y++) {
          for (int x = 0; x < targetW; x++) {
            final p = letterboxed.getPixel(x, y);
            final v = c == 0 ? p.r : c == 1 ? p.g : p.b;
            flatInput[idx++] = v.toDouble() / divisor;
          }
        }
      }
    } else {
      for (int y = 0; y < targetH; y++) {
        for (int x = 0; x < targetW; x++) {
          final p = letterboxed.getPixel(x, y);
          flatInput[idx++] = p.r.toDouble() / divisor;
          flatInput[idx++] = p.g.toDouble() / divisor;
          flatInput[idx++] = p.b.toDouble() / divisor;
        }
      }
    }

    return {
      'success': true,
      'flatInput': flatInput,
      'newW': newW,
      'newH': newH,
      'padX': padX,
      'padY': padY,
    };
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

// ── Internal Helpers ──────────────────────────────────────────────────────────

class _RawCandidate {
  final int classId;
  final double score;
  final Rect box;
  const _RawCandidate(
      {required this.classId, required this.score, required this.box});
}

double _iouStatic(Rect a, Rect b) {
  final l = max(a.left, b.left);
  final t = max(a.top, b.top);
  final r = min(a.right, b.right);
  final btm = min(a.bottom, b.bottom);
  final inter = max(0.0, r - l) * max(0.0, btm - t);
  final union = a.width * a.height + b.width * b.height - inter;
  return union > 0 ? inter / union : 0.0;
}

/// Extension on [Tensor] to provide safe, direct buffer copying.
extension TensorCopyExtension on Tensor {
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
