// lib/screens/qr_scan_screen.dart
//
// Generic QR scanner. Currently used only for "Join via QR" (see
// widgets/join_group_dialog.dart), to scan the invite QR that
// InviteMemberScreen generates via qr_flutter with `data:
// invite.code` -- so a successful scan here just IS the invite code,
// no separate decoding/parsing needed. Pops with that raw decoded
// string on the first successful scan.
//
// NEW DEPENDENCY: this screen needs `mobile_scanner` added to
// pubspec.yaml, e.g.:
//
//   dependencies:
//     mobile_scanner: ^7.4.2
//
// Why a new package rather than reusing the app's existing camera code:
// camera_scanner_screen.dart already opens a camera, but it's a
// purpose-built product-recognition pipeline on top of the raw `camera`
// package (frame capture -> backend recognition), not a QR/barcode
// reader -- there's no decoding logic in there to hook into. Rather than
// bolt QR decoding onto that pipeline, this uses mobile_scanner, a
// well-maintained package built specifically for QR/barcode scanning,
// which also manages its own camera-permission prompt/UI so this screen
// doesn't need to duplicate that.

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../generated/l10n/app_localizations.dart';
import '../services/haptic_service.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> with WidgetsBindingObserver {
  late final MobileScannerController _controller;

  // Guards against onDetect firing more than once for the same code
  // (mobile_scanner can report multiple frames before the pop actually
  // unmounts this screen).
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes to prevent camera issues
    if (!mounted) return;
    
    switch (state) {
      case AppLifecycleState.resumed:
        // Restart camera when app is resumed
        if (_controller.value.isInitialized) {
          try {
            _controller.start();
          } catch (e) {
            debugPrint('Error restarting camera: $e');
          }
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Stop camera when app is paused/inactive
        try {
          _controller.stop();
        } catch (e) {
          debugPrint('Error stopping camera: $e');
        }
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
    _controller.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (value == null || value.isEmpty) return;

    _handled = true;
    HapticService().vibrate();
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(loc.scanQrTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'Flash',
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_outlined),
            tooltip: 'Switch camera',
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              // Attempt to recover from camera errors
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  try {
                    _controller.stop();
                    Future.delayed(const Duration(milliseconds: 200), () {
                      if (mounted) {
                        _controller.start();
                      }
                    });
                  } catch (e) {
                    debugPrint('Error recovering camera: $e');
                  }
                }
              });
              
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Camera error: ${error.toString()}',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Attempting to recover...',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
          // Simple viewfinder frame -- purely visual, doesn't affect
          // detection (mobile_scanner scans the full camera frame
          // regardless of this overlay).
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                loc.scanQrInstruction,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
