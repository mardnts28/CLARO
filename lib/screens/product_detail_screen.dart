import 'dart:async';
import 'package:flutter/material.dart';
import '../core/utils/number_format_utils.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product_model.dart';
import '../services/fda_verification_service.dart';
import '../services/auth_service.dart';
import '../services/voice_assistant_service.dart';
import '../services/haptic_service.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/locale_service.dart';
import '../widgets/voice_assistant_fab.dart';
import 'compare_products_screen.dart';
import 'more_details_screen.dart';
import 'unknown_product_submission_screen.dart';
import '../data/models/health_profile.dart';
import '../data/models/health_advisory.dart';
import '../data/models/product_evaluation.dart';
import '../data/models/ranked_product_result.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/group_evaluation.dart';
import '../data/models/health_group.dart' show HealthGroup;
import '../data/repositories/group_repository.dart' show GroupMemberProfile;
import '../core/utils/group_advisory_builder.dart';
import '../data/models/comparison_matrix.dart';
import '../core/constants/who_fda_thresholds.dart';
import '../core/utils/rank_label_helper.dart';
import '../core/utils/who_calculator.dart';
import '../core/utils/fallback_advisory_generator.dart';
import '../core/utils/nutrition_availability.dart';
import '../core/utils/nutrition_calculator.dart';
import '../core/utils/nutri_score_calculator.dart';
import '../core/utils/nova_score_calculator.dart';
import '../core/utils/gerd_trigger_detector.dart';
import '../core/utils/kidney_advisory_facts.dart';
import '../widgets/health_info_warning_card.dart';
import '../widgets/score_badge_strips.dart';
import '../data/services/backend_locator.dart';
import '../data/repositories/product_repository.dart';
import '../data/services/favorites_service.dart';
import '../services/guest_session.dart';
import '../services/guest_favorites_service.dart';
import '../services/feature_access.dart';
import '../widgets/locked_feature_card.dart';
import 'login_screen.dart';

// One selectable health group on the product detail screen. `members` stays
// null until that group's member profiles have been fetched and evaluated.
class _GroupOption {
  _GroupOption(this.group);
  final HealthGroup group;
  List<MemberEvaluation>? members;
  bool get loading => members == null;
}

class _GroupContext {
  const _GroupContext({required this.options, required this.selected});
  final List<_GroupOption>
  options; // every group worth showing (>= 1 other member)
  final _GroupOption selected;
}

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final double confidence;

  // Optional: the full set of products this one is being compared against
  // (populated when navigated from CompareProductsScreen or
  // MultiScanResultsScreen). Must include an entry for `product` itself.
  // When null/omitted, this is a solo scan -- advisory-only, no comparison
  // matrix, matching the original Phase 2 solo flow.
  final List<RankedProductResult>? comparisonSet;
  final Map<String, int>? productCounts;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.confidence = 0.95,
    this.comparisonSet,
    this.productCounts,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isFavorite = false;
  bool _favoriteBusy = false;
  FdaVerificationResult? _fdaResult;
  final _authService = AuthService();

  // Backend-derived health advisory state (WhoCalculator + GeminiAdvisoryService,
  // via ProductRankingService.getProductDetail -- see backend_locator.dart).
  bool _advisoryLoading = true;
  bool? _profileComplete;
  Future<void>? _guestLiveRefresh;
  bool _dismissPersonalizedLock = false;

  // Ensures the full spoken analysis is only auto-announced once per
  // product load -- not on every _refreshVoiceSummary() call (e.g. when
  // the user changes the pack-size dropdown afterward).
  bool _hasAutoAnnouncedSummary = false;
  bool _nutritionUnavailable = false;
  ProductEvaluation? _evaluation;
  HealthAdvisory? _advisory;
  ComparisonMatrix? _comparisonMatrix;
  String? _rankingExplanation;
  UserHealthProfile? _userHealthProfile;

  // Placeholder scan-event id used only for GeminiAdvisoryService's
  // per-scan-event response cache. Once a real scan-session id is threaded
  // through from the camera/multi-scan flow, pass that in instead.
  late String _scanEventId;

  bool _advisoryStarted = false;

  // ── Group mode ────────────────────────────────────────────────────────
  // Group mode is only active when the user's active health group has at
  // least one OTHER member whose profile could be read. Otherwise every
  // field below stays empty and the screen behaves exactly as it always
  // has for a solo user.
  //
  // While group mode is active, `_evaluation` / `_userHealthProfile` hold
  // the SELECTED member's data, so the existing Health Analysis rows
  // (nutrients, allergens) render for whoever is selected without any
  // change to how those rows are built. The banner switches to the group
  // verdict.
  bool _groupChecking = true; // group lookup + group advisory still in flight
  List<MemberEvaluation> _groupMembers =
      const []; // members of the SELECTED group
  String? _selectedMemberKey;
  HealthAdvisory? _groupAdvisory; // for the selected group
  bool _groupAdvisoryLoading =
      false; // true while a just-picked group's text is generated

  // Multi-group: every group of the user that has at least one other
  // member. The selector pill/sheet only appears when there are 2 or more.
  List<_GroupOption> _groupOptions = const [];
  String? _selectedGroupId;
  final Map<String, HealthAdvisory> _groupAdvisoryCache = {};
  // Lets the (possibly open) group sheet rebuild as background group loads
  // finish.
  final ValueNotifier<int> _groupOptionsTick = ValueNotifier<int>(0);

  // The Gemini group text is always written for the product's labeled
  // serving size; any other selected size gets the local rewrite.
  double get _groupAdvisorySizeG =>
      _currentProduct.servingSizeG > 0 ? _currentProduct.servingSizeG : 100.0;

  String _lastGroupPrefKey(String uid) => 'product_detail_last_group_$uid';

  bool get _isGroupMode => _groupMembers.length > 1;

  // Local state for the current product to allow updates from Compare
  late Product _currentProduct;
  List<RankedProductResult>? _currentComparisonSet;

  late double _selectedSizeG;
  late List<double> _availableSizes;
  late String _displayedImageUrl;

  // Toast notification state
  bool _hasShownReportToast = false;
  bool _isReportTooltipVisible = false;
  Timer? _reportToastTimer;

  void _initSizes(Product product) {
    final originalG = product.servingSizeG > 0 ? product.servingSizeG : 100.0;
    final sizeSet = <double>{originalG, ...product.availableSizes};
    _availableSizes = sizeSet.toList()..sort();
    _selectedSizeG = originalG;
    _displayedImageUrl = product.imageUrlForSize(originalG);
  }

  double get _sizeScale {
    final original = _currentProduct.servingSizeG > 0
        ? _currentProduct.servingSizeG
        : 100.0;
    return _selectedSizeG / original;
  }

  @override
  void initState() {
    super.initState();
    LocaleService.localeNotifier.addListener(_onLocaleChanged);
    VoiceAssistantService.setLatestScanProduct(widget.product);
    VoiceAssistantService.activeResultProductNotifier.value = widget.product;
    _currentProduct = widget.product;
    _currentComparisonSet = widget.comparisonSet;
    _scanEventId =
        '${widget.product.id}_${DateTime.now().millisecondsSinceEpoch}';
    _initSizes(_currentProduct);
    if (GuestSession.isGuest.value &&
        BackendLocator.productRepository is FirestoreProductRepository) {
      _guestLiveRefresh = _refreshGuestProductLive();
    }
    if (_authService.currentUser != null &&
        VoiceAssistantService.instance.isEnabled) {
      VoiceAssistantService.instance.announcePage('product_detail');
    }
    _loadFdaVerification();
    _loadFavoriteStatus();
    FavoritesService.favoriteActionNotifier.addListener(
      _handleFavoriteActionChanged,
    );
  }

  void _handleFavoriteActionChanged() {
    if (!mounted) return;
    final map = FavoritesService.favoriteActionNotifier.value;
    if (map.containsKey(_currentProduct.id)) {
      final isFav = map[_currentProduct.id]!;
      if (_isFavorite != isFav) {
        setState(() => _isFavorite = isFav);
      }
    }
  }

  void _onLocaleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Navigates to the report screen for reporting incorrect product information
  void _navigateToReport() {
    _dismissReportTooltip();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const UnknownProductSubmissionScreen(
          capturedImagePath:
              null, // No pre-captured image when reporting from detail screen
        ),
      ),
    );
  }

  /// Shows the toast notification to help users discover the report button
  void _showReportToast() {
    if (_hasShownReportToast || !mounted) return;
    setState(() {
      _hasShownReportToast = true;
      _isReportTooltipVisible = true;
    });

    _reportToastTimer?.cancel();
    _reportToastTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() => _isReportTooltipVisible = false);
      }
    });
  }

  void _dismissReportTooltip() {
    _reportToastTimer?.cancel();
    if (_isReportTooltipVisible && mounted) {
      setState(() => _isReportTooltipVisible = false);
    }
  }

  Widget _buildReportTooltip(double topPadding, AppLocalizations loc) {
    String message = loc.reportButtonToast.replaceAll('🔔 ', '');
    return Positioned(
      top: topPadding + 56 + 4,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 210,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Triangular tip pointing upward, exactly aligned to the Report button center
              // Screen right: 16 padding + 24 favorite + 16 gap + 12 (half of report button) = 68px.
              // Container right is 12px -> 68px - 12px = 56px center -> right = 50px (with 12px tip width).
              Positioned(
                top: -6,
                right: 50,
                child: CustomPaint(
                  size: const Size(12, 6),
                  painter: _TrianglePainter(color: Colors.grey[800]!),
                ),
              ),
              // Speech bubble body
              Container(
                width: 210,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticService().vibrate();
                          _navigateToReport();
                        },
                        child: Text(
                          message,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        HapticService().vibrate();
                        _dismissReportTooltip();
                      },
                      child: const Icon(
                        Icons.close,
                        size: 15,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (VoiceAssistantService.activeResultProductNotifier.value?.id ==
        _currentProduct.id) {
      VoiceAssistantService.activeResultProductNotifier.value = null;
    }
    _reportToastTimer?.cancel();
    FavoritesService.favoriteActionNotifier.removeListener(
      _handleFavoriteActionChanged,
    );
    LocaleService.localeNotifier.removeListener(_onLocaleChanged);
    _groupOptionsTick.dispose();
    super.dispose();
  }

  /// Updates the currently displayed product and reloads all associated data.
  /// Called when returning from Compare with a selected product.
  void _updateProduct(
    Product newProduct,
    List<RankedProductResult>? newComparisonSet,
  ) {
    VoiceAssistantService.setLatestScanProduct(newProduct);
    VoiceAssistantService.activeResultProductNotifier.value = newProduct;
    setState(() {
      _currentProduct = newProduct;
      _currentComparisonSet = newComparisonSet;
      _scanEventId =
          '${newProduct.id}_${DateTime.now().millisecondsSinceEpoch}';
      _initSizes(newProduct);
      _advisoryLoading = true;
      _nutritionUnavailable = false;
      _evaluation = null;
      _advisory = null;
      _comparisonMatrix = null;
      _rankingExplanation = null;
      _fdaResult = null;
      _userHealthProfile = null;
      _groupChecking = true;
      _groupMembers = const [];
      _selectedMemberKey = null;
      _groupAdvisory = null;
      _groupAdvisoryLoading = false;
      _groupOptions = const [];
      _selectedGroupId = null;
      _groupAdvisoryCache.clear();
      _isFavorite = false;
      _hasAutoAnnouncedSummary = false;
      _favoriteBusy =
          true; // Prevent interaction while loading new product's favorite status
    });
    _loadFdaVerification();
    _loadFavoriteStatus();
    _loadAdvisory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_advisoryStarted) {
      _advisoryStarted = true;
      _loadAdvisory();
    }

    // Show report toast notification after a short delay to help users discover the feature
    // Only show it once per screen instance to avoid repetition
    if (!_hasShownReportToast) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _showReportToast();
        }
      });
    }
  }

  Future<void> _loadFdaVerification() async {
    await _guestLiveRefresh;
    // Try verification using CPR number first, fall back to fuzzy match by product name
    FdaVerificationResult result = await FdaVerificationService()
        .verifyByCprNumber(_currentProduct.fdaRegistrationNumber);

    if (result.isUnverified) {
      result = await FdaVerificationService().verifyByProductName(
        _currentProduct.name,
      );
    }

    if (mounted) {
      setState(() => _fdaResult = result);
      _refreshVoiceSummary();
    }
  }

  Future<void> _loadFavoriteStatus() async {
    if (GuestSession.isGuest.value) {
      if (mounted) {
        setState(() {
          _isFavorite = GuestFavoritesService.isFavorite(_currentProduct.id);
          _favoriteBusy = false;
        });
      }
      return;
    }
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _favoriteBusy = false);
      return;
    }

    try {
      final isFav = await BackendLocator.favoritesService.isFavorite(
        userId: uid,
        productId: _currentProduct.id,
      );

      if (mounted) {
        setState(() {
          _isFavorite = isFav;
        });
      }
    } catch (e) {
      debugPrint('Error loading favorite status: $e');
    } finally {
      if (mounted) {
        setState(() {
          _favoriteBusy = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (GuestSession.isGuest.value) {
      if (mounted) {
        setState(
          () => _isFavorite = GuestFavoritesService.toggle(_currentProduct.id),
        );
      }
      return;
    }
    final uid = _authService.currentUser?.uid;
    if (uid == null || _favoriteBusy) return;

    // Optimistic update -- flip the icon immediately so the tap feels
    // responsive, then reconcile with what the repository actually did.
    final previous = _isFavorite;
    final target = !previous;
    setState(() {
      _isFavorite = target;
      _favoriteBusy = true;
    });

    try {
      final newState = await BackendLocator.favoritesService.toggleFavorite(
        userId: uid,
        productId: _currentProduct.id,
        isCurrentlyFavorite: previous,
      );
      if (mounted) {
        setState(() {
          _isFavorite = newState;
          _favoriteBusy = false;
        });
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      // In offline mode, the write is queued in local Firestore cache.
      // Keep the toggled state so the heart stays filled!
      if (mounted) {
        setState(() {
          _isFavorite = target;
          _favoriteBusy = false;
        });
      }
    }
  }

  /// Loads the user's health profile (via UserRepository, which already
  /// maps Firestore's English/Tagalog condition labels onto the backend's
  /// HealthCondition enum -- see firestore_label_mappings.dart) and runs
  /// the real WhoCalculator/GeminiAdvisoryService pipeline for this
  /// product, replacing the old hand-rolled warning strings.
  Future<void> _loadAdvisory() async {
    try {
      await _guestLiveRefresh;
      final uid = _authService.currentUser?.uid;
      final isGuest = GuestSession.isGuest.value;
      final guestProfile = isGuest
          ? const UserHealthProfile(
              userId: 'guest',
              displayName: 'Guest',
              conditions: [],
              allergies: [],
            )
          : null;
      if (uid == null) {
        if (guestProfile != null &&
            NutritionAvailability.isAvailable(_currentProduct)) {
          await _loadSoloAdvisory(profile: guestProfile);
          if (mounted) setState(() => _groupChecking = false);
          return;
        }
        if (mounted) {
          setState(() {
            _advisoryLoading = false;
            _groupChecking = false;
          });
        }
        return;
      }

      _profileComplete = await _authService.hasCompletedOnboarding();

      // WhoCalculator/GeminiAdvisoryService/ProductRankingService assume
      // real nutrition data for every product involved -- a product with no
      // real data (all-zero defaults) would otherwise silently score as
      // "Suitable" and skew ranking/comparison for every product alongside
      // it. Detect that up front and skip the whole pipeline rather than
      // feed it bad data; none of those services themselves are touched.
      if (!NutritionAvailability.isAvailable(_currentProduct)) {
        if (mounted) {
          setState(() {
            _nutritionUnavailable = true;
            _advisoryLoading = false;
            _groupChecking = false;
          });
        }
        return;
      }

      // Group lookup runs alongside the solo pipeline (it never throws --
      // any failure just means "solo"). The solo pipeline still runs for
      // everyone: it produces the primary user's own evaluation plus the
      // comparison matrix / ranking text, none of which are group-specific.
      final groupFuture = _prepareGroups(uid);
      await _loadSoloAdvisory();
      await _finishGroup(groupFuture, uid);
    } catch (e) {
      debugPrint('Error loading health advisory: $e');
      if (mounted) {
        setState(() {
          _advisoryLoading = false;
          _groupChecking = false;
        });
      }
    }
  }

  Future<void> _refreshGuestProductLive() async {
    final repository = BackendLocator.productRepository;
    if (repository is! FirestoreProductRepository) return;

    try {
      final refreshed = _currentProduct.isOfflineFallback
          ? await repository.getProductByYoloLabel(
              _currentProduct.id,
              forceLive: true,
            )
          : await repository.getProductById(
              _currentProduct.id,
              forceLive: true,
            );
      if (!mounted) return;
      setState(() {
        _currentProduct = refreshed;
        _initSizes(refreshed);
      });
    } catch (e) {
      debugPrint('Guest live product refresh failed: $e');
    }
  }

  /// Evaluates the current product against the primary user's own health
  /// profile only.
  Future<void> _loadSoloAdvisory({UserHealthProfile? profile}) async {
    final resolvedProfile =
        profile ??
        await BackendLocator.userRepository.getHealthProfile(
          _authService.currentUser!.uid,
        );

    if (mounted) {
      setState(() => _userHealthProfile = resolvedProfile);
    }

    // Filter comparison set to only include products with available nutrition data
    final validComparisonSet = _currentComparisonSet
        ?.where((r) => NutritionAvailability.isAvailable(r.evaluation.product))
        .toList();

    // If a valid comparisonSet was handed to us (from Compare / multi-scan),
    // use it as-is -- it's already ranked. Otherwise this is a solo
    // scan: rank just this one product so we still get a proper
    // ProductEvaluation out of WhoCalculator.
    List<RankedProductResult> ranked;
    if (validComparisonSet != null && validComparisonSet.length > 1) {
      ranked = validComparisonSet;
    } else {
      ranked = BackendLocator.productRankingService.rankProducts(
        products: [_currentProduct],
        user: resolvedProfile,
      );
    }

    final target = ranked.firstWhere(
      (r) => r.evaluation.product.id == _currentProduct.id,
      orElse: () => ranked.first,
    );

    final languageCode = mounted
        ? Localizations.localeOf(context).languageCode
        : 'en';

    final detail = await BackendLocator.productRankingService.getProductDetail(
      target: target,
      comparisonSet: ranked.length > 1 ? ranked : null,
      user: resolvedProfile,
      scanEventId: _scanEventId,
      languageCode: languageCode,
    );

    if (mounted) {
      setState(() {
        _evaluation = target.evaluation;
        _advisory = detail.advisory;
        _comparisonMatrix = detail.comparisonMatrix;
        _rankingExplanation = detail.rankingExplanation;
        _advisoryLoading = false;
      });
      // Voice summary + auto-announce happen in _finishGroup() so a group
      // user hears the GROUP verdict instead of the solo one.
    }
  }

  /// Refreshes the spoken summary and, once per product, auto-announces it
  /// when the voice assistant is enabled.
  void _finishVoice() {
    if (!mounted) return;
    _refreshVoiceSummary();

    // Auto-speak the full analysis the moment it's ready, so the user
    // doesn't have to say "summarize" to hear it -- only once per
    // product, and only if voice assistant is actually enabled.
    if (!_hasAutoAnnouncedSummary && VoiceAssistantService.instance.isEnabled) {
      _hasAutoAnnouncedSummary = true;
      final summary = VoiceAssistantService.latestScanSummaryNotifier.value;
      if (summary != null && summary.trim().isNotEmpty) {
        unawaited(VoiceAssistantService.instance.speak(summary));
      }
    }
  }

  // ── Group evaluation ────────────────────────────────────────────────

  MemberEvaluation _evaluateMember({
    required String key,
    required String name,
    required String? avatar,
    required bool isSelf,
    required UserHealthProfile profile,
  }) {
    final ranked = BackendLocator.productRankingService.rankProducts(
      products: [_currentProduct],
      user: profile,
    );
    return MemberEvaluation(
      key: key,
      name: name,
      avatar: avatar,
      isSelf: isSelf,
      profile: profile,
      evaluation: ranked.first.evaluation,
    );
  }

  /// Loads and evaluates ONE group's members for the current product
  /// (signed-in user first). Returns null when the group has nobody else
  /// whose profile could be read, or on any failure -- such a group simply
  /// isn't offered, and a user with no such group stays a solo screen.
  Future<List<MemberEvaluation>?> _loadGroupMembers(
    HealthGroup group,
    String uid,
  ) async {
    try {
      final entries = await BackendLocator.groupRepository
          .getGroupMemberProfiles(group.id);
      bool isSelfEntry(GroupMemberProfile e) =>
          e.member.isLinked && e.member.linkedUid == uid;
      if (!entries.any((e) => !isSelfEntry(e))) return null; // nobody else

      final members = <MemberEvaluation>[];
      for (final e in entries) {
        final self = isSelfEntry(e);
        final memberName = e.member.displayName?.trim();
        members.add(
          _evaluateMember(
            // Same identity the profile was fetched under: uid for linked
            // members, member id for managed ones.
            key: e.profile.userId,
            name: (memberName != null && memberName.isNotEmpty)
                ? memberName
                : (e.profile.displayName.isNotEmpty
                      ? e.profile.displayName
                      : 'Member'),
            avatar: e.member.avatar,
            isSelf: self,
            profile: e.profile,
          ),
        );
      }

      // The user's own member record can be missing on older groups (it is
      // created when the owner first opens Group Details). Their own card
      // must always be part of the group view, so add it from their profile.
      if (!members.any((m) => m.isSelf)) {
        final profile = await BackendLocator.userRepository.getHealthProfile(
          uid,
        );
        String? avatar;
        try {
          final doc = await _authService.db.collection('users').doc(uid).get();
          final a = doc.data()?['avatar']?.toString();
          if (a != null && a.isNotEmpty) avatar = a;
        } catch (_) {}
        members.insert(
          0,
          _evaluateMember(
            key: profile.userId,
            name: profile.displayName.isNotEmpty ? profile.displayName : 'Me',
            avatar: avatar,
            isSelf: true,
            profile: profile,
          ),
        );
      }
      return members.length > 1 ? members : null;
    } catch (e) {
      debugPrint('Group ${group.id} skipped: $e');
      return null;
    }
  }

  /// Finds the user's groups and loads the one to show first: the group
  /// they last picked here, else their primary group, else the first one
  /// that has other members. Every other group is only listed (still
  /// loading) and is filled in later by _loadRemainingGroups(). Null means
  /// "stay solo".
  Future<_GroupContext?> _prepareGroups(String uid) async {
    try {
      final repo = BackendLocator.groupRepository;
      final groups = await repo.getGroups(uid);
      if (groups.isEmpty) return null;

      String? lastId;
      try {
        lastId = (await SharedPreferences.getInstance()).getString(
          _lastGroupPrefKey(uid),
        );
      } catch (_) {}
      HealthGroup? primary;
      try {
        primary = await repo.getActiveGroup(uid);
      } catch (_) {}

      int rank(HealthGroup g) =>
          g.id == lastId ? 0 : (g.id == primary?.id ? 1 : 2);
      final ordered = [...groups]
        ..sort((a, b) {
          final r = rank(a).compareTo(rank(b));
          return r != 0 ? r : groups.indexOf(a).compareTo(groups.indexOf(b));
        });

      final options = ordered.map((g) => _GroupOption(g)).toList();
      _GroupOption? selected;
      final dropped = <_GroupOption>[];
      for (final o in options) {
        final members = await _loadGroupMembers(o.group, uid);
        if (members != null) {
          o.members = members;
          selected = o;
          break;
        }
        dropped.add(o); // solo / unreadable group -- not offered
      }
      if (selected == null) return null;
      options.removeWhere(dropped.contains);
      return _GroupContext(options: options, selected: selected);
    } catch (e) {
      debugPrint('Group evaluation skipped: $e');
      return null;
    }
  }

  Future<HealthAdvisory> _generateGroupAdvisory(
    List<MemberEvaluation> members,
  ) {
    final size = _groupAdvisorySizeG;
    final languageCode = mounted
        ? Localizations.localeOf(context).languageCode
        : 'en';
    return BackendLocator.geminiAdvisoryService.generateGroupAdvisory(
      productId: _currentProduct.id,
      productName: _currentProduct.name,
      servingSizeG: size,
      facts: GroupAdvisoryBuilder.buildFacts(members, size),
      languageCode: languageCode,
    );
  }

  Future<void> _finishGroup(Future<_GroupContext?> pending, String uid) async {
    final token = _scanEventId; // detects a product switch mid-load
    final ctx = await pending;
    if (!mounted || token != _scanEventId) return;

    if (ctx == null) {
      setState(() => _groupChecking = false);
      _finishVoice();
      return;
    }

    // Only the group being shown gets a Gemini call.
    final members = ctx.selected.members!;
    final advisory = await _generateGroupAdvisory(members);
    if (!mounted || token != _scanEventId) return;

    final self = members.firstWhere((m) => m.isSelf);
    _groupAdvisoryCache[ctx.selected.group.id] = advisory;
    setState(() {
      _groupOptions = ctx.options;
      _selectedGroupId = ctx.selected.group.id;
      _groupMembers = members;
      _groupAdvisory = advisory;
      _selectedMemberKey = self.key;
      _userHealthProfile = self.profile;
      _evaluation = self.evaluation;
      _groupChecking = false;
    });
    _groupOptionsTick.value++;
    _finishVoice();

    _loadRemainingGroups(ctx, uid, token);
  }

  /// Evaluates the groups that were only listed so far, in parallel and in
  /// the background, so the selector sheet can show each one's verdict. A
  /// group with nobody else in it drops out of the list (and the selector
  /// disappears if that leaves only one group).
  void _loadRemainingGroups(_GroupContext ctx, String uid, String token) {
    for (final o in ctx.options.where((o) => o.loading)) {
      unawaited(() async {
        final members = await _loadGroupMembers(o.group, uid);
        if (!mounted || token != _scanEventId) return;
        setState(() {
          if (members == null) {
            _groupOptions = _groupOptions.where((x) => x != o).toList();
          } else {
            o.members = members;
          }
        });
        _groupOptionsTick.value++;
      }());
    }
  }

  /// Switches the banner + Health Analysis card to another group.
  Future<void> _selectGroup(_GroupOption o) async {
    final members = o.members;
    if (members == null || o.group.id == _selectedGroupId) return;
    HapticService().vibrate();

    final self = members.firstWhere((m) => m.isSelf);
    final cached = _groupAdvisoryCache[o.group.id];
    setState(() {
      _selectedGroupId = o.group.id;
      _groupMembers = members;
      _selectedMemberKey = self.key;
      _userHealthProfile = self.profile;
      _evaluation = self.evaluation;
      _groupAdvisory = cached;
      _groupAdvisoryLoading = cached == null;
    });
    _groupOptionsTick.value++;

    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      SharedPreferences.getInstance()
          .then((p) => p.setString(_lastGroupPrefKey(uid), o.group.id))
          .catchError((_) => false);
    }

    if (cached == null) {
      final token = _scanEventId;
      final advisory = await _generateGroupAdvisory(members);
      if (!mounted || token != _scanEventId) return;
      _groupAdvisoryCache[o.group.id] = advisory;
      if (_selectedGroupId == o.group.id) {
        setState(() {
          _groupAdvisory = advisory;
          _groupAdvisoryLoading = false;
        });
      }
    }
    if (mounted && _selectedGroupId == o.group.id) _refreshVoiceSummary();
  }

  void _selectMember(MemberEvaluation m) {
    if (m.key == _selectedMemberKey) return;
    HapticService().vibrate();
    setState(() {
      _selectedMemberKey = m.key;
      _userHealthProfile = m.profile;
      _evaluation = m.evaluation;
    });
  }

  /// Members ordered for display: most severe first (at the serving size
  /// currently selected), then the signed-in user, then by name.
  List<MemberEvaluation> get _sortedGroupMembers {
    final list = [..._groupMembers];
    list.sort((a, b) {
      final la = GroupAdvisoryBuilder.severity(
        GroupAdvisoryBuilder.levelAt(a.evaluation, _selectedSizeG),
      );
      final lb = GroupAdvisoryBuilder.severity(
        GroupAdvisoryBuilder.levelAt(b.evaluation, _selectedSizeG),
      );
      if (la != lb) return lb.compareTo(la);
      if (a.isSelf != b.isSelf) return a.isSelf ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  AdvisoryLevel get _groupLevel => GroupAdvisoryBuilder.groupLevel(
    _groupMembers.map(
      (m) => GroupAdvisoryBuilder.levelAt(m.evaluation, _selectedSizeG),
    ),
  );

  /// The Gemini group text while the pack size is still the one it was
  /// written for; a deterministic rewrite for any other size (same idea as
  /// _effectiveAdvisory() on the single-user card -- no extra AI call, and
  /// it can never disagree with the levels shown on screen).
  HealthAdvisory? _effectiveGroupAdvisory(BuildContext context) {
    if (_groupAdvisory == null) return null;
    if (_selectedSizeG == _groupAdvisorySizeG) return _groupAdvisory;
    return GroupAdvisoryBuilder.fallback(
      GroupAdvisoryBuilder.buildFacts(_groupMembers, _selectedSizeG),
      servingSizeG: _selectedSizeG,
      languageCode: Localizations.localeOf(context).languageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _currentProduct;
    final topPadding = MediaQuery.of(context).padding.top;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              // ── Header bar: back, Resulta, heart (perfectly centered Stack) ──
              Container(
                color: colorScheme.surface,
                height: topPadding + 56,
                padding: EdgeInsets.only(left: 16, right: 16, top: topPadding),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Centered Title
                    Text(
                      loc.resultsTitle,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                    // Left Back Button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () {
                          HapticService().vibrate();
                          _dismissReportTooltip();
                          Navigator.pop(context);
                        },
                        child: Icon(
                          Icons.arrow_back,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                      ),
                    ),
                    // Right Heart Button + Report Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Report button
                          Semantics(
                            button: true,
                            label: loc.reportProductButton,
                            child: GestureDetector(
                              onTap: () {
                                HapticService().vibrate();
                                _navigateToReport();
                              },
                              child: Icon(
                                Icons.report_problem_outlined,
                                color: colorScheme.onSurfaceVariant,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Favorite button
                          Semantics(
                            button: true,
                            label: _isFavorite
                                ? 'Remove from favorites'
                                : 'Add to favorites',
                            child: GestureDetector(
                              onTap: () {
                                HapticService().vibrate();
                                _toggleFavorite();
                              },
                              child: Icon(
                                _isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: _isFavorite
                                    ? const Color(0xFFD32F2F)
                                    : colorScheme.onSurfaceVariant,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.dividerColor),

              // ── Scrollable content ────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  key: const PageStorageKey<String>('product_detail_scroll'),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),

                      if (p.isOfflineFallback)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.dark
                                  ? const Color(
                                      0xFFE65100,
                                    ).withValues(alpha: 0.15)
                                  : const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.brightness == Brightness.dark
                                    ? const Color(
                                        0xFFFFB74D,
                                      ).withValues(alpha: 0.4)
                                    : const Color(
                                        0xFFFFB74D,
                                      ).withValues(alpha: 0.8),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.wifi_off_rounded,
                                  size: 18,
                                  color: theme.brightness == Brightness.dark
                                      ? const Color(0xFFFFB74D)
                                      : const Color(0xFFE65100),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    loc.offlineBasicRecognitionBanner,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: theme.brightness == Brightness.dark
                                          ? const Color(0xFFFFB74D)
                                          : const Color(0xFFE65100),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ── 1. Main Product Info Card ──────────────────────
                      _buildCard(
                        context: context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Product image (Cloudinary-hosted, via imageURL from
                                // Firestore) with graceful placeholder fallback for
                                // missing/invalid URLs.
                                Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        color: theme.cardColor.withValues(
                                          alpha: 0.5,
                                        ),
                                        child: _displayedImageUrl.isEmpty
                                            ? Icon(
                                                Icons.dining_outlined,
                                                size: 40,
                                                color: colorScheme.outline,
                                              )
                                            : Image.network(
                                                _displayedImageUrl,
                                                key: ValueKey(
                                                  _displayedImageUrl,
                                                ),
                                                width: 80,
                                                height: 80,
                                                fit: BoxFit.cover,
                                                loadingBuilder:
                                                    (context, child, progress) {
                                                      if (progress == null) {
                                                        return child;
                                                      }
                                                      return Center(
                                                        child: SizedBox(
                                                          width: 20,
                                                          height: 20,
                                                          child:
                                                              CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                color:
                                                                    colorScheme
                                                                        .outline,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return Icon(
                                                        Icons.dining_outlined,
                                                        size: 40,
                                                        color:
                                                            colorScheme.outline,
                                                      );
                                                    },
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // ── Size dropdown ──
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: theme.dividerColor,
                                        ),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<double>(
                                          value: _selectedSizeG,
                                          isDense: true,
                                          icon: Icon(
                                            Icons.arrow_drop_down,
                                            size: 18,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurface,
                                          ),
                                          items: _availableSizes.map((size) {
                                            final label =
                                                size == size.roundToDouble()
                                                ? '${size.toInt()}g'
                                                : '${size.toStringAsFixed(1)}g';
                                            return DropdownMenuItem(
                                              value: size,
                                              child: Text(label),
                                            );
                                          }).toList(),
                                          onChanged: (newSize) {
                                            if (newSize != null) {
                                              setState(() {
                                                _selectedSizeG = newSize;
                                                _displayedImageUrl = p
                                                    .imageUrlForSize(newSize);
                                              });
                                              _refreshVoiceSummary();
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.productCounts != null &&
                                                (widget.productCounts![p.id] ??
                                                        1) >
                                                    1
                                            ? '${p.name} (x${widget.productCounts![p.id]})'
                                            : p.name,
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        p.nutritionalFacts.servingSize,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      // FDA badge
                                      _buildFdaBadge(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildScoreBadgePanel(p),
                          ],
                        ),
                      ),

                      // ── FDA Warning Banner (only shown if expired or unverified) ────
                      if (_fdaResult != null && !_fdaResult!.isActive)
                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _fdaResult!.isExpired
                                ? Colors.red.withValues(alpha: 0.1)
                                : Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _fdaResult!.isExpired
                                  ? Colors.red.withValues(alpha: 0.5)
                                  : Colors.amber.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: _fdaResult!.isExpired
                                    ? Colors.red
                                    : Colors.amber[800],
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _fdaResult!.isExpired
                                      ? loc.fdaExpiredWarning
                                      : loc.fdaUnverifiedWarning,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),
                      _buildAdvisoryBanner(context, loc),

                      // Spacers are dropped for whichever of the two cards is
                      // hidden by the GERD-only rule (see _gerdOnlyDetection).
                      if (!_hideAdvisoryForGerdOnly) const SizedBox(height: 12),

                      // ── 3b. GERD Warning card (awareness-only) ────────────────
                      // Positioned above Health Analysis card but below Health Advisory banner
                      // Follows the profile currently driving the Health Analysis card below
                      _buildAwarenessWarningCards(context, loc, p),

                      if (!_isGerdOnlyClean) const SizedBox(height: 12),

                      // ── 3. Batayan ng Pagsusuri (Reminders Box) ───────
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFE5D5C5),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Image.asset(
                                  'assets/images/health.png',
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        loc.analysisBasisTitle,
                                        style: GoogleFonts.outfit(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        loc.analysisBasisSubtitle(
                                          '${_selectedSizeG == _selectedSizeG.roundToDouble() ? _selectedSizeG.toInt().toString() : _selectedSizeG.toStringAsFixed(1)}g',
                                        ),
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.85),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // Group mode: pick whose health profile the rows below
                            // are evaluated for. Solo users keep the original spacing.
                            if (_isGroupMode) ...[
                              const SizedBox(height: 16),
                              _buildMemberSwitcher(context, colorScheme),
                              const Divider(height: 28),
                            ] else
                              ...(() {
                                // Non-group users: the suggested-amount badge
                                // sits in the same spot group members get
                                // theirs (under the header, above the rows).
                                final badge = _buildSuggestedAmountBadge(
                                  context,
                                  colorScheme,
                                );
                                return <Widget>[
                                  if (badge != null) ...[
                                    const SizedBox(height: 16),
                                    badge,
                                  ],
                                  const SizedBox(height: 20),
                                ];
                              })(),

                            if (!p.nutritionalFacts.hasNutritionData)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 18,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        loc.nutritionDataUnavailable,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              // Nutrient + allergy rows, combined into a single
                              // ordered list. Ranking: a direct allergen match is
                              // the strongest signal this card can show -- it's
                              // the one thing that forces the overall verdict to
                              // Caution regardless of any nutrient level (see
                              // `_currentOverallLevel`) -- so it now goes through
                              // the same "user-related comes first" ranking as
                              // the health-condition rows below, instead of
                              // always being pinned to the bottom of the card
                              // regardless of relevance.
                              ...(() {
                                final evals = <DisplayNutrientEval>[
                                  // 1. Sodium (Hypertension)
                                  (() {
                                    final val100g = p.nutritionPer100g.sodiumMg;
                                    final valServing =
                                        (val100g / 100) * _selectedSizeG;
                                    final limit = 2000.0;
                                    final pct = (valServing / limit) * 100;
                                    return DisplayNutrientEval(
                                      label: _sodiumConditionLabel(loc),
                                      shortLabel: loc.bpSodiumShortLabel,
                                      nutrientKey: 'sodiumMg',
                                      valuePerServing: valServing,
                                      limit: limit,
                                      percentage: pct,
                                      level:
                                          WhoCalculator.classifyByWhoPercentage(
                                            pct,
                                          ),
                                      unit: 'mg',
                                    );
                                  })(),
                                  // 2. Sugars (Diabetes)
                                  (() {
                                    final val100g = p.nutritionPer100g.sugarsG;
                                    final valServing =
                                        (val100g / 100) * _selectedSizeG;
                                    final limit = 50.0;
                                    final pct = (valServing / limit) * 100;
                                    return DisplayNutrientEval(
                                      label: loc.diabetesSugarsLabel,
                                      shortLabel: loc.diabetesSugarsShortLabel,
                                      nutrientKey: 'sugarsG',
                                      valuePerServing: valServing,
                                      limit: limit,
                                      percentage: pct,
                                      level:
                                          WhoCalculator.classifyByWhoPercentage(
                                            pct,
                                          ),
                                      unit: 'g',
                                    );
                                  })(),
                                  // 3. Saturated Fats (Heart disease)
                                  (() {
                                    final val100g =
                                        p.nutritionPer100g.saturatedFatG;
                                    final valServing =
                                        (val100g / 100) * _selectedSizeG;
                                    final limit = 22.2;
                                    final pct = (valServing / limit) * 100;
                                    return DisplayNutrientEval(
                                      label: loc.heartSatFatLabel,
                                      shortLabel: loc.heartSatFatShortLabel,
                                      nutrientKey: 'saturatedFatG',
                                      valuePerServing: valServing,
                                      limit: limit,
                                      percentage: pct,
                                      level:
                                          WhoCalculator.classifyByWhoPercentage(
                                            pct,
                                          ),
                                      unit: 'g',
                                    );
                                  })(),
                                  // 4. Trans Fat (Heart disease) -- WHO: < 1% of
                                  // total energy/day (~2.2 g/day on 2,000 kcal).
                                  // Always shown; highlighted only for users
                                  // with heart disease (see
                                  // `_isNutrientKeyRelatedToUser`).
                                  (() {
                                    final val100g =
                                        p.nutritionalFacts.getPer100g(
                                          'transFatG',
                                        ) ??
                                        p.nutritionalFacts.transFatG;
                                    final valServing =
                                        (val100g / 100) * _selectedSizeG;
                                    final limit =
                                        WhoDailyLimits.transFatGPerDay;
                                    final pct = (valServing / limit) * 100;
                                    return DisplayNutrientEval(
                                      label: _heartTransFatLabel(loc),
                                      shortLabel: _transFatShortLabel(loc),
                                      nutrientKey: 'transFatG',
                                      valuePerServing: valServing,
                                      limit: limit,
                                      percentage: pct,
                                      level:
                                          WhoCalculator.classifyByWhoPercentage(
                                            pct,
                                          ),
                                      unit: 'g',
                                    );
                                  })(),
                                  // 5. Protein (Kidney disease only) -- WHO:
                                  // 10-15% of daily energy (~75 g/day on 2,000
                                  // kcal). Only added, and therefore only
                                  // highlighted, for users with kidney disease.
                                  if (_userHealthProfile?.hasKidneyDisease ??
                                      false)
                                    (() {
                                      final val100g =
                                          p.nutritionPer100g.proteinG;
                                      final valServing =
                                          (val100g / 100) * _selectedSizeG;
                                      final limit =
                                          WhoDailyLimits.proteinGPerDay;
                                      final pct = (valServing / limit) * 100;
                                      return DisplayNutrientEval(
                                        label: _kidneyProteinLabel(loc),
                                        shortLabel: _proteinShortLabel(loc),
                                        nutrientKey: 'proteinG',
                                        valuePerServing: valServing,
                                        limit: limit,
                                        percentage: pct,
                                        level:
                                            WhoCalculator.classifyByWhoPercentage(
                                              pct,
                                            ),
                                        unit: 'g',
                                      );
                                    })(),
                                ];

                                // Reorder evaluations based on user's health profile
                                final orderedEvals =
                                    _reorderNutrientEvaluations(evals);

                                // Allergens that are both (a) present in this
                                // product AND (b) saved in the user's own health
                                // profile. `p.allergens` alone is every allergen
                                // the PRODUCT contains, not the ones relevant to
                                // this user; cross-reference against
                                // `_evaluation.allergenAssessment.matchedContains`
                                // (computed by WhoCalculator.assessAllergens
                                // against the signed-in user's saved allergies)
                                // so a user who only lists "milk" doesn't see
                                // unrelated allergens like crustaceans/fish/soy
                                // that simply happen to be in the product.
                                //
                                // -- consolidated into ONE row listing every
                                // matched allergen together, rather than
                                // repeating the full title/badge/note layout per
                                // allergen. With 2+ allergens that per-item
                                // layout stacked duplicate "may cause allergic
                                // reaction" notes and made the card grow
                                // unbounded; grouping them still surfaces every
                                // allergen while keeping the card a fixed height
                                // regardless of how many are detected.
                                final matchedAllergenLabels =
                                    _matchedUserAllergenLabels(
                                      p,
                                      Localizations.localeOf(
                                        context,
                                      ).languageCode,
                                    );

                                return [
                                  if (matchedAllergenLabels.isNotEmpty)
                                    _buildAllergyRow(
                                      matchedAllergenLabels,
                                      colorScheme,
                                      loc,
                                    ),
                                  ...orderedEvals.map(
                                    (e) =>
                                        _buildConditionRow(e, colorScheme, loc),
                                  ),
                                ];
                              })(),

                              // Legend section - How to understand
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(height: 24, thickness: 1),
                                  Text(
                                    loc.howToUnderstandTitle,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildLegendItem(
                                    dotColor: const Color(0xFF2E7D32),
                                    label: loc.suitableLegend,
                                    description: loc.legendSuitableDesc,
                                    colorScheme: colorScheme,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildLegendItem(
                                    dotColor: const Color(0xFFE65100),
                                    label: loc.moderateLegend,
                                    description: loc.legendModerateDesc,
                                    colorScheme: colorScheme,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildLegendItem(
                                    dotColor: const Color(0xFFC62828),
                                    label: loc.cautionLegend,
                                    description: loc.legendCautionDesc,
                                    colorScheme: colorScheme,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      // ── 4. For more details link ──────────────────────────
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 8,
                          bottom: 12,
                          left: 24,
                          right: 24,
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => MoreDetailsScreen(
                                  product: p,
                                  matchedAllergens:
                                      _evaluation
                                          ?.allergenAssessment
                                          .matchedContains ??
                                      const [],
                                  healthProfile: _userHealthProfile,
                                  // Same conditions WhoCalculator.evaluateProduct() iterated
                                  // over for this user (i.e. the ones on their saved health
                                  // profile) -- lets the "How CLARO Calculates" guide only
                                  // badge a nutrient card with a condition the user actually
                                  // has.
                                  userConditions:
                                      _evaluation?.nutrientEvaluations
                                          .map((e) => e.condition)
                                          .toSet()
                                          .toList() ??
                                      const [],
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.keyboard_return_rounded,
                                  size: 20,
                                  color: colorScheme.onSurface,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  loc.forMoreDetails,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurface,
                                    decoration: TextDecoration.underline,
                                    decorationColor: colorScheme.onSurface,
                                    decorationThickness: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── 6. Kabuuang Nutrisyon Card ────────────────────
                      _buildCard(
                        context: context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.totalNutritionTitle,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (!p.nutritionalFacts.hasNutritionData)
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      loc.nutritionDataUnavailable,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              (() {
                                final caloriesVal =
                                    p.nutritionalFacts.caloriesKcal *
                                    _sizeScale;
                                final carbsVal =
                                    p.nutritionalFacts.carbsG * _sizeScale;
                                final proteinVal =
                                    p.nutritionalFacts.proteinG * _sizeScale;
                                final totalFatVal =
                                    p.nutritionalFacts.totalFatG * _sizeScale;
                                final fiberVal =
                                    p.nutritionalFacts.fiberG * _sizeScale;
                                final potassiumVal =
                                    p.nutritionalFacts.potassiumMg * _sizeScale;
                                final calciumVal =
                                    p.nutritionalFacts.calciumMg * _sizeScale;
                                final ironVal =
                                    p.nutritionalFacts.ironMg * _sizeScale;

                                // Only show nutrients with an actual non-zero
                                // value, so the list doesn't pad itself out with
                                // rows reading "0g" / "0mg" for facts the
                                // product simply doesn't have.
                                final entries = <_NutrientEntry>[
                                  _NutrientEntry(
                                    loc.nutriCalories,
                                    caloriesVal,
                                    '${caloriesVal.toStringAsFixed(0)} kcal',
                                  ),
                                  _NutrientEntry(
                                    loc.nutriCarbs,
                                    carbsVal,
                                    '${carbsVal.toStringAsFixed(1)}g',
                                  ),
                                  // Protein is hidden for users with Kidney
                                  // Disease -- it is shown (and highlighted)
                                  // in the Health Analysis card instead.
                                  // Follows the profile currently driving the
                                  // Health Analysis card (the selected member
                                  // in group mode).
                                  if (!(_userHealthProfile?.hasKidneyDisease ??
                                      false))
                                    _NutrientEntry(
                                      loc.nutriProtein,
                                      proteinVal,
                                      '${proteinVal.toStringAsFixed(1)}g',
                                    ),
                                  _NutrientEntry(
                                    loc.nutriTotalFat,
                                    totalFatVal,
                                    '${totalFatVal.toStringAsFixed(1)}g',
                                  ),
                                  _NutrientEntry(
                                    loc.nutriFiber,
                                    fiberVal,
                                    '${fiberVal.toStringAsFixed(1)}g',
                                  ),
                                  _NutrientEntry(
                                    loc.nutriPotassium,
                                    potassiumVal,
                                    '${potassiumVal.toStringAsFixed(0)}mg',
                                  ),
                                  _NutrientEntry(
                                    loc.nutriCalcium,
                                    calciumVal,
                                    '${calciumVal.toStringAsFixed(0)}mg',
                                  ),
                                  _NutrientEntry(
                                    loc.nutriIron,
                                    ironVal,
                                    '${ironVal.toStringAsFixed(1)}mg',
                                  ),
                                ].where((entry) => entry.value != 0).toList();

                                return Column(
                                  children: [
                                    for (int i = 0; i < entries.length; i++)
                                      _nutriListRow(
                                        context,
                                        entries[i].label,
                                        entries[i].formatted,
                                        showDivider: i != entries.length - 1,
                                      ),
                                  ],
                                );
                              })(),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── 7. Scores (Individual White Cards: Nutri-Score & NOVA) ─
                      (() {
                        final langCode = Localizations.localeOf(
                          context,
                        ).languageCode;
                        final nutriResult =
                            NutriScoreCalculator.computeFromProduct(
                              _currentProduct,
                              customServingSizeG: _selectedSizeG,
                            );
                        final novaResult =
                            NovaScoreCalculator.computeFromProduct(
                              _currentProduct,
                            );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                loc.scoresTitle,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            _scoreCard(
                              context: context,
                              label: loc.scoreNutrition,
                              badge: nutriResult.gradeLetter,
                              badgeColor: Color(nutriResult.gradeColorHex),
                              description: nutriResult.description(langCode),
                            ),
                            const SizedBox(height: 8),
                            _scoreCard(
                              context: context,
                              label: loc.scoreProcess,
                              badge: novaResult.groupString,
                              badgeColor: Color(novaResult.colorHex),
                              isCircle: true,
                              description: novaResult.description(langCode),
                            ),
                          ],
                        );
                      })(),

                      const SizedBox(height: 16),

                      // ── 8. Product Ranking Card ─────────────────────────
                      // Only rendered when this product was viewed as part of
                      // a comparison set (Compare button / multi-scan), per
                      // ProductDetailResult.hasComparison.
                      if (_comparisonMatrix != null &&
                          !_comparisonMatrix!.isEmpty)
                        _buildComparisonCard(context, loc),

                      if (_comparisonMatrix != null &&
                          !_comparisonMatrix!.isEmpty)
                        const SizedBox(height: 16),

                      // ── 9. Ihambing Button ─────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () async {
                              _dismissReportTooltip();
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CompareProductsScreen(sourceProduct: p),
                                ),
                              );
                              if (result != null &&
                                  result is Map<String, dynamic>) {
                                final newProduct = result['product'] as Product;
                                final newComparisonSet =
                                    result['comparisonSet']
                                        as List<RankedProductResult>?;
                                _updateProduct(newProduct, newComparisonSet);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              loc.compareButton,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Clean trailing bottom space (no huge excessive spacing)
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isReportTooltipVisible) _buildReportTooltip(topPadding, loc),
        ],
      ),
      floatingActionButton: const VoiceAssistantFab(),
    );
  }

  // Returns true if `nutrientKey` corresponds to one of the conditions
  // saved in the signed-in user's own health profile. Shared by the
  // reordering logic below and by the row builder, so "is this the row
  // tied to the user" can never drift between the two.
  bool _isNutrientKeyRelatedToUser(String nutrientKey) {
    if (_userHealthProfile == null || _userHealthProfile!.conditions.isEmpty) {
      return false;
    }
    for (final condition in _userHealthProfile!.conditions) {
      switch (condition) {
        case HealthCondition.hypertension:
          if (nutrientKey == 'sodiumMg') return true;
          break;
        case HealthCondition.diabetes:
          if (nutrientKey == 'sugarsG') return true;
          break;
        case HealthCondition.heartCondition:
          if (nutrientKey == 'saturatedFatG' || nutrientKey == 'transFatG') {
            return true;
          }
          break;
        case HealthCondition.gerd:
          break;
        case HealthCondition.kidneyDisease:
          if (nutrientKey == 'sodiumMg' || nutrientKey == 'proteinG') {
            return true;
          }
          break;
      }
    }
    return false;
  }

  // Picks the Health Analysis card's sodium row title based on which of
  // the two sodium-relevant conditions (hypertension, kidney disease) the
  // signed-in user actually has on file. Only the LABEL changes here --
  // the nutrient math (val100g/valServing/pct/level above), the
  // `_isNutrientKeyRelatedToUser`/`_reorderNutrientEvaluations` relevance
  // and ordering logic, the highlight styling in `_buildConditionRow`,
  // and every other condition's row are untouched: kidney disease already
  // shares the same `sodiumMg` key as hypertension via
  // `ConditionThresholds.thresholds`, so no new nutrientKey or threshold
  // is introduced, only which title is shown for that existing row.
  //   - Hypertension only (or no conditions on file): "Blood pressure -
  //     Sodium", same text as before this change.
  //   - Kidney disease only: "Kidney Disease - Sodium".
  //   - Both hypertension and kidney disease: "CKD & Blood Pressure -
  //     Sodium".
  String _sodiumConditionLabel(AppLocalizations loc) {
    final List<HealthCondition> conditions =
        _userHealthProfile?.conditions ?? const <HealthCondition>[];
    final hasHypertension = conditions.contains(HealthCondition.hypertension);
    final hasKidneyDisease = conditions.contains(HealthCondition.kidneyDisease);

    if (hasHypertension && hasKidneyDisease) {
      return loc.ckdBpSodiumLabel;
    }
    if (hasKidneyDisease) {
      return loc.kidneySodiumLabel;
    }
    return loc.bpSodiumLabel;
  }

  // Trans fat row titles. There are no localization keys for these yet, so
  // they mirror `heartSatFatLabel` / `heartSatFatShortLabel` ("Heart disease
  // - Saturated fats" / "Saturated fats") for both supported languages.
  String _heartTransFatLabel(AppLocalizations loc) =>
      loc.localeName.startsWith('tl')
      ? 'Sakit sa puso - Trans fats'
      : 'Heart disease - Trans fats';

  String _transFatShortLabel(AppLocalizations loc) => 'Trans fats';

  // Kidney Disease protein row titles, mirroring `kidneySodiumLabel` ("Kidney
  // Disease - Sodium" / "Sakit sa Bato - Sodium").
  String _kidneyProteinLabel(AppLocalizations loc) =>
      loc.localeName.startsWith('tl')
      ? 'Sakit sa Bato - Protein'
      : 'Kidney Disease - Protein';

  String _proteinShortLabel(AppLocalizations loc) => 'Protein';

  // ── Helper method to reorder nutrient evaluations based on user's health profile ──────
  List<DisplayNutrientEval> _reorderNutrientEvaluations(
    List<DisplayNutrientEval> evals,
  ) {
    if (_userHealthProfile == null || _userHealthProfile!.conditions.isEmpty) {
      return evals;
    }

    final relatedEvals = <DisplayNutrientEval>[];
    final unrelatedEvals = <DisplayNutrientEval>[];

    for (final eval in evals) {
      if (_isNutrientKeyRelatedToUser(eval.nutrientKey)) {
        relatedEvals.add(eval);
      } else {
        unrelatedEvals.add(eval);
      }
    }

    // Sort related conditions alphabetically if user has multiple health conditions
    if (relatedEvals.length > 1) {
      relatedEvals.sort((a, b) => a.label.compareTo(b.label));
    }

    // Sort unrelated conditions alphabetically
    if (unrelatedEvals.length > 1) {
      unrelatedEvals.sort((a, b) => a.label.compareTo(b.label));
    }

    // Combine: related first, then unrelated
    return [...relatedEvals, ...unrelatedEvals];
  }

  // Builds a single nutrient row for the Health Analysis card. The row
  // tied to the user's own health profile shows the full
  // "<Condition> - <Nutrient>" title (e.g. "Diabetes - Total sugars") so
  // it's clear *why* it matters to this user; every other row shows just
  // the nutrient name (e.g. "Total sugars") since the condition prefix
  // isn't relevant to them. That same related row also gets a tinted,
  // bordered background and a bolded percentage so it reads as the
  // priority concern rather than one of several equal rows.
  Widget _buildConditionRow(
    DisplayNutrientEval e,
    ColorScheme colorScheme,
    AppLocalizations loc,
  ) {
    final isDark = colorScheme.brightness == Brightness.dark;
    Color progressColor;
    Color badgeBgColor;
    Color badgeTextColor;
    String badgeLabel;

    // badgeBgColor/badgeTextColor are reused for both the small status
    // pill AND (below) the full-width tint on the highlighted/priority
    // row -- previously both stayed at their light-mode pastel/dark-text
    // values even in dark mode, so the priority row's title/percentage
    // text (which uses colorScheme.onSurface, near-white in dark mode)
    // sat on a light background with poor contrast. Swapping in a dark
    // tinted background + lighter accent text in dark mode keeps the
    // same "priority concern" highlighting while staying readable.
    String capitalize(String s) =>
        s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;

    switch (e.level) {
      case AdvisoryLevel.suitable:
        progressColor = const Color(0xFF2E7D32);
        badgeBgColor = isDark
            ? const Color(0xFF1B3320)
            : const Color(0xFFE8F5E9);
        badgeTextColor = isDark
            ? const Color(0xFF81C784)
            : const Color(0xFF2E7D32);
        badgeLabel = capitalize(loc.levelLow);
        break;
      case AdvisoryLevel.moderate:
        progressColor = const Color(0xFFE65100);
        badgeBgColor = isDark
            ? const Color(0xFF3A2A12)
            : const Color(0xFFFFF3E0);
        badgeTextColor = isDark
            ? const Color(0xFFFFB74D)
            : const Color(0xFFE65100);
        badgeLabel = capitalize(loc.levelMedium);
        break;
      case AdvisoryLevel.caution:
        progressColor = const Color(0xFFC62828);
        badgeBgColor = isDark
            ? const Color(0xFF3A1414)
            : const Color(0xFFFFEBEE);
        badgeTextColor = isDark
            ? const Color(0xFFEF9A9A)
            : const Color(0xFFC62828);
        badgeLabel = capitalize(loc.levelHigh);
        break;
    }

    final isRelated = _isNutrientKeyRelatedToUser(e.nutrientKey);
    final displayLabel = isRelated ? e.label : e.shortLabel;
    // colorScheme.primary is a fixed dark maroon -- legible on the light
    // pastel badgeBgColor above, but not on its dark-mode tinted
    // counterpart. colorScheme.secondary is already brightness-aware
    // (a brighter red in dark mode), so use that instead for the bold
    // highlighted percentage when in dark mode.
    final highlightAccentColor = isDark
        ? colorScheme.secondary
        : colorScheme.primary;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                displayLabel,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeLabel,
                style: GoogleFonts.inter(
                  color: badgeTextColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (e.percentage / 100).clamp(0.0, 1.0),
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 12,
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text:
                    '${_formatValue(e.valuePerServing)}${e.unit} / ${_formatValue(e.limit)}${e.unit} ${loc.dailySuffix} · ',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextSpan(
                text:
                    '${e.percentage.toStringAsFixed(0)}% ${e.nutrientKey == 'sugarsG' ? loc.ofWhoFreeSugarReference : loc.ofWhoLimit}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isRelated
                      ? highlightAccentColor
                      : colorScheme.onSurfaceVariant,
                  fontWeight: isRelated ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (!isRelated) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: content,
      );
    }

    // Priority concern: bleed the tint to the full width of the enclosing
    // card and cover the title, progress bar, and percentage text as one
    // unified row -- no border, no inset gap around it.
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: badgeBgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: content,
      ),
    );
  }

  // Builds the Health Analysis card's allergy row for allergens both
  // present in this product and saved in the user's own health profile.
  // A direct allergen match forces the overall verdict to Caution
  // regardless of any nutrient level, so this row always gets the same
  // "priority concern" tinted background as a matched health condition.
  Widget _buildAllergyRow(
    List<String> matchedAllergenLabels,
    ColorScheme colorScheme,
    AppLocalizations loc,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              'Allergy - ${matchedAllergenLabels.join(', ')}',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              loc.allergenDetectedBadge,
              style: GoogleFonts.inter(
                color: const Color(0xFFC62828),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper method to build advisory subtitle with emphasized last sentence ──────
  //
  // For users with health conditions or allergens, the advisory text is always
  // a 3-sentence structure (see fallback_advisory_generator.dart and
  // advisory_prompt_builder.dart). The last sentence is where the "safe
  // serving" recommendation is placed, so bolding/italicizing it is how the
  // recommended intake amount gets visual emphasis without touching the
  // underlying text or calculation.
  //
  // For users with no health conditions and no allergens, the advisory uses
  // sentences too, just fewer of them.
  // Text.rich/Text always soft-wrap within whatever width their parent (an Expanded Column here)
  // gives them, so long translated sentences or long words wrap onto new lines instead of
  // overflowing -- no fixed width/height is applied here, intentionally, so this keeps working
  // regardless of text length or screen size.
  Widget _buildAdvisorySubtitle(
    String subtitle,
    ColorScheme colorScheme,
    AdvisoryLevel level,
  ) {
    final trimmedSubtitle = subtitle.trim();

    // Don't apply emphasis when suitability level is Suitable
    if (level == AdvisoryLevel.suitable) {
      return Text(
        trimmedSubtitle,
        softWrap: true,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: colorScheme.onSurface,
          height: 1.4,
        ),
      );
    }

    final parts = trimmedSubtitle
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }

    // If there's only one part, emphasize it
    if (parts.length == 1) {
      return Text(
        parts.first,
        softWrap: true,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: colorScheme.onSurface,
          height: 1.4,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // Build text spans with emphasis on the last sentence
    final textSpans = <TextSpan>[];

    // Add all sentences except the last one normally
    for (int i = 0; i < parts.length - 1; i++) {
      textSpans.add(
        TextSpan(
          text: '${parts[i]} ',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: colorScheme.onSurface,
            height: 1.4,
          ),
        ),
      );
    }

    // Add the last sentence -- the recommended serving/intake amount --
    // with emphasis (bold and italic, no underline).
    textSpans.add(
      TextSpan(
        text: parts.last,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: colorScheme.onSurface,
          height: 1.4,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        ),
      ),
    );

    return Text.rich(TextSpan(children: textSpans), softWrap: true);
  }

  // ── Health advisory banner (WhoCalculator + GeminiAdvisoryService) ──────
  Widget _buildAdvisoryBanner(
    BuildContext context,
    AppLocalizations loc, {
    bool includePersonalizedLock = true,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (GuestSession.isGuest.value && includePersonalizedLock) {
      return Column(
        children: [
          _buildAdvisoryBanner(context, loc, includePersonalizedLock: false),
          _buildPersonalizedLockCard(context),
        ],
      );
    }

    if (includePersonalizedLock &&
        !useFeatureAccess(
          FeatureKey.personalizedAdvisory,
          isProfileComplete: _profileComplete,
        ).allowed) {
      if (_dismissPersonalizedLock) return const SizedBox.shrink();
      return _buildPersonalizedLockCard(context);
    }

    if (_advisoryLoading || _groupChecking) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(height: 20, child: LinearProgressIndicator()),
      );
    }

    if (_nutritionUnavailable) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              color: colorScheme.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                loc.nutritionDataUnavailable,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Group mode: one verdict for the whole health group (Gemini-written
    // explanation + member avatars). Solo users never reach this.
    if (_isGroupMode) return _buildGroupBanner(context, loc);

    // Known gap fix (UI layer only): a user whose ONLY saved conditions
    // are awareness-only (see HealthConditionKind.isAwarenessOnly) has nothing for
    // WhoCalculator.evaluateProduct to score: `nutrientEvaluations` stays
    // empty, so `evaluation.overallLevel`/`_currentOverallLevel()` falls
    // back to Suitable even though nothing was actually evaluated. That
    // "Suitable" verdict would be misleading here, so this banner is
    // hidden entirely for that case -- the awareness card(s) below (e.g.
    // the GERD Warning card) carry the relevant information instead.
    // Does NOT apply when there's no profile/no conditions at all (that
    // keeps showing today's Suitable banner, unchanged), and does not
    // suppress a direct-allergen Caution, which is independent of
    // condition scoring.
    final profile = _userHealthProfile;
    final hasOnlyAwarenessConditions =
        profile != null &&
        profile.conditions.isNotEmpty &&
        profile.scoredConditions.isEmpty;
    if (hasOnlyAwarenessConditions &&
        !(_evaluation?.allergenAssessment.hasDirectAllergen ?? false)) {
      return const SizedBox.shrink();
    }

    // GERD-only user + detected GERD trigger(s): the GERD Warning card is
    // the only card shown, so the Health Advisory banner is hidden. A direct
    // allergen match still keeps the banner (see _hideAdvisoryForGerdOnly).
    if (_hideAdvisoryForGerdOnly) return const SizedBox.shrink();

    // The backend's `_evaluation.overallLevel` is fixed to the product's
    // labeled serving size (`product.servingSizeG`) -- deliberately, so
    // ranking/comparison across products stays size-independent (see
    // WhoCalculator.evaluateProduct). But on THIS single-product screen,
    // the nutrient rows below already recalculate live against whichever
    // size the user picked in the dropdown, so the verdict badge should
    // agree with them rather than staying frozen on the label size.
    final level = _currentOverallLevel();
    late final Color color;
    late final IconData icon;
    switch (level) {
      case AdvisoryLevel.suitable:
        color = Colors.green;
        icon = Icons.verified_user_outlined;
        break;
      case AdvisoryLevel.moderate:
        color = Colors.amber[800]!;
        icon = Icons.info_outline;
        break;
      case AdvisoryLevel.caution:
        color = Colors.red;
        icon = Icons.warning_amber_rounded;
        break;
    }

    final levelLabel = _levelLabel(level);
    final effectiveAdvisory = _effectiveAdvisory(context);
    final isTagalog = Localizations.localeOf(context).languageCode == 'tl';
    // A GERD-only user with no detected GERD triggers gets the same advisory
    // a user with no health condition gets when the product is Suitable
    // (see _isGerdOnlyClean and _effectiveAdvisory).
    final hasNoConditionsAndNoAllergens =
        ((profile == null || profile.conditions.isEmpty) || _isGerdOnlyClean) &&
        (profile == null || profile.allergies.isEmpty) &&
        !(_evaluation?.allergenAssessment.hasDirectAllergen ?? false);
    final hasNoFlaggedNutrients =
        _evaluation == null ||
        _evaluation!.nutrientEvaluations.every(
          (e) => e.level == AdvisoryLevel.suitable,
        );

    String title;
    if (level == AdvisoryLevel.suitable &&
        hasNoConditionsAndNoAllergens &&
        hasNoFlaggedNutrients) {
      title = isTagalog
          ? '$levelLabel - Walang Minarkahang Nutrient o Sangkap'
          : '$levelLabel - No Flagged Nutrient or Ingredient';
    } else {
      final advisoryTitle =
          effectiveAdvisory?.warningText ??
          (level == AdvisoryLevel.suitable
              ? loc.safeToConsume
              : loc.reminderLabel);

      // Remove decision word from advisoryTitle if it's duplicated at the start
      // This handles cases where AI might include "Caution" in warningText despite instructions
      String cleanAdvisoryTitle = advisoryTitle;
      if (advisoryTitle.toLowerCase().startsWith(levelLabel.toLowerCase()) ||
          advisoryTitle.toLowerCase().startsWith(
            '${levelLabel.toLowerCase()}:',
          )) {
        cleanAdvisoryTitle = advisoryTitle.substring(levelLabel.length).trim();
        if (cleanAdvisoryTitle.startsWith(':') ||
            cleanAdvisoryTitle.startsWith('-')) {
          cleanAdvisoryTitle = cleanAdvisoryTitle.substring(1).trim();
        }
      }

      title = cleanAdvisoryTitle.isEmpty
          ? levelLabel
          : '$levelLabel - $cleanAdvisoryTitle';
    }

    final subtitle =
        effectiveAdvisory?.explanation ?? loc.safeToConsumeSubtitle;

    final currentEvaluation = _evaluation;
    final showKidneyFooterNote =
        currentEvaluation != null &&
        KidneyAdvisoryFacts.build(
              currentEvaluation,
              servingSizeG: _selectedSizeG,
            ) !=
            null;

    // "Multiple allergen detected" variant: only when 2+ of the user's
    // allergens matched this product. Replaces the title/explanation with a
    // list of "Allergen: triggering ingredient" rows.
    final multiAllergenRows = _multiAllergenRows(
      Localizations.localeOf(context).languageCode,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (multiAllergenRows != null) ...[
                  Text(
                    isTagalog ? 'Babala sa Allergen' : 'Allergen Warning',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isTagalog
                        ? 'Maraming allergen ang natukoy'
                        : 'Multiple allergen detected',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final row in multiAllergenRows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text.rich(
                        TextSpan(
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: colorScheme.onSurface,
                            height: 1.4,
                          ),
                          children: [
                            TextSpan(
                              text: row.ingredient.isEmpty
                                  ? row.allergen
                                  : '${row.allergen}: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (row.ingredient.isNotEmpty)
                              TextSpan(text: row.ingredient),
                          ],
                        ),
                      ),
                    ),
                ] else ...[
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildAdvisorySubtitle(subtitle, colorScheme, level),
                ],
                // Kidney Disease footer note -- the same note the removed
                // Kidney Disease Warning card ended with. Only shown while the
                // advisory above is the kidney version (see
                // KidneyAdvisoryFacts.build), so it always refers to the
                // nutrients that advisory just mentioned.
                if (showKidneyFooterNote) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: color.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          loc.kidneyExpertAdvice,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalizedLockCard(BuildContext context) {
    return LockedFeatureCard(
      title: 'Sign in for Personalized Safety Insights',
      subtitle:
          'See if this product is safe for your specific health conditions and allergies.',
      ctaLabel: 'Sign In',
      onCtaPress: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            returnTo: 'product_detail:${_currentProduct.id}',
            returnBuilder: (_) => ProductDetailScreen(product: _currentProduct),
          ),
        ),
      ),
      onNotNow: () => setState(() => _dismissPersonalizedLock = true),
    );
  }

  // Rows for the "Multiple allergen detected" Health Advisory variant, or
  // null when it doesn't apply (fewer than two of the user's allergens
  // matched this product, or group mode). One row per matched allergen, in
  // the order WhoCalculator.assessAllergens produced them, paired with the
  // product ingredient that triggered the match (first letter capitalised,
  // otherwise as written on the label). The ingredient comes only from
  // AllergenAssessment.ingredientSources, so nothing here is guessed.
  List<({String allergen, String ingredient})>? _multiAllergenRows(
    String langCode,
  ) {
    if (_isGroupMode) return null;
    final assessment = _evaluation?.allergenAssessment;
    if (assessment == null || !assessment.hasDirectAllergen) return null;
    if (assessment.matchedContains.length < 2) return null;

    final rows = <({String allergen, String ingredient})>[];
    for (final type in assessment.matchedContains) {
      AllergenIngredientMatch? source;
      for (final m in assessment.ingredientSources) {
        if (m.allergen == type) {
          source = m;
          break;
        }
      }
      final raw = (source?.ingredient ?? '').trim();
      final ingredient = raw.isEmpty
          ? ''
          : raw[0].toUpperCase() + raw.substring(1);
      rows.add((
        allergen: _allergenLabelFor(type, _currentProduct, langCode),
        ingredient: ingredient,
      ));
    }
    return rows;
  }

  // Suggested per-meal amount badge for NON-group users. Rendered at the top
  // of the Health Analysis card (below the header), in the same position and
  // with the same styling/level colour as the per-member badge that group
  // members see in _buildMemberSwitcher, so the card looks the same whether
  // or not the user belongs to a health group. It used to live in the Health
  // Advisory banner; it must not be shown there any more.
  //
  // The amount itself is untouched: it is still `safeServingSize` from the
  // effective advisory, only populated for users with a scored health
  // condition. Visibility mirrors the old banner placement exactly (hidden
  // while loading, when nutrition data is unavailable, when the banner is
  // hidden for awareness-only / GERD-only users, and for users with no
  // conditions and no allergens). Group mode returns null -- group members
  // already get their badge from _buildMemberSwitcher.
  Widget? _buildSuggestedAmountBadge(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    if (_isGroupMode ||
        _advisoryLoading ||
        _groupChecking ||
        _nutritionUnavailable) {
      return null;
    }

    final profile = _userHealthProfile;
    final hasDirectAllergen =
        _evaluation?.allergenAssessment.hasDirectAllergen ?? false;
    final hasOnlyAwarenessConditions =
        profile != null &&
        profile.conditions.isNotEmpty &&
        profile.scoredConditions.isEmpty;
    if (hasOnlyAwarenessConditions && !hasDirectAllergen) return null;
    if (_hideAdvisoryForGerdOnly) return null;

    final hasNoConditionsAndNoAllergens =
        ((profile == null || profile.conditions.isEmpty) || _isGerdOnlyClean) &&
        (profile == null || profile.allergies.isEmpty) &&
        !hasDirectAllergen;

    final suggestedAmount = _effectiveAdvisory(context)?.safeServingSize;
    if (hasNoConditionsAndNoAllergens || suggestedAmount == null) return null;

    final isTagalog = Localizations.localeOf(context).languageCode == 'tl';
    final suggestedAmountText = isTagalog
        ? '$suggestedAmount (para sa hanggang 3 beses na pagkain sa isang araw).'
        : '$suggestedAmount (for up to 3 meals a day).';

    // Same colour source as the group card's badge (_groupLevelColor).
    final color = _groupLevelColor(_currentOverallLevel());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.restaurant_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              suggestedAmountText,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Awareness Warning Cards (GERD) ────────────────────────────────────
  //
  // Only GERD still uses a dedicated warning card. Kidney Disease no longer
  // has one: its sodium/protein WHO percentages and detected phosphate
  // additives are now written into the Health Advisory banner (see
  // KidneyAdvisoryFacts), followed by the consult-an-expert footer note.
  //
  // The card is shown only when the user has GERD *and*
  // GerdTriggerDetector.detect() reports at least one detected trigger for
  // the current product -- whether GERD is the user's only condition or is
  // combined with one or more other conditions. A GERD user whose product
  // has no detected trigger (including when there's simply no
  // ingredient/nutrition data to check) never sees this card.
  Widget _buildAwarenessWarningCards(
    BuildContext context,
    AppLocalizations loc,
    Product p,
  ) {
    final hasGerd = _userHealthProfile?.hasGerd ?? false;
    if (!hasGerd) return const SizedBox.shrink();
    // Show the GERD Warning card only when a trigger is actually detected
    // in the current product. This applies regardless of whether GERD is
    // the user's only condition or combined with others -- a GERD user
    // with no detected trigger should never see the card, and "no
    // ingredient/nutrition data" is not treated as a detected trigger
    // (GerdDetectionResult.hasTriggers is false in that case).
    final detection = GerdTriggerDetector.detect(_currentProduct);
    if (!detection.hasTriggers) return const SizedBox.shrink();
    return _buildGerdWarningCard(context, loc, p);
  }

  // ── GERD-only display rule ────────────────────────────────────────────
  //
  // For a solo user whose ONLY health condition is GERD, exactly one card
  // is shown, depending on what GerdTriggerDetector finds in the product:
  //   - trigger(s) detected -> GERD Warning card only (Health Advisory
  //     card hidden).
  //   - checked, nothing detected -> Health Advisory card only, using the
  //     no-condition Suitable advisory (GERD Warning card hidden).
  // Returns null (rule not applicable, everything renders as before) for
  // group mode, unavailable nutrition data, and any user who has another
  // condition or no GERD.
  GerdDetectionResult? _gerdOnlyDetection() {
    if (_isGroupMode || _nutritionUnavailable) return null;
    final profile = _userHealthProfile;
    if (profile == null || !profile.hasGerd) return null;
    if (profile.conditions.any((c) => c != HealthCondition.gerd)) return null;
    return GerdTriggerDetector.detect(_currentProduct);
  }

  /// GERD-only + trigger(s) detected -> hide the Health Advisory card. A
  /// direct allergen match is independent of GERD, so it keeps the banner.
  bool get _hideAdvisoryForGerdOnly {
    final result = _gerdOnlyDetection();
    if (result == null || !result.hasTriggers) return false;
    return !(_evaluation?.allergenAssessment.hasDirectAllergen ?? false);
  }

  /// GERD-only + product actually checked (ingredient list available) + no
  /// triggers found. When the ingredient list is missing, "nothing detected"
  /// really means "couldn't check", so that case keeps its existing display
  /// (Health Advisory + the GERD card's "not enough information" note).
  bool get _isGerdOnlyClean {
    final result = _gerdOnlyDetection();
    return result != null && !result.hasTriggers && result.hasIngredientData;
  }

  // ── GERD Warning card (awareness-only) ────────────────────────────────
  //
  // Never uses Suitable/Moderate/Caution language and never says a
  // product is unsafe/safe/will-cause-symptoms/should-be-avoided. Shows
  // one of three states:
  //   1. Trigger(s) detected -> lists them; the intro copy explains these
  //      are *potential* triggers and that reactions vary between
  //      individuals.
  //   2. GERD but no triggers detected, and there WAS ingredient or
  //      nutrition data to check -> a neutral "no common triggers
  //      detected" note. Chosen over hiding the card entirely so a GERD
  //      user always sees that the product was actually checked, not
  //      just silently skipped.
  //   3. No ingredient data AND no nutrition data at all -> a neutral
  //      "not enough information" note.
  Widget _buildGerdWarningCard(
    BuildContext context,
    AppLocalizations loc,
    Product p,
  ) {
    final result = GerdTriggerDetector.detect(p);
    final tl = Localizations.localeOf(context).languageCode == 'tl';

    final items = result.triggers
        .map(
          (t) => HealthInfoWarningItem(
            label: _gerdTriggerLabel(t, loc, p.name),
            detail: t.type == GerdTriggerType.highFat
                ? (tl
                      ? '${NumberFormatUtils.formatValue(t.matchedValue!)}g na taba bawat serving'
                      : '${NumberFormatUtils.formatValue(t.matchedValue!)}g fat per serving')
                : t.matchedIngredient,
          ),
        )
        .toList();

    String? neutralMessage;
    if (!result.hasIngredientData) {
      neutralMessage = loc.gerdInsufficientData;
    } else if (!result.hasTriggers) {
      neutralMessage = loc.gerdNoTriggersFound;
    }

    return HealthInfoWarningCard(
      title: loc.gerdWarningTitle,
      icon: Icons.info_outline, // Information icon as requested
      intro: loc.gerdWarningIntro,
      items: items,
      neutralMessage: neutralMessage,
      expertAdvice: loc.gerdExpertAdvice,
    );
  }

  String _gerdTriggerLabel(
    GerdTriggerMatch trigger,
    AppLocalizations loc,
    String productName,
  ) {
    switch (trigger.type) {
      case GerdTriggerType.tomatoAcidic:
        return loc.gerdTriggerTomatoAcidic;
      case GerdTriggerType.spicy:
        // Always use the standard spicy label - the detail shows the actual matched ingredient
        return loc.gerdTriggerSpicy;
      case GerdTriggerType.caffeine:
        return loc.gerdTriggerCaffeine;
      case GerdTriggerType.chocolate:
        return loc.gerdTriggerChocolate;
      case GerdTriggerType.highFat:
        return loc.gerdTriggerHighFat;
    }
  }

  // ── Group mode widgets ───────────────────────────────────────────────

  Color _groupLevelColor(AdvisoryLevel level) {
    switch (level) {
      case AdvisoryLevel.suitable:
        return Colors.green;
      case AdvisoryLevel.moderate:
        return Colors.amber[800]!;
      case AdvisoryLevel.caution:
        return Colors.red;
    }
  }

  String _memberLabel(MemberEvaluation m, bool tl) =>
      m.isSelf ? (tl ? 'Ako' : 'Me') : m.name;

  String _groupConditionName(HealthCondition c, bool tl) {
    switch (c) {
      case HealthCondition.hypertension:
        return tl ? 'Alta-presyon' : 'Hypertension';
      case HealthCondition.diabetes:
        return 'Diabetes';
      case HealthCondition.heartCondition:
        return tl ? 'Sakit sa puso' : 'Heart condition';
      case HealthCondition.gerd:
        return 'GERD';
      case HealthCondition.kidneyDisease:
        return tl ? 'Sakit sa bato' : 'Kidney disease';
    }
  }

  // Member avatar (their chosen image, or initials) with an optional
  // status dot showing their verdict for the product.
  Widget _memberAvatar(
    MemberEvaluation m,
    ColorScheme cs, {
    double size = 32,
    bool showDot = true,
  }) {
    final level = GroupAdvisoryBuilder.levelAt(m.evaluation, _selectedSizeG);
    final trimmed = m.name.trim();
    final initials = trimmed.isEmpty
        ? '?'
        : trimmed.substring(0, 1).toUpperCase();

    Widget initialsCircle() => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: cs.primaryContainer,
      child: Text(
        initials,
        style: GoogleFonts.inter(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: cs.onPrimaryContainer,
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: SizedBox(
            width: size,
            height: size,
            child: m.avatar != null
                ? Image.asset(
                    m.avatar!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => initialsCircle(),
                  )
                : initialsCircle(),
          ),
        ),
        if (showDot)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: size * 0.38,
              height: size * 0.38,
              decoration: BoxDecoration(
                color: _groupLevelColor(level),
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  _GroupOption? get _selectedGroupOption {
    for (final o in _groupOptions) {
      if (o.group.id == _selectedGroupId) return o;
    }
    return null;
  }

  AdvisoryLevel _optionLevel(_GroupOption o) => GroupAdvisoryBuilder.groupLevel(
    (o.members ?? const <MemberEvaluation>[]).map(
      (m) => GroupAdvisoryBuilder.levelAt(m.evaluation, _selectedSizeG),
    ),
  );

  int _optionFlagged(_GroupOption o) =>
      (o.members ?? const <MemberEvaluation>[])
          .where(
            (m) =>
                GroupAdvisoryBuilder.levelAt(m.evaluation, _selectedSizeG) !=
                AdvisoryLevel.suitable,
          )
          .length;

  // Another group that looks WORSE than the one being viewed, so a safe
  // result for one group never hides a problem in another.
  _GroupOption? get _worseOtherGroup {
    final current = _selectedGroupOption;
    if (current == null) return null;
    final currentSeverity = GroupAdvisoryBuilder.severity(
      _optionLevel(current),
    );
    _GroupOption? worst;
    var worstSeverity = currentSeverity;
    for (final o in _groupOptions) {
      if (o == current || o.loading) continue;
      final sev = GroupAdvisoryBuilder.severity(_optionLevel(o));
      if (sev > worstSeverity) {
        worst = o;
        worstSeverity = sev;
      }
    }
    return worst;
  }

  // "Family v" pill at the top of the group banner (opens the group sheet),
  // with a note on the right about other groups.
  Widget _buildGroupSelectorRow(ColorScheme cs, bool tl) {
    final current = _selectedGroupOption;
    final warn = _worseOtherGroup;
    final others = _groupOptions.length - 1;
    final warnColor = warn == null
        ? null
        : _groupLevelColor(_optionLevel(warn));

    return Row(
      children: [
        Semantics(
          button: true,
          label: tl ? 'Pumili ng grupo' : 'Choose group',
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _showGroupSheet,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 190),
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.primary.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      current?.group.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: cs.primary,
                  ),
                  if (warnColor != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: warnColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            warn != null
                ? '${_levelLabel(_optionLevel(warn))} ${tl ? "sa" : "in"} ${warn.group.name}'
                : (tl
                      ? '$others pang grupo'
                      : (others == 1
                            ? '1 other group'
                            : '$others other groups')),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: warn != null ? FontWeight.w700 : FontWeight.w500,
              color: warnColor ?? cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  void _showGroupSheet() {
    HapticService().vibrate();
    final tl = Localizations.localeOf(context).languageCode == 'tl';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: ValueListenableBuilder<int>(
            valueListenable: _groupOptionsTick,
            builder: (ctx, _, _) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tl
                          ? 'Suriin ang produktong ito para sa'
                          : 'Check this product for',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._groupOptions.map(
                      (o) => _buildGroupSheetRow(ctx, o, cs, tl),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildGroupSheetRow(
    BuildContext ctx,
    _GroupOption o,
    ColorScheme cs,
    bool tl,
  ) {
    final isSelected = o.group.id == _selectedGroupId;
    final members = o.members;

    String subtitle;
    Widget trailing;
    if (members == null) {
      subtitle = tl ? 'Sinusuri...' : 'Checking...';
      trailing = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      final total = members.length;
      final flagged = _optionFlagged(o);
      subtitle = flagged == 0
          ? (tl
                ? '$total miyembro, walang naka-flag'
                : '$total members, none flagged')
          : (tl
                ? '$total miyembro, $flagged ang naka-flag'
                : '$total members, $flagged flagged');
      final level = _optionLevel(o);
      final color = _groupLevelColor(level);
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _levelLabel(level),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${o.group.name}, $subtitle',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: members == null
            ? null
            : () {
                Navigator.pop(ctx);
                _selectGroup(o);
              },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? cs.primary.withValues(alpha: 0.08) : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? cs.primary : cs.outlineVariant,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing,
              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_rounded, size: 20, color: cs.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Group verdict banner: replaces the single-user advisory banner when the
  // user's health group has other members.
  Widget _buildGroupBanner(BuildContext context, AppLocalizations loc) {
    final cs = Theme.of(context).colorScheme;
    final tl = Localizations.localeOf(context).languageCode == 'tl';
    final members = _sortedGroupMembers;
    final level = _groupLevel;
    final color = _groupLevelColor(level);
    final icon = switch (level) {
      AdvisoryLevel.suitable => Icons.verified_user_outlined,
      AdvisoryLevel.moderate => Icons.info_outline,
      AdvisoryLevel.caution => Icons.warning_amber_rounded,
    };

    final flaggedCount = members
        .where(
          (m) =>
              GroupAdvisoryBuilder.levelAt(m.evaluation, _selectedSizeG) !=
              AdvisoryLevel.suitable,
        )
        .length;
    final levelLabel = _levelLabel(level);
    final advisory = _effectiveGroupAdvisory(context);

    // Same "<Level> - <headline>" shape as the single-user banner, minus
    // any decision word the AI repeated at the start of the headline.
    var headline = advisory?.warningText.trim() ?? '';
    if (headline.toLowerCase().startsWith(levelLabel.toLowerCase())) {
      headline = headline.substring(levelLabel.length).trim();
      if (headline.startsWith(':') || headline.startsWith('-')) {
        headline = headline.substring(1).trim();
      }
    }
    final title = headline.isEmpty ? levelLabel : '$levelLabel - $headline';

    final caption = flaggedCount == 0
        ? (tl ? 'Walang naka-flag na miyembro' : 'No members flagged')
        : (tl
              ? '$flaggedCount sa ${members.length} miyembro ang naka-flag'
              : '$flaggedCount of ${members.length} members flagged');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Only shown when the user has 2+ groups with other members.
          if (_groupOptions.length > 1) ...[
            _buildGroupSelectorRow(cs, tl),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if (_groupAdvisoryLoading) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(minHeight: 3),
                    ] else if (advisory != null &&
                        advisory.explanation.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _buildAdvisorySubtitle(advisory.explanation, cs, level),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            caption,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: members.map((m) {
                final memberLevel = GroupAdvisoryBuilder.levelAt(
                  m.evaluation,
                  _selectedSizeG,
                );
                return Semantics(
                  button: true,
                  label: '${_memberLabel(m, tl)}, ${_levelLabel(memberLevel)}',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _selectMember(m),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _memberAvatar(m, cs, size: 38),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 56,
                            child: Text(
                              _memberLabel(m, tl),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Member chips + the selected member's summary line, shown at the top of
  // the Health Analysis card in group mode. Everything below it in the card
  // is evaluated for the selected member.
  Widget _buildMemberSwitcher(BuildContext context, ColorScheme cs) {
    final tl = Localizations.localeOf(context).languageCode == 'tl';
    final members = _sortedGroupMembers;
    final selected = _groupMembers.firstWhere(
      (m) => m.key == _selectedMemberKey,
      orElse: () => _groupMembers.first,
    );
    final selectedLevel = GroupAdvisoryBuilder.levelAt(
      selected.evaluation,
      _selectedSizeG,
    );
    final selectedColor = _groupLevelColor(selectedLevel);
    final conditions = selected.profile.conditions.isEmpty
        ? (tl ? 'Walang kondisyon sa kalusugan' : 'No health conditions')
        : selected.profile.conditions
              .map((c) => _groupConditionName(c, tl))
              .join(', ');
    // Suggested per-meal amount for THIS member (null for Suitable members
    // and allergen matches -- see GroupAdvisoryBuilder.memberAmountLine).
    final amountLine = GroupAdvisoryBuilder.memberAmountLine(
      GroupAdvisoryBuilder.memberFacts(selected, _selectedSizeG),
      _selectedSizeG,
      tl: tl,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: members.map((m) {
              final isSel = m.key == selected.key;
              final level = GroupAdvisoryBuilder.levelAt(
                m.evaluation,
                _selectedSizeG,
              );
              return Semantics(
                button: true,
                selected: isSel,
                label: '${_memberLabel(m, tl)}, ${_levelLabel(level)}',
                child: GestureDetector(
                  onTap: () => _selectMember(m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
                    decoration: BoxDecoration(
                      color: isSel
                          ? cs.primary.withValues(alpha: 0.12)
                          : cs.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSel ? cs.primary : cs.outlineVariant,
                        width: isSel ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _memberAvatar(m, cs, size: 24, showDot: false),
                        const SizedBox(width: 6),
                        Text(
                          _memberLabel(m, tl),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSel
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _groupLevelColor(level),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _memberAvatar(selected, cs, size: 40, showDot: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _memberLabel(selected, tl),
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    conditions,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: selectedColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _levelLabel(selectedLevel),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selectedColor,
                ),
              ),
            ),
          ],
        ),
        if (amountLine != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selectedColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.restaurant_outlined, size: 16, color: selectedColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    amountLine,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Nutrient comparison card (ComparisonMatrixBuilder output) ───────────
  Widget _buildComparisonCard(BuildContext context, AppLocalizations loc) {
    final matrix = _comparisonMatrix!;
    final productId = _currentProduct.id;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine rank level label + color based on product's rank -- both
    // come from RankLabelHelper so this title always matches the tag
    // color shown for this same product on the compare/ranking list
    // screen (compare_products_screen.dart).
    final rankLabel = _getRankLevelLabel();
    final rankColor = _getRankLevelColor();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rankLabel,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: rankColor,
            ),
          ),
          if (_rankingExplanation != null) ...[
            const SizedBox(height: 8),
            Text(
              _rankingExplanation!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...matrix.nutrientRows.map((row) {
            final cell = row.cells.firstWhere(
              (c) => c.productId == productId,
              orElse: () => row.cells.first,
            );
            final Color dotColor;
            switch (cell.highlight) {
              case ComparisonHighlight.favorable:
                dotColor = Colors.green;
                break;
              case ComparisonHighlight.unfavorable:
                dotColor = Colors.red;
                break;
              case ComparisonHighlight.neutral:
                dotColor = Colors.grey;
                break;
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row.nutrient.displayLabel,
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ),
                  Text(
                    '${cell.value.toStringAsFixed(1)}${row.nutrient.unit} / 100g',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
          // Only show an allergen warning here if WhoCalculator.assessAllergens
          // actually confirmed it via ingredient-text evidence for THIS
          // product (_evaluation.allergenAssessment.matchedContains) --
          // the exact same set the Health Advisory, Health Analysis, and
          // Ingredients cards already use. Previously this trusted
          // matrix.allergenRows' presence check alone, which only looks at
          // the product's raw declared-allergen label (product.containsAllergens)
          // with no ingredient evidence required -- so a product whose label
          // lists an allergen the ingredient list doesn't actually support
          // showed a warning here while every other card on the same screen
          // correctly stayed silent about it.
          for (final row in matrix.allergenRows)
            if ((_evaluation?.allergenAssessment.matchedContains.contains(
                      row.allergen,
                    ) ??
                    false) &&
                row.cells.any(
                  (c) =>
                      c.productId == productId &&
                      c.presence != AllergenPresence.none,
                ))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      row.allergen.displayLabel,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  String _levelLabel(AdvisoryLevel level) {
    switch (level) {
      case AdvisoryLevel.suitable:
        return 'Suitable';
      case AdvisoryLevel.moderate:
        return 'Moderate';
      case AdvisoryLevel.caution:
        return 'Caution';
    }
  }

  // Both label and color are delegated to RankLabelHelper
  // (core/utils/rank_label_helper.dart) -- the single source of truth
  // shared with compare_products_screen.dart's list-card tags, so the
  // title here always matches that tag's text and color for the same
  // product.
  String _getRankLevelLabel() {
    final comparisonSet = _currentComparisonSet ?? widget.comparisonSet;
    if (comparisonSet == null || comparisonSet.isEmpty) {
      return 'Product Ranking';
    }

    final currentProduct = comparisonSet.firstWhere(
      (r) => r.evaluation.product.id == _currentProduct.id,
      orElse: () => comparisonSet.first,
    );

    return RankLabelHelper.label(
      rank: currentProduct.rank,
      totalProducts: comparisonSet.length,
      suitabilityRankLabel: currentProduct.suitabilityRankLabel,
      includeChoiceSuffix: true,
    );
  }

  Color _getRankLevelColor() {
    final comparisonSet = _currentComparisonSet ?? widget.comparisonSet;
    if (comparisonSet == null || comparisonSet.isEmpty) {
      return Colors.green;
    }

    final currentProduct = comparisonSet.firstWhere(
      (r) => r.evaluation.product.id == _currentProduct.id,
      orElse: () => comparisonSet.first,
    );

    return RankLabelHelper.color(
      rank: currentProduct.rank,
      totalProducts: comparisonSet.length,
      suitabilityRankLabel: currentProduct.suitabilityRankLabel,
    );
  }

  // ── Helper card builder to make cards completely uniform ────────────────
  Widget _buildCard({required BuildContext context, required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── Nutritional linear list row ───────────────────────────────────────
  // The nutrient label carries the primary visual weight (what it is);
  // the value is secondary (how much). This intentionally reverses the
  // old grid-card hierarchy, where the value was bold and the label was
  // small and gray -- for a list read top-to-bottom, the label is what
  // the eye should anchor on first.
  Widget _nutriListRow(
    BuildContext context,
    String label,
    String value, {
    bool showDivider = true,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: theme.dividerColor.withValues(alpha: 0.5),
          ),
      ],
    );
  }

  Widget _buildScoreBadgePanel(Product product) {
    final nutriResult = NutriScoreCalculator.computeFromProduct(
      product,
      customServingSizeG: _selectedSizeG,
    );
    final novaResult = NovaScoreCalculator.computeFromProduct(product);

    return ScoreBadgePanel(
      nutriGrade: nutriResult.gradeLetter,
      novaGroup: novaResult.groupString,
      nutriColor: Color(nutriResult.gradeColorHex),
      novaColor: Color(novaResult.colorHex),
    );
  }

  // ── Individual white score card (matches the style of scores section) ────
  Widget _scoreCard({
    required BuildContext context,
    required String label,
    required String badge,
    required Color badgeColor,
    required String description,
    bool isCircle = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Badge indicator block
          Column(
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: isCircle ? null : BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    badge,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Description text
          Expanded(
            child: Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFdaBadge() {
    final fda = _fdaResult;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // CPR/validity/manufacturer text below was hardcoded to black45,
    // which is unreadable against the dark card background -- switch to
    // white in dark mode while keeping the original black45 in light mode.
    final fdaMetaColor = isDark ? Colors.white : Colors.black45;
    if (fda == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const SizedBox(
          width: 60,
          height: 14,
          child: LinearProgressIndicator(),
        ),
      );
    }

    Color badgeColor;
    IconData badgeIcon;
    String badgeText;

    switch (fda.status) {
      case FdaStatus.active:
        badgeColor = const Color(0xFF2E7D32);
        badgeIcon = Icons.verified;
        badgeText = 'FDA ACTIVE';
        break;
      case FdaStatus.expired:
        badgeColor = const Color(0xFFC62828);
        badgeIcon = Icons.warning_amber_rounded;
        badgeText = 'FDA EXPIRED';
        break;
      case FdaStatus.unverified:
        badgeColor = const Color(0xFFF57F17);
        badgeIcon = Icons.help_outline;
        badgeText = 'UNVERIFIED';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(badgeIcon, color: Colors.white, size: 13),
              const SizedBox(width: 4),
              Text(
                badgeText,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (fda.cprNumber.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'CPR: ${fda.cprNumber}',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: fdaMetaColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (fda.validityDate.isNotEmpty)
            Text(
              'Valid until: ${fda.validityDate}',
              style: GoogleFonts.inter(fontSize: 10, color: fdaMetaColor),
            ),
          if (fda.manufacturer.isNotEmpty)
            Text(
              fda.manufacturer,
              style: GoogleFonts.inter(fontSize: 10, color: fdaMetaColor),
            ),
        ],
      ],
    );
  }

  // Returns a display label for every allergen in
  // `_evaluation.allergenAssessment.matchedContains` -- the exact set the
  // Health Advisory banner already uses (via WhoCalculator.assessAllergens),
  // which matches BOTH allergens explicitly listed in `product.allergens`
  // AND allergens only detected by scanning ingredient text (e.g. an
  // ingredient like "whey powder" flags dairy even if "milk"/"dairy" isn't
  // itself one of the product's listed allergens). Iterating
  // `matchedContains` directly (instead of trying to map it back onto
  // `product.allergens`) is what fixes ingredient-only matches silently
  // being dropped from this card while still showing up correctly in the
  // Health Advisory banner.
  //
  // Prefers the product's own (possibly localized) allergen string when
  // one exists in `product.allergens` for that type; falls back to the
  // generic `AllergenTypeDisplay.displayLabel` (same one comparison
  // screens use) for ingredient-only matches that have no such entry.
  List<String> _matchedUserAllergenLabels(Product product, String langCode) {
    final matchedTypes = _evaluation?.allergenAssessment.matchedContains;
    if (matchedTypes == null || matchedTypes.isEmpty) return const [];

    final labels = <String>[];
    for (final type in matchedTypes) {
      final label = _allergenLabelFor(type, product, langCode);
      if (!labels.contains(label)) labels.add(label);
    }
    return labels;
  }

  // Display label for one allergen type: the product's own (possibly
  // localized) allergen string when it lists that type, otherwise the generic
  // `AllergenTypeDisplay.displayLabel`.
  String _allergenLabelFor(
    AllergenType type,
    Product product,
    String langCode,
  ) {
    final rawIndex = product.containsAllergens.indexOf(type);
    return rawIndex != -1
        ? _getAllergenName(product.allergens[rawIndex], langCode)
        : type.displayLabel;
  }

  String _buildVoiceSummary(
    BuildContext context,
    ProductEvaluation evaluation,
  ) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final allergenLabels = _matchedUserAllergenLabels(
      _currentProduct,
      languageCode,
    );
    final advisory = _effectiveAdvisory(context);
    final verdict = switch (_currentOverallLevel()) {
      AdvisoryLevel.suitable => 'Suitable',
      AdvisoryLevel.moderate => 'Moderate',
      AdvisoryLevel.caution => 'Caution',
    };
    final flaggedNutrients = <String>[];
    for (final nutrient in evaluation.nutrientEvaluations) {
      if (nutrient.level == AdvisoryLevel.suitable) continue;
      final label = _voiceNutrientLabel(nutrient.nutrientKey);
      if (!flaggedNutrients.contains(label)) {
        flaggedNutrients.add(label);
      }
    }

    final sections = <String>[];
    if (allergenLabels.isNotEmpty && !_isGroupMode) {
      sections.add('Allergen warning: ${allergenLabels.join(', ')}.');
    }

    sections.add(
      'Product: ${_currentProduct.name}, size ${_selectedSizeG.toStringAsFixed(0)} grams.',
    );
    if (_isGroupMode) {
      final groupAdvisory = _effectiveGroupAdvisory(context);
      final flaggedCount = _groupMembers
          .where(
            (m) =>
                GroupAdvisoryBuilder.levelAt(m.evaluation, _selectedSizeG) !=
                AdvisoryLevel.suitable,
          )
          .length;
      final groupName = _groupOptions.length > 1
          ? _selectedGroupOption?.group.name
          : null;
      final groupLabel = groupName == null
          ? 'Group verdict'
          : 'Group $groupName verdict';
      sections.add(
        '$groupLabel: ${_levelLabel(_groupLevel)}. '
        '$flaggedCount of ${_groupMembers.length} members flagged.',
      );
      if (groupAdvisory != null) {
        if (groupAdvisory.warningText.trim().isNotEmpty) {
          sections.add('${groupAdvisory.warningText.trim()}.');
        }
        if (groupAdvisory.explanation.trim().isNotEmpty) {
          sections.add(groupAdvisory.explanation.trim());
        }
      }
    } else {
      sections.add('Overall verdict: $verdict.');

      if (advisory != null) {
        if (advisory.warningText.trim().isNotEmpty) {
          sections.add(advisory.warningText.trim());
        }
        if (advisory.explanation.trim().isNotEmpty) {
          sections.add(advisory.explanation.trim());
        }
      }
    }

    if (flaggedNutrients.isNotEmpty && !_isGroupMode) {
      sections.add(
        'Nutrients driving this verdict: ${flaggedNutrients.join(', ')}.',
      );
    }

    final fda = _fdaResult;
    if (fda != null) {
      sections.add(
        fda.isActive
            ? 'FDA status: active.'
            : fda.isExpired
            ? 'FDA status: expired.'
            : 'FDA status: unverified.',
      );
    }

    final comparisonSet = _currentComparisonSet;
    if (comparisonSet != null && comparisonSet.isNotEmpty) {
      final currentRank = comparisonSet.firstWhere(
        (item) => item.evaluation.product.id == _currentProduct.id,
        orElse: () => comparisonSet.first,
      );
      final rankLabel = RankLabelHelper.label(
        rank: currentRank.rank,
        totalProducts: comparisonSet.length,
        suitabilityRankLabel: currentRank.suitabilityRankLabel,
      );
      if (_rankingExplanation != null &&
          _rankingExplanation!.trim().isNotEmpty) {
        sections.add(
          'Comparison ranking: $rankLabel. ${_rankingExplanation!.trim()}',
        );
      } else {
        sections.add('Comparison ranking: $rankLabel.');
      }
    }

    return sections.join(' ');
  }

  void _refreshVoiceSummary() {
    final evaluation = _evaluation;
    if (!mounted || evaluation == null) return;
    VoiceAssistantService.setLatestScanSummary(
      _buildVoiceSummary(context, evaluation),
    );
  }

  String _voiceNutrientLabel(String nutrientKey) {
    switch (nutrientKey) {
      case 'sodiumMg':
        return 'sodium';
      case 'sugarsG':
        return 'sugar';
      case 'saturatedFatG':
        return 'saturated fat';
      default:
        return nutrientKey;
    }
  }

  // Re-derives the overall advisory level (the badge on this screen) for
  // whichever pack size the user currently has selected in the dropdown,
  // instead of the backend's fixed-label-serving-size `overallLevel`.
  //
  // Deliberately reuses `_evaluation.nutrientEvaluations` -- the exact set
  // of nutrients WhoCalculator.evaluateProduct() already evaluated for
  // THIS user's saved health conditions -- so this stays in sync with
  // whatever conditions the user actually has, rather than hardcoding a
  // fixed nutrient list. Only the per-serving math is redone here, against
  // `_selectedSizeG` in place of the product's label serving size; the
  // WHO daily limits and classification thresholds come from the same
  // WhoCalculator functions the backend used, so this can't drift out of
  // sync with the server-side thresholds.
  //
  // Ranking/comparison screens are untouched -- they always call
  // WhoCalculator.rankProducts/evaluateProduct directly, which keeps using
  // the label serving size on purpose (see WhoCalculator comments), so a
  // product's rank never changes just because someone viewed it here with
  // a different size selected.
  AdvisoryLevel _currentOverallLevel() {
    final evaluation = _evaluation;
    if (evaluation == null) return AdvisoryLevel.suitable;

    // Allergen match doesn't scale with pack size -- keep the backend's
    // hard override as-is.
    if (evaluation.allergenAssessment.hasDirectAllergen) {
      return AdvisoryLevel.caution;
    }

    var worst = evaluation.scoredFactors.fold<AdvisoryLevel>(
      AdvisoryLevel.suitable,
      (current, factor) => _worseLevel(current, factor.level),
    );
    for (final nutrientEval in evaluation.nutrientEvaluations) {
      final valuePerServing =
          (nutrientEval.valuePer100g / 100) * _selectedSizeG;
      final whoDailyLimit = WhoCalculator.getWhoDailyLimit(
        nutrientEval.nutrientKey,
      );
      final whoPercentage = (valuePerServing / whoDailyLimit) * 100;
      final level = WhoCalculator.classifyByWhoPercentage(whoPercentage);
      worst = _worseLevel(worst, level);
    }
    return worst;
  }

  AdvisoryLevel _worseLevel(AdvisoryLevel first, AdvisoryLevel second) {
    if (first == AdvisoryLevel.caution || second == AdvisoryLevel.caution) {
      return AdvisoryLevel.caution;
    }
    if (first == AdvisoryLevel.moderate || second == AdvisoryLevel.moderate) {
      return AdvisoryLevel.moderate;
    }
    return AdvisoryLevel.suitable;
  }

  // Returns the advisory text (title + explanation) to show alongside the
  // verdict badge, kept consistent with `_currentOverallLevel()`:
  //
  // - While the dropdown is still on the product's original label serving
  //   size, this is just `_advisory` unchanged -- the Gemini-written text
  //   fetched once in `_loadAdvisory()`, since nothing has been recomputed
  //   yet and it already matches that level.
  // - Once the user picks a DIFFERENT size, `_advisory` (written for the
  //   label size) would silently go stale, so this regenerates the text
  //   locally via FallbackAdvisoryGenerator using the same scaled
  //   nutrient math as `_currentOverallLevel()` -- deterministic, free
  //   (no AI call), and guaranteed to agree with the badge because both
  //   are derived from the same WhoCalculator functions. Less nuanced
  //   than the AI phrasing, but always accurate to what's on screen.
  HealthAdvisory? _effectiveAdvisory(BuildContext context) {
    final evaluation = _evaluation;
    if (evaluation == null) return _advisory;

    // GERD-only user with no detected GERD triggers: `_advisory` was written
    // for a user WITH a condition, so build the same no-condition Suitable
    // advisory instead (deterministic, no AI call -- the same template
    // GeminiAdvisoryService uses for a Suitable product). A direct allergen
    // match keeps the normal allergen advisory.
    final useNoConditionAdvisory =
        _isGerdOnlyClean && !evaluation.allergenAssessment.hasDirectAllergen;

    final labelServingSizeG = evaluation.product.servingSizeG;
    if (_selectedSizeG == labelServingSizeG && !useNoConditionAdvisory) {
      return _advisory;
    }

    // Use combined nutrient calculation for users without health conditions
    final conditionsEmpty =
        (_userHealthProfile?.conditions.isEmpty ?? false) ||
        useNoConditionAdvisory;
    final useCombinedNutrients = conditionsEmpty;
    final hasNoConditionsAndNoAllergens =
        conditionsEmpty && !evaluation.allergenAssessment.hasDirectAllergen;

    return FallbackAdvisoryGenerator.generate(
      evaluation,
      reason: FallbackReason.notNeeded,
      languageCode: Localizations.localeOf(context).languageCode,
      servingSizeGOverride: _selectedSizeG,
      useCombinedNutrients: useCombinedNutrients,
      hasNoConditionsAndNoAllergens: hasNoConditionsAndNoAllergens,
    );
  }

  String _getAllergenName(String allergen, String languageCode) {
    final norm = allergen.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (languageCode == 'tl') {
      switch (norm) {
        case 'fish':
        case 'isda':
          return 'Isda';
        case 'milk':
        case 'gatas':
          return 'Gatas';
        case 'egg':
        case 'itlog':
          return 'Itlog';
        case 'soy':
        case 'soya':
        case 'soybean':
          return 'Soya';
        case 'wheat':
        case 'trigo':
          return 'Wheat';
        case 'shellfish':
        case 'lamangdagat':
        case 'lamang-dagat':
          return 'Lamang-Dagat';
        case 'peanut':
        case 'mani':
          return 'Mani';
        default:
          return allergen;
      }
    } else {
      switch (norm) {
        case 'fish':
        case 'isda':
          return 'Fish';
        case 'milk':
        case 'gatas':
          return 'Milk';
        case 'egg':
        case 'itlog':
          return 'Egg';
        case 'soy':
        case 'soya':
        case 'soybean':
          return 'Soy';
        case 'wheat':
        case 'trigo':
          return 'Wheat';
        case 'shellfish':
        case 'lamangdagat':
        case 'lamang-dagat':
          return 'Shellfish';
        case 'peanut':
        case 'mani':
          return 'Peanut';
        default:
          return allergen;
      }
    }
  }

  String _formatValue(double value) {
    return NumberFormatUtils.formatValue(value);
  }

  Widget _buildLegendItem({
    required Color dotColor,
    required String label,
    required String description,
    required ColorScheme colorScheme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 8),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                TextSpan(
                  text: description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Pairs a Total Nutrition row's label with its raw scaled value (used to
// decide whether to show the row at all) and its pre-formatted display
// string (used to render it).
class _NutrientEntry {
  final String label;
  final double value;
  final String formatted;

  _NutrientEntry(this.label, this.value, this.formatted);
}

class DisplayNutrientEval {
  final String label;
  final String shortLabel;
  final String nutrientKey;
  final double valuePerServing;
  final double limit;
  final double percentage;
  final AdvisoryLevel level;
  final String unit;

  DisplayNutrientEval({
    required this.label,
    required this.shortLabel,
    required this.nutrientKey,
    required this.valuePerServing,
    required this.limit,
    required this.percentage,
    required this.level,
    required this.unit,
  });
}

// Custom painter for the triangular tip of the speech bubble
class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0) // Top center point
      ..lineTo(0, size.height) // Bottom left
      ..lineTo(size.width, size.height) // Bottom right
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
