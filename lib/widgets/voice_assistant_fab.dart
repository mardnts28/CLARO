import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../services/voice_assistant_service.dart';
import '../services/haptic_service.dart';
import '../services/voice_command_router.dart';

class VoiceAssistantFab extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool draggable;

  const VoiceAssistantFab({
    super.key,
    this.onPressed,
    this.draggable = true,
  });

  @override
  State<VoiceAssistantFab> createState() => _VoiceAssistantFabState();
}

class _VoiceAssistantFabState extends State<VoiceAssistantFab>
    with TickerProviderStateMixin {
  late final AnimationController _rippleController;
  late final AnimationController _waveController;
  late final AnimationController _breathingController;

  Offset _dragOffset = Offset.zero;
  Offset _activeDragDelta = Offset.zero;

  @override
  void initState() {
    super.initState();

    // Main expanding pulse
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Wave movement
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    // Subtle breathing effect for the microphone itself
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    VoiceAssistantService.isListeningNotifier.addListener(
      _handleListeningChanged,
    );

    _handleListeningChanged();
  }

  @override
  void dispose() {
    VoiceAssistantService.isListeningNotifier.removeListener(
      _handleListeningChanged,
    );

    _rippleController.dispose();
    _waveController.dispose();
    _breathingController.dispose();

    super.dispose();
  }

  void _handleListeningChanged() {
    final isListening = VoiceAssistantService.isListeningNotifier.value;

    if (isListening) {
      if (!_rippleController.isAnimating) {
        _rippleController.repeat();
      }

      if (!_waveController.isAnimating) {
        _waveController.repeat();
      }

      if (!_breathingController.isAnimating) {
        _breathingController.repeat(reverse: true);
      }
    } else {
      _rippleController.stop();
      _rippleController.reset();

      _waveController.stop();
      _waveController.reset();

      _breathingController.stop();
      _breathingController.reset();
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<bool>(
      valueListenable: VoiceAssistantService.isEnabledNotifier,
      builder: (context, isEnabled, child) {
        if (!isEnabled) {
          return const SizedBox.shrink();
        }

        return ValueListenableBuilder<bool>(
          valueListenable: VoiceAssistantService.isListeningNotifier,
          builder: (context, isListening, child) {
            final button = SizedBox(
              width: 56,
              height: 56,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _rippleController,
                  _waveController,
                  _breathingController,
                ]),
                builder: (context, child) {
                  final breathing =
                      math.sin(_breathingController.value * math.pi);

                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Large soft glow behind the microphone
                      if (isListening)
                        _buildGlow(
                          theme,
                          breathing,
                        ),

                      // Expanding circular pulses
                      if (isListening)
                        for (var index = 0; index < 3; index++)
                          _buildRipple(
                            theme,
                            (_rippleController.value + (index / 3)) % 1.0,
                          ),

                      // Moving audio-wave effect
                      if (isListening)
                        _buildListeningWave(
                          theme,
                          _waveController.value,
                        ),

                      // Microphone button
                      child!,
                    ],
                  );
                },
                child: FloatingActionButton(
                  heroTag: 'voice_assistant_fab_${context.hashCode}',
                  onPressed: () {
                    HapticService().vibrate();

                    if (widget.onPressed != null) {
                      widget.onPressed!();
                    } else {
                      VoiceCommandRouter.instance.handleMicTap(context);
                    }
                  },
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  elevation: isListening ? 6 : 4,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: child,
                      );
                    },
                    child: Icon(
                      isListening ? Icons.mic : Icons.mic_none,
                      key: ValueKey(isListening),
                    ),
                  ),
                ),
              ),
            );

            final positionedButton = Transform.translate(
              offset: _dragOffset,
              child: button,
            );

            if (!widget.draggable) {
              return positionedButton;
            }

            return Draggable<String>(
              data: 'voice-mic',
              maxSimultaneousDrags: 1,
              feedback: Material(
                color: Colors.transparent,
                child: button,
              ),
              childWhenDragging: Opacity(
                opacity: 0.25,
                child: button,
              ),
              onDragStarted: () {
                _activeDragDelta = Offset.zero;
              },
              onDragUpdate: (details) {
                _activeDragDelta += details.delta;
              },
              onDragEnd: (_) {
                setState(() {
                  _dragOffset += _activeDragDelta;
                  _activeDragDelta = Offset.zero;
                });
              },
              child: positionedButton,
            );
          },
        );
      },
    );
  }

  /// Soft glow that gently expands and contracts while listening.
  Widget _buildGlow(
    ThemeData theme,
    double breathing,
  ) {
    final size = 66.0 + (breathing * 12.0);
    final opacity = 0.10 + (breathing * 0.10);

    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.primary.withValues(
            alpha: opacity,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(
                alpha: 0.18 + (breathing * 0.12),
              ),
              blurRadius: 18 + (breathing * 8),
              spreadRadius: 3 + (breathing * 3),
            ),
          ],
        ),
      ),
    );
  }

  /// Expanding pulse rings.
  Widget _buildRipple(
    ThemeData theme,
    double progress,
  ) {
    final easedProgress = Curves.easeOut.transform(progress);

    final size = 56.0 + (easedProgress * 82.0);

    final opacity = 0.55 * (1.0 - easedProgress);

    final strokeWidth = 2.5 - (easedProgress * 1.0);

    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.primary.withValues(
              alpha: opacity,
            ),
            width: strokeWidth,
          ),
        ),
      ),
    );
  }

  /// Dynamic circular waveform.
  ///
  /// This creates a moving wave around the microphone.
  /// If the voice service later exposes microphone amplitude,
  /// the `intensity` value can be connected to the real audio level.
  Widget _buildListeningWave(
    ThemeData theme,
    double progress,
  ) {
    return IgnorePointer(
      child: SizedBox(
        width: 160,
        height: 160,
        child: CustomPaint(
          painter: _ListeningWavePainter(
            color: theme.colorScheme.primary,
            progress: progress,
          ),
        ),
      ),
    );
  }
}

class _ListeningWavePainter extends CustomPainter {
  final Color color;
  final double progress;

  const _ListeningWavePainter({
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Four wave layers.
    for (var ring = 0; ring < 4; ring++) {
      final ringProgress = (progress + ring * 0.25) % 1.0;

      final baseRadius = 42.0 + (ringProgress * 32.0);

      // Fade the wave as it moves outward.
      final fade = 1.0 - ringProgress;

      // Make the wave stronger in the middle of its movement.
      final waveStrength =
          math.sin(ringProgress * math.pi) * 5.0;

      paint
        ..strokeWidth = 1.5 + (fade * 1.2)
        ..color = color.withValues(
          alpha: 0.08 + (fade * 0.18),
        );

      final path = Path();

      const points = 120;

      for (var point = 0; point <= points; point++) {
        final angle =
            (point / points) * math.pi * 2;

        // Multiple sine waves create an organic audio-wave appearance.
        final wave1 = math.sin(
              angle * 5 +
                  progress * math.pi * 2,
            ) *
            waveStrength;

        final wave2 = math.sin(
              angle * 9 -
                  progress * math.pi * 3,
            ) *
            (waveStrength * 0.35);

        final waveOffset = wave1 + wave2;

        final radius = baseRadius + waveOffset;

        final pointOffset = Offset(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius,
        );

        if (point == 0) {
          path.moveTo(
            pointOffset.dx,
            pointOffset.dy,
          );
        } else {
          path.lineTo(
            pointOffset.dx,
            pointOffset.dy,
          );
        }
      }

      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(
    _ListeningWavePainter oldDelegate,
  ) {
    return oldDelegate.color != color ||
        oldDelegate.progress != progress;
  }
}