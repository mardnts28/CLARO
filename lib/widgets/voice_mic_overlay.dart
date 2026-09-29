import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class _VoiceMicOverlayState extends State<VoiceMicOverlay>
    with SingleTickerProviderStateMixin {
  static const double _fabSize = 56;
  static const double _edgeMargin = 16;
  static const double _defaultBottomOffset = 86;

  Offset? _position;
  bool _isDragging = false;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Offset _clamp(Offset p, Rect bounds) => Offset(
        p.dx.clamp(bounds.left, bounds.right),
        p.dy.clamp(bounds.top, bounds.bottom),
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final padding = MediaQuery.paddingOf(context);

        // Allowed area for the top-left corner of the FAB.
        final bounds = Rect.fromLTRB(
          _edgeMargin,
          padding.top + _edgeMargin,
          (size.width - _fabSize - _edgeMargin).clamp(_edgeMargin, double.infinity),
          (size.height - _fabSize - padding.bottom - _edgeMargin)
              .clamp(padding.top + _edgeMargin, double.infinity),
        );

        final defaultPosition = Offset(
          bounds.right,
          bounds.bottom - (_defaultBottomOffset - _edgeMargin - _fabSize / 2),
        );
        final position = _clamp(_position ?? defaultPosition, bounds);

        return Stack(
          children: [
            widget.child,
            ValueListenableBuilder<bool>(
              valueListenable: VoiceAssistantService.isEnabledNotifier,
              builder: (context, isEnabled, _) {
                if (!isEnabled || !widget.showMic) {
                  return const SizedBox.shrink();
                }

                return AnimatedPositioned(
                  // Follow the finger instantly, glide when snapping to an edge.
                  duration: _isDragging
                      ? Duration.zero
                      : const Duration(milliseconds: 320),
                  curve: Curves.easeOutBack,
                  left: position.dx,
                  top: position.dy,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (_) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _isDragging = true;
                        _position = position;
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _position = _clamp(
                          (_position ?? position) + details.delta,
                          bounds,
                        );
                      });
                    },
                    onPanEnd: (_) {
                      HapticFeedback.lightImpact();
                      final current = _position ?? position;
                      final snapToLeft =
                          current.dx + _fabSize / 2 < size.width / 2;
                      setState(() {
                        _isDragging = false;
                        _position = Offset(
                          snapToLeft ? bounds.left : bounds.right,
                          current.dy,
                        );
                      });
                    },
                    onPanCancel: () => setState(() => _isDragging = false),
                    child: TweenAnimationBuilder<double>(
                      // Pop-in when the mic appears.
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) =>
                          Transform.scale(scale: value, child: child),
                      child: _buildFab(colors),
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

  Widget _buildFab(ColorScheme colors) {
    return Semantics(
      button: true,
      label: 'Voice assistant',
      hint: 'Tap to speak. Drag to move.',
      child: SizedBox(
        width: _fabSize,
        height: _fabSize,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Soft pulsing halo while idle.
            if (!_isDragging)
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) {
                    final t = Curves.easeOut.transform(_pulse.value);
                    return Transform.scale(
                      scale: 1 + 0.55 * t,
                      child: Container(
                        width: _fabSize,
                        height: _fabSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary.withOpacity(0.28 * (1 - t)),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Lift + glow while dragging.
            AnimatedScale(
              scale: _isDragging ? 1.14 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: _fabSize,
                height: _fabSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary
                          .withOpacity(_isDragging ? 0.45 : 0.28),
                      blurRadius: _isDragging ? 24 : 14,
                      spreadRadius: _isDragging ? 2 : 0,
                      offset: Offset(0, _isDragging ? 8 : 4),
                    ),
                  ],
                ),
                child: VoiceAssistantFab(
                  draggable: false,
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    VoiceCommandRouter.instance.handleMicTap(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}