import 'package:flutter/material.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/home_tab_controller.dart';
import '../services/haptic_service.dart';
import '../services/voice_assistant_service.dart';
import '../widgets/voice_assistant_fab.dart';
import 'profile_screen.dart';
import 'camera_scanner_screen.dart';
import 'history_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _primaryRed = Color(0xFF8B1A1A);
  static const _lightRed = Color(0xFFFCE7E7);
  static const _navPill = Color(0xFFF6CDCD);
  // Amber accent used for the WHO tip card, kept separate from the red
  // (FDA) accent so the two info sources stay visually distinguishable.
  static const _amberBg = Color(0xFFFCEEDA);
  static const _amberText = Color(0xFF8A5A0B);
  int _selectedIndex = 0;
  final _authService = AuthService();
  String _userName = 'User';

  // Expand/collapse state for each grade card on the home page.
  bool _healthExpanded = false;
  bool _processExpanded = false;

  @override
  void initState() {
    super.initState();
    // Keep local state in sync with whatever tab HomeTabController
    // currently holds, and listen for future changes.
    _selectedIndex = HomeTabController.tabNotifier.value;
    HomeTabController.tabNotifier.addListener(_handleTabChange);

    // Previously this screen had no initState() at all, so the
    // greeting only ever loaded the user's name via pull-to-refresh
    // (_onRefresh) — on first launch it just sat at the 'User' default
    // until the user manually refreshed. Loading it here fixes that.
    _loadUserName();

    // Listen to the shared name notifier so this greeting updates
    // instantly if the name is changed elsewhere (e.g.
    // PersonalInfoScreen), without requiring a manual refresh.
    AuthService.userNameNotifier.addListener(_handleNameChanged);
  }

  void _handleNameChanged() {
    if (!mounted) return;
    setState(() => _userName = AuthService.userNameNotifier.value);
  }

  @override
  void dispose() {
    HomeTabController.tabNotifier.removeListener(_handleTabChange);
    AuthService.userNameNotifier.removeListener(_handleNameChanged);
    super.dispose();
  }

  void _handleTabChange() {
    if (!mounted) return;
    setState(() => _selectedIndex = HomeTabController.tabNotifier.value);
  }

  void switchToTab(int index) {
    if (!mounted) return;
    setState(() => _selectedIndex = index);
  }

  Future<void> _loadUserName() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        final userDoc = await _authService.db
            .collection('users')
            .doc(uid)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data();
          if (data != null) {
            setState(() {
              _userName = data['name'] ?? 'User';
              if (_userName.isEmpty) _userName = 'User';
            });
            // Keep the shared notifier in sync so ProfileScreen (and any
            // other listener) reflects whatever this screen just loaded.
            AuthService.userNameNotifier.value = _userName;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user name: $e');
    }
  }

  /// Pull-to-refresh handler for the home tab. Re-fetches the latest user
  /// data (and gives light haptic feedback) so the greeting stays in sync
  /// with any changes made elsewhere (e.g. profile edits).
  Future<void> _onRefresh() async {
    HapticService().vibrate();
    await _loadUserName();
  }

  void _onNavTap(int index) {
    HapticService().vibrate();
    HomeTabController.tabNotifier.value = index;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              SafeArea(bottom: false, child: _buildHomeContent()),
              _buildScanPage(),
              SafeArea(bottom: false, child: _buildHistoryPage()),
              const SafeArea(bottom: false, child: ProfileScreen()),
            ],
          ),
        ],
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: VoiceAssistantService.isEnabledNotifier,
        builder: (context, isEnabled, child) {
          // Hide mic on scan tab
          if (!isEnabled || _selectedIndex == 1) return const SizedBox.shrink();
          return const VoiceAssistantFab();
        },
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomeContent() {
    final theme = Theme.of(context);
    return RefreshIndicator(
      color: theme.colorScheme.primary,
      onRefresh: _onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildScanCard(),
            const SizedBox(height: 22),
            _buildLabelIntro(),
            const SizedBox(height: 18),
            _buildInfoCarousel(),
            const SizedBox(height: 18),
            _buildHealthCard(),
            const SizedBox(height: 12),
            _buildProcessCard(),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    final bodyLarge = theme.textTheme.bodyLarge;
    final bodyMedium = theme.textTheme.bodyMedium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(
          'assets/images/logoII.png',
          height: 60,
        ),
        const SizedBox(height: 12),
        Text(
          loc.greeting(_userName),
          style: bodyLarge?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          loc.homeTagline,
          style: bodyMedium?.copyWith(
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildScanCard() {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC62E2E), Color(0xFF6B0F0F)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primaryRed.withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.scanCardTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  loc.scanCardSubtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => _onNavTap(1),
                    child: Text(
                      loc.scanNow,
                      style: const TextStyle(
                        color: _primaryRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildViewfinderIcon(),
        ],
      ),
    );
  }

  /// Viewfinder-style camera icon: four corner brackets with a camera
  /// glyph centered inside, matching the scan card in the mockup.
  Widget _buildViewfinderIcon({double size = 100, double bracketSize = 26}) {
    const strokeWidth = 2.4;
    const cornerRadius = Radius.circular(8);

    Widget bracket({
      required Alignment alignment,
      required bool top,
      required bool left,
    }) {
      return Align(
        alignment: alignment,
        child: Container(
          width: bracketSize,
          height: bracketSize,
          decoration: BoxDecoration(
            border: Border(
              top: top
                  ? const BorderSide(color: Colors.white, width: strokeWidth)
                  : BorderSide.none,
              bottom: !top
                  ? const BorderSide(color: Colors.white, width: strokeWidth)
                  : BorderSide.none,
              left: left
                  ? const BorderSide(color: Colors.white, width: strokeWidth)
                  : BorderSide.none,
              right: !left
                  ? const BorderSide(color: Colors.white, width: strokeWidth)
                  : BorderSide.none,
            ),
            borderRadius: BorderRadius.only(
              topLeft: top && left ? cornerRadius : Radius.zero,
              topRight: top && !left ? cornerRadius : Radius.zero,
              bottomLeft: !top && left ? cornerRadius : Radius.zero,
              bottomRight: !top && !left ? cornerRadius : Radius.zero,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          bracket(alignment: Alignment.topLeft, top: true, left: true),
          bracket(alignment: Alignment.topRight, top: true, left: false),
          bracket(alignment: Alignment.bottomLeft, top: false, left: true),
          bracket(alignment: Alignment.bottomRight, top: false, left: false),
          const Center(
            child: Icon(
              Icons.camera_alt_outlined,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelIntro() {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final bodyLarge = theme.textTheme.bodyLarge;
    final bodyMedium = theme.textTheme.bodyMedium;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.labelIntroTitle,
                style: bodyLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loc.labelIntroSubtitle,
                style: bodyMedium?.copyWith(fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Image.asset(
              'assets/images/cart.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Info carousel — quick-access tips (FDA label guide, WHO nutrient
  // limits). Tapping a tile opens a bottom sheet with the full detail.
  //
  // NOTE: strings here are hardcoded Filipino rather than routed through
  // AppLocalizations because the corresponding keys don't exist yet in
  // the .arb files. Add them there (e.g. infoFdaTitle, infoWhoTitle,
  // etc.) and swap these literals for loc.xxx before shipping.
  // ---------------------------------------------------------------------

  Widget _buildInfoCarousel() {
    final loc = AppLocalizations.of(context)!;
    final isLtr = Directionality.of(context) == TextDirection.ltr;
    return SizedBox(
      height: 132,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        reverse: !isLtr,
        children: [
          _TipCard(
            icon: Icons.description_outlined,
            title: loc.infoFdaTitle,
            subtitle: loc.infoFdaSubtitle,
            bgColor: _lightRed,
            fgColor: _primaryRed,
            onTap: () => _showInfoSheet(_buildFdaSheetContent()),
          ),
          const SizedBox(width: 10),
          _TipCard(
            icon: Icons.balance_outlined,
            title: loc.infoWhoTitle,
            subtitle: loc.infoWhoSubtitle,
            bgColor: _amberBg,
            fgColor: _amberText,
            onTap: () => _showInfoSheet(_buildWhoSheetContent()),
          ),
        ],
      ),
    );
  }

  void _showInfoSheet(Widget content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SingleChildScrollView(
            controller: scrollController,
            child: content,
          ),
        ),
      ),
    );
  }

  /// Detail content shown when the FDA tip card is tapped. Steps follow
  /// the FDA's own "How to Understand and Use the Nutrition Facts Label"
  /// guidance (serving size → calories → %DV), fda.gov.
  Widget _buildFdaSheetContent() {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final steps = [
      loc.infoFdaSheetStep1,
      loc.infoFdaSheetStep2,
      loc.infoFdaSheetStep3,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSheetHandle(),
        Row(
          children: [
            Icon(Icons.description_outlined, size: 20, color: _primaryRed),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loc.infoFdaSheetHeading,
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          loc.infoFdaSheetSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 16),
        ...List.generate(steps.length, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: _lightRed,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryRed),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(steps[i], style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13, height: 1.5)),
              ),
            ],
          ),
        )),
      ],
    );
  }

  /// Detail content shown when the WHO tip card is tapped. Figures are
  /// WHO's percent-of-energy targets (sugar <10%, sat fat <10%, trans fat
  /// <1%, sodium <2g) converted to grams for a 2,000 kcal reference diet.
  Widget _buildWhoSheetContent() {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final limits = [
      (loc.infoWhoSheetLimitSugar, loc.infoWhoSheetLimitSugarValue),
      (loc.infoWhoSheetLimitSalt, loc.infoWhoSheetLimitSaltValue),
      (loc.infoWhoSheetLimitSaturatedFat, loc.infoWhoSheetLimitSaturatedFatValue),
      (loc.infoWhoSheetLimitTransFat, loc.infoWhoSheetLimitTransFatValue),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSheetHandle(),
        Row(
          children: [
            Icon(Icons.balance_outlined, size: 20, color: _amberText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loc.infoWhoSheetHeading,
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          loc.infoWhoSheetSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 16),
        ...limits.map((row) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _amberBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(row.$1, style: TextStyle(fontSize: 13, color: _amberText)),
              Text(row.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _amberText)),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildSheetHandle() {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Health & Eco grade cards (A–E scale, expandable arrow-ribbon detail)
  // ---------------------------------------------------------------------

  static const List<Color> _gradeColors = [
    Color(0xFF69A64A),
    Color(0xFF8FDB42),
    Color(0xFFD9A62E),
    Color(0xFFF26C3C),
    Color(0xFFEA3F2D),
  ];
  static const List<String> _gradeLetters = ['A', 'B', 'C', 'D', 'E'];

  Widget _buildHealthCard() {
    return _buildGradeCard(
      icon: Icons.balance,
      title: AppLocalizations.of(context)!.healthGradeTitle,
      subtitle: AppLocalizations.of(context)!.healthGradeSubtitle,
      values: [
        AppLocalizations.of(context)!.healthGradeValue0,
        AppLocalizations.of(context)!.healthGradeValue1,
        AppLocalizations.of(context)!.healthGradeValue2,
        AppLocalizations.of(context)!.healthGradeValue3,
        AppLocalizations.of(context)!.healthGradeValue4,
      ],
      expanded: _healthExpanded,
      onTap: () {
        HapticService().vibrate();
        setState(() => _healthExpanded = !_healthExpanded);
      },
    );
  }



  Widget _buildGradeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> values,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final bodyLarge = theme.textTheme.bodyLarge;
    final bodyMedium = theme.textTheme.bodyMedium;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                  child: Icon(icon, size: 18, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: bodyLarge?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: bodyMedium?.copyWith(
                            fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : (Directionality.of(context) == TextDirection.ltr
                          ? Icons.chevron_right
                          : Icons.chevron_left),
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState:
            expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: _buildGradeSummaryBar(),
            secondChild: _buildGradeDetailList(values),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeSummaryBar() {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return Row(
      children: [
        SizedBox(
          width: 46,
          child: Text(
            loc.bestLabelShort,
            style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant, height: 1.2),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Row(
            children: List.generate(_gradeColors.length, (index) {
              final isFirst = index == 0;
              final isLast = index == _gradeColors.length - 1;
              return Expanded(
                child: Container(
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _gradeColors[index],
                    borderRadius: BorderRadius.horizontal(
                      left: isFirst ? const Radius.circular(13) : Radius.zero,
                      right: isLast ? const Radius.circular(13) : Radius.zero,
                    ),
                  ),
                  child: Text(
                    _gradeLetters[index],
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 46,
          child: Text(
            loc.worstLabelShort,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant, height: 1.2),
          ),
        ),
      ],
    );
  }

  /// Expanded state: a full arrow/ribbon breakdown, each grade narrower
  /// than the last, matching a Nutri-Score-style detail view.
  Widget _buildGradeDetailList(List<String> values) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.bestLabel,
          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        ...List.generate(values.length, (index) {
          final widthFactor = 1.0 - (index * 0.05);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: widthFactor,
                child: _buildArrowRibbon(
                  letter: _gradeLetters[index],
                  label: values[index],
                  color: _gradeColors[index],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 2),
        Text(
          loc.worstLabel,
          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildArrowRibbon({
    required String letter,
    required String label,
    required Color color,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 30,
            constraints: const BoxConstraints(minHeight: 34),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(8),
              ),
            ),
            child: Text(
              letter,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            child: ClipPath(
              clipper: _ArrowClipper(),
              child: Container(
                color: color,
                constraints: const BoxConstraints(minHeight: 34),
                padding: const EdgeInsets.only(left: 10, right: 18, top: 7, bottom: 7),
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  softWrap: true,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      height: 1.25,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Processing level card (1-4 scale, expandable)
  // ---------------------------------------------------------------------

  static const List<Color> _processColors = [
    Color(0xFF69A64A),
    Color(0xFF8FDB42),
    Color(0xFFF4A93B),
    Color(0xFFEA3F2D),
  ];
  static const List<String> _processLabels = [
    'Hindi o bahagyang naproseso',
    'May naprosesong sangkap sa pagluluto',
    'Naprosesong pagkain',
    'Malubhang naprosesong pagkain',
  ];

  Widget _buildProcessCard() {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final bodyLarge = theme.textTheme.bodyLarge;
    final bodyMedium = theme.textTheme.bodyMedium;

    final processLabels = [
      loc.processLabel0,
      loc.processLabel1,
      loc.processLabel2,
      loc.processLabel3,
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticService().vibrate();
              setState(() => _processExpanded = !_processExpanded);
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                  child: Icon(Icons.blender_outlined, size: 18, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.processGradeTitle,
                        style: bodyLarge?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loc.processGradeSubtitle,
                        style: bodyMedium?.copyWith(
                            fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _processExpanded
                      ? Icons.keyboard_arrow_up
                      : (Directionality.of(context) == TextDirection.ltr
                          ? Icons.chevron_right
                          : Icons.chevron_left),
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(loc.processGroupFirst,
                  style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant, height: 1.2)),
              ...List.generate(4, (index) {
                final level = index + 1;
                return CircleAvatar(
                  radius: 15,
                  backgroundColor: _processColors[index],
                  child: Text(
                    '$level',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                );
              }),
              Text(loc.processGroupFourth,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant, height: 1.2)),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _processExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                children: List.generate(processLabels.length, (index) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: _processColors[index],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${index + 1}  ${processLabels[index]}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceButton() {
    return PositionedDirectional(
      bottom: 92,
      end: 24,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _primaryRed,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _primaryRed.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.mic, color: Colors.white),
          onPressed: () {
            HapticService().vibrate();
            _onNavTap(1);
          },
        ),
      ),
    );
  }

  Widget _buildScanPage() {
    return CameraScannerScreen(
      embeddedMode: true,
      isActive: _selectedIndex == 1,
    );
  }

  Widget _buildHistoryPage() {
    return const HistoryScreen(embeddedMode: true);
  }

  Widget _buildPlaceholderPage(String title, String subtitle) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bodyLarge = theme.textTheme.bodyLarge;
    final bodyMedium = theme.textTheme.bodyMedium;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: bodyLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: bodyMedium?.copyWith(fontSize: 14, height: 1.5, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Bottom navigation bar — pink pill highlight behind the active tab
  // ---------------------------------------------------------------------

  Widget _buildBottomNav() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final navPillColor = theme.brightness == Brightness.dark
        ? colorScheme.primary.withOpacity(0.2)
        : const Color(0xFFF6CDCD);

    final items = [
      (icon: Icons.home_outlined, activeIcon: Icons.home, label: AppLocalizations.of(context)!.home),
      (icon: Icons.qr_code_scanner_outlined, activeIcon: Icons.qr_code_scanner, label: AppLocalizations.of(context)!.scan),
      (icon: Icons.history_outlined, activeIcon: Icons.history, label: AppLocalizations.of(context)!.history),
      (icon: Icons.person_outline, activeIcon: Icons.person, label: AppLocalizations.of(context)!.profile),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.dark ? Colors.black.withOpacity(0.25) : Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isSelected = index == _selectedIndex;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _onNavTap(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? navPillColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? item.activeIcon : item.icon,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.primary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Tappable tip card used in the home info carousel. Wrapped in Material
/// + InkWell so it gets a real ripple on tap, plus a small press-down
/// scale so it also reads as clickable to users on platforms/situations
/// where the ripple alone is easy to miss (e.g. fast taps).
class _TipCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color bgColor;
  final Color fgColor;
  final VoidCallback onTap;

  const _TipCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bgColor,
    required this.fgColor,
    required this.onTap,
  });

  @override
  State<_TipCard> createState() => _TipCardState();
}

class _TipCardState extends State<_TipCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: SizedBox(
        width: 150,
        child: Material(
          color: widget.bgColor,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            splashColor: widget.fgColor.withOpacity(0.12),
            highlightColor: widget.fgColor.withOpacity(0.08),
            onTapDown: (_) => _setPressed(true),
            onTapCancel: () => _setPressed(false),
            onTap: () {
              _setPressed(false);
              HapticService().vibrate();
              widget.onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Builder(builder: (context) {
                final isLtr = Directionality.of(context) == TextDirection.ltr;
                return Column(
                  crossAxisAlignment: isLtr ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: isLtr
                          ? [
                              Icon(widget.icon, size: 20, color: widget.fgColor),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: widget.fgColor.withOpacity(0.5),
                              ),
                            ]
                          : [
                              Icon(
                                Icons.chevron_left,
                                size: 18,
                                color: widget.fgColor.withOpacity(0.5),
                              ),
                              Icon(widget.icon, size: 20, color: widget.fgColor),
                            ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.title,
                      textAlign: isLtr ? TextAlign.left : TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: widget.fgColor,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      textAlign: isLtr ? TextAlign.left : TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: widget.fgColor.withOpacity(0.85)),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// Clips a rectangle into a right-pointing arrow/ribbon shape, used for
/// the expanded grade-detail rows (Nutri-Score-style).
class _ArrowClipper extends CustomClipper<Path> {
  final double arrowWidth;
  const _ArrowClipper({this.arrowWidth = 12});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width - arrowWidth, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(size.width - arrowWidth, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}