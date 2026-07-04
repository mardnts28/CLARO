import 'package:flutter/material.dart';

import '../services/translation_service.dart';

class TranslatedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  const TranslatedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;

    return FutureBuilder<String>(
      future: TranslationService.translate(text, locale),
      builder: (context, snapshot) {
        final resolvedText = snapshot.data ?? text;
        return Text(
          resolvedText,
          style: style,
          textAlign: textAlign,
        );
      },
    );
  }
}
