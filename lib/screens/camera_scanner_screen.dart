import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/yolo_recognition_service.dart';
import '../services/image_validation_service.dart';
import '../services/history_service.dart';
import '../services/home_tab_controller.dart';
import '../data/services/backend_locator.dart';
import 'product_detail_screen.dart';
import 'product_not_found_screen.dart';
import 'multi_scan_results_screen.dart';
import '../models/product_model.dart';
import '../generated/l10n/app_localizations.dart';

class CameraScannerScreen extends StatefulWidget {
  final bool embeddedMode;
  final bool isActive;
  const CameraScannerScreen({
    super.key,
    this.embeddedMode = false,
    this.isActive = true,
  });

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _cameraController;

  @override
  void didUpdateWidget(CameraScannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _checkPermissionAndInit();
      } else {
        _stopImageStreamIfActive();
        _cameraController?.dispose();
        setState(() {
          _cameraController = null;
        });
      }
    }
  }

  bool _isFlashOn = false;
  bool _isProcessing = false;
  String? _qualityWarning;

  final YoloRecognitionService _yoloService = YoloRecognitionService();
  final ImageValidationService _validationService = ImageValidationService();

  // Live detection & dynamic frame guide state
  Timer? _continuousAnalysisTimer;
  List<DetectionResult> _liveDetections = [];
  bool _isProductInGuide = false;

  DateTime? _productFirstDetectedTime;
  DateTime? _lastSeenTime;

  // Laser animation
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (widget.isActive) {
      _checkPermissionAndInit();
    }

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopImageStreamIfActive();
      _cameraController?.dispose();
      setState(() {
        _cameraController = null;
      });
    } else if (state == AppLifecycleState.resumed) {
      _checkPermissionAndInit();
    }
  }

  @override
  void dispose() {
    _continuousAnalysisTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _cameraController?.dispose();
    _laserController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkPermissionAndInit() async {
    // 1. Load the TFLite model first — camera frames must not arrive before
    //    the interpreter is ready or every frame silently returns [].
    await _yoloService.initialize();
    // 2. Only then start the camera (the camera plugin shows the OS
    //    permission dialog automatically on CameraController.initialize()).
    await _initCamera();
  }

  // Camera hardware lock — prevents _runLiveAnalysis and _performScan from
  // using the camera simultaneously.
  bool _isLiveAnalysisRunning = false;

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        back,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(FlashMode.off);
      if (mounted) {
        setState(() => _isFlashOn = false);
        // Wait 500ms for camera preview session to fully stabilize on Android
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _startContinuousAnalysis();
          }
        });
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }


  void _stopImageStreamIfActive() {
    if (_cameraController?.value.isStreamingImages == true) {
      try {
        _cameraController?.stopImageStream();
      } catch (_) {}
    }
  }

  int _frameCount = 0;

  void _startContinuousAnalysis() {
    _continuousAnalysisTimer?.cancel();
    _productFirstDetectedTime = null;
    _frameCount = 0;

    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    if (_cameraController?.value.isStreamingImages != true) {
      try {
        _cameraController?.startImageStream((CameraImage image) {
          _frameCount++;
          // Throttle: process every 4th frame (~7.5 fps target if source is 30fps)
          if (_frameCount % 4 != 0) return;

          if (_isProcessing || _isLiveAnalysisRunning || !mounted) return;

          _isLiveAnalysisRunning = true;

          final sensorOrientation =
              _cameraController?.description.sensorOrientation ?? 90;

          _yoloService
              .detectProductsFromCameraImage(image, sensorOrientation)
              .then((detections) {
            debugPrint('Live scan detections count: ${detections.length} (${detections.map((d) => d.label).join(", ")})');
            if (!mounted) {
              _isLiveAnalysisRunning = false;
              return;
            }

            const vl = (1.0 - 0.88) / 2.0;
            const vt = 0.12;
            const vr = vl + 0.88;
            const vb = 0.88;
            const guideRect = Rect.fromLTRB(vl, vt, vr, vb);

            bool productInGuide = false;
            for (final det in detections) {
              final detRect = det.boundingBox;
              final cx = detRect.left + detRect.width / 2.0;
              final cy = detRect.top + detRect.height / 2.0;
              if (det.confidence >= _yoloService.confidenceThreshold &&
                  (guideRect.contains(Offset(cx, cy)) ||
                      detRect.overlaps(guideRect))) {
                productInGuide = true;
              }
            }

            // Only rebuild if something actually changed
            final changed = _liveDetections.length != detections.length ||
                _isProductInGuide != productInGuide;
            if (changed) {
              setState(() {
                _liveDetections = detections;
                _isProductInGuide = productInGuide;
              });
            }

            if (productInGuide && !_isProcessing) {
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
            }

            _isLiveAnalysisRunning = false;
          }).catchError((e) {
            debugPrint('Live analysis error: $e');
            _isLiveAnalysisRunning = false;
          });
        });
      } catch (e) {
        debugPrint('startImageStream error: $e');
      }
    }
  }



  void _handleClose() {
    _continuousAnalysisTimer?.cancel();
    HomeTabController.switchToTab(0);
    if (!widget.embeddedMode && Navigator.canPop(context)) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _toggleFlash() async {
    if (_cameraController?.value.isInitialized == true) {
      final nextState = !_isFlashOn;
      try {
        await _cameraController!.setFlashMode(
          nextState ? FlashMode.torch : FlashMode.off,
        );
        setState(() => _isFlashOn = nextState);
      } catch (e) {
        debugPrint('Flash toggle error: $e');
      }
    }
  }

  Future<void> _performScan() async {
    if (_isProcessing) return;

    _continuousAnalysisTimer?.cancel();

    // Wait for any in-flight live analysis to finish
    int waitAttempts = 0;
    while (_isLiveAnalysisRunning && waitAttempts < 20) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitAttempts++;
    }

    setState(() {
      _isProcessing = true;
      _qualityWarning = null;
    });

    try {
      if (_cameraController?.value.isInitialized != true) {
        setState(() => _isProcessing = false);
        _startContinuousAnalysis();
        return;
      }

      _stopImageStreamIfActive();
      await _cameraController!.setFlashMode(
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
      }

      // YOLO detection
      final List<DetectionResult> detections = imagePath.isNotEmpty 
          ? await _yoloService.detectProducts(imagePath) 
          : _liveDetections;

      debugPrint('CameraScannerScreen: YOLO detected ${detections.length} objects: '
          '${detections.map((d) => "${d.label} (${(d.confidence * 100).toStringAsFixed(1)}%)").join(", ")}');

      setState(() {
        _isProcessing = false;
      });

      if (detections.isNotEmpty) {
        final List<Product> resolvedProducts = [];
        final Map<String, int> productCounts = {};

        // Extract unique YOLO labels and their counts first
        final Map<String, int> labelCounts = {};
        for (var det in detections) {
          labelCounts[det.label] = (labelCounts[det.label] ?? 0) + 1;
        }

        // Query database once per unique label
        for (var entry in labelCounts.entries) {
          final label = entry.key;
          final count = entry.value;
          try {
            final prod =
                await BackendLocator.productRepository.getProductByYoloLabel(label);
            resolvedProducts.add(prod);
            productCounts[prod.id] = (productCounts[prod.id] ?? 0) + count;
          } catch (e) {
            debugPrint('CameraScannerScreen: product lookup failed for $label: $e');
            try {
              for (int i = 0; i < count; i++) {
                await FirebaseFirestore.instance.collection('unmatched_yolo_scans').add({
                  'label': label,
                  'timestamp': FieldValue.serverTimestamp(),
                });
              }
            } catch (_) {}
          }
        }

        final distinctProducts = resolvedProducts.toSet().toList();

        if (distinctProducts.length == 1) {
          if (mounted) {
            final singleProd = distinctProducts.first;
            HistoryService().addScanRecord(singleProd);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(
                  product: singleProd,
                  confidence: detections.first.confidence,
                  productCounts: productCounts,
                ),
              ),
            ).then((_) {
              if (mounted) _startContinuousAnalysis();
            });
          }
        } else if (distinctProducts.length > 1) {
          if (mounted) {
            for (var p in distinctProducts) {
              HistoryService().addScanRecord(p);
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MultiScanResultsScreen(
                  detectedProducts: distinctProducts,
                  productCounts: productCounts,
                ),
              ),
            ).then((_) {
              if (mounted) _startContinuousAnalysis();
            });
          }
        } else {
          // Detections exist but none matched catalog -> ProductNotFoundScreen
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductNotFoundScreen(
                capturedImagePath: imagePath,
              ),
            ),
          ).then((_) {
            if (mounted) _startContinuousAnalysis();
          });
        }
      } else {
        // Zero detections -> ProductNotFoundScreen
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductNotFoundScreen(
              capturedImagePath: imagePath,
            ),
          ),
        ).then((_) {
          if (mounted) _startContinuousAnalysis();
        });
      }
    } catch (e) {
      debugPrint('Scan error: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _qualityWarning = 'Scan failed. Please try again.';
        });
        _startContinuousAnalysis();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // ── Camera / Simulator view ─────────────────────────────
          Expanded(
            child: Stack(
              children: [
                // Live camera preview or permission-denied / simulator fallback
                Positioned.fill(
                  child: _cameraController?.value.isInitialized == true
                    ? CameraPreview(_cameraController!)
                    : const SizedBox.shrink(),
                ),

                // (Tap-to-scan removed — scanning is now fully automatic)

                // Viewfinder overlay & dynamic green/white border painter
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _laserAnimation,
                      builder: (_, __) => CustomPaint(
                        painter: _ScannerOverlayPainter(
                          laserProgress: _laserAnimation.value,
                          isProcessing: _isProcessing,
                          isProductInGuide: _isProductInGuide,
                          detections: _liveDetections,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Sleek status pill header ─────────────────────────────
                Positioned(
                  top: topPadding + 18,
                  left: 70,
                  right: 70,
                  child: Center(
                    child: _buildStatusPill(),
                  ),
                ),

                // ── Guide text: "Fit to camera to scan" ─────────────
                Positioned(
                  top: topPadding + 105,
                  left: 24,
                  right: 24,
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)!.scanGuideText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            offset: Offset(0, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── X (Close) button top-left ──────────────────────
                Positioned(
                  top: topPadding + 16,
                  left: 16,
                  child: GestureDetector(
                    onTap: _handleClose,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.black87, size: 22),
                    ),
                  ),
                ),

                // ── Flash button top-right ─────────────────────────
                Positioned(
                  top: topPadding + 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: _toggleFlash,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isFlashOn ? Icons.flash_on : Icons.flash_off,
                        color: _isFlashOn
                            ? const Color(0xFFFFD600)
                            : Colors.black87,
                        size: 22,
                      ),
                    ),
                  ),
                ),

                // ── Quality warning banner ──────────────────────────
                if (_qualityWarning != null)
                  Positioned(
                    top: topPadding + 70,
                    left: 24,
                    right: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _qualityWarning!,
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Processing spinner ──────────────────────────────
                if (_isProcessing)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black38,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4CAF50),
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  ),

              ],
            ),
          ),

          // (Bottom tap-hint bar removed — scanning is fully automatic)
        ],
      ),
    );
  }

  Widget _buildStatusPill() {
    String statusText;
    Color statusColor;
    IconData iconData;

    final isTagalog = Localizations.localeOf(context).languageCode == 'tl';

    if (_isProcessing) {
      statusText = isTagalog ? 'Sinusuri ang Produkto...' : 'Analyzing Product...';
      statusColor = const Color(0xFF00E676);
      iconData = Icons.sync;
    } else if (_isProductInGuide) {
      statusText = isTagalog ? 'Nakilala ang Produkto' : 'Product Recognized';
      statusColor = const Color(0xFF00E676);
      iconData = Icons.check_circle_rounded;
    } else {
      statusText = isTagalog ? 'Naghahanap ng mga produkto...' : 'Scanning for products...';
      statusColor = Colors.white70;
      iconData = Icons.center_focus_weak_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isProductInGuide || _isProcessing
              ? const Color(0xFF00E676)
              : Colors.white24,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isProcessing)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF00E676),
              ),
            )
          else
            Icon(
              iconData,
              size: 15,
              color: statusColor,
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              statusText,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // (_buildPermissionDeniedView removed — OS native permission dialog is used instead)
}

// ── Custom Scanner Overlay Painter ──────────────────────────────────────────
class _ScannerOverlayPainter extends CustomPainter {
  final double laserProgress;
  final bool isProcessing;
  final bool isProductInGuide;
  final List<DetectionResult> detections;

  _ScannerOverlayPainter({
    required this.laserProgress,
    required this.isProcessing,
    required this.isProductInGuide,
    required this.detections,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Viewfinder: 88% wide, stretched from top controls to near bottom
    final vw = w * 0.88;
    final vl = (w - vw) / 2;
    final vt = h * 0.12;   // starts just below top controls
    final vr = vl + vw;
    final vb = h * 0.88;   // stretches to near bottom
    final vh = vb - vt;

    // Dim the region outside viewfinder
    final dimPaint = Paint()..color = Colors.black.withOpacity(0.55);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, vt), dimPaint);
    canvas.drawRect(Rect.fromLTWH(0, vb, w, h - vb), dimPaint);
    canvas.drawRect(Rect.fromLTWH(0, vt, vl, vh), dimPaint);
    canvas.drawRect(Rect.fromLTWH(vr, vt, w - vr, vh), dimPaint);

    // Frame guide border color: turns VIVID NEON GREEN when product detected in guide, else white
    final guideColor = isProductInGuide
        ? const Color(0xFF00E676)
        : (isProcessing ? const Color(0xFF69F0AE) : Colors.white70);

    final bracketPaint = Paint()
      ..color = guideColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isProductInGuide ? 5.0 : 3.5
      ..strokeJoin = StrokeJoin.round;

    const arm = 28.0;

    final pathTL = Path()
      ..moveTo(vl + arm, vt)
      ..lineTo(vl, vt)
      ..lineTo(vl, vt + arm);

    final pathTR = Path()
      ..moveTo(vr - arm, vt)
      ..lineTo(vr, vt)
      ..lineTo(vr, vt + arm);

    final pathBL = Path()
      ..moveTo(vl + arm, vb)
      ..lineTo(vl, vb)
      ..lineTo(vl, vb - arm);

    final pathBR = Path()
      ..moveTo(vr - arm, vb)
      ..lineTo(vr, vb)
      ..lineTo(vr, vb - arm);

    if (isProductInGuide) {
      final glowPaint = Paint()
        ..color = const Color(0xFF00E676).withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0
        ..strokeJoin = StrokeJoin.round;
        // maskFilter is handled in the painter if blur is supported.
      canvas.drawPath(pathTL, glowPaint);
      canvas.drawPath(pathTR, glowPaint);
      canvas.drawPath(pathBL, glowPaint);
      canvas.drawPath(pathBR, glowPaint);
    }

    canvas.drawPath(pathTL, bracketPaint);
    canvas.drawPath(pathTR, bracketPaint);
    canvas.drawPath(pathBL, bracketPaint);
    canvas.drawPath(pathBR, bracketPaint);

    // Draw live bounding boxes for detected products — green when detected,
    // default (white semi-transparent) when nothing is detected. Limit to top 5 products.
    final boxColor = detections.isNotEmpty
        ? const Color(0xFF00E676)
        : Colors.white54;
    final boxPaint = Paint()
      ..color = boxColor.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (final det in detections.take(5)) {
      final rect = Rect.fromLTRB(
        det.boundingBox.left * w,
        det.boundingBox.top * h,
        det.boundingBox.right * w,
        det.boundingBox.bottom * h,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        boxPaint,
      );
    }
    // (Label/text overlays on bounding boxes removed for clean camera view)

    // Laser scan animation line
    final laserY = vt + (vh * laserProgress);
    final laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          guideColor.withOpacity(0.9),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTRB(vl, laserY - 1, vr, laserY + 1))
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(vl, laserY), Offset(vr, laserY), laserPaint);
  }

  // (_formatLabelText removed — label overlays removed from bounding boxes)

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter old) =>
      old.laserProgress != laserProgress ||
      old.isProcessing != isProcessing ||
      old.isProductInGuide != isProductInGuide ||
      old.detections != detections;
}