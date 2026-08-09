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
    with SingleTickerProviderStateMixin {
  late final AnimationController _rippleController;
  Offset _dragOffset = Offset.zero;
  Offset _activeDragDelta = Offset.zero;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  void _updateAnimation(bool isListening) {
    if (isListening) {
      if (!_rippleController.isAnimating) {
        _rippleController.repeat();
      }
    } else {
      if (_rippleController.isAnimating) {
        _rippleController.stop();
        _rippleController.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: VoiceAssistantService.isEnabledNotifier,
      builder: (context, isEnabled, child) {
        if (!isEnabled) return const SizedBox.shrink();

        return ValueListenableBuilder<bool>(
          valueListenable: VoiceAssistantService.isListeningNotifier,
          builder: (context, isListening, child) {
            _updateAnimation(isListening);

            final button = SizedBox(
              width: 56,
              height: 56,
              child: AnimatedBuilder(
                animation: _rippleController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      if (isListening)
                        for (var index = 0; index < 3; index++)
                          _buildRipple(
                            theme,
                            (_rippleController.value + (index / 3)) % 1.0,
                          ),
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
                  child: Icon(isListening ? Icons.mic : Icons.mic_none),
                ),
              ),
            );

            final positionedButton = Transform.translate(
              offset: _dragOffset,
              child: button,
            );

            if (!widget.draggable) return positionedButton;

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

  Widget _buildRipple(ThemeData theme, double progress) {
    final easedProgress = Curves.easeOut.transform(progress);
    final size = 56.0 + (easedProgress * 78.0);
    final opacity = 0.62 * (1.0 - easedProgress);

    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: opacity),
            width: 2.5,
          ),
        ),
      ),
    );
  }
}
