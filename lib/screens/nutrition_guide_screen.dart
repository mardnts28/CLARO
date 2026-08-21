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

    bool _isTagalog(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'tl';

    String _text(BuildContext context, String english, String tagalog) =>
      _isTagalog(context) ? tagalog : english;

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
          SnackBar(
            content: Text(_text(context, 'Unable to open the official website.', 'Hindi mabuksan ang opisyal na website.')),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_text(context, 'Unable to open the official website.', 'Hindi mabuksan ang opisyal na website.')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,

      appBar: AppBar(
        elevation: 0,

        backgroundColor: theme.colorScheme.primary,

        foregroundColor: Colors.white,

        centerTitle: true,

          title: Text(
          isFDA
            ? _text(context, 'How to Read Nutrition Labels', 'Paano Basahin ang Nutrition Label')
            : _text(context, 'Daily Nutrient Guidelines', 'Mga Gabay sa Nutrients Kada Araw'),

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

        Text(
          _text(context, 'How to Read Nutrition Labels', 'Paano Basahin ang Nutrition Label'),

          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          _text(context, 'Learn how to understand the information on food labels and make more informed food choices.', 'Alamin kung paano unawain ang impormasyon sa food label para makagawa ng mas mabuting pagpili ng pagkain.'),

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
              _text(context, 'Read the Official FDA Guide', 'Basahin ang Opisyal na Gabay ng FDA'),

          subtitle:
              _text(context, 'View the FDA Nutrition Facts Label guide', 'Tingnan ang gabay ng FDA sa Nutrition Facts Label'),

          icon:
              Icons.open_in_new,

          onTap: () =>
              _openOfficialWebsite(context),
        ),

        const SizedBox(height: 24),

        _buildGuideItem(
          context,

          number: '1',

          title: _text(context, 'Serving Size', 'Laki ng Serving'),

          description:
              _text(context, 'Check the serving size first. Nutrition information is generally based on this amount.', 'Tingnan muna ang laki ng serving. Karaniwang nakabatay rito ang impormasyon sa nutrisyon.'),

          icon:
              Icons.restaurant_outlined,
        ),

        _buildGuideItem(
          context,

          number: '2',

          title: _text(context, 'Calories', 'Calories'),

          description:
              _text(context, 'Look at the calories per serving to understand how much energy the food provides.', 'Tingnan ang calories bawat serving para malaman kung gaano karaming enerhiya ang ibinibigay ng pagkain.'),

          icon:
              Icons.local_fire_department_outlined,
        ),

        _buildGuideItem(
          context,

          number: '3',

          title: _text(context, '% Daily Value', '% Daily Value'),

          description:
              _text(context, 'Use the % Daily Value to see how much a nutrient in one serving contributes to a daily diet.', 'Gamitin ang % Daily Value para makita ang ambag ng isang nutrient sa iyong pang-araw-araw na diyeta.'),

          icon:
              Icons.percent,
        ),

        _buildGuideItem(
          context,

          number: '4',

          title: _text(context, 'Nutrients to Limit', 'Mga Nutrient na Dapat Limitahan'),

          description:
              _text(context, 'Pay attention to nutrients such as sodium, saturated fat, and added sugars.', 'Bigyang-pansin ang sodium, saturated fat, at added sugars.'),

          icon:
              Icons.warning_amber_outlined,
        ),

        _buildGuideItem(
          context,

          number: '5',

            title: _text(context, 'Nutrients to Get Enough Of', 'Mga Nutrient na Dapat Sapat ang Intake'),

          description:
              _text(context, 'Look for beneficial nutrients such as dietary fiber, vitamins, and minerals.', 'Hanapin ang dietary fiber, vitamins, at minerals na kapaki-pakinabang sa katawan.'),

          icon:
              Icons.favorite_border,
        ),

        const SizedBox(height: 12),

        _buildSourceCard(
          context,

          _text(context, 'Official Source: U.S. Food and Drug Administration (FDA)', 'Opisyal na Pinagmulan: U.S. Food and Drug Administration (FDA)'),
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

        Text(
          _text(context, 'Daily Nutrient Limit Guidelines', 'Mga Gabay sa Limitasyon ng Nutrients Kada Araw'),

          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          _text(context, 'Learn about daily nutrient guidance that can help support a healthier and more balanced diet.', 'Alamin ang gabay sa nutrients kada araw para sa mas malusog at balanseng diyeta.'),

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
              _text(context, 'Read the Official WHO Guidelines', 'Basahin ang Opisyal na Gabay ng WHO'),

          subtitle:
              _text(context, 'View WHO healthy diet recommendations', 'Tingnan ang rekomendasyon ng WHO para sa malusog na diyeta'),

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
              _text(context, 'Sodium (Salt)', 'Sodium (Asin)'),

          value:
              _text(context, 'Less than 2,000 mg of sodium per day for adults.', 'Mas mababa sa 2,000 mg sodium bawat araw para sa matatanda.'),
        ),

        _buildNutrientItem(
          context,

          icon:
              Icons.cake_outlined,

          title:
              _text(context, 'Free Sugars', 'Free Sugars'),

          value:
              _text(context, 'Limit free sugars to less than 10% of total daily energy intake. Reducing it further to 5% or less may provide additional health benefits.', 'Limitahan ang free sugars sa mas mababa sa 10% ng kabuuang enerhiya bawat araw. Ang 5% o mas mababa ay maaaring magbigay ng dagdag na benepisyo sa kalusugan.'),
        ),

        _buildNutrientItem(
          context,

          icon:
              Icons.opacity_outlined,

          title:
              _text(context, 'Saturated Fat', 'Saturated Fat'),

          value:
              _text(context, 'No more than 10% of total daily energy intake should come from saturated fat.', 'Hindi dapat lumampas sa 10% ng kabuuang enerhiya bawat araw ang galing sa saturated fat.'),
        ),

        _buildNutrientItem(
          context,

          icon:
              Icons.no_food_outlined,

          title:
              _text(context, 'Trans Fat', 'Trans Fat'),

          value:
              _text(context, 'Limit trans fat to less than 1% of total daily energy intake and avoid industrially produced trans fats.', 'Limitahan ang trans fat sa mas mababa sa 1% ng kabuuang enerhiya bawat araw at iwasan ang industrially produced trans fats.'),
        ),

        _buildNutrientItem(
          context,

          icon:
              Icons.eco_outlined,

          title:
              _text(context, 'Dietary Fiber', 'Dietary Fiber'),

          value:
              _text(context, 'Adults and children over 10 years should aim for at least 25 g of naturally occurring dietary fiber per day.', 'Ang matatanda at batang higit 10 taong gulang ay dapat maghangad ng hindi bababa sa 25 g dietary fiber bawat araw.'),
        ),

        const SizedBox(height: 12),

        _buildSourceCard(
          context,

          _text(context, 'Official Source: World Health Organization (WHO)', 'Opisyal na Pinagmulan: World Health Organization (WHO)'),
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
              _text(
                context,
                'These guidelines are provided for general nutrition education. Individual nutrient needs may vary depending on age, health status, and other factors.',
                'Ang mga gabay na ito ay para sa pangkalahatang edukasyon sa nutrisyon. Maaaring mag-iba ang pangangailangan ng bawat tao depende sa edad, kalagayan ng kalusugan, at iba pang salik.',
              ),

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