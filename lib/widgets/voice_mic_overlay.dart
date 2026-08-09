import 'package:flutter/material.dart';

import '../services/voice_assistant_service.dart';
import '../services/voice_command_router.dart';
import 'voice_assistant_fab.dart';

class VoiceMicOverlay extends StatefulWidget {
  final Widget child;
  final bool showMic;

  const VoiceMicOverlay({super.key, required this.child, this.showMic = true});

  @override
  State<VoiceMicOverlay> createState() => _VoiceMicOverlayState();
}

class _VoiceMicOverlayState extends State<VoiceMicOverlay> {
  Offset? _position;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final defaultPosition = Offset(
          size.width - 72,
          size.height - MediaQuery.of(context).padding.bottom - 142,
        );
        final position = _position ?? defaultPosition;
        final maxX = (size.width - 56).clamp(0.0, double.infinity);
        final maxY = (size.height - 56).clamp(0.0, double.infinity);
        final safePosition = Offset(
          position.dx.clamp(0.0, maxX),
          position.dy.clamp(0.0, maxY),
        );

        return Stack(
          children: [
            widget.child,
            ValueListenableBuilder<bool>(
              valueListenable: VoiceAssistantService.isEnabledNotifier,
              builder: (context, isEnabled, child) {
                if (!isEnabled || !widget.showMic) {
                  return const SizedBox.shrink();
                }

                return Positioned(
                  left: safePosition.dx,
                  top: safePosition.dy,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _position = (_position ?? safePosition) + details.delta;
                      });
                    },
                    child: VoiceAssistantFab(
                      draggable: false,
                      onPressed: () => VoiceCommandRouter.instance.handleMicTap(context),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
