
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../generated/l10n/app_localizations.dart';
import '../widgets/voice_assistant_fab.dart';
import 'unknown_product_submission_screen.dart';

/// Full-page screen shown when the camera scanner cannot identify a product.
///
/// Matches the CLARO design language:
///   - Warm off-white background
///   - An illustration of a can inside a scanning viewfinder
///   - Descriptive text explaining the situation
///   - Two action buttons: "Scan again" and "Report the product"
///   - Bottom navigation bar consistent with the rest of the app
class ProductNotFoundScreen extends StatelessWidget {
  /// Optional path to the image that was captured during the failed scan.
  /// If provided, it will be forwarded to the report screen so the user
  /// doesn't have to re-take the photo.
  final String? capturedImagePath;

  const ProductNotFoundScreen({super.key, this.capturedImagePath});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Back button ──────────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: colorScheme.primary, size: 26),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // ── Title ────────────────────────────────────────
                    Text(
                      loc.notFoundTitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Illustration ─────────────────────────────────
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/unidentified_product.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.search_off_rounded,
                            size: 80,
                            color: colorScheme.primary.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // ── Body text ────────────────────────────────────
                    Text(
                      loc.notFoundBody,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      loc.notFoundHint,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 44),

                    // ── Scan Again button (outlined) ─────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: theme.dividerColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          loc.scanAgainButton,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Report product button (filled) ───────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UnknownProductSubmissionScreen(
                                capturedImagePath: capturedImagePath,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          loc.reportProductButton,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: const VoiceAssistantFab(),

      // ── Bottom Navigation Bar ──────────────────────────────────────
      bottomNavigationBar: _buildBottomNav(context, colorScheme, theme, bottomPadding),
    );
  }

  Widget _buildBottomNav(
    BuildContext context,
    ColorScheme colorScheme,
    ThemeData theme,
    double bottomPadding,
  ) {
    final loc = AppLocalizations.of(context)!;
    final navPillColor = theme.brightness == Brightness.dark
        ? colorScheme.primary.withValues(alpha: 0.2)
        : const Color(0xFFF6CDCD);

    final items = [
      (icon: Icons.home_outlined, label: loc.home, active: false),
      (icon: Icons.qr_code_scanner, label: loc.scan, active: true),
      (icon: Icons.history_outlined, label: loc.history, active: false),
      (icon: Icons.person_outline, label: loc.profile, active: false),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: items.map((item) {
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: item.active ? navPillColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, color: colorScheme.primary, size: 22),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.primary,
                        fontWeight: item.active ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
