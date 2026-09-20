// lib/widgets/avatar_picker.dart
//
// Image-only avatar picker: up to 8 avatars from assets/images/avatars/
// laid out as two rows of four, same look as the Add Member screen's
// avatar section. Tapping an avatar selects it; tapping the selected one
// again clears it.

import 'package:flutter/material.dart';

import '../core/utils/avatar_assets.dart';
import '../services/haptic_service.dart';

class AvatarPicker extends StatefulWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;

  const AvatarPicker({super.key, required this.selected, required this.onChanged});

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  List<String> _options = const [];

  @override
  void initState() {
    super.initState();
    AvatarAssets.load().then((list) {
      if (mounted) setState(() => _options = list);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_options.isEmpty) return const SizedBox(height: 8);

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1,
      children: _options.map((path) {
        final selected = widget.selected == path;
        return GestureDetector(
          onTap: () {
            HapticService().vibrate();
            widget.onChanged(selected ? null : path);
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? colorScheme.primary : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      path,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.person_outline, color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
