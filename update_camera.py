import re

with open('lib/screens/camera_scanner_screen.dart', 'r') as f:
    content = f.read()

# 1. Add WidgetsBindingObserver
content = content.replace(
    'with SingleTickerProviderStateMixin {',
    'with SingleTickerProviderStateMixin, WidgetsBindingObserver {'
)

# 2. Add addObserver and removeObserver
content = content.replace(
    'super.initState();',
    'super.initState();\n    WidgetsBinding.instance.addObserver(this);'
)
content = content.replace(
    'super.dispose();',
    'WidgetsBinding.instance.removeObserver(this);\n    super.dispose();'
)

# 3. Add didChangeAppLifecycleState
lifecycle_code = '''
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopImageStreamIfActive();
      _cameraController?.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      _checkPermissionAndInit();
    }
  }

  @override
'''
content = content.replace('  @override\n  void dispose() {', lifecycle_code + '  void dispose() {')

# 4. Add _lastSeenTime
content = content.replace(
    'DateTime? _productFirstDetectedTime;',
    'DateTime? _productFirstDetectedTime;\n  DateTime? _lastSeenTime;'
)

# 5. Replace hold logic
old_hold_logic = '''              if (productInGuide && !_isProcessing) {
                _productFirstDetectedTime ??= DateTime.now();
                final holdDuration = DateTime.now().difference(_productFirstDetectedTime!).inSeconds;
                
                if (holdDuration >= 5) {
                  _productFirstDetectedTime = null;
                  _performScan();
                }
              } else {
                _productFirstDetectedTime = null;
              }'''

new_hold_logic = '''              if (productInGuide && !_isProcessing) {
                _productFirstDetectedTime ??= DateTime.now();
                _lastSeenTime = DateTime.now();
                
                final holdDuration = DateTime.now().difference(_productFirstDetectedTime!).inSeconds;
                if (holdDuration >= 3) {
                  _productFirstDetectedTime = null;
                  _lastSeenTime = null;
                  _performScan();
                }
              } else if (!_isProcessing) {
                if (_lastSeenTime != null) {
                  final missedDuration = DateTime.now().difference(_lastSeenTime!).inMilliseconds;
                  if (missedDuration > 1500) {
                    _productFirstDetectedTime = null;
                    _lastSeenTime = null;
                  }
                }
              }'''
content = content.replace(old_hold_logic, new_hold_logic)

# 6. Fallback for manual capture and Unmatched logging
# First we need to import cloud_firestore
if "import 'package:cloud_firestore/cloud_firestore.dart';" not in content:
    content = content.replace(
        "import 'package:camera/camera.dart';",
        "import 'package:camera/camera.dart';\nimport 'package:cloud_firestore/cloud_firestore.dart';"
    )

old_scan_start = '''      await _cameraController!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
      final file = await _cameraController!.takePicture();
      final imagePath = file.path;

      // Quality check
      final quality = await _validationService.validateImageQuality(imagePath);'''

new_scan_start = '''      await _cameraController!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
      
      XFile? file;
      try {
        file = await _cameraController!.takePicture();
      } on CameraException catch (e) {
        debugPrint('takePicture failed: $e');
        if (_liveDetections.isNotEmpty) {
           debugPrint('Falling back to live detections.');
        } else {
           setState(() {
             _isProcessing = false;
             _qualityWarning = 'Camera busy. Try again.';
           });
           _startContinuousAnalysis();
           return;
        }
      }

      final String imagePath = file?.path ?? '';
      
      // If we fell back to live detections, we skip quality check (or assume valid enough)
      if (imagePath.isNotEmpty) {
        final quality = await _validationService.validateImageQuality(imagePath);
        if (!quality.isValid) {
          setState(() {
            _qualityWarning = quality.message;
            _isProcessing = false;
          });
          _startContinuousAnalysis();
          return;
        }
      }'''
content = content.replace(old_scan_start, new_scan_start)

# Remove the old quality check abort since we moved it above
content = content.replace('''
      if (!quality.isValid) {
        setState(() {
          _qualityWarning = quality.message;
          _isProcessing = false;
        });
        _startContinuousAnalysis();
        return;
      }
''', '')

# Replace detection call to use fallback
old_det_call = '''      // YOLO detection
      final List<DetectionResult> detections = await _yoloService.detectProducts(imagePath);'''
new_det_call = '''      // YOLO detection
      final List<DetectionResult> detections = imagePath.isNotEmpty 
          ? await _yoloService.detectProducts(imagePath) 
          : _liveDetections;'''
content = content.replace(old_det_call, new_det_call)

# 7. Unmatched Firestore logging
old_product_loop = '''        for (var det in detections) {
          try {
            final prod =
                await BackendLocator.productRepository.getProductByYoloLabel(det.label);
            resolvedProducts.add(prod);
            productCounts[prod.id] = (productCounts[prod.id] ?? 0) + 1;
          } catch (e) {
            debugPrint('CameraScannerScreen: product lookup failed for ${det.label}: $e');
          }
        }'''
new_product_loop = '''        for (var det in detections) {
          try {
            final prod =
                await BackendLocator.productRepository.getProductByYoloLabel(det.label);
            resolvedProducts.add(prod);
            productCounts[prod.id] = (productCounts[prod.id] ?? 0) + 1;
          } catch (e) {
            debugPrint('CameraScannerScreen: product lookup failed for ${det.label}: $e');
            try {
              await FirebaseFirestore.instance.collection('unmatched_yolo_scans').add({
                'label': det.label,
                'timestamp': FieldValue.serverTimestamp(),
              });
            } catch (_) {}
          }
        }'''
content = content.replace(old_product_loop, new_product_loop)

with open('lib/screens/camera_scanner_screen.dart', 'w') as f:
    f.write(content)

