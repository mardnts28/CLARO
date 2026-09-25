import 'package:flutter/material.dart';

class LockedFeatureCard extends StatelessWidget {
  const LockedFeatureCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onCtaPress,
    this.icon = Icons.lock_outline,
    this.onNotNow,
  });

  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onCtaPress;
  final IconData icon;
  final VoidCallback? onNotNow;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: 'Locked. Sign in required to view personalized health advisory.',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.primary.withValues(alpha: 0.16),
                        colors.primary.withValues(alpha: 0.06),
                      ],
                    ),
                  ),
                  child: Icon(icon, color: colors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                        backgroundColor: colors.primary,
                        elevation: 0,
                      ),
                      onPressed: onCtaPress,
                      child: Text(
                        ctaLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ),
                ),
                if (onNotNow != null) ...[
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: onNotNow,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.onSurfaceVariant,
                    ),
                    child: const Text('Not now'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}