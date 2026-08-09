import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

enum NutritionGuideType {
  fda,
  who,
}

class NutritionGuideScreen extends StatelessWidget {
  final NutritionGuideType type;

  const NutritionGuideScreen({
    super.key,
    required this.type,
  });

  bool get isFDA =>
      type == NutritionGuideType.fda;

  // ---------------------------------------------------------------------------
  // OFFICIAL LINKS
  // ---------------------------------------------------------------------------

  static final Uri _fdaUrl = Uri.parse(
    'https://www.fda.gov/food/nutrition-education-resources-materials/nutrition-facts-label',
  );

  static final Uri _whoUrl = Uri.parse(
    'https://www.who.int/en/news-room/fact-sheets/detail/healthy-diet',
  );

  // ---------------------------------------------------------------------------
  // OPEN OFFICIAL WEBSITE
  // ---------------------------------------------------------------------------

  Future<void> _openOfficialWebsite(
    BuildContext context,
  ) async {
    final Uri url = isFDA ? _fdaUrl : _whoUrl;

    try {
      final bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open the official website.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open the official website.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        elevation: 0,

        backgroundColor:
            const Color(0xFF8B1A1A),

        foregroundColor: Colors.white,

        centerTitle: true,

        title: Text(
          isFDA
              ? 'How to Read Nutrition Labels'
              : 'Daily Nutrient Guidelines',

          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            32,
          ),

          child: isFDA
              ? _buildFDAContent(context)
              : _buildWHOContent(context),
        ),
      ),
    );
  }

  // ===========================================================================
  // FDA PAGE
  // ===========================================================================

  Widget _buildFDAContent(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        _buildHeroImage(
          context,
          'assets/images/fdaimg.png',
        ),

        const SizedBox(height: 20),

        const Text(
          'How to Read Nutrition Labels',

          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Learn how to understand the information on food labels and make more informed food choices.',

          style: TextStyle(
            fontSize: 14,
            height: 1.5,

            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 20),

        // ---------------------------------------------------------------------
        // OFFICIAL FDA BUTTON
        // ---------------------------------------------------------------------

        _buildOfficialWebsiteButton(
          context,

          label:
              'Read the Official FDA Guide',

          subtitle:
              'View the FDA Nutrition Facts Label guide',

          icon:
              Icons.open_in_new,

          onTap: () =>
              _openOfficialWebsite(context),
        ),

        const SizedBox(height: 24),

        _buildGuideItem(
          context,

          number: '1',

          title: 'Serving Size',

          description:
              'Check the serving size first. Nutrition information is generally based on this amount.',

          icon:
              Icons.restaurant_outlined,
        ),

        _buildGuideItem(
          context,

          number: '2',

          title: 'Calories',

          description:
              'Look at the calories per serving to understand how much energy the food provides.',

          icon:
              Icons.local_fire_department_outlined,
        ),

        _buildGuideItem(
          context,

          number: '3',

          title: '% Daily Value',

          description:
              'Use the % Daily Value to see how much a nutrient in one serving contributes to a daily diet.',

          icon:
              Icons.percent,
        ),

        _buildGuideItem(
          context,

          number: '4',

          title: 'Nutrients to Limit',

          description:
              'Pay attention to nutrients such as sodium, saturated fat, and added sugars.',

          icon:
              Icons.warning_amber_outlined,
        ),

        _buildGuideItem(
          context,

          number: '5',

          title:
              'Nutrients to Get Enough Of',

          description:
              'Look for beneficial nutrients such as dietary fiber, vitamins, and minerals.',

          icon:
              Icons.favorite_border,
        ),

        const SizedBox(height: 12),

        _buildSourceCard(
          context,

          'Official Source: U.S. Food and Drug Administration (FDA)',
        ),
      ],
    );
  }

  // ===========================================================================
  // WHO PAGE
  // ===========================================================================

  Widget _buildWHOContent(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        _buildHeroImage(
          context,
          'assets/images/whoimg.png',
        ),

        const SizedBox(height: 20),

        const Text(
          'Daily Nutrient Limit Guidelines',

          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Learn about daily nutrient guidance that can help support a healthier and more balanced diet.',

          style: TextStyle(
            fontSize: 14,
            height: 1.5,

            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 20),

        // ---------------------------------------------------------------------
        // OFFICIAL WHO BUTTON
        // ---------------------------------------------------------------------

        _buildOfficialWebsiteButton(
          context,

          label:
              'Read the Official WHO Guidelines',

          subtitle:
              'View WHO healthy diet recommendations',

          icon:
              Icons.open_in_new,

          onTap: () =>
              _openOfficialWebsite(context),
        ),

        const SizedBox(height: 24),

        _buildNutrientItem(
          context,

          icon:
              Icons.water_drop_outlined,

          title:
              'Sodium (Salt)',

          value:
              'Less than 2,000 mg of sodium per day for adults.',
        ),

        _buildNutrientItem(
          context,

          icon:
              Icons.cake_outlined,

          title:
              'Free Sugars',

          value:
              'Limit free sugars to less than 10% of total daily energy intake. Reducing it further to 5% or less may provide additional health benefits.',
        ),

        _buildNutrientItem(
          context,

          icon:
              Icons.opacity_outlined,

          title:
              'Saturated Fat',

          value:
              'No more than 10% of total daily energy intake should come from saturated fat.',
        ),

        _buildNutrientItem(
          context,

          icon:
              Icons.no_food_outlined,

          title:
              'Trans Fat',

          value:
              'Limit trans fat to less than 1% of total daily energy intake and avoid industrially produced trans fats.',
        ),

        _buildNutrientItem(
          context,

          icon:
              Icons.eco_outlined,

          title:
              'Dietary Fiber',

          value:
              'Adults and children over 10 years should aim for at least 25 g of naturally occurring dietary fiber per day.',
        ),

        const SizedBox(height: 12),

        _buildSourceCard(
          context,

          'Official Source: World Health Organization (WHO)',
        ),

        const SizedBox(height: 10),

        _buildDisclaimerCard(context),
      ],
    );
  }

  // ===========================================================================
  // OFFICIAL WEBSITE BUTTON
  // ===========================================================================

  Widget _buildOfficialWebsiteButton(
    BuildContext context, {
    required String label,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,

      child: InkWell(
        onTap: onTap,

        borderRadius:
            BorderRadius.circular(16),

        child: Container(
          width: double.infinity,

          padding:
              const EdgeInsets.all(14),

          decoration: BoxDecoration(
            color: theme
                .colorScheme
                .primary
                .withOpacity(0.08),

            borderRadius:
                BorderRadius.circular(16),

            border: Border.all(
              color: theme
                  .colorScheme
                  .primary
                  .withOpacity(0.25),
            ),
          ),

          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,

                decoration: BoxDecoration(
                  color: theme
                      .colorScheme
                      .primary,

                  shape:
                      BoxShape.circle,
                ),

                child: Icon(
                  icon,

                  color: Colors.white,

                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      label,

                      style: TextStyle(
                        fontSize: 14,

                        fontWeight:
                            FontWeight.bold,

                        color: theme
                            .colorScheme
                            .onSurface,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,

                      style: TextStyle(
                        fontSize: 11.5,

                        color: theme
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right,

                color: theme
                    .colorScheme
                    .primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HERO IMAGE
  // ===========================================================================

  Widget _buildHeroImage(
    BuildContext context,
    String imagePath,
  ) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,

      height: 210,

      decoration: BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest,

        borderRadius:
            BorderRadius.circular(20),
      ),

      clipBehavior:
          Clip.antiAlias,

      child: Image.asset(
        imagePath,

        fit: BoxFit.cover,

        errorBuilder:
            (context, error, stackTrace) {
          return Center(
            child: Icon(
              Icons
                  .image_not_supported_outlined,

              size: 50,

              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // FDA GUIDE ITEM
  // ===========================================================================

  Widget _buildGuideItem(
    BuildContext context, {
    required String number,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),

      padding:
          const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: theme.cardColor,

        borderRadius:
            BorderRadius.circular(16),

        border: Border.all(
          color: theme.dividerColor,
        ),
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Container(
            width: 44,
            height: 44,

            decoration: BoxDecoration(
              color: theme
                  .colorScheme
                  .primary
                  .withOpacity(0.10),

              shape:
                  BoxShape.circle,
            ),

            child: Stack(
              alignment:
                  Alignment.center,

              children: [
                Icon(
                  icon,

                  size: 21,

                  color: theme
                      .colorScheme
                      .primary,
                ),

                Positioned(
                  right: 0,
                  top: 0,

                  child: Container(
                    width: 17,
                    height: 17,

                    decoration:
                        BoxDecoration(
                      color: theme
                          .colorScheme
                          .primary,

                      shape:
                          BoxShape.circle,
                    ),

                    alignment:
                        Alignment.center,

                    child: Text(
                      number,

                      style:
                          const TextStyle(
                        color:
                            Colors.white,

                        fontSize: 9,

                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style:
                      const TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  description,

                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,

                    color: theme
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // WHO NUTRIENT ITEM
  // ===========================================================================

  Widget _buildNutrientItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,

      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),

      padding:
          const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: theme.cardColor,

        borderRadius:
            BorderRadius.circular(16),

        border: Border.all(
          color: theme.dividerColor,
        ),
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Container(
            width: 44,
            height: 44,

            decoration: BoxDecoration(
              color: theme
                  .colorScheme
                  .primary
                  .withOpacity(0.10),

              shape:
                  BoxShape.circle,
            ),

            child: Icon(
              icon,

              color:
                  theme.colorScheme.primary,

              size: 21,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style:
                      const TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,

                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,

                    color: theme
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SOURCE CARD
  // ===========================================================================

  Widget _buildSourceCard(
    BuildContext context,
    String source,
  ) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: theme
            .colorScheme
            .primary
            .withOpacity(0.06),

        borderRadius:
            BorderRadius.circular(14),
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Icon(
            Icons.verified_outlined,

            size: 18,

            color:
                theme.colorScheme.primary,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              source,

              style: TextStyle(
                fontSize: 11,
                height: 1.4,

                fontWeight:
                    FontWeight.w600,

                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DISCLAIMER
  // ===========================================================================

  Widget _buildDisclaimerCard(
    BuildContext context,
  ) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest,

        borderRadius:
            BorderRadius.circular(14),
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Icon(
            Icons.info_outline,

            size: 18,

            color: theme
                .colorScheme
                .onSurfaceVariant,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              'These guidelines are provided for general nutrition education. Individual nutrient needs may vary depending on age, health status, and other factors.',

              style: TextStyle(
                fontSize: 11,
                height: 1.45,

                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}