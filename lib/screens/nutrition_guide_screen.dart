import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

enum NutritionGuideType { fda, who, kidney, gerd }

class NutritionGuideScreen extends StatelessWidget {
  final NutritionGuideType type;

  const NutritionGuideScreen({super.key, required this.type});

  bool get isFDA => type == NutritionGuideType.fda;

  bool get isKidney => type == NutritionGuideType.kidney;

  bool _isTagalog(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'tl';

  String _text(BuildContext context, String english, String tagalog) =>
      _isTagalog(context) ? tagalog : english;

  // ---------------------------------------------------------------------------
  // SHARED SHADOW STYLE
  //
  // Replaces the old thin outlines. Two layers: a soft ambient shadow plus a
  // tight contact shadow so cards read clearly as raised surfaces. Dark mode
  // uses a stronger opacity because black shadows are much harder to see
  // against a dark background.
  // ---------------------------------------------------------------------------

  List<BoxShadow> _softShadows(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return [
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.50 : 0.14),
        blurRadius: 14,
        spreadRadius: 0,
        offset: const Offset(0, 5),
      ),
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
        blurRadius: 4,
        spreadRadius: 0,
        offset: const Offset(0, 1.5),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // OFFICIAL LINKS
  // ---------------------------------------------------------------------------

  static final Uri _fdaUrl = Uri.parse(
    'https://www.fda.gov/food/nutrition-education-resources-materials/nutrition-facts-label',
  );

  static final Uri _whoUrl = Uri.parse(
    'https://www.who.int/en/news-room/fact-sheets/detail/healthy-diet',
  );

  static final Uri _kidneyUrl = Uri.parse(
    'https://www.niddk.nih.gov/health-information/kidney-disease/chronic-kidney-disease-ckd/healthy-eating-adults-chronic-kidney-disease',
  );

  static final Uri _gerdUrl = Uri.parse(
    'https://www.niddk.nih.gov/health-information/digestive-diseases/acid-reflux-ger-gerd-adults/eating-diet-nutrition',
  );

  // ---------------------------------------------------------------------------
  // OPEN OFFICIAL WEBSITE
  // ---------------------------------------------------------------------------

  Future<void> _openOfficialWebsite(BuildContext context) async {
    final Uri url;
    if (isFDA) {
      url = _fdaUrl;
    } else if (type == NutritionGuideType.who) {
      url = _whoUrl;
    } else if (isKidney) {
      url = _kidneyUrl;
    } else {
      url = _gerdUrl;
    }

    try {
      final bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _text(
                context,
                'Unable to open the official website.',
                'Hindi mabuksan ang opisyal na website.',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _text(
                context,
                'Unable to open the official website.',
                'Hindi mabuksan ang opisyal na website.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(
        elevation: 0,

        backgroundColor: theme.colorScheme.primary,

        foregroundColor: Colors.white,

        centerTitle: true,

        title: Text(
          isFDA
              ? _text(
                  context,
                  'How to Read Nutrition Labels',
                  'Paano Basahin ang Nutrition Label',
                )
              : type == NutritionGuideType.who
              ? _text(
                  context,
                  'Daily Nutrient Guidelines',
                  'Mga Gabay sa Nutrients Kada Araw',
                )
              : isKidney
              ? _text(
                  context,
                  'Healthy Eating with Chronic Kidney Disease',
                  'Malusog na Pagkain para sa Chronic Kidney Disease',
                )
              : _text(
                  context,
                  'Eating, Diet, & Nutrition for GERD',
                  'Pagkain, Diyeta, at Nutrisyon para sa GERD',
                ),

          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),

          child: isFDA
              ? _buildFDAContent(context)
              : type == NutritionGuideType.who
              ? _buildWHOContent(context)
              : isKidney
              ? _buildKidneyContent(context)
              : _buildGerdContent(context),
        ),
      ),
    );
  }

  // ===========================================================================
  // FDA PAGE
  // ===========================================================================

  Widget _buildFDAContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _buildHeroImage(context, 'assets/images/learn-more/fdaimg.png'),

        const SizedBox(height: 20),

        Text(
          _text(
            context,
            'How to Read Nutrition Labels',
            'Paano Basahin ang Nutrition Label',
          ),

          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        Text(
          _text(
            context,
            'Learn how to understand the information on food labels and make more informed food choices.',
            'Alamin kung paano unawain ang impormasyon sa food label para makagawa ng mas mabuting pagpili ng pagkain.',
          ),

          style: TextStyle(
            fontSize: 14,
            height: 1.5,

            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 20),

        // ---------------------------------------------------------------------
        // OFFICIAL FDA BUTTON
        // ---------------------------------------------------------------------
        _buildOfficialWebsiteButton(
          context,

          label: _text(
            context,
            'Read the Official FDA Guide',
            'Basahin ang Opisyal na Gabay ng FDA',
          ),

          subtitle: _text(
            context,
            'View the FDA Nutrition Facts Label guide',
            'Tingnan ang gabay ng FDA sa Nutrition Facts Label',
          ),

          icon: Icons.open_in_new,

          onTap: () => _openOfficialWebsite(context),
        ),

        const SizedBox(height: 24),

        _buildGuideItem(
          context,

          number: '1',

          title: _text(context, 'Serving Size', 'Laki ng Serving'),

          description: _text(
            context,
            'Check the serving size first. Nutrition information is generally based on this amount.',
            'Tingnan muna ang laki ng serving. Karaniwang nakabatay rito ang impormasyon sa nutrisyon.',
          ),

          icon: Icons.restaurant_outlined,
        ),

        _buildGuideItem(
          context,

          number: '2',

          title: _text(context, 'Calories', 'Calories'),

          description: _text(
            context,
            'Look at the calories per serving to understand how much energy the food provides.',
            'Tingnan ang calories bawat serving para malaman kung gaano karaming enerhiya ang ibinibigay ng pagkain.',
          ),

          icon: Icons.local_fire_department_outlined,
        ),

        _buildGuideItem(
          context,

          number: '3',

          title: _text(context, '% Daily Value', '% Daily Value'),

          description: _text(
            context,
            'Use the % Daily Value to see how much a nutrient in one serving contributes to a daily diet.',
            'Gamitin ang % Daily Value para makita ang ambag ng isang nutrient sa iyong pang-araw-araw na diyeta.',
          ),

          icon: Icons.percent,
        ),

        _buildGuideItem(
          context,

          number: '4',

          title: _text(
            context,
            'Nutrients to Limit',
            'Mga Nutrient na Dapat Limitahan',
          ),

          description: _text(
            context,
            'Pay attention to nutrients such as sodium, saturated fat, and added sugars.',
            'Bigyang-pansin ang sodium, saturated fat, at added sugars.',
          ),

          icon: Icons.warning_amber_outlined,
        ),

        _buildGuideItem(
          context,

          number: '5',

          title: _text(
            context,
            'Nutrients to Get Enough Of',
            'Mga Nutrient na Dapat Sapat ang Intake',
          ),

          description: _text(
            context,
            'Look for beneficial nutrients such as dietary fiber, vitamins, and minerals.',
            'Hanapin ang dietary fiber, vitamins, at minerals na kapaki-pakinabang sa katawan.',
          ),

          icon: Icons.favorite_border,
        ),

        const SizedBox(height: 12),

        _buildSourceCard(
          context,

          _text(
            context,
            'Official Source: U.S. Food and Drug Administration (FDA)',
            'Opisyal na Pinagmulan: U.S. Food and Drug Administration (FDA)',
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // WHO PAGE
  // ===========================================================================

  Widget _buildWHOContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _buildHeroImage(context, 'assets/images/learn-more/whoimg.png'),

        const SizedBox(height: 20),

        Text(
          _text(
            context,
            'Daily Nutrient Limit Guidelines',
            'Mga Gabay sa Limitasyon ng Nutrients Kada Araw',
          ),

          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        Text(
          _text(
            context,
            'Learn about daily nutrient guidance that can help support a healthier and more balanced diet.',
            'Alamin ang gabay sa nutrients kada araw para sa mas malusog at balanseng diyeta.',
          ),

          style: TextStyle(
            fontSize: 14,
            height: 1.5,

            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 20),

        // ---------------------------------------------------------------------
        // OFFICIAL WHO BUTTON
        // ---------------------------------------------------------------------
        _buildOfficialWebsiteButton(
          context,

          label: _text(
            context,
            'Read the Official WHO Guidelines',
            'Basahin ang Opisyal na Gabay ng WHO',
          ),

          subtitle: _text(
            context,
            'View WHO healthy diet recommendations',
            'Tingnan ang rekomendasyon ng WHO para sa malusog na diyeta',
          ),

          icon: Icons.open_in_new,

          onTap: () => _openOfficialWebsite(context),
        ),

        const SizedBox(height: 24),

        _buildNutrientItem(
          context,

          icon: Icons.water_drop_outlined,

          title: _text(context, 'Sodium (Salt)', 'Sodium (Asin)'),

          value: _text(
            context,
            'Less than 2,000 mg of sodium per day for adults.',
            'Mas mababa sa 2,000 mg sodium bawat araw para sa matatanda.',
          ),
        ),

        _buildNutrientItem(
          context,

          icon: Icons.cake_outlined,

          title: _text(context, 'Free Sugars', 'Free Sugars'),

          value: _text(
            context,
            'Limit free sugars to less than 10% of total daily energy intake. Reducing it further to 5% or less may provide additional health benefits.',
            'Limitahan ang free sugars sa mas mababa sa 10% ng kabuuang enerhiya bawat araw. Ang 5% o mas mababa ay maaaring magbigay ng dagdag na benepisyo sa kalusugan.',
          ),
        ),

        _buildNutrientItem(
          context,

          icon: Icons.opacity_outlined,

          title: _text(context, 'Saturated Fat', 'Saturated Fat'),

          value: _text(
            context,
            'No more than 10% of total daily energy intake should come from saturated fat.',
            'Hindi dapat lumampas sa 10% ng kabuuang enerhiya bawat araw ang galing sa saturated fat.',
          ),
        ),

        _buildNutrientItem(
          context,

          icon: Icons.no_food_outlined,

          title: _text(context, 'Trans Fat', 'Trans Fat'),

          value: _text(
            context,
            'Limit trans fat to less than 1% of total daily energy intake and avoid industrially produced trans fats.',
            'Limitahan ang trans fat sa mas mababa sa 1% ng kabuuang enerhiya bawat araw at iwasan ang industrially produced trans fats.',
          ),
        ),

        _buildNutrientItem(
          context,

          icon: Icons.eco_outlined,

          title: _text(context, 'Dietary Fiber', 'Dietary Fiber'),

          value: _text(
            context,
            'Adults and children over 10 years should aim for at least 25 g of naturally occurring dietary fiber per day.',
            'Ang matatanda at batang higit 10 taong gulang ay dapat maghangad ng hindi bababa sa 25 g dietary fiber bawat araw.',
          ),
        ),

        const SizedBox(height: 12),

        _buildSourceCard(
          context,

          _text(
            context,
            'Official Source: World Health Organization (WHO)',
            'Opisyal na Pinagmulan: World Health Organization (WHO)',
          ),
        ),

        const SizedBox(height: 10),

        _buildDisclaimerCard(context),
      ],
    );
  }

  Widget _buildKidneyContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroImage(context, 'assets/images/learn-more/niddkdimg.png'),
        const SizedBox(height: 20),
        Text(
          _text(
            context,
            'Healthy Eating with Chronic Kidney Disease',
            'Malusog na Pagkain para sa Chronic Kidney Disease',
          ),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _text(
            context,
            'Learn how food choices can support adults living with chronic kidney disease.',
            'Alamin kung paano makakatulong ang mga pagpili ng pagkain sa mga matatandang may chronic kidney disease.',
          ),
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        _buildOfficialWebsiteButton(
          context,
          label: _text(
            context,
            'Read the Official NIDDK Guide',
            'Basahin ang Opisyal na Gabay ng NIDDK',
          ),
          subtitle: _text(
            context,
            'View NIDDK guidance for adults with chronic kidney disease',
            'Tingnan ang gabay ng NIDDK para sa matatandang may chronic kidney disease',
          ),
          icon: Icons.open_in_new,
          onTap: () => _openOfficialWebsite(context),
        ),
        const SizedBox(height: 24),
        _buildGuideItem(
          context,
          number: '1',
          title: _text(
            context,
            'Watch your sodium intake',
            'Bantayan ang sodium sa pagkain',
          ),
          description: _text(
            context,
            'Too much sodium can make the body hold extra fluid and may raise blood pressure. Choose foods with less sodium when following your eating plan.',
            'Ang sobrang sodium ay maaaring magdulot ng pag-ipon ng fluid sa katawan at pagtaas ng blood pressure. Pumili ng pagkaing mas kaunti ang sodium ayon sa iyong eating plan.',
          ),
          icon: Icons.water_drop_outlined,
        ),
        _buildGuideItem(
          context,
          number: '2',
          title: _text(
            context,
            'Ask about phosphorus',
            'Magtanong tungkol sa phosphorus',
          ),
          description: _text(
            context,
            'Some people with chronic kidney disease need to limit phosphorus. A health professional can help identify foods and drinks that fit your needs.',
            'Maaaring kailangang limitahan ng ilang taong may chronic kidney disease ang phosphorus. Makakatulong ang health professional sa pagpili ng angkop na pagkain at inumin.',
          ),
          icon: Icons.science_outlined,
        ),
        _buildGuideItem(
          context,
          number: '3',
          title: _text(
            context,
            'Potassium and protein needs vary',
            'Nag-iiba ang pangangailangan sa potassium at protein',
          ),
          description: _text(
            context,
            'Your potassium and protein needs may depend on your kidney function, treatment, and other health needs. Follow the personalized advice from your health professional.',
            'Maaaring depende sa kidney function, treatment, at iba pang pangangailangan sa kalusugan ang potassium at protein. Sundin ang personalized na payo ng iyong health professional.',
          ),
          icon: Icons.info_outline,
        ),
        _buildGuideItem(
          context,
          number: '4',
          title: _text(
            context,
            'Make a personal eating plan',
            'Gumawa ng personal na eating plan',
          ),
          description: _text(
            context,
            'The right food choices can change as kidney disease changes. Ask a doctor or dietitian which foods, portions, and nutrients are right for you.',
            'Maaaring magbago ang tamang pagpili ng pagkain habang nagbabago ang kidney disease. Magtanong sa doktor o dietitian tungkol sa angkop na pagkain, dami, at nutrients.',
          ),
          icon: Icons.help_outline,
        ),
        const SizedBox(height: 12),
        _buildSourceCard(
          context,
          _text(
            context,
            'Official Source: National Institute of Diabetes and Digestive and Kidney Diseases (NIDDK)',
            'Opisyal na Pinagmulan: National Institute of Diabetes and Digestive and Kidney Diseases (NIDDK)',
          ),
        ),
        const SizedBox(height: 10),
        _buildDisclaimerCard(context),
      ],
    );
  }

  Widget _buildGerdContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroImage(context, 'assets/images/learn-more/niddkdimg.png'),
        const SizedBox(height: 20),
        Text(
          _text(
            context,
            'Eating, Diet, & Nutrition for GERD',
            'Pagkain, Diyeta, at Nutrisyon para sa GERD',
          ),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _text(
            context,
            'Learn how eating habits and personal food triggers may relate to GERD symptoms.',
            'Alamin kung paano maaaring maiugnay sa mga sintomas ng GERD ang eating habits at personal na food triggers.',
          ),
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        _buildOfficialWebsiteButton(
          context,
          label: _text(
            context,
            'Read the Official NIDDK Guide',
            'Basahin ang Opisyal na Gabay ng NIDDK',
          ),
          subtitle: _text(
            context,
            'View NIDDK guidance about eating, diet, and nutrition for GERD',
            'Tingnan ang gabay ng NIDDK tungkol sa pagkain, diyeta, at nutrisyon para sa GERD',
          ),
          icon: Icons.open_in_new,
          onTap: () => _openOfficialWebsite(context),
        ),
        const SizedBox(height: 24),
        _buildGuideItem(
          context,
          number: '1',
          title: _text(
            context,
            'Notice foods that affect you',
            'Pansinin ang mga pagkaing nakakaapekto sa iyo',
          ),
          description: _text(
            context,
            'Foods that are high in fat may worsen symptoms for some people. Keep track of foods that bother you and discuss them with a health professional.',
            'Ang mga pagkaing mataas sa fat ay maaaring magpalala ng sintomas sa ilang tao. Itala ang mga pagkaing nakakaabala sa iyo at pag-usapan ito sa health professional.',
          ),
          icon: Icons.opacity_outlined,
        ),
        _buildGuideItem(
          context,
          number: '2',
          title: _text(
            context,
            'Common food triggers vary',
            'Nag-iiba ang mga karaniwang food trigger',
          ),
          description: _text(
            context,
            'Tomatoes, citrus foods, coffee, chocolate, mint, spicy foods, and high-fat foods may bother some people. A food that causes symptoms for one person may not affect another person.',
            'Maaaring makaabala sa ilang tao ang kamatis, citrus foods, kape, tsokolate, mint, spicy foods, at pagkaing mataas sa fat. Maaaring hindi makaapekto sa iba ang pagkaing nagdudulot ng sintomas sa isang tao.',
          ),
          icon: Icons.search_outlined,
        ),
        _buildGuideItem(
          context,
          number: '3',
          title: _text(
            context,
            'Try smaller meals',
            'Subukan ang mas maliliit na meal',
          ),
          description: _text(
            context,
            'Eating smaller meals may help some people. Avoid lying down for at least 3 hours after eating if this is part of your care plan.',
            'Maaaring makatulong sa ilang tao ang mas maliliit na meal. Iwasang humiga nang hindi bababa sa 3 oras pagkatapos kumain kung bahagi ito ng iyong care plan.',
          ),
          icon: Icons.info_outline,
        ),
        _buildGuideItem(
          context,
          number: '4',
          title: _text(
            context,
            'Use advice that fits you',
            'Gamitin ang payong angkop sa iyo',
          ),
          description: _text(
            context,
            'GERD symptoms and food triggers differ from person to person. Talk with a health professional for advice based on your symptoms and health needs.',
            'Nag-iiba ang sintomas at food triggers ng GERD sa bawat tao. Makipag-usap sa health professional para sa payong naaayon sa iyong sintomas at pangangailangan sa kalusugan.',
          ),
          icon: Icons.help_outline,
        ),
        const SizedBox(height: 12),
        _buildSourceCard(
          context,
          _text(
            context,
            'Official Source: National Institute of Diabetes and Digestive and Kidney Diseases (NIDDK)',
            'Opisyal na Pinagmulan: National Institute of Diabetes and Digestive and Kidney Diseases (NIDDK)',
          ),
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

    // Solid (opaque) version of the old translucent primary tint. A
    // translucent fill would let the shadow show through the inside of the
    // button, so the tint is pre-blended onto the card color instead.
    final solidTint = Color.alphaBlend(
      theme.colorScheme.primary.withOpacity(0.08),
      theme.cardColor,
    );

    return Material(
      color: Colors.transparent,

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(16),

        // No outline -- visible shadow instead.
        child: Container(
          width: double.infinity,

          padding: const EdgeInsets.all(14),

          decoration: BoxDecoration(
            color: solidTint,

            borderRadius: BorderRadius.circular(16),

            boxShadow: _softShadows(context),
          ),

          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,

                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,

                  shape: BoxShape.circle,
                ),

                child: Icon(icon, color: Colors.white, size: 20),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      label,

                      style: TextStyle(
                        fontSize: 14,

                        fontWeight: FontWeight.bold,

                        color: theme.colorScheme.onSurface,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,

                      style: TextStyle(
                        fontSize: 11.5,

                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(Icons.chevron_right, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HERO IMAGE
  // ===========================================================================

  Widget _buildHeroImage(BuildContext context, String imagePath) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,

      height: 210,

      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,

        borderRadius: BorderRadius.circular(20),
      ),

      clipBehavior: Clip.antiAlias,

      child: Image.asset(
        imagePath,

        fit: BoxFit.cover,

        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Icon(
              Icons.image_not_supported_outlined,

              size: 50,

              color: theme.colorScheme.onSurfaceVariant,
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
      margin: const EdgeInsets.only(bottom: 14),

      padding: const EdgeInsets.all(14),

      // No outline -- visible shadow instead.
      decoration: BoxDecoration(
        color: theme.cardColor,

        borderRadius: BorderRadius.circular(16),

        boxShadow: _softShadows(context),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Container(
            width: 44,
            height: 44,

            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.10),

              shape: BoxShape.circle,
            ),

            child: Stack(
              alignment: Alignment.center,

              children: [
                Icon(icon, size: 21, color: theme.colorScheme.primary),

                Positioned(
                  right: 0,
                  top: 0,

                  child: Container(
                    width: 17,
                    height: 17,

                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,

                      shape: BoxShape.circle,
                    ),

                    alignment: Alignment.center,

                    child: Text(
                      number,

                      style: const TextStyle(
                        color: Colors.white,

                        fontSize: 9,

                        fontWeight: FontWeight.bold,
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
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  description,

                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,

                    color: theme.colorScheme.onSurfaceVariant,
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

      margin: const EdgeInsets.only(bottom: 14),

      padding: const EdgeInsets.all(14),

      // No outline -- visible shadow instead.
      decoration: BoxDecoration(
        color: theme.cardColor,

        borderRadius: BorderRadius.circular(16),

        boxShadow: _softShadows(context),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Container(
            width: 44,
            height: 44,

            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.10),

              shape: BoxShape.circle,
            ),

            child: Icon(icon, color: theme.colorScheme.primary, size: 21),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,

                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,

                    color: theme.colorScheme.onSurfaceVariant,
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

  Widget _buildSourceCard(BuildContext context, String source) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.06),

        borderRadius: BorderRadius.circular(14),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(
            Icons.verified_outlined,

            size: 18,

            color: theme.colorScheme.primary,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              source,

              style: TextStyle(
                fontSize: 11,
                height: 1.4,

                fontWeight: FontWeight.w600,

                color: theme.colorScheme.onSurfaceVariant,
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

  Widget _buildDisclaimerCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,

        borderRadius: BorderRadius.circular(14),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(
            Icons.info_outline,

            size: 18,

            color: theme.colorScheme.onSurfaceVariant,
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

                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}