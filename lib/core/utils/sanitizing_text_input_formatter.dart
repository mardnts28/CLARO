import 'package:flutter/services.dart';

/// Formatter that strips control characters (ASCII 0x00-0x1F, 0x7F-0x9F, non-printable characters)
/// while explicitly preserving all printable Unicode/Tagalog characters, apostrophes, hyphens,
/// periods, and spaces.
class SanitizingTextInputFormatter extends TextInputFormatter {
  // Matches control characters (null bytes, tabs, newlines, system control codes)
  static final RegExp _controlCharRegex = RegExp(r'[\x00-\x1F\x7F-\x9F]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final sanitizedText = newValue.text.replaceAll(_controlCharRegex, '');
    if (sanitizedText == newValue.text) {
      return newValue;
    }
    return TextEditingValue(
      text: sanitizedText,
      selection: TextSelection.collapsed(
        offset: newValue.selection.baseOffset.clamp(0, sanitizedText.length),
      ),
    );
  }
}
