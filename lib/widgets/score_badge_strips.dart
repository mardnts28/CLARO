import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Standard Nutri-Score colours, A -> E.
const List<Color> _kNutriPalette = [
  Color(0xFF2E9E44), // A
  Color(0xFF9BD03F), // B
  Color(0xFFFFC800), // C
  Color(0xFFF08A00), // D
  Color(0xFFF23D12), // E
];

// NOVA colours, 1 -> 4.
const List<Color> _kNovaPalette = [
  Color(0xFF2E9E44), // 1
  Color(0xFFFFC800), // 2
  Color(0xFFF08A00), // 3
  Color(0xFFF23D12), // 4
];

// Sizes shared by both strips: every option is a small rounded square, and
// the one that applies to the product is drawn larger.
const double _kCellSize = 22;
const double _kActiveWidth = 28;
const double _kActiveHeight = 34;
const double _kCellGap = 3;

/// One rounded-square cell of a strip. Small when idle, larger + bolder
/// (with a soft shadow) when it is the value that applies to the product.
/// Supports tap / hover tooltip to show what the letter/group means in simplest terms.
class _ScoreCell extends StatelessWidget {
  const _ScoreCell({
    required this.label,
    required this.color,
    required this.isActive,
    this.tooltip,
  });

  final String label;
  final Color color;
  final bool isActive;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cell = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isActive ? _kActiveWidth : _kCellSize,
      height: isActive ? _kActiveHeight : _kCellSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(isActive ? 9 : 6),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: isActive ? 19 : 11,
          fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(
        message: tooltip!,
        triggerMode: TooltipTriggerMode.tap,
        preferBelow: false,
        verticalOffset: 22,
        showDuration: const Duration(seconds: 4),
        waitDuration: Duration.zero,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        textStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 1),
            child: cell,
          ),
        ),
      );
    }

    return cell;
  }
}

/// Nutri-Score strip:  A B C D E  -- the grade that applies to the product
/// is enlarged; the others stay small.
class NutriScoreStrip extends StatelessWidget {
  const NutriScoreStrip({super.key, required this.grade, this.activeColor});

  /// 'A'..'E'. Anything else (unknown / unavailable) leaves every letter
  /// in its small, un-highlighted state.
  final String grade;

  /// Optional override for the highlighted cell's colour (e.g. the colour
  /// NutriScoreCalculator returned) so it matches the Scores cards below.
  final Color? activeColor;

  static const List<String> _letters = ['A', 'B', 'C', 'D', 'E'];

  static String _getTooltip(String letter, bool isTagalog) {
    switch (letter.toUpperCase()) {
      case 'A':
        return isTagalog
            ? 'Nutri-Score A: Napakagandang kalidad ng nutrisyon'
            : 'Nutri-Score A: Very good nutritional quality';
      case 'B':
        return isTagalog
            ? 'Nutri-Score B: Magandang kalidad ng nutrisyon'
            : 'Nutri-Score B: Good nutritional quality';
      case 'C':
        return isTagalog
            ? 'Nutri-Score C: Katamtamang kalidad ng nutrisyon'
            : 'Nutri-Score C: Average nutritional quality';
      case 'D':
        return isTagalog
            ? 'Nutri-Score D: Mababang kalidad ng nutrisyon'
            : 'Nutri-Score D: Low nutritional quality';
      case 'E':
        return isTagalog
            ? 'Nutri-Score E: Mahinang kalidad ng nutrisyon'
            : 'Nutri-Score E: Poor nutritional quality';
      default:
        return 'Nutri-Score $letter';
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _letters.indexOf(grade.trim().toUpperCase());
    final lang = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    final isTagalog = lang == 'tl' || lang == 'fil';

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < _letters.length; i++)
          Padding(
            padding: EdgeInsets.only(
              right: i == _letters.length - 1 ? 0 : _kCellGap,
            ),
            child: _ScoreCell(
              label: _letters[i],
              color: (i == active && activeColor != null)
                  ? activeColor!
                  : _kNutriPalette[i],
              isActive: i == active,
              tooltip: _getTooltip(_letters[i], isTagalog),
            ),
          ),
      ],
    );
  }
}

/// NOVA strip:  1 2 3 4  -- the processing group that applies to the product
/// is enlarged; the others stay small.
class NovaScoreStrip extends StatelessWidget {
  const NovaScoreStrip({super.key, required this.group, this.activeColor});

  /// '1'..'4' (as produced by NovaScoreCalculator's `groupString`).
  final String group;

  /// Optional override for the highlighted cell's colour.
  final Color? activeColor;

  static String _getTooltip(int group, bool isTagalog) {
    switch (group) {
      case 1:
        return isTagalog
            ? 'NOVA 1: Hindi o bahagyang naproseso'
            : 'NOVA 1: Minimally processed foods';
      case 2:
        return isTagalog
            ? 'NOVA 2: Sangkap sa pagluluto'
            : 'NOVA 2: Processed culinary ingredients';
      case 3:
        return isTagalog
            ? 'NOVA 3: Naprosesong pagkain'
            : 'NOVA 3: Processed foods';
      case 4:
        return isTagalog
            ? 'NOVA 4: Ultra-processed na pagkain'
            : 'NOVA 4: Ultra-processed foods';
      default:
        return 'NOVA $group';
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = int.tryParse(group.trim());
    final active = (parsed != null && parsed >= 1 && parsed <= 4)
        ? parsed - 1
        : -1;
    final lang = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    final isTagalog = lang == 'tl' || lang == 'fil';

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < 4; i++)
          Padding(
            padding: EdgeInsets.only(right: i == 3 ? 0 : _kCellGap),
            child: _ScoreCell(
              label: '${i + 1}',
              color: (i == active && activeColor != null)
                  ? activeColor!
                  : _kNovaPalette[i],
              isActive: i == active,
              tooltip: _getTooltip(i + 1, isTagalog),
            ),
          ),
      ],
    );
  }
}

/// The tinted panel shown at the bottom of the product info card:
///
///   [leaf] Nutri-Score   |   [hexagon] NOVA
///   A B C D [E]          |   1 2 3 [4]
///
/// Only the grade / group that applies to the product is enlarged.
class ScoreBadgePanel extends StatelessWidget {
  const ScoreBadgePanel({
    super.key,
    required this.nutriGrade,
    required this.novaGroup,
    this.nutriColor,
    this.novaColor,
    this.nutriLabel = 'Nutri-Score',
    this.novaLabel = 'NOVA',
  });

  /// 'A'..'E', or '' when there is no nutrition data (nothing is enlarged).
  final String nutriGrade;

  /// '1'..'4'.
  final String novaGroup;

  final Color? nutriColor;
  final Color? novaColor;
  final String nutriLabel;
  final String novaLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        // Soft red tint that reads well on both light and dark cards.
        color: const Color(0xFFC62828).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 6,
              child: _section(
                cs,
                icon: Icons.eco,
                label: nutriLabel,
                strip: NutriScoreStrip(
                  grade: nutriGrade,
                  activeColor: nutriColor,
                ),
              ),
            ),
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: cs.outlineVariant,
            ),
            Expanded(
              flex: 5,
              child: _section(
                cs,
                icon: Icons.hexagon_outlined,
                label: novaLabel,
                strip: NovaScoreStrip(group: novaGroup, activeColor: novaColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(
    ColorScheme cs, {
    required IconData icon,
    required String label,
    required Widget strip,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Shrinks the strip slightly on very narrow screens instead of
        // overflowing.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: strip,
        ),
      ],
    );
  }
}