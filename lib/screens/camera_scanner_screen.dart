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
import '../services/voice_assistant_service.dart';
import '../services/auth_service.dart';
import '../data/services/backend_locator.dart';
import 'product_detail_screen.dart';
import 'multi_scan_results_screen.dart';
import 'unknown_product_submission_screen.dart';
import '../models/product_model.dart';
import '../generated/l10n/app_localizations.dart';

class CameraScannerScreen extends StatefulWidget {
  final bool embeddedMode;
  final bool isActive;

  // When true, this screen is being used as a sub-flow (e.g. Product
  // Ranking's "Add Product" bottom sheet) rather than the main Scan tab.
  // On a successful recognition it pops itself with the resolved
  // product(s) instead of navigating on to ProductDetailScreen /
  // MultiScanResultsScreen -- everything else about the scan (camera,
  // YOLO detection, catalog lookup, history logging) is unchanged, so
  // callers get the exact same recognition behavior the rest of the app
  // uses, just handed back as a result instead of a new screen.
  final bool returnResultsOnDetect;

  const CameraScannerScreen({
    super.key,
    this.embeddedMode = false,
    this.isActive = true,
    this.returnResultsOnDetect = false,
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
        setState(() {
          _isProcessing = false;
          _isLiveAnalysisRunning = false;
          _qualityWarning = null;
        });
        _checkPermissionAndInit();
      } else {
        _continuousAnalysisTimer?.cancel();
        _stopImageStreamIfActive();
        _cameraController?.dispose();
        setState(() {
          _isProcessing = false;
          _isLiveAnalysisRunning = false;
          _cameraController = null;
        });
      }
    }
  }

  @override
  void deactivate() {
    _continuousAnalysisTimer?.cancel();
    _isProcessing = false;
    _isLiveAnalysisRunning = false;
    super.deactivate();
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

  // 5-8s fallback timeout tracking
  DateTime? _noProductStartTime;
  bool _isFallbackModalOpen = false;

  // Laser animation
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  // Background advisory prefetch cache tracking
  final Set<String> _prefetchedLabels = {};

  void _triggerAdvisoryPrefetch(List<DetectionResult> detections) {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;

    for (final det in detections) {
      if (det.confidence >= 0.50 && !_prefetchedLabels.contains(det.label)) {
        _prefetchedLabels.add(det.label);
        unawaited(() async {
          try {
            final product = await BackendLocator.productRepository.getProductByYoloLabel(det.label);
            final profile = await BackendLocator.userRepository.getHealthProfile(uid);
            final languageCode = mounted ? Localizations.localeOf(context).languageCode : 'en';
            await BackendLocator.productRankingService.prefetchAdvisory(
              product: product,
              user: profile,
              languageCode: languageCode,
            );
            debugPrint('CameraScannerScreen: Background advisory prefetch completed for ${det.label}');
          } catch (e) {
            debugPrint('CameraScannerScreen: Advisory prefetch skipped for ${det.label}: $e');
          }
        }());
      }
    }
  }


  @override
  void initState() {
    super.initState();
    HomeTabController.tabNotifier.addListener(_handleTabChange);
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (widget.isActive) {
      _checkPermissionAndInit();
    }
    _announceIfVisible();

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
    HomeTabController.tabNotifier.removeListener(_handleTabChange);
    _continuousAnalysisTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _stopImageStreamIfActive();
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
        ResolutionPreset.medium,
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


  Future<void> _stopImageStreamIfActive() async {
    if (_cameraController?.value.isStreamingImages == true) {
      try {
        await _cameraController?.stopImageStream();
      } catch (_) {}
    }
  }

  void _handleTabChange() {
    _announceIfVisible();
  }

  void _announceIfVisible() {
    if (HomeTabController.tabNotifier.value == 1 &&
        VoiceAssistantService.instance.isEnabled) {
      VoiceAssistantService.instance.announcePage('scan');
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
          // Throttle: process every 3rd frame to align with Camera2 ImageReader buffer recycling
          if (_frameCount % 3 != 0) return;

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

            const vl = (1.0 - 0.96) / 2.0;
            const vt = 0.04;
            const vr = vl + 0.96;
            const vb = 0.96;
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
              _noProductStartTime = null;
              _productFirstDetectedTime ??= DateTime.now();
              _lastSeenTime = DateTime.now();
              _triggerAdvisoryPrefetch(detections);
              
              final holdDurationMs = DateTime.now().difference(_productFirstDetectedTime!).inMilliseconds;
              if (holdDurationMs >= 1200) {
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

              // Track continuous time without any product in the guide rectangle
              _noProductStartTime ??= DateTime.now();
              final noProductDurationMs =
                  DateTime.now().difference(_noProductStartTime!).inMilliseconds;

              // 6 seconds continuous missing product threshold -> trigger guidance fallback
              if (noProductDurationMs >= 6000 && !_isFallbackModalOpen) {
                _showNoProductFallbackDialog();
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

    if (widget.returnResultsOnDetect) {
      // Add-product sub-flow: just back out to whoever pushed this screen
      // (e.g. CompareProductsScreen) without touching the app-wide tab
      // selection or clearing the rest of the navigation stack.
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    }

    HomeTabController.switchToTab(0);
    if (!widget.embeddedMode && Navigator.canPop(context)) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _showNoProductFallbackDialog({String? capturedImagePath}) {
    if (_isFallbackModalOpen || !mounted) return;
    _isFallbackModalOpen = true;

    final isTagalog = Localizations.localeOf(context).languageCode == 'tl';

    VoiceAssistantService.instance.speak(
      isTagalog
          ? 'Walang produktong nahanap sa camera. Subukang itapat nang mas malapit o ipagbigay-alam ang hindi kilalang produkto.'
          : 'No product detected on camera. Try moving closer or report the unknown product.',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isTl = Localizations.localeOf(ctx).languageCode == 'tl';
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Icon(Icons.help_outline_rounded,
                      color: Colors.amberAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    isTl ? 'Walang Produktong Nahanap' : 'No Product Found',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isTl
                        ? 'Hindi matukoy ang produkto sa camera. Pumili ng aksyon:'
                        : 'Could not detect product on camera. Choose an action:',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.report_problem_outlined),
                      label: Flexible(
                        child: Text(
                          isTl
                              ? 'I-report ang Hindi Kilalang Produkto'
                              : 'Report Unidentified Product',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _navigateToReportDirectly(capturedImagePath: capturedImagePath);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Flexible(
                        child: Text(
                          isTl ? 'Subukan Ulit' : 'Try Again',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        _isFallbackModalOpen = false;
        _noProductStartTime = DateTime.now();
        _startContinuousAnalysis();
      }
    });
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

  Future<void> _navigateToReportDirectly({String? capturedImagePath}) async {
    if (_isProcessing) return;

    _continuousAnalysisTimer?.cancel();

    String? path = capturedImagePath;
    if ((path == null || path.isEmpty) && _cameraController?.value.isInitialized == true) {
      try {
        await _stopImageStreamIfActive();
        await _cameraController!.setFlashMode(
          _isFlashOn ? FlashMode.torch : FlashMode.off,
        );
        final file = await _cameraController!.takePicture();
        path = file.path;
      } catch (e) {
        debugPrint('Could not take picture for direct report: $e');
      }
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UnknownProductSubmissionScreen(
          capturedImagePath: path,
        ),
      ),
    );

    if (mounted) {
      _startContinuousAnalysis();
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

    // Safety timer: if scanning resolution gets interrupted or hangs,
    // auto-reset _isProcessing state after 3.5 seconds.
    Timer? safetyTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _isProcessing) {
        debugPrint('CameraScannerScreen: Safety timer triggered, resetting analyze state.');
        setState(() {
          _isProcessing = false;
        });
        _startContinuousAnalysis();
      }
    });

    try {
      if (_cameraController?.value.isInitialized != true) {
        safetyTimer.cancel();
        setState(() => _isProcessing = false);
        _startContinuousAnalysis();
        return;
      }

      await _stopImageStreamIfActive();
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
           safetyTimer.cancel();
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
          safetyTimer.cancel();
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

      safetyTimer.cancel();

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
            // Fire-and-forget background log so UI navigation is instant
            unawaited(() async {
              try {
                for (int i = 0; i < count; i++) {
                  await FirebaseFirestore.instance.collection('unmatched_yolo_scans').add({
                    'label': label,
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                }
              } catch (_) {}
            }());
          }
        }

        final distinctProducts = resolvedProducts.toSet().toList();

        if (distinctProducts.isNotEmpty && widget.returnResultsOnDetect) {
          // Add-product sub-flow (Product Ranking screen): hand the
          // recognized product(s) straight back to the caller instead of
          // drilling into ProductDetailScreen / MultiScanResultsScreen.
          // History logging still happens, same as a normal scan.
          if (mounted) {
            for (var p in distinctProducts) {
              HistoryService().addScanRecord(p);
            }
            Navigator.pop(context, {
              'products': distinctProducts,
              'productCounts': productCounts,
            });
          }
        } else if (distinctProducts.length == 1) {
          if (mounted) {
            final singleProd = distinctProducts.first;
            HistoryService().addScanRecord(singleProd);
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
              if (mounted) {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                _startContinuousAnalysis();
              }
            });
          }
        } else if (distinctProducts.length > 1) {
          if (mounted) {
            for (var p in distinctProducts) {
              HistoryService().addScanRecord(p);
            }
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MultiScanResultsScreen(
                  detectedProducts: distinctProducts,
                  productCounts: productCounts,
                ),
              ),
            ).then((_) {
              if (mounted) {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                _startContinuousAnalysis();
              }
            });
          }
        } else {
          // Detections exist but none matched catalog -> show camera bottom sheet fallback dialog
          if (!mounted) return;
          _showNoProductFallbackDialog(capturedImagePath: imagePath);
        }
      } else {
        // Zero detections -> show camera bottom sheet fallback dialog
        if (!mounted) return;
        _showNoProductFallbackDialog(capturedImagePath: imagePath);
      }
    } catch (e) {
      safetyTimer.cancel();
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
                // Live camera preview
                Positioned.fill(
                  child: _cameraController?.value.isInitialized == true
                    ? CameraPreview(_cameraController!)
                    : const SizedBox.shrink(),
                ),

                // (Tap-to-scan removed — scanning is now fully automatic)

                // Dim overlay outside viewfinder & live region accessibility semantics
                Positioned.fill(
                  child: Semantics(
                    label: _getScannerSemanticLabel(context),
                    liveRegion: true,
                    container: true,
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
                ),

                // ── Static Guide text: "Point camera at product" ────────────
                // Positioned below the Close / Report / Flash buttons (which
                // sit at topPadding+16, 40px tall, so their bottom edge is at
                // topPadding+56) so it never overlaps or renders behind them.
                Positioned(
                  top: topPadding + 66,
                  left: 24,
                  right: 24,
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)!.scanGuideText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
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
                  child: Semantics(
                    button: true,
                    label: Localizations.localeOf(context).languageCode == 'tl'
                        ? 'Isara ang scanner'
                        : 'Close scanner',
                    child: GestureDetector(
                      onTap: _handleClose,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.black87, size: 20),
                      ),
                    ),
                  ),
                ),

                // ── Top-right actions (Report & Flash) ───────────────
                Positioned(
                  top: topPadding + 16,
                  right: 16,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Report icon button in top bar
                      Semantics(
                        button: true,
                        label: AppLocalizations.of(context)!.reportProductButton,
                        child: GestureDetector(
                          onTap: _navigateToReportDirectly,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.report_problem_outlined,
                              color: Colors.black87,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Flash icon button
                      Semantics(
                        button: true,
                        label: _isFlashOn
                            ? (Localizations.localeOf(context).languageCode == 'tl'
                                ? 'Patayin ang flash'
                                : 'Turn off flash')
                            : (Localizations.localeOf(context).languageCode == 'tl'
                                ? 'Buksan ang flash'
                                : 'Turn on flash'),
                        child: GestureDetector(
                          onTap: _toggleFlash,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isFlashOn ? Icons.flash_on : Icons.flash_off,
                              color: _isFlashOn
                                  ? const Color(0xFFFFD600)
                                  : Colors.black87,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Quality warning banner ──────────────────────────
                // Sits below the static guide text (which now starts at
                // topPadding + 66 and runs roughly two lines tall).
                if (_qualityWarning != null)
                  Positioned(
                    top: topPadding + 118,
                    left: 24,
                    right: 24,
                    child: Semantics(
                      liveRegion: true,
                      container: true,
                      label: _qualityWarning!,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.9),
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
                  ),

                // ── Dynamic Status Indicator + bottom helper prompt ──────
                // The status pill ("Scanning for product, hold steady") now
                // lives in the bottom portion of the screen, stacked
                // directly above the "Can't scan your product? Report here"
                // prompt in a single Column. Stacking them (rather than
                // using two independently-positioned widgets with fixed
                // pixel offsets) guarantees the pill never overlaps the
                // helper prompt below it, and its full-width (24/24) bounds
                // mean the complete status message stays visible instead of
                // being clipped.
                Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatusPill(),
                      const SizedBox(height: 12),
                      Semantics(
                        button: true,
                        label: Localizations.localeOf(context).languageCode == 'tl'
                            ? 'Hindi mahanap ang produkto? I-report'
                            : 'Can’t scan your product? Report here',
                        child: GestureDetector(
                          onTap: _navigateToReportDirectly,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white24,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.help_outline_rounded,
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    Localizations.localeOf(context).languageCode == 'tl'
                                        ? 'Hindi mahanap ang produkto? I-report'
                                        : 'Can’t scan your product? Report here',
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Colors.white70,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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

  String _getScannerSemanticLabel(BuildContext context) {
    final isTagalog = Localizations.localeOf(context).languageCode == 'tl';
    if (_isProcessing) {
      return isTagalog
          ? 'Sinusuri ang natukoy na produkto'
          : 'Analyzing detected product';
    } else if (_isProductInGuide) {
      return isTagalog
          ? 'Natukoy ang produkto sa viewfinder. Paki-hawak nang steady'
          : 'Product recognized in viewfinder. Hold steady';
    } else if (_liveDetections.isNotEmpty) {
      return isTagalog
          ? 'May natukoy na produkto sa viewfinder region'
          : 'Product detected near viewfinder';
    } else {
      return isTagalog
          ? 'Naghahanap ng mga produkto sa camera region'
          : 'Scanning camera view for food products';
    }
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
    } else if (_qualityWarning != null && _qualityWarning!.toLowerCase().contains('dark')) {
      statusText = isTagalog ? 'Masyadong Madilim - Buksan ang Flash' : 'Too Dark - Turn on Flash';
      statusColor = const Color(0xFFFFB74D);
      iconData = Icons.flash_on;
    } else if (_isProductInGuide) {
      statusText = isTagalog ? 'I-hold steady nang 1.2s...' : 'Hold steady... (1.2s)';
      statusColor = const Color(0xFF00E676);
      iconData = Icons.check_circle_rounded;
    } else {
      statusText = isTagalog ? 'Naghahanap ng mga produkto...' : 'Scanning for products...';
      statusColor = Colors.white70;
      iconData = Icons.center_focus_weak_rounded;
    }

    return Semantics(
      label: statusText,
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF00E676),
                ),
              )
            else
              Icon(
                iconData,
                size: 17,
                color: statusColor,
              ),
            const SizedBox(width: 8),
            // Font size increased (12 -> 15) for readability; no longer
            // constrained to a narrow pill width, so the full status
            // message (e.g. "Scanning for product, hold steady") stays
            // on-screen instead of being truncated with an ellipsis.
            Flexible(
              child: Text(
                statusText,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
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