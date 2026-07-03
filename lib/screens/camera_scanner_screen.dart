import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/yolo_recognition_service.dart';
import '../services/image_validation_service.dart';
import '../services/product_db_service.dart';
import '../services/nutrition_service.dart';
import '../services/history_service.dart';
import 'product_detail_screen.dart';
import 'unknown_product_submission_screen.dart';
import 'multi_scan_results_screen.dart';
import '../models/product_model.dart';

class CameraScannerScreen extends StatefulWidget {
  const CameraScannerScreen({super.key});

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isPermissionGranted = false;
  bool _isFlashOn = false;
  bool _isProcessing = false;
  bool _showCapturedBadge = false;
  String? _qualityWarning;

  final YoloRecognitionService _yoloService = YoloRecognitionService();
  final ImageValidationService _validationService = ImageValidationService();
  final ProductDbService _dbService = ProductDbService();

  // Laser animation
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  // Simulator toggles
  bool _simulateDark = false;
  bool _simulateBlur = false;
  bool _simulateMultiScan = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _yoloService.initialize();
    _checkPermissionAndInit();

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _cameraController?.dispose();
    _laserController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionAndInit() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() => _isPermissionGranted = true);
      await _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        back, ResolutionPreset.high, enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _toggleFlash() async {
    if (_cameraController?.value.isInitialized == true) {
      await _cameraController!.setFlashMode(
        _isFlashOn ? FlashMode.off : FlashMode.torch,
      );
    }
    setState(() => _isFlashOn = !_isFlashOn);
  }

  Future<void> _performScan() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _qualityWarning = null;
      _showCapturedBadge = false;
    });

    try {
      String imagePath = 'simulator_mock.jpg';

      if (_cameraController?.value.isInitialized == true) {
        final file = await _cameraController!.takePicture();
        imagePath = file.path;
      }

      // Quality check
      ImageQualityResult quality;
      if (_cameraController == null) {
        quality = ImageQualityResult(
          isValid: !_simulateDark && !_simulateBlur,
          isTooDark: _simulateDark,
          isBlurry: _simulateBlur,
          message: _simulateDark
              ? 'Too dark. Move to a brighter area.'
              : _simulateBlur
                  ? 'Image blurry. Hold steady.'
                  : 'OK',
          brightnessScore: _simulateDark ? 10.0 : 80.0,
          sharpnessScore: _simulateBlur ? 5.0 : 75.0,
        );
      } else {
        quality = await _validationService.validateImageQuality(imagePath);
      }

      if (!quality.isValid) {
        setState(() {
          _qualityWarning = quality.message;
          _isProcessing = false;
        });
        return;
      }

      // YOLO detection
      final detections = await _yoloService.detectProducts(
        imagePath,
        forceScanCount: _simulateMultiScan ? 5 : null,
      );

      setState(() {
        _isProcessing = false;
        _showCapturedBadge = true;
      });

      // Hide badge after 1.5s then navigate
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      setState(() => _showCapturedBadge = false);

      if (detections.isNotEmpty) {
        final List<Product> products = [];
        for (var det in detections) {
          final prod = _dbService.getProductById(det.label);
          if (prod != null) {
            final enriched = await NutritionService().getProductByName(prod.name);
            products.add(enriched ?? prod);
          }
        }

        if (products.length == 1) {
          if (mounted) {
            HistoryService().addScanRecord(products.first);
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(
                    product: products.first,
                    confidence: detections.first.confidence,
                  ),
                ),
              );
            }
          }
        } else if (products.length > 1) {
          if (mounted) {
            for (var p in products) {
              HistoryService().addScanRecord(p);
            }
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MultiScanResultsScreen(
                    detectedProducts: products,
                  ),
                ),
              );
            }
          }
        }
      } else {
        // No product recognized → fallback
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search_off_rounded, size: 56, color: Colors.grey),
                const SizedBox(height: 16),
                Text('Product Not Recognized',
                    style: GoogleFonts.outfit(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'The product could not be identified. Would you like to submit it for review?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.black54, height: 1.5),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Try Again',
                            style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const UnknownProductSubmissionScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB71C1C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Submit',
                            style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _qualityWarning = 'Scan failed. Please try again.';
      });
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
                // Camera preview or simulator placeholder
                Positioned.fill(
                  child: _isPermissionGranted &&
                          _cameraController?.value.isInitialized == true
                      ? CameraPreview(_cameraController!)
                      : _buildSimulatorView(),
                ),

                // Dim overlay outside viewfinder
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _laserAnimation,
                    builder: (_, __) => CustomPaint(
                      painter: _ScannerOverlayPainter(
                        laserProgress: _laserAnimation.value,
                        isProcessing: _isProcessing,
                      ),
                    ),
                  ),
                ),

                // ── Guide text: "Fit to camera to scan" ─────────────
                Positioned(
                  top: topPadding + 90,
                  left: 24,
                  right: 24,
                  child: Center(
                    child: Text(
                      'I-align ang label ng produkto upang i-scan',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white.withAlpha(180), // enough visibility only
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          const Shadow(
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
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(220),
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
                        color: Colors.white.withAlpha(220),
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
                    top: 70,
                    left: 24,
                    right: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withAlpha(230),
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

                // ── "Product Captured!" badge ───────────────────────
                if (_showCapturedBadge)
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(210),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4CAF50),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check,
                                  color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Product Captured!',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Tap-to-scan area (covers viewfinder center) ─────
                if (!_isProcessing && !_showCapturedBadge)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _performScan,
                      behavior: HitTestBehavior.translucent,
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ),

          // ── Bottom tap-hint bar ─────────────────────────────────
          Container(
            color: Colors.black,
            padding: EdgeInsets.only(
              top: 14,
              bottom: MediaQuery.of(context).padding.bottom + 14,
            ),
            child: Text(
              'Tap anywhere to scan',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: Colors.white54, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulatorView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined,
                size: 64, color: Color(0xFF4CAF50)),
            const SizedBox(height: 20),
            Text('Simulator Mode',
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Tap the screen to simulate a product scan.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: Colors.white54, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            // Debug toggles
            _buildSimToggle('Simulate Dark', _simulateDark, (v) {
              setState(() {
                _simulateDark = v;
                if (v) _simulateBlur = false;
              });
            }),
            _buildSimToggle('Simulate Blur', _simulateBlur, (v) {
              setState(() {
                _simulateBlur = v;
                if (v) _simulateDark = false;
              });
            }),
            _buildSimToggle('Simulate Multi-Scan (5 items)', _simulateMultiScan, (v) {
              setState(() {
                _simulateMultiScan = v;
              });
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSimToggle(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF4CAF50),
          activeTrackColor: const Color(0xFF4CAF50).withAlpha(80),
        ),
      ],
    );
  }
}

// ── Custom Scanner Overlay Painter ──────────────────────────────────────────
class _ScannerOverlayPainter extends CustomPainter {
  final double laserProgress;
  final bool isProcessing;

  _ScannerOverlayPainter(
      {required this.laserProgress, required this.isProcessing});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Viewfinder: 78% wide, 48% tall, vertically centered slightly above middle
    final vw = w * 0.78;
    final vh = h * 0.48;
    final vl = (w - vw) / 2;
    final vt = (h - vh) / 2 - h * 0.04;
    final vr = vl + vw;
    final vb = vt + vh;

    // Dim the outside
    final dimPaint = Paint()..color = Colors.black.withAlpha(140);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, vt), dimPaint);
    canvas.drawRect(Rect.fromLTWH(0, vb, w, h - vb), dimPaint);
    canvas.drawRect(Rect.fromLTWH(0, vt, vl, vh), dimPaint);
    canvas.drawRect(Rect.fromLTWH(vr, vt, w - vr, vh), dimPaint);

    // Corner bracket paint (using continuous paths to ensure zero corner gaps)
    final cornerColor =
        isProcessing ? const Color(0xFF69F0AE) : const Color(0xFF4CAF50);
    final bracketPaint = Paint()
      ..color = cornerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeJoin = StrokeJoin.round;

    const arm = 28.0;

    // Top-left
    final pathTL = Path()
      ..moveTo(vl + arm, vt)
      ..lineTo(vl, vt)
      ..lineTo(vl, vt + arm);
    canvas.drawPath(pathTL, bracketPaint);

    // Top-right
    final pathTR = Path()
      ..moveTo(vr - arm, vt)
      ..lineTo(vr, vt)
      ..lineTo(vr, vt + arm);
    canvas.drawPath(pathTR, bracketPaint);

    // Bottom-left
    final pathBL = Path()
      ..moveTo(vl + arm, vb)
      ..lineTo(vl, vb)
      ..lineTo(vl, vb - arm);
    canvas.drawPath(pathBL, bracketPaint);

    // Bottom-right
    final pathBR = Path()
      ..moveTo(vr - arm, vb)
      ..lineTo(vr, vb)
      ..lineTo(vr, vb - arm);
    canvas.drawPath(pathBR, bracketPaint);

    // Laser scan line
    final laserY = vt + (vh * laserProgress);
    final laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          cornerColor.withAlpha(220),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTRB(vl, laserY - 1, vr, laserY + 1))
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(vl, laserY), Offset(vr, laserY), laserPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter old) =>
      old.laserProgress != laserProgress || old.isProcessing != isProcessing;
}
