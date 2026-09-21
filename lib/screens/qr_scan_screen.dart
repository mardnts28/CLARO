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
//     mobile_scanner: ^5.2.3
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

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  // Guards against onDetect firing more than once for the same code
  // (mobile_scanner can report multiple frames before the pop actually
  // unmounts this screen).
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
          MobileScanner(controller: _controller, onDetect: _onDetect),
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
