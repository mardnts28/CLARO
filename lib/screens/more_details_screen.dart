import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/product_model.dart';
import '../data/models/health_profile.dart';
import '../core/constants/who_fda_thresholds.dart';
import '../core/utils/who_calculator.dart';
import '../core/utils/number_format_utils.dart';
import '../services/voice_assistant_service.dart';
import '../generated/l10n/app_localizations.dart';
import '../widgets/voice_assistant_fab.dart';

/// A screen showing additional product details:
/// - Ingredients list with allergen warnings
/// - Storage instructions / tips
class MoreDetailsScreen extends StatefulWidget {
  final Product product;
  // Allergens found on THIS product that also match the signed-in user's
  // saved health-profile allergies -- the same set the Health Advisory
  // banner and the product detail screen's Analysis Basis card use (both
  // ultimately from WhoCalculator.assessAllergens), passed in rather than
  // recomputed here so all three surfaces can never disagree. Empty by
  // default only so this widget still compiles/renders for any caller
  // that doesn't have a computed assessment on hand -- the real call site
  // in product_detail_screen.dart always passes the actual matched set.
  final List<AllergenType> matchedAllergens;

  // Health conditions saved on the signed-in user's health profile (e.g.
  // [HealthCondition.hypertension, HealthCondition.diabetes]) -- the same
  // set WhoCalculator.evaluateProduct() iterates over to build
  // ProductEvaluation.nutrientEvaluations. Used ONLY to decide whether to
  // show a nutrient card's health-condition badge in the "How CLARO
  // Calculates" guide: a condition badge only appears when that condition
  // is actually part of this user's profile. Empty by default so this
  // screen still renders (with all condition badges hidden) for any
  // caller that doesn't have an evaluation on hand.
  final List<HealthCondition> userConditions;

  const MoreDetailsScreen({
    super.key,
    required this.product,
    this.matchedAllergens = const [],
    this.userConditions = const [],
  });

  @override
  State<MoreDetailsScreen> createState() => _MoreDetailsScreenState();
}

class _MoreDetailsScreenState extends State<MoreDetailsScreen> {
  String? _dynamicStorageText;
  bool _loadingStorage = true;

  // Official WHO "Healthy diet" fact sheet -- the single reference source
  // cited in the "How CLARO Calculates" guide.
  static final Uri _whoHealthyDietUri =
      Uri.parse('https://www.who.int/news-room/fact-sheets/detail/healthy-diet');

  // TapGestureRecognizer for the inline hyperlink in the guide's intro
  // text. Created once and disposed in dispose() (per Flutter's
  // GestureRecognizer contract) rather than recreated on every build.
  late final TapGestureRecognizer _whoLinkRecognizer;

  @override
  void initState() {
    super.initState();
    _whoLinkRecognizer = TapGestureRecognizer()..onTap = _openWhoHealthyDietPage;
    if (VoiceAssistantService.instance.isEnabled) {
      VoiceAssistantService.instance.announcePage('more_details');
    }
    _fetchStorageInstructions();
  }

  @override
  void dispose() {
    _whoLinkRecognizer.dispose();
    super.dispose();
  }

  Future<void> _openWhoHealthyDietPage() async {
    try {
      final launched = await launchUrl(_whoHealthyDietUri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the official WHO website.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the official WHO website.')),
        );
      }
    }
  }

  Future<void> _fetchStorageInstructions() async {
    if (widget.product.category.isEmpty) {
      if (mounted) setState(() => _loadingStorage = false);
      return;
    }
    
    try {
      final docId = widget.product.category.toLowerCase().replaceAll(' ', '_');
      final doc = await FirebaseFirestore.instance.collection('categories').doc(docId).get();
      if (doc.exists && mounted) {
        setState(() {
          _dynamicStorageText = doc.data()?['default_storage'];
          _loadingStorage = false;
        });
      } else if (mounted) {
        setState(() => _loadingStorage = false);
      }
    } catch (e) {
      debugPrint('Error fetching storage instructions: $e');
      if (mounted) setState(() => _loadingStorage = false);
    }
  }

  String _toTitleCase(String text) {
    if (text.trim().isEmpty) return text;
    final words = text.split(' ');
    return words.map((w) {
      if (w.isEmpty) return w;
      int prefixLen = 0;
      while (prefixLen < w.length && (w[prefixLen] == '(' || w[prefixLen] == '[')) {
        prefixLen++;
      }
      if (prefixLen >= w.length) return w;
      final prefix = w.substring(0, prefixLen);
      final body = w.substring(prefixLen);
      if (body.isEmpty) return w;
      final lower = body.toLowerCase();
      if (['and', 'or', 'with', 'in', 'of', 'for'].contains(lower) && prefixLen == 0) {
        return lower;
      }
      final formattedBody = lower[0].toUpperCase() + lower.substring(1);
      return prefix + formattedBody;
    }).join(' ');
  }

  List<String> _parseIngredientsList(List<String> rawIngredients) {
    if (rawIngredients.isEmpty) return [];
    final fullText = rawIngredients.join(', ');

    final List<String> items = [];
    final StringBuffer current = StringBuffer();
    int parenDepth = 0;

    for (int i = 0; i < fullText.length; i++) {
      final char = fullText[i];
      if (char == '(' || char == '[') {
        parenDepth++;
        current.write(char);
      } else if (char == ')' || char == ']') {
        if (parenDepth > 0) parenDepth--;
        current.write(char);
      } else if (char == ',' && parenDepth == 0) {
        final str = current.toString().trim();
        if (str.isNotEmpty) items.add(_toTitleCase(str));
        current.clear();
      } else {
        current.write(char);
      }
    }
    final str = current.toString().trim();
    if (str.isNotEmpty) items.add(_toTitleCase(str));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          loc.moreDetailsScreenTitle,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // ── Ingredients Card ──────────────────────────────────
            _buildSectionCard(
              context: context,
              icon: Icons.chat_bubble,
              iconColor: const Color(0xFFB71C1C),
              title: loc.ingredientsTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Builder(builder: (context) {
                    final parsedItems = _parseIngredientsList(product.ingredients);
                    if (parsedItems.isEmpty) {
                      return Text('—',
                          style: GoogleFonts.inter(
                              fontSize: 14, color: colorScheme.onSurface));
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: parsedItems.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• ',
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary)),
                              Expanded(
                                child: Text(
                                  item,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: colorScheme.onSurface,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  }),
                  // Allergen warnings -- ONLY for allergens matched against
                  // the signed-in user's saved health profile
                  // (`widget.matchedAllergens`, the same set the Health
                  // Advisory banner and Analysis Basis card use), NOT every
                  // allergen the product happens to contain. Listed
                  // together in a single line (comma-separated) rather than
                  // one stacked container per allergen, so 2+ detected
                  // allergens don't grow the card with repeated icon/badge
                  // rows.
                  if (widget.matchedAllergens.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Builder(builder: (context) {
                      final langCode = Localizations.localeOf(context).languageCode;
                      // Parallel to product.allergens -- lets us prefer the
                      // product's own (possibly localized) allergen string
                      // when one exists, same as the product detail screen.
                      final productAllergenTypes = product.containsAllergens;
                      final displayNamesList = <String>[];
                      for (final type in widget.matchedAllergens) {
                        final rawIndex = productAllergenTypes.indexOf(type);
                        final label = rawIndex != -1
                            ? _getAllergenDisplayName(product.allergens[rawIndex], langCode)
                            : type.displayLabel;
                        if (!displayNamesList.contains(label)) displayNamesList.add(label);
                      }
                      final displayNames = displayNamesList.join(', ');
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEF9A9A)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Color(0xFFC62828), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                loc.containsAllergenPrefix(displayNames),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFC62828),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Storage Instructions Card ─────────────────────────
            _buildSectionCard(
              context: context,
              icon: Icons.storefront_rounded,
              iconColor: const Color(0xFFB71C1C),
              title: loc.storageTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  if (_loadingStorage)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_dynamicStorageText != null && _dynamicStorageText!.isNotEmpty)
                    _buildStorageTip(
                      context: context,
                      icon: Icons.info_outline,
                      text: _dynamicStorageText!,
                    )
                  else ...[
                    _buildStorageTip(
                      context: context,
                      icon: Icons.wb_sunny_outlined,
                      text: loc.storageTipCool,
                    ),
                    const SizedBox(height: 14),
                    _buildStorageTip(
                      context: context,
                      icon: Icons.ac_unit,
                      text: loc.storageTipRefrigerate,
                    ),
                    const SizedBox(height: 14),
                    _buildStorageTip(
                      context: context,
                      icon: Icons.access_time,
                      text: loc.storageTipConsume,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── How CLARO Calculates Your Health Guide Card ───────
            _buildHowClaroCalculatesCard(context: context, product: product, loc: loc),

            const SizedBox(height: 24),
          ],
        ),
      ),
      floatingActionButton: const VoiceAssistantFab(),
    );
  }

  /// Builds the "How CLARO Calculates Your Health Guide" card: a plain-
  /// language, non-mathematical explainer of the WHO-reference-vs-
  /// classification pipeline that already powers the Health Analysis card
  /// and Health Advisory banner. Shows a visual threshold table (WHO daily
  /// limit / threshold range / health condition / suitability) instead of
  /// any formula or worked calculation, reading the same constants
  /// (WhoDailyLimits, ConditionThresholds) and classification function
  /// (WhoCalculator.classifyNutrient) those other features use, so this
  /// card can never disagree with them -- it duplicates no logic of its
  /// own.
  Widget _buildHowClaroCalculatesCard({
    required BuildContext context,
    required Product product,
    required AppLocalizations loc,
  }) {
    return _buildSectionCard(
      context: context,
      icon: Icons.insights_rounded,
      iconColor: const Color(0xFFB71C1C),
      title: loc.howClaroCalculatesTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _buildWhoReferenceText(context, loc),
          const SizedBox(height: 16),
          _buildWhoThresholdTable(context, product, loc),
        ],
      ),
    );
  }

  /// "We reference Healthy Diet by World Health Organization" -- with the
  /// WHO fact-sheet title as a tappable inline hyperlink that opens
  /// https://www.who.int/news-room/fact-sheets/detail/healthy-diet in an
  /// external browser. Uses colorScheme.primary for the link color so it
  /// automatically matches the app's existing dark/light theme rather
  /// than a new hardcoded color.
  Widget _buildWhoReferenceText(BuildContext context, AppLocalizations loc) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: loc.howClaroReferencePrefix,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: colorScheme.onSurface.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
          TextSpan(
            text: loc.howClaroReferenceLinkLabel,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
              decoration: TextDecoration.underline,
              decorationColor: colorScheme.primary,
              height: 1.5,
            ),
            recognizer: _whoLinkRecognizer,
          ),
        ],
      ),
    );
  }

  /// Builds the visual WHO-threshold table: one row-card per tracked
  /// nutrient (Sodium/Hypertension, Sugars/Diabetes, Saturated Fat/Heart
  /// Condition), each listing the WHO daily reference limit plus the
  /// Suitable / Moderate / Caution per-100g threshold range for its
  /// health condition (straight from ConditionThresholds -- Table 3.14 --
  /// no numbers are computed or displayed here beyond what those
  /// constants already define). Purely additive/explanatory: no formula,
  /// no arithmetic shown to the user.
  ///
  /// Every row-card and every cell inside it uses Expanded/Wrap (never a
  /// fixed width wider than its parent), so this table cannot overflow
  /// horizontally regardless of screen size or how long a localized label
  /// is -- it wraps or shrinks, it never clips past the card edge.
  Widget _buildWhoThresholdTable(BuildContext context, Product product, AppLocalizations loc) {
    final rows = <_ThresholdRow>[
      _ThresholdRow(
        nutrientKey: 'sodiumMg',
        condition: HealthCondition.hypertension,
        unit: 'mg',
        whoDailyLimit: WhoDailyLimits.sodiumMgPerDay,
      ),
      _ThresholdRow(
        nutrientKey: 'sugarsG',
        condition: HealthCondition.diabetes,
        unit: 'g',
        whoDailyLimit: WhoDailyLimits.sugarsGPerDay,
      ),
      _ThresholdRow(
        nutrientKey: 'saturatedFatG',
        condition: HealthCondition.heartCondition,
        unit: 'g',
        whoDailyLimit: WhoDailyLimits.saturatedFatGPerDay,
      ),
    ];

    final hasData = product.nutritionalFacts.hasNutritionData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _buildThresholdRowCard(context, rows[i], product, hasData, loc),
        ],
      ],
    );
  }

  /// One nutrient's row-card: header (nutrient name, condition chip -- only
  /// when that condition is on the user's health profile -- and WHO
  /// reference) followed by its three threshold cells. If the product has
  /// no usable nutrition data, the ranges still show (they're reference
  /// info, not product-specific) but no cell is highlighted and a small
  /// note explains why.
  Widget _buildThresholdRowCard(
    BuildContext context,
    _ThresholdRow row,
    Product product,
    bool hasData,
    AppLocalizations loc,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final band = ConditionThresholds.thresholds[row.condition]?[row.nutrientKey];

    AdvisoryLevel? productLevel;
    if (hasData && band != null) {
      final value = WhoCalculator.readNutrientValue(product.nutritionPer100g, row.nutrientKey);
      productLevel = WhoCalculator.classifyNutrient(row.condition, row.nutrientKey, value);
    }

    // The condition badge only appears when this row's health condition is
    // actually saved on the signed-in user's health profile
    // (widget.userConditions) -- not for every condition CLARO tracks.
    final showConditionBadge = widget.userConditions.contains(row.condition);

    // Each band's absolute threshold, expressed as a percentage of the
    // nutrient's WHO daily reference -- e.g. sodium's 100mg Suitable cutoff
    // is 5% of the 2,000mg WHO daily reference. Derived live from the same
    // constants the ranges above come from, never hardcoded.
    final suitablePercent = band == null ? null : (band.suitableMaxInclusive / row.whoDailyLimit) * 100;
    final cautionPercent = band == null ? null : (band.cautionMinInclusive / row.whoDailyLimit) * 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header -- nutrient name + health-condition chip. Wrap (not
          // Row) so a long localized nutrient name or condition label
          // drops to a second line instead of overflowing sideways.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                _nutrientDisplayLabel(row.nutrientKey, loc),
                softWrap: true,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              if (showConditionBadge)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _conditionDisplayLabel(row.condition),
                    softWrap: true,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            row.nutrientKey == 'sugarsG'
                ? '${loc.whoFreeSugarReferenceLabel}: ${NumberFormatUtils.formatValue(row.whoDailyLimit)}${row.unit}/day'
                : '${loc.whoReferenceLabel}: ${NumberFormatUtils.formatValue(row.whoDailyLimit)}${row.unit}/day',
            softWrap: true,
            style: GoogleFonts.inter(fontSize: 11.5, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          if (band == null)
            Text('—',
                style: GoogleFonts.inter(fontSize: 12, color: colorScheme.onSurfaceVariant))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildThresholdCell(
                    context,
                    level: AdvisoryLevel.suitable,
                    rangeText:
                        '≤ ${NumberFormatUtils.formatValue(band.suitableMaxInclusive)}${row.unit}',
                    percentText: '≤ ${NumberFormatUtils.formatValue(suitablePercent!)}%',
                    isActive: productLevel == AdvisoryLevel.suitable,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildThresholdCell(
                    context,
                    level: AdvisoryLevel.moderate,
                    rangeText:
                        '${NumberFormatUtils.formatValue(band.suitableMaxInclusive)}–${NumberFormatUtils.formatValue(band.cautionMinInclusive)}${row.unit}',
                    percentText:
                        '${NumberFormatUtils.formatValue(suitablePercent)}–${NumberFormatUtils.formatValue(cautionPercent!)}%',
                    isActive: productLevel == AdvisoryLevel.moderate,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildThresholdCell(
                    context,
                    level: AdvisoryLevel.caution,
                    rangeText:
                        '≥ ${NumberFormatUtils.formatValue(band.cautionMinInclusive)}${row.unit}',
                    percentText: '≥ ${NumberFormatUtils.formatValue(cautionPercent)}%',
                    isActive: productLevel == AdvisoryLevel.caution,
                  ),
                ),
              ],
            ),
          if (band != null && !hasData) ...[
            const SizedBox(height: 8),
            Text(
              'No nutrition data available to classify this product.',
              softWrap: true,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// One Suitable/Moderate/Caution cell. When [isActive] is true (this
  /// scanned product's own per-100g value falls in this band), the cell
  /// is highlighted using the same dark/light-mode-aware palette the rest
  /// of the advisory UI already uses (_levelStyleFor), so the highlight
  /// always matches the app's existing dark-mode look rather than
  /// introducing a new hardcoded color.
  Widget _buildThresholdCell(
    BuildContext context, {
    required AdvisoryLevel level,
    required String rangeText,
    required String percentText,
    required bool isActive,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final style = _levelStyleFor(level, isDark);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? style.badgeBg : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? style.textColor : colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            style.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: isActive ? style.textColor : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            rangeText,
            softWrap: true,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? style.textColor : colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            percentText,
            softWrap: true,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? style.textColor : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _nutrientDisplayLabel(String nutrientKey, AppLocalizations loc) {
    switch (nutrientKey) {
      case 'sodiumMg':
        return loc.bpSodiumShortLabel;
      case 'sugarsG':
        return loc.diabetesSugarsShortLabel;
      case 'saturatedFatG':
        return loc.heartSatFatShortLabel;
      default:
        return nutrientKey;
    }
  }

  /// Display label for the health condition each threshold row maps to.
  /// NOTE: hardcoded English for now, same as _levelStyleFor's
  /// Suitable/Moderate/Caution labels below -- if you want these
  /// bilingual (English/Tagalog) like the allergen names in
  /// _getAllergenDisplayName, add condition-name keys to the ARB files and
  /// swap these for loc.* calls.
  String _conditionDisplayLabel(HealthCondition condition) {
    switch (condition) {
      case HealthCondition.hypertension:
        return 'Hypertension';
      case HealthCondition.diabetes:
        return 'Diabetes';
      case HealthCondition.heartCondition:
        return 'Heart Condition';
    }
  }

  _LevelStyle _levelStyleFor(AdvisoryLevel level, bool isDark) {
    switch (level) {
      case AdvisoryLevel.suitable:
        return _LevelStyle(
          label: 'Suitable',
          badgeBg: isDark ? const Color(0xFF1B3320) : const Color(0xFFE8F5E9),
          textColor: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
        );
      case AdvisoryLevel.moderate:
        return _LevelStyle(
          label: 'Moderate',
          badgeBg: isDark ? const Color(0xFF3A2A12) : const Color(0xFFFFF3E0),
          textColor: isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100),
        );
      case AdvisoryLevel.caution:
        return _LevelStyle(
          label: 'Caution',
          badgeBg: isDark ? const Color(0xFF3A1414) : const Color(0xFFFFEBEE),
          textColor: isDark ? const Color(0xFFEF9A9A) : const Color(0xFFC62828),
        );
    }
  }

  /// Builds a card section with an icon + title header.
  Widget _buildSectionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5D5C5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  softWrap: true,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }

  /// Builds a single storage tip row with an icon and text.
  Widget _buildStorageTip({
    required BuildContext context,
    required IconData icon,
    required String text,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: colorScheme.onSurface,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  /// Returns the localized display name for a given allergen string.
  String _getAllergenDisplayName(String allergen, String langCode) {
    final normalized = allergen.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final isTagalog = langCode == 'tl';

    switch (normalized) {
      case 'fish':
      case 'isda':
        return isTagalog ? 'isda' : 'fish';
      case 'milk':
      case 'gatas':
        return isTagalog ? 'gatas' : 'milk';
      case 'egg':
      case 'itlog':
        return isTagalog ? 'itlog' : 'egg';
      case 'soy':
      case 'soya':
      case 'soybean':
        return isTagalog ? 'soya' : 'soy';
      case 'wheat':
      case 'trigo':
        return isTagalog ? 'trigo (wheat)' : 'wheat';
      case 'shellfish':
      case 'lamangdagat':
        return isTagalog ? 'lamang-dagat' : 'shellfish';
      case 'peanut':
      case 'mani':
        return isTagalog ? 'mani' : 'peanut';
      default:
        return allergen;
    }
  }
}

/// Config for one row of the WHO threshold table: which nutrient/health
/// condition pair it covers and that nutrient's WHO daily reference limit.
/// The actual Suitable/Moderate/Caution range values are looked up live
/// from ConditionThresholds (not stored here), so this table can never
/// drift out of sync with the constants file.
class _ThresholdRow {
  final String nutrientKey;
  final HealthCondition condition;
  final String unit;
  final double whoDailyLimit;

  _ThresholdRow({
    required this.nutrientKey,
    required this.condition,
    required this.unit,
    required this.whoDailyLimit,
  });
}

/// Small bundle of colors/label for rendering one AdvisoryLevel's badge,
/// matching the same palette product_detail_screen.dart's Health Analysis
/// card already uses for Suitable/Moderate/Caution.
class _LevelStyle {
  final String label;
  final Color badgeBg;
  final Color textColor;

  _LevelStyle({
    required this.label,
    required this.badgeBg,
    required this.textColor,
  });
}