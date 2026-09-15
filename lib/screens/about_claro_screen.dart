import 'package:flutter/material.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/haptic_service.dart';
import '../services/voice_assistant_service.dart';
import '../widgets/voice_assistant_fab.dart';

class AboutClaroScreen extends StatefulWidget {
  const AboutClaroScreen({super.key});

  @override
  State<AboutClaroScreen> createState() => _AboutClaroScreenState();
}

class _AboutClaroScreenState extends State<AboutClaroScreen> {
  @override
  void initState() {
    super.initState();
    if (VoiceAssistantService.instance.isEnabled) {
      VoiceAssistantService.instance.announcePage('about_claro');
    }
  }

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
          onPressed: () {
            HapticService().vibrate();
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          loc.aboutClaro,
          style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withAlpha(15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                loc.aboutClaroDescription,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  height: 1.5,
                  fontSize: 14,
                ),
                textAlign: TextAlign.start,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      floatingActionButton: const VoiceAssistantFab(),
    );
  }
}

