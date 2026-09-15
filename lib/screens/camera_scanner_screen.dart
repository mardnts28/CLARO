import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/yolo_recognition_service.dart';
import '../services/image_validation_service.dart';
import '../services/history_service.dart';
import '../services/home_tab_controller.dart';
import '../services/voice_assistant_service.dart';
import '../services/haptic_service.dart';
import '../data/services/backend_locator.dart';
import 'product_detail_screen.dart';
import 'multi_scan_results_screen.dart';
import 'unknown_product_submission_screen.dart';
import '../models/product_model.dart';
import '../core/utils/success_feedback_utils.dart';
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
    with WidgetsBindingObserver {
  CameraController? _cameraController;

  @override
  void didUpdateWidget(CameraScannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        setState(() {
          _isProcessing = false;
          _qualityWarning = null;
        });
        _checkPermissionAndInit();
      } else {
        _stopImageStreamIfActive();
        _cameraController?.dispose();
        setState(() {
          _isProcessing = false;
          _cameraController = null;
        });
      }
    }
  }

  @override
  void deactivate() {
    _isProcessing = false;
    super.deactivate();
  }

  bool _isFlashOn = false;
  bool _isProcessing = false;
  String? _qualityWarning;

  final YoloRecognitionService _yoloService = YoloRecognitionService();
  final ImageValidationService _validationService = ImageValidationService();

  // Detection & frame guide state (populated only when user taps to scan)
  List<DetectionResult> _liveDetections = [];
  bool _isProductInGuide = false;
  bool _hasTappedToScan = false;
  bool _isFallbackModalOpen = false;
  bool _isScreenActive = true;

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
  }

  bool _isInitializingCamera = false;
  bool _cameraInitFailed = false;
  String? _cameraErrorMessage;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopImageStreamIfActive();
      _cameraController?.dispose();
      setState(() {
        _cameraController = null;
      });
    } else if (state == AppLifecycleState.resumed) {
      final isScanTab = !widget.embeddedMode || HomeTabController.tabNotifier.value == 1;
      if (isScanTab && mounted) {
        _checkPermissionAndInit();
      }
    }
  }

  @override
  void dispose() {
    HomeTabController.tabNotifier.removeListener(_handleTabChange);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _stopImageStreamIfActive();
    _cameraController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Concurrency Guard — ensures initialize() can only be in-flight once.
  Future<void> _checkPermissionAndInit() async {
    if (_isInitializingCamera) {
      debugPrint('[Camera] Initialization already in progress, skipping duplicate request.');
      return;
    }
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      debugPrint('[Camera] Camera already initialized and running.');
      return;
    }
    _isInitializingCamera = true;
    if (mounted) {
      setState(() {
        _cameraInitFailed = false;
        _cameraErrorMessage = null;
      });
    }

    try {
      debugPrint('[Camera] Step 1: Initializing YOLO background service...');
      await _yoloService.initialize();

      debugPrint('[Camera] Step 2: Initializing Camera Hardware...');
      await _initCameraWithFallback();
    } catch (e) {
      debugPrint('[Camera] Fatal initialization exception: $e');
      if (mounted) {
        setState(() {
          _cameraInitFailed = true;
          _cameraErrorMessage = e.toString();
        });
      }
    } finally {
      _isInitializingCamera = false;
    }
  }

  /// Hardware Camera Configuration with Resolution Fallback
  Future<void> _initCameraWithFallback() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('[Camera] No cameras found on device.');
        if (mounted) {
          setState(() {
            _cameraInitFailed = true;
            _cameraErrorMessage = 'No camera found on this device.';
          });
        }
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // Fully dispose any previous controller to prevent resource leaks
      if (_cameraController != null) {
        try {
          await _stopImageStreamIfActive();
          await _cameraController!.dispose();
        } catch (e) {
          debugPrint('[Camera] Error disposing previous controller: $e');
        }
        _cameraController = null;
      }

      // Attempt 1: ResolutionPreset.medium with explicit YUV_420 format
      bool success = false;
      try {
        debugPrint('[Camera] Attempting controller creation with ResolutionPreset.medium...');
        final controller = CameraController(
          back,
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.yuv420,
        );
        debugPrint('[Camera] Calling controller.initialize()...');
        await controller.initialize();
        await controller.setFlashMode(FlashMode.off);
        _cameraController = controller;
        success = true;
        debugPrint('[Camera] ResolutionPreset.medium initialize() completed successfully! Preview size: ${controller.value.previewSize}');
      } catch (mediumErr) {
        debugPrint('[Camera] ResolutionPreset.medium failed ($mediumErr). Falling back to ResolutionPreset.low...');
      }

      // Attempt 2: ResolutionPreset.low fallback
      if (!success) {
        if (_cameraController != null) {
          try {
            await _cameraController!.dispose();
          } catch (_) {}
          _cameraController = null;
        }

        try {
          debugPrint('[Camera] Attempting fallback with ResolutionPreset.low...');
          final lowController = CameraController(
            back,
            ResolutionPreset.low,
            enableAudio: false,
            imageFormatGroup: ImageFormatGroup.yuv420,
          );
          debugPrint('[Camera] Calling lowController.initialize()...');
          await lowController.initialize();
          await lowController.setFlashMode(FlashMode.off);
          _cameraController = lowController;
          success = true;
          debugPrint('[Camera] ResolutionPreset.low fallback initialize() completed successfully! Preview size: ${lowController.value.previewSize}');
        } catch (lowErr) {
          debugPrint('[Camera] ResolutionPreset.low fallback also failed: $lowErr');
          if (mounted) {
            setState(() {
              _cameraInitFailed = true;
              _cameraErrorMessage = 'Camera hardware initialization failed ($lowErr). Tap to retry.';
            });
          }
          return;
        }
      }

      if (mounted && success) {
        setState(() {
          _isFlashOn = false;
          _cameraInitFailed = false;
        });
        debugPrint('[Camera] Camera preview ready. Smooth native preview active — awaiting user tap to scan.');
      }
    } catch (e) {
      debugPrint('[Camera] _initCameraWithFallback outer error: $e');
      if (mounted) {
        setState(() {
          _cameraInitFailed = true;
          _cameraErrorMessage = 'Camera error: $e';
        });
      }
    }
  }

  Future<void> _stopImageStreamIfActive() async {
    if (_cameraController?.value.isStreamingImages == true) {
      try {
        debugPrint('[Camera] Stopping image stream...');
        await _cameraController?.stopImageStream();
      } catch (_) {}
    }
  }

  void _handleTabChange() {
    final isScanTab = !widget.embeddedMode || HomeTabController.tabNotifier.value == 1;
    if (isScanTab) {
      _isScreenActive = true;
      _hasTappedToScan = false;
      _announceIfVisible();
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        _checkPermissionAndInit();
      }
    } else {
      _isScreenActive = false;
      _hasTappedToScan = false;
      _isFallbackModalOpen = false;
      _stopImageStreamIfActive();
    }
  }

  void _announceIfVisible() {
    if (HomeTabController.tabNotifier.value == 1 &&
        VoiceAssistantService.instance.isEnabled) {
      VoiceAssistantService.instance.announcePage('scan');
    }
  }

  void _handleClose() {
    if (widget.returnResultsOnDetect) {
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
    if (_isFallbackModalOpen || !mounted || !_isScreenActive) return;
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
                      label: Text(
                        isTl
                            ? 'I-report ang Hindi Kilalang Produkto'
                            : 'Report Unidentified Product',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
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
                      label: Text(
                        isTl ? 'Subukan Ulit' : 'Try Again',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
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
        setState(() {
          _isFallbackModalOpen = false;
          _hasTappedToScan = false;
          _isProcessing = false;
          _liveDetections = [];
          _isProductInGuide = false;
        });
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
      setState(() {
        _hasTappedToScan = false;
        _isProcessing = false;
        _liveDetections = [];
        _isProductInGuide = false;
      });
    }
  }

  /// Runs YOLO object detection ONLY after user explicitly taps the screen or shutter button.
  Future<void> _performScan() async {
    if (_isProcessing) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _hasTappedToScan = true;
      _qualityWarning = null;
    });

    // Safety timer: 8.0s timeout to reset UI in case hardware capture stalls
    Timer? safetyTimer = Timer(const Duration(milliseconds: 8000), () {
      if (mounted && _isProcessing) {
        debugPrint('CameraScannerScreen: Safety timer triggered, resetting scan state.');
        setState(() {
          _isProcessing = false;
          _hasTappedToScan = false;
          _qualityWarning = 'Scan timed out. Please try again.';
        });
      }
    });

    try {
      // Step 1: Set flash mode safely
      await _cameraController!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );

      // Step 2: Take picture safely from camera hardware
      XFile? file;
      try {
        file = await _cameraController!.takePicture();
      } on CameraException catch (e) {
        debugPrint('takePicture failed: $e');
        safetyTimer.cancel();
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _hasTappedToScan = false;
            _qualityWarning = 'Camera busy. Please try again.';
          });
        }
        return;
      }

      final String imagePath = file.path;

      if (imagePath.isNotEmpty) {
        final quality = await _validationService.validateImageQuality(imagePath);
        if (!quality.isValid) {
          safetyTimer.cancel();
          if (mounted) {
            setState(() {
              _qualityWarning = quality.message;
              _isProcessing = false;
              _hasTappedToScan = false;
            });
          }
          return;
        }
      }

      // Step 3: Run YOLO detection on the captured still photo
      debugPrint('CameraScannerScreen: Running YOLO detection on captured image...');
      final List<DetectionResult> detections = imagePath.isNotEmpty
          ? await _yoloService.detectProducts(imagePath)
          : <DetectionResult>[];

      debugPrint('CameraScannerScreen: YOLO detected ${detections.length} objects: '
          '${detections.map((d) => "${d.label} (${(d.confidence * 100).toStringAsFixed(1)}%)").join(", ")}');

      safetyTimer.cancel();
      if (!mounted) return;

      if (detections.isNotEmpty) {
        setState(() {
          _liveDetections = detections;
          _isProductInGuide = true;
        });
        HapticService().vibrate();
        SystemSound.play(SystemSoundType.click);
        await _resolveAndNavigateDetections(detections, imagePath);
      } else {
        setState(() {
          _isProcessing = false;
          _hasTappedToScan = false;
          _liveDetections = [];
          _isProductInGuide = false;
        });
        _showNoProductFallbackDialog(capturedImagePath: imagePath);
      }
    } catch (e) {
      safetyTimer.cancel();
      debugPrint('Scan error: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _hasTappedToScan = false;
          _qualityWarning = 'Scan error. Please try again.';
        });
      }
    }
  }

  Future<void> _resolveAndNavigateDetections(
    List<DetectionResult> detections,
    String imagePath,
  ) async {
    setState(() {
      _isProcessing = false;
      _hasTappedToScan = false;
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
        }
      }

      final distinctProducts = resolvedProducts.toSet().toList();

      if (distinctProducts.any((p) => p.isOfflineFallback) && mounted) {
        final loc = AppLocalizations.of(context)!;
        await SuccessFeedbackUtils.showOfflineNoticeDialog(
          context,
          title: loc.noInternetTitle,
          message: loc.noInternetNutritionMessage,
          buttonText: loc.gotIt,
        );
        if (!mounted) return;
      }

      if (distinctProducts.isNotEmpty && widget.returnResultsOnDetect) {
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
          _isScreenActive = false;
          await _stopImageStreamIfActive();
          if (!mounted) return;
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
            if (mounted && (!widget.embeddedMode || HomeTabController.tabNotifier.value == 1)) {
              setState(() {
                _isScreenActive = true;
                _hasTappedToScan = false;
                _isProcessing = false;
                _liveDetections = [];
                _isProductInGuide = false;
              });
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
            }
          });
        }
      } else if (distinctProducts.length > 1) {
        if (mounted) {
          for (var p in distinctProducts) {
            HistoryService().addScanRecord(p);
          }
          _isScreenActive = false;
          await _stopImageStreamIfActive();
          if (!mounted) return;
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
            if (mounted && (!widget.embeddedMode || HomeTabController.tabNotifier.value == 1)) {
              setState(() {
                _isScreenActive = true;
                _hasTappedToScan = false;
                _isProcessing = false;
                _liveDetections = [];
                _isProductInGuide = false;
              });
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
            }
          });
        }
      } else {
        if (!mounted) return;
        _showNoProductFallbackDialog(capturedImagePath: imagePath);
      }
    } else {
      if (!mounted) return;
      _showNoProductFallbackDialog(capturedImagePath: imagePath);
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
                // Live camera preview (smooth native 60fps, no continuous frame processing)
                Positioned.fill(
                  child: _cameraController?.value.isInitialized == true
                    ? CameraPreview(_cameraController!)
                    : const SizedBox.shrink(),
                ),

                // Camera Hardware Init Error Fallback Card
                if (_cameraInitFailed)
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.videocam_off_outlined, color: Colors.amber, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              _cameraErrorMessage ?? 'Camera initialization error',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () {
                                _isInitializingCamera = false;
                                _checkPermissionAndInit();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry Camera'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B1A1A),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Viewfinder Tap-to-Scan Gesture: Tap anywhere on viewfinder to scan!
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      if (_isProcessing) return;
                      HapticService().vibrate();
                      _performScan();
                    },
                  ),
                ),

                // Center "Tap anywhere to scan" hint (visible when idle)
                if (!_hasTappedToScan && !_isProcessing)
                  Positioned.fill(
                    child: Center(
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: _hasTappedToScan ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 250),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.touch_app_outlined,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  AppLocalizations.of(context)!.tapToScanHint,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Dim overlay outside viewfinder & live region accessibility semantics
                Positioned.fill(
                  child: Semantics(
                    label: _getScannerSemanticLabel(context),
                    liveRegion: true,
                    container: true,
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ScannerOverlayPainter(
                          isProcessing: _isProcessing,
                          isProductInGuide: _isProductInGuide,
                          detections: _liveDetections,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Static Guide text: "Point camera at product" ────────────
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

                // ── Dynamic Status Indicator + Shutter Button + Report Prompt ──────
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

                // ── Processing spinner overlay ──────────────────────
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
    } else {
      return isTagalog
          ? 'Pindutin kahit saan sa screen para mag-scan ng produkto'
          : 'Tap anywhere on screen to scan product';
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
    } else if (_qualityWarning != null) {
      if (_qualityWarning!.toLowerCase().contains('dark')) {
        statusText = isTagalog ? 'Masyadong Madilim - Buksan ang Flash' : 'Too Dark - Turn on Flash';
        statusColor = const Color(0xFFFFB74D);
        iconData = Icons.flash_on;
      } else {
        statusText = _qualityWarning!;
        statusColor = const Color(0xFFFFB74D);
        iconData = Icons.warning_amber_rounded;
      }
    } else {
      statusText = isTagalog ? 'Handa na' : 'Ready';
      statusColor = Colors.white70;
      iconData = Icons.check_circle_outline_rounded;
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
                : (_qualityWarning != null
                    ? const Color(0xFFFFB74D)
                    : Colors.white24),
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
  final bool isProcessing;
  final bool isProductInGuide;
  final List<DetectionResult> detections;

  _ScannerOverlayPainter({
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
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
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
        ..color = const Color(0xFF00E676).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(pathTL, glowPaint);
      canvas.drawPath(pathTR, glowPaint);
      canvas.drawPath(pathBL, glowPaint);
      canvas.drawPath(pathBR, glowPaint);
    }

    canvas.drawPath(pathTL, bracketPaint);
    canvas.drawPath(pathTR, bracketPaint);
    canvas.drawPath(pathBL, bracketPaint);
    canvas.drawPath(pathBR, bracketPaint);

    // Draw live bounding boxes for detected products — strictly clipped within the viewfinder
    final boxColor = detections.isNotEmpty
        ? const Color(0xFF00E676)
        : Colors.white54;
    final boxPaint = Paint()
      ..color = boxColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(vl, vt, vw, vh));

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
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter old) =>
      old.isProcessing != isProcessing ||
      old.isProductInGuide != isProductInGuide ||
      old.detections != detections;
}