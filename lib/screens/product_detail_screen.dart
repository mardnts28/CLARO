import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product_model.dart';
import '../services/fda_verification_service.dart';
import '../services/auth_service.dart';
import 'camera_scanner_screen.dart';
import 'compare_products_screen.dart';
import 'history_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final double confidence;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.confidence = 0.95,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isFavorite = false;
  FdaVerificationResult? _fdaResult;
  final _authService = AuthService();
  List<String> _personalWarnings = [];

  @override
  void initState() {
    super.initState();
    _loadFdaVerification();
    _loadUserHealthProfile();
  }

  Future<void> _loadFdaVerification() async {
    // Try verification using CPR number first, fall back to fuzzy match by product name
    FdaVerificationResult result = await FdaVerificationService()
        .verifyByCprNumber(widget.product.fdaRegistrationNumber);
    
    if (result.isUnverified) {
      result = await FdaVerificationService()
          .verifyByProductName(widget.product.name);
    }

    if (mounted) {
      setState(() => _fdaResult = result);
    }
  }

  Future<void> _loadUserHealthProfile() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) return;
      final doc = await _authService.db.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null) return;

      final conditions = (data['conditions'] as List<dynamic>?)?.cast<String>() ?? [];
      final allergens = (data['allergens'] as List<dynamic>?)?.cast<String>() ?? [];

      final warnings = <String>[];
      final p = widget.product;

      // Check allergen matches
      for (final userAllergen in allergens) {
        for (final productAllergen in p.allergens) {
          if (productAllergen.toLowerCase().contains(userAllergen.toLowerCase()) ||
              userAllergen.toLowerCase().contains(productAllergen.toLowerCase())) {
            warnings.add('⚠️ May $productAllergen ka na allergen – naglalaman ang produktong ito nito.');
          }
        }
      }

      // Check condition-based warnings
      if (conditions.contains('Diabetes')) {
        final sugar = p.nutritionalFacts.sugars;
        if (p.nutritionalFacts.sugarsG > 0) {
          warnings.add('⚠️ May diabetes ka – suriin ang sugar content ($sugar) ng produktong ito.');
        }
      }
      if (conditions.contains('Alta-presyon')) {
        final sodium = p.nutritionalFacts.sodium;
        if (p.nutritionalFacts.sodiumMg > 0) {
          warnings.add('⚠️ May alta-presyon ka – suriin ang sodium content ($sodium) ng produktong ito.');
        }
      }
      if (conditions.contains('Sakit sa puso')) {
        final fat = p.nutritionalFacts.totalFat;
        if (p.nutritionalFacts.totalFatG > 0) {
          warnings.add('⚠️ May sakit sa puso ka – suriin ang fat content ($fat) ng produktong ito.');
        }
      }

      if (mounted) {
        setState(() {
          _personalWarnings = warnings;
        });
      }
    } catch (e) {
      debugPrint('Error loading health profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final hasAllergens = p.allergens.isNotEmpty;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Header bar: back, Resulta, heart (perfectly centered Stack) ──
          Container(
            color: Colors.white,
            height: topPadding + 56,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: topPadding,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Centered Title
                Text(
                  'Resulta',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8B1A1A),
                  ),
                ),
                // Left Back Button
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back,
                        color: Color(0xFF8B1A1A), size: 24),
                  ),
                ),
                // Right Heart Button
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => setState(() => _isFavorite = !_isFavorite),
                    child: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: const Color(0xFFB71C1C),
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE0E0E0)),

          // ── Scrollable content ────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),

                  // ── 1. Main Product Info Card ──────────────────────
                  _buildCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product image placeholder
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.dining_outlined,
                              size: 40, color: Color(0xFFBDBDBD)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                p.nutritionalFacts.servingSize,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.black54,
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
                  ),

                  // ── FDA Warning Banner (only shown if expired or unverified) ────
                  if (_fdaResult != null && !_fdaResult!.isActive)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _fdaResult!.isExpired
                            ? const Color(0xFFFFEBEE)
                            : const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _fdaResult!.isExpired
                              ? const Color(0xFFEF9A9A)
                              : const Color(0xFFFFCC02),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: _fdaResult!.isExpired ? Colors.red : Colors.amber[800],
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _fdaResult!.isExpired
                                  ? 'BABALA: Ang produktong ito ay may EXPIRED na FDA registration. Maaaring hindi ito ligtas.'
                                  : 'Ang produktong ito ay hindi pa nabeberipika ng FDA Philippines.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── 2. Age recommendation and LIGTAS I-KONSUMO ──────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '3+ yrs old',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF4CAF50), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.verified_user_outlined,
                            color: Color(0xFF2E7D32), size: 36),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LIGTAS I-KONSUMO',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2E7D32),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Pinakamainam kainin sa katamtamang dami dahil mas mataas sa taba at calories.',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── 3. Paalala Card ────────────────────────────────
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paalala',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Green checkmark notice
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check,
                                color: Color(0xFF4CAF50), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Angkop para sa mga may diabetes, ngunit ang madalas na pagkonsumo ay maaaring hindi mainam para sa mga nagkokontrol ng kolesterol o calorie intake.',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF2E7D32),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Allergen warning (red)
                        if (hasAllergens) ...[
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: Colors.redAccent, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Naglalaman ng ${p.allergens.join(', ')}',
                                  style: GoogleFonts.inter(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // ── Personalized Health Warnings ──
                        if (_personalWarnings.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFF9800), width: 1.2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '🩺 Babala Batay sa Iyong Kalusugan',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFE65100),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ..._personalWarnings.map((w) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    w,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFFBF360C),
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                )),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),

                        // Serving recommendation box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFF4CAF50), width: 1.2),
                          ),
                          child: Text(
                            '½–¾ ng lata (90–135g) sa bawat meal, maaaring kainin 2–3 beses kada linggo.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // "Higit pang detalye" link
                        Row(
                          children: [
                            const Icon(Icons.subdirectory_arrow_right_rounded,
                                color: Colors.black45, size: 16),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {},
                              child: Text(
                                'Higit pang detalye',
                                style: GoogleFonts.inter(
                                  color: Colors.black87,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── 6. Kabuuang Nutrisyon Card ────────────────────
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kabuuang Nutrisyon',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _nutriCard('Calories', p.nutritionalFacts.calories),
                            const SizedBox(width: 8),
                            _nutriCard('Sodium', p.nutritionalFacts.sodium),
                            const SizedBox(width: 8),
                            _nutriCard('Sugar', p.nutritionalFacts.sugars),
                            const SizedBox(width: 8),
                            _nutriCard('Protein', p.nutritionalFacts.protein),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _nutriCard('Total Fat', p.nutritionalFacts.totalFat),
                            const SizedBox(width: 8),
                            _nutriCard('Sat. Fat', p.nutritionalFacts.saturatedFat),
                            const SizedBox(width: 8),
                            _nutriCard('Trans Fat', p.nutritionalFacts.transFat),
                            const SizedBox(width: 8),
                            _nutriCard('Fiber', p.nutritionalFacts.dietaryFiber),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _nutriCard('Potassium', p.nutritionalFacts.potassiumMg > 0
                                ? '${p.nutritionalFacts.potassiumMg.toStringAsFixed(0)}mg'
                                : '0mg'),
                            const SizedBox(width: 8),
                            _nutriCard('Calcium', p.nutritionalFacts.calciumMg > 0
                                ? '${p.nutritionalFacts.calciumMg.toStringAsFixed(0)}mg'
                                : '0mg'),
                            const SizedBox(width: 8),
                            _nutriCard('Iron', p.nutritionalFacts.ironMg > 0
                                ? '${p.nutritionalFacts.ironMg.toStringAsFixed(1)}mg'
                                : '0.0mg'),
                            const SizedBox(width: 8),
                            Expanded(child: const SizedBox()),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── 7. Scores (Individual White Cards) ─────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Scores',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  _scoreCard(
                    label: 'Nutrisyon',
                    badge: 'C',
                    badgeColor: const Color(0xFFFFB300),
                    description: 'Magandang pinagkukunan ng protina ngunit mas mataas sa taba at calories.',
                  ),
                  const SizedBox(height: 8),
                  _scoreCard(
                    label: 'Kalikasan',
                    badge: 'B',
                    badgeColor: const Color(0xFF4CAF50),
                    description: 'Moderate environmental impact.',
                  ),
                  const SizedBox(height: 8),
                  _scoreCard(
                    label: 'Proseso',
                    badge: '3',
                    badgeColor: const Color(0xFFFF9800),
                    isCircle: true,
                    description: 'Processed food with relatively simple ingredients.',
                  ),

                  const SizedBox(height: 16),

                  // ── 8. Karagdagang Kaalaman Card ──────────────────
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCE4EC),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Karagdagang Kaalaman',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF388E3C),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Mas nakakabusog at mas malasa dahil sa mantika, ngunit may mas mataas na calories at taba.',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── 9. Ihambing Button ─────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CompareProductsScreen(
                                sourceProduct: p,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB71C1C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Ihambing',
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

      // ── Bottom Navigation Bar ─────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
        ),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 4, top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_outlined, 'Home', false),
            _navItemActive(),
            _navItem(Icons.history, 'History', false),
            _navItem(Icons.person_outline, 'Profile', false),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.mic, size: 26),
      ),
    );
  }

  // ── Helper card builder to make cards completely uniform ────────────────
  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── Nutritional mini grid card ──────────────────────────────────────────
  Widget _nutriCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Column(
          children: [
            Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  // ── Individual white score card (matches the style of scores section) ────
  Widget _scoreCard({
    required String label,
    required String badge,
    required Color badgeColor,
    required String description,
    bool isCircle = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
                    color: Colors.black54,
                    fontWeight: FontWeight.w600),
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
                  fontSize: 13, color: Colors.black87, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom nav helpers ───────────────────────────────────────────────────
  Widget _navItem(IconData icon, String label, bool active) {
    return GestureDetector(
      onTap: () {
        if (label == 'Home') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CameraScannerScreen()),
          );
        } else if (label == 'History') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HistoryScreen()),
          );
        } else if (label == 'Profile') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profile features coming soon!', style: GoogleFonts.inter()),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? const Color(0xFFB71C1C) : Colors.black38,
              size: 26),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: active ? const Color(0xFFB71C1C) : Colors.black38,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _navItemActive() {
    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CameraScannerScreen()),
        );
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner,
                color: Color(0xFFB71C1C), size: 26),
            const SizedBox(height: 2),
            Text('Scan',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFFB71C1C),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildFdaBadge() {
    final fda = _fdaResult;
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
            style: GoogleFonts.inter(fontSize: 10, color: Colors.black45, fontWeight: FontWeight.bold),
          ),
          if (fda.validityDate.isNotEmpty)
            Text(
              'Valid until: ${fda.validityDate}',
              style: GoogleFonts.inter(fontSize: 10, color: Colors.black45),
            ),
          if (fda.manufacturer.isNotEmpty)
            Text(
              fda.manufacturer,
              style: GoogleFonts.inter(fontSize: 10, color: Colors.black45),
            ),
        ],
      ],
    );
  }
}
