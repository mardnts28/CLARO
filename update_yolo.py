import re

with open('lib/services/yolo_recognition_service.dart', 'r') as f:
    content = f.read()

# 1. Update isolateArgs in detectProductsFromCameraImage
args_pattern = re.compile(r'final isolateArgs = <String, dynamic>\{([^}]+)\};', re.DOTALL)
new_args = '''final isolateArgs = <String, dynamic>{
        'w': cameraImage.width,
        'h': cameraImage.height,
        'yBuf': yBuf,
        'uBuf': uBuf,
        'vBuf': vBuf,
        'yStride': cameraImage.planes[0].bytesPerRow,
        'uvStride': cameraImage.planes[1].bytesPerRow,
        'uvPixStep': cameraImage.planes[1].bytesPerPixel ?? 1,
        'isNCHW': _isNCHW,
        'targetW': _isNCHW ? _inputShape[3] : _inputShape[2],
        'targetH': _isNCHW ? _inputShape[2] : _inputShape[1],
      };'''

content = args_pattern.sub(new_args, content)

# 2. Update Isolate function
isolate_pattern = re.compile(r'Map<String, dynamic> _preprocessCameraFrameIsolate.*', re.DOTALL)
new_isolate = '''Map<String, dynamic> _preprocessCameraFrameIsolate(Map<String, dynamic> args) {
  final int srcW = args['w'];
  final int srcH = args['h'];
  final Uint8List yBuf = args['yBuf'];
  final Uint8List uBuf = args['uBuf'];
  final Uint8List vBuf = args['vBuf'];
  final int yStride = args['yStride'];
  final int uvStride = args['uvStride'];
  final int uvPixStep = args['uvPixStep'];
  final bool isNCHW = args['isNCHW'];
  final int targetW = args['targetW'];
  final int targetH = args['targetH'];

  bool rotate = srcW > srcH;
  int realW = rotate ? srcH : srcW;
  int realH = rotate ? srcW : srcH;

  final double scale = min(targetW / realW, targetH / realH);
  final int newW = (realW * scale).round();
  final int newH = (realH * scale).round();
  final int padX = (targetW - newW) ~/ 2;
  final int padY = (targetH - newH) ~/ 2;

  final Object input;
  if (isNCHW) {
    input = [
      List.generate(3, (c) => List.generate(targetH, (y) => List.generate(targetW, (x) {
        if (x >= padX && x < padX + newW && y >= padY && y < padY + newH) {
          int rx = ((x - padX) / scale).floor().clamp(0, realW - 1);
          int ry = ((y - padY) / scale).floor().clamp(0, realH - 1);
          int sx = rotate ? ry : rx;
          int sy = rotate ? (srcH - 1 - rx) : ry;
          
          final int yIdx = sy * yStride + sx;
          final int uvIdx = (sy ~/ 2) * uvStride + (sx ~/ 2) * uvPixStep;
          final int yp = yBuf[yIdx];
          final int up = uBuf[uvIdx] - 128;
          final int vp = vBuf[uvIdx] - 128;
          
          if (c == 0) return (yp + 1.402 * vp).round().clamp(0, 255) / 255.0;
          if (c == 1) return (yp - 0.344136 * up - 0.714136 * vp).round().clamp(0, 255) / 255.0;
          return (yp + 1.772 * up).round().clamp(0, 255) / 255.0;
        }
        return 114.0 / 255.0;
      })))
    ];
  } else {
    input = [
      List.generate(targetH, (y) => List.generate(targetW, (x) {
        if (x >= padX && x < padX + newW && y >= padY && y < padY + newH) {
          int rx = ((x - padX) / scale).floor().clamp(0, realW - 1);
          int ry = ((y - padY) / scale).floor().clamp(0, realH - 1);
          int sx = rotate ? ry : rx;
          int sy = rotate ? (srcH - 1 - rx) : ry;
          
          final int yIdx = sy * yStride + sx;
          final int uvIdx = (sy ~/ 2) * uvStride + (sx ~/ 2) * uvPixStep;
          final int yp = yBuf[yIdx];
          final int up = uBuf[uvIdx] - 128;
          final int vp = vBuf[uvIdx] - 128;
          
          final double r = (yp + 1.402 * vp).round().clamp(0, 255) / 255.0;
          final double g = (yp - 0.344136 * up - 0.714136 * vp).round().clamp(0, 255) / 255.0;
          final double b = (yp + 1.772 * up).round().clamp(0, 255) / 255.0;
          return [r, g, b];
        }
        return [114.0 / 255.0, 114.0 / 255.0, 114.0 / 255.0];
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

content = isolate_pattern.sub(new_isolate, content)

with open('lib/services/yolo_recognition_service.dart', 'w') as f:
    f.write(content)
