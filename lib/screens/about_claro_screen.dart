import 'package:flutter/material.dart';
import '../generated/l10n/app_localizations.dart';
import '../widgets/voice_assistant_fab.dart';

class AboutClaroScreen extends StatelessWidget {
  const AboutClaroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          loc.aboutClaro,
          style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 6),
            Text(
              loc.aboutClaroHeading,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withAlpha(20),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Text(
                loc.aboutClaroDescription,
                style: TextStyle(color: theme.colorScheme.onSurface, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                loc.aboutDevelopers,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                Expanded(
                  child: _DevCard(
                    name: 'Mary Faith Ardientes',
                    role: 'Project Manager',
                  ),
                ),
                Expanded(
                  child: _DevCard(
                    name: 'Jay Bhie Bite',
                    role: 'Front-end Developer',
                  ),
                ),
                Expanded(
                  child: _DevCard(
                    name: 'Rochelle Ann Salucop',
                    role: 'Back-end Developer',
                  ),
                ),
              ],
            ),
            const Spacer(),
            const SizedBox(height: 90),
          ],
        ),
      ),
      floatingActionButton: const VoiceAssistantFab(),
    );
  }
}

class _DevCard extends StatelessWidget {
  final String name;
  final String role;

  const _DevCard({required this.name, required this.role});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: Text(
            name,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        Flexible(
          child: Text(
            role,
            style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}