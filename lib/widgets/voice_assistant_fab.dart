import 'package:flutter/material.dart';
import '../services/voice_assistant_service.dart';
import '../services/haptic_service.dart';

class VoiceAssistantFab extends StatelessWidget {
  final VoidCallback? onPressed;

  const VoiceAssistantFab({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: VoiceAssistantService.isEnabledNotifier,
      builder: (context, isEnabled, child) {
        if (!isEnabled) return const SizedBox.shrink();
        
        return FloatingActionButton(
          heroTag: 'voice_assistant_fab_${context.hashCode}',
          onPressed: () {
            HapticService().vibrate();
            if (onPressed != null) {
              onPressed!();
            } else {
              // Default action: maybe show a snackbar or trigger voice listening
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Voice Assistant listening...')),
              );
            }
          },
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          child: const Icon(Icons.mic),
        );
      },
    );
  }
}
