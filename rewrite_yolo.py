import re

with open('lib/services/yolo_recognition_service.dart', 'r') as f:
    content = f.read()

# 1. Change confidenceThreshold
content = content.replace('double confidenceThreshold = 0.25;', 'double confidenceThreshold = 0.15;')

# 2. Replace detectProductsFromCameraImage and _convertYUV420ToImage
detect_func_pattern = re.compile(
    r'(\s*/// Detect products directly from a live camera frame.*?)'
    r'(\s*// ── Inference pipeline ──)',
    re.DOTALL
)

new_detect_logic = '''
  /// Detect products directly from a live camera frame.
  Future<List<DetectionResult>> detectProductsFromCameraImage(
      CameraImage cameraImage) async {
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

      // Must copy bytes because CameraImage planes are destroyed quickly
      final yBuf = Uint8List.fromList(cameraImage.planes[0].bytes);
      final uBuf = Uint8List.fromList(cameraImage.planes[1].bytes);
      final vBuf = Uint8List.fromList(cameraImage.planes[2].bytes);

      final isolateArgs = <String, dynamic>{
        'w': cameraImage.width,
        'h': cameraImage.height,
        'yBuf': yBuf,
        'uBuf': uBuf,
        'vBuf': vBuf,
        'yStride': cameraImage.planes[0].bytesPerRow,
        'uvStride': cameraImage.planes[1].bytesPerRow,
        'uvPixStep': cameraImage.planes[1].bytesPerPixel ?? 1,
        'isNCHW': _isNCHW,
      };

      // Offload heavy processing to Isolate to prevent UI freeze
      final result = await compute(_preprocessCameraFrameIsolate, isolateArgs);

      final inputTensorList = result['input'];
      final newW = result['newW'] as int;
      final newH = result['newH'] as int;
      final padX = result['padX'] as int;
      final padY = result['padY'] as int;

      final int dim1 = _outputShape.length >= 2 ? _outputShape[1] : 61;
      final int dim2 = _outputShape.length >= 3 ? _outputShape[2] : 8400;
      final output = List.generate(
          1, (_) => List.generate(dim1, (_) => List<double>.filled(dim2, 0.0)));

      // Inference
      _interpreter!.run(inputTensorList, output);

      return _decodeOutput(
        output: output,
        dim1: dim1,
        dim2: dim2,
        newW: newW,
        newH: newH,
        padX: padX,
        padY: padY,
      );
    } catch (e) {
      debugPrint('YOLO live frame error: $e');
      return [];
    }
  }

  // ── Inference pipeline ──'''

content = detect_func_pattern.sub(new_detect_logic, content)

# 3. Replace Decode output section in _inferencePass
decode_pattern = re.compile(
    r'(\s*// ── Decode output ──.*?)(?=\s*// ── NMS ──)',
    re.DOTALL
)

new_decode_logic = '''
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
    // ── Decode output ─────────────────────────────────────────────────────────
    final int numClasses = _labels.length; // e.g. 57
    final int numBoxes = dim2; // 8400
    final List<_RawCandidate> candidates = [];

    double applyConfidence(double raw) {
      if (raw >= 0.0 && raw <= 1.0) return raw; // already a probability
      if (raw > 10.0) return 1.0;
      if (raw < -10.0) return 0.0;
      return 1.0 / (1.0 + exp(-raw));
    }

    final bool isTransposed = dim1 == (4 + numClasses); // [1, 61, 8400]

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

        final x1 = ((cx - bw / 2.0 - padX) / newW).clamp(0.0, 1.0);
        final y1 = ((cy - bh / 2.0 - padY) / newH).clamp(0.0, 1.0);
        final x2 = ((cx + bw / 2.0 - padX) / newW).clamp(0.0, 1.0);
        final y2 = ((cy + bh / 2.0 - padY) / newH).clamp(0.0, 1.0);

        if (x2 <= x1 || y2 <= y1) continue;

        candidates.add(_RawCandidate(
          classId: bestClass,
          score: conf,
          box: Rect.fromLTRB(x1, y1, x2, y2),
        ));
      }
    } else {
      // [1, 8400, 61]
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

        final x1 = ((cx - bw / 2.0 - padX) / newW).clamp(0.0, 1.0);
        final y1 = ((cy - bh / 2.0 - padY) / newH).clamp(0.0, 1.0);
        final x2 = ((cx + bw / 2.0 - padX) / newW).clamp(0.0, 1.0);
        final y2 = ((cy + bh / 2.0 - padY) / newH).clamp(0.0, 1.0);

        if (x2 <= x1 || y2 <= y1) continue;

        candidates.add(_RawCandidate(
          classId: bestClass,
          score: conf,
          box: Rect.fromLTRB(x1, y1, x2, y2),
        ));
      }
    }

'''

content = decode_pattern.sub(new_decode_logic, content)

# 4. Append the top-level isolate function at the end
isolate_func = '''
// ── Isolate Processing ───────────────────────────────────────────────────────

Map<String, dynamic> _preprocessCameraFrameIsolate(Map<String, dynamic> args) {
  final int srcW = args['w'];
  final int srcH = args['h'];
  final Uint8List yBuf = args['yBuf'];
  final Uint8List uBuf = args['uBuf'];
  final Uint8List vBuf = args['vBuf'];
  final int yStride = args['yStride'];
  final int uvStride = args['uvStride'];
  final int uvPixStep = args['uvPixStep'];
  final bool isNCHW = args['isNCHW'];

  const int targetW = 640;
  const int targetH = 640;

  bool rotate = srcW > srcH;
  int realW = rotate ? srcH : srcW;
  int realH = rotate ? srcW : srcH;

  final double scale = min(targetW / realW, targetH / realH);
  final int newW = (realW * scale).round();
  final int newH = (realH * scale).round();
  final int padX = (targetW - newW) ~/ 2;
  final int padY = (targetH - newH) ~/ 2;

  final int outW = srcW ~/ 2;
  final int outH = srcH ~/ 2;
  final image = img.Image(width: outW, height: outH);

  for (int row = 0; row < outH; row++) {
    for (int col = 0; col < outW; col++) {
      final int yIdx = (row * 2) * yStride + (col * 2);
      final int uvIdx = row * uvStride + col * uvPixStep;
      final int yp = yBuf[yIdx];
      final int up = uBuf[uvIdx] - 128;
      final int vp = vBuf[uvIdx] - 128;

      final int r = (yp + 1.402 * vp).round().clamp(0, 255);
      final int g = (yp - 0.344136 * up - 0.714136 * vp).round().clamp(0, 255);
      final int b = (yp + 1.772 * up).round().clamp(0, 255);
      image.setPixelRgb(col, row, r, g, b);
    }
  }

  img.Image finalImage = image;
  if (rotate) {
    finalImage = img.copyRotate(finalImage, angle: 90);
  }
  
  final resized = img.copyResize(finalImage, width: newW, height: newH);
  final letterboxed = img.Image(width: targetW, height: targetH);
  img.fill(letterboxed, color: img.ColorRgb8(114, 114, 114));
  img.compositeImage(letterboxed, resized, dstX: padX, dstY: padY);

  final Object input;
  if (isNCHW) {
    input = [
      List.generate(3, (c) => List.generate(targetH, (y) => List.generate(targetW, (x) {
        final p = letterboxed.getPixel(x, y);
        final v = c == 0 ? p.r : c == 1 ? p.g : p.b;
        return v.toDouble() / 255.0;
      })))
    ];
  } else {
    input = [
      List.generate(targetH, (y) => List.generate(targetW, (x) {
        final p = letterboxed.getPixel(x, y);
        return [
          p.r.toDouble() / 255.0,
          p.g.toDouble() / 255.0,
          p.b.toDouble() / 255.0,
        ];
      }))
    ];
  }

  return {
    'input': input,
    'newW': newW,
    'newH': newH,
    'padX': padX,
    'padY': padY,
  };
}
'''
content += isolate_func

with open('lib/services/yolo_recognition_service.dart', 'w') as f:
    f.write(content)
