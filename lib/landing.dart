import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _loopController;

  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  late Animation<double> _pulseGlow;
  late Animation<double> _floating;

  // Warna Tema Neon Cyber
  static const Color cyanNeon = Color(0xFF00E5FF);
  static const Color blueNeon = Color(0xFF29B6F6);
  static const Color purpleNeon = Color(0xFF7C4DFF);
  static const Color magentaNeon = Color(0xFFFF2D75);
  static const Color darkBg = Color(0xFF090B10);
  static const Color darkSurface = Color(0xFF121622);

  @override
  void initState() {
    super.initState();

    // Controller untuk animasi masuk awal
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );

    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );

    // Controller untuk animasi loop terus-menerus (Floating, Pulse, Grid Shift)
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _pulseGlow = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _loopController, curve: Curves.easeInOut),
    );

    _floating = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _loopController, curve: Curves.easeInOut),
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception("Tidak dapat membuka $uri");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: darkBg,
      extendBodyBehindAppBar: true,
      appBar: _buildCyberAppBar(context, theme),
      body: Stack(
        children: [
          // ─── 1. ANIMATED CYBER BACKGROUND (GRID & PARTICLES & GLOW) ───────
          AnimatedBuilder(
            animation: _loopController,
            builder: (context, child) {
              return CustomPaint(
                size: screenSize,
                painter: _CyberBackgroundPainter(
                  progress: _loopController.value,
                ),
              );
            },
          ),

          // ─── 2. MAIN CONTENT SCROLL VIEW ─────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // ─── HEADER: LOGO & JUDUL & BADGE ──────────────────────
                      _buildHeaderSection(theme),

                      const SizedBox(height: 36),

                      // ─── STATISTIK SECTION (NEW) ─────────────────────────
                      _buildStatisticsSection(theme),

                      const SizedBox(height: 36),

                      // ─── FITUR UTAMA (GLASSMORPHISM CARDS) ───────────────
                      _buildFeatureCardsGrid(theme),

                      const SizedBox(height: 36),

                      // ─── TOMBOL UTAMA (MASUK & BELI AKSES) ───────────────
                      _buildActionButtons(theme),

                      const SizedBox(height: 40),

                      // ─── HUBUNGI KAMI ────────────────────────────────────
                      _buildContactSection(theme),

                      const SizedBox(height: 40),

                      // ─── FOOTER ──────────────────────────────────────────
                      _buildFooter(theme),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== APP BAR ====================
  PreferredSizeWidget _buildCyberAppBar(BuildContext context, ThemeProvider theme) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(65),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: darkBg.withOpacity(0.5),
              border: Border(
                bottom: BorderSide(
                  color: cyanNeon.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cyanNeon.withOpacity(0.15),
                          boxShadow: [
                            BoxShadow(
                              color: cyanNeon.withOpacity(0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shield_moon,
                          color: cyanNeon,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [cyanNeon, blueNeon],
                        ).createShader(bounds),
                        child: const Text(
                          "GOD OF WAR",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          cyanNeon.withOpacity(0.2),
                          magentaNeon.withOpacity(0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: cyanNeon.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          color: cyanNeon,
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          "Premium Security",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== HEADER SECTION ====================
  Widget _buildHeaderSection(ThemeProvider theme) {
    return Column(
      children: [
        // Logo dengan Animasi Pulse, Glow & Floating
        AnimatedBuilder(
          animation: _loopController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _floating.value),
              child: Transform.scale(
                scale: _pulseGlow.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const SweepGradient(
                      colors: [cyanNeon, purpleNeon, magentaNeon, cyanNeon],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cyanNeon.withOpacity(0.6),
                        blurRadius: 35,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: magentaNeon.withOpacity(0.4),
                        blurRadius: 55,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(3.5),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: darkBg,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        "assets/images/logo.png",
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.security,
                              size: 55,
                              color: cyanNeon,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 28),

        // Judul Utama dengan Gradient Cyan -> Purple -> Pink
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [cyanNeon, purpleNeon, magentaNeon],
            stops: [0.0, 0.5, 1.0],
          ).createShader(bounds),
          child: const Text(
            "GOD OF WAR",
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 4,
              shadows: [
                Shadow(
                  color: cyanNeon,
                  blurRadius: 20,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 12),

        // Subtitle dengan Icon Security
        _buildGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          borderRadius: 30,
          borderColor: cyanNeon.withOpacity(0.3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.security,
                color: cyanNeon,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                "Advanced Security System",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Badge: Powered by Remzz4you dengan Glow Effect
        _buildGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          borderRadius: 20,
          borderColor: magentaNeon.withOpacity(0.4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: magentaNeon.withOpacity(0.8),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.verified,
                  color: magentaNeon,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "Powered by Remzz4you",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== STATISTIK SECTION ====================
  Widget _buildStatisticsSection(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: "STATISTIK UTAMA",
          icon: Icons.analytics_outlined,
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 2.1,
          children: [
            _buildStatCard(
              icon: Icons.people,
              label: "Pengguna Aktif",
              value: "50,000+",
              color: cyanNeon,
            ),
            _buildStatCard(
              icon: Icons.security,
              label: "Keamanan",
              value: "99.9%",
              color: magentaNeon,
            ),
            _buildStatCard(
              icon: Icons.bolt,
              label: "Respon",
              value: "< 1ms",
              color: blueNeon,
            ),
            _buildStatCard(
              icon: Icons.cloud_done,
              label: "Server Online",
              value: "99.99%",
              color: purpleNeon,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return _buildGlassCard(
      borderRadius: 20,
      borderColor: color.withOpacity(0.3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
              border: Border.all(color: color.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== FEATURE CARDS GRID (GLASSMORPHISM) ====================
  Widget _buildFeatureCardsGrid(ThemeProvider theme) {
    final List<Map<String, dynamic>> features = [
      {
        "title": "Aman",
        "desc": "Enkripsi tingkat tinggi",
        "icon": Icons.shield,
        "color": cyanNeon,
      },
      {
        "title": "Cepat",
        "desc": "Respon super cepat",
        "icon": Icons.speed,
        "color": blueNeon,
      },
      {
        "title": "Terpercaya",
        "desc": "Layanan terpercaya",
        "icon": Icons.verified,
        "color": magentaNeon,
      },
      {
        "title": "Update",
        "desc": "Update Otomatis",
        "icon": Icons.system_update_alt,
        "color": purpleNeon,
      },
      {
        "title": "Cloud",
        "desc": "Cloud Server",
        "icon": Icons.cloud_done,
        "color": cyanNeon,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: "KEUNGGULAN SISTEM",
          icon: Icons.stars,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: features.map((f) {
                double itemWidth = (constraints.maxWidth - 12) / 2;
                if (constraints.maxWidth > 600) {
                  itemWidth = (constraints.maxWidth - 48) / 5;
                }
                return SizedBox(
                  width: itemWidth,
                  child: _buildGlassFeatureCard(
                    title: f["title"],
                    desc: f["desc"],
                    icon: f["icon"],
                    accentColor: f["color"],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGlassFeatureCard({
    required String title,
    required String desc,
    required IconData icon,
    required Color accentColor,
  }) {
    return _buildGlassCard(
      borderRadius: 22,
      borderColor: accentColor.withOpacity(0.35),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withOpacity(0.15),
              border: Border.all(color: accentColor.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.4),
                  blurRadius: 15,
                ),
              ],
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.65),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TOMBOL MASUK & BELI AKSES ====================
  Widget _buildActionButtons(ThemeProvider theme) {
    return Column(
      children: [
        // 🚀 Tombol MASUK (Gradient Cyan -> Pink)
        SizedBox(
          width: double.infinity,
          height: 58,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.pushNamed(context, "/login");
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [cyanNeon, purpleNeon, magentaNeon],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: cyanNeon.withOpacity(0.5),
                      blurRadius: 25,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: magentaNeon.withOpacity(0.3),
                      blurRadius: 35,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "MASUK SEKARANG",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 💎 Tombol BELI AKSES (Outline Neon & Pulse)
        SizedBox(
          width: double.infinity,
          height: 58,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _openUrl("https://t.me/remzz4you"),
              child: Container(
                decoration: BoxDecoration(
                  color: darkSurface.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cyanNeon,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cyanNeon.withOpacity(0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_checkout,
                        color: cyanNeon,
                        size: 22,
                      ),
                      SizedBox(width: 12),
                      Text(
                        "BELI AKSES PREMIUM",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: cyanNeon,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== SEKSI KONTAK ====================
  Widget _buildContactSection(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: "HUBUNGI KAMI",
          icon: Icons.support_agent,
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.9,
          children: [
            _buildContactCard(
              title: "Telegram",
              icon: Icons.telegram,
              url: "https://t.me/remzz4you",
              color: const Color(0xFF0088CC),
            ),
            _buildContactCard(
              title: "WhatsApp",
              icon: Icons.wechat,
              url: "https://wa.me//",
              color: const Color(0xFF25D366),
            ),
            _buildContactCard(
              title: "Email",
              icon: Icons.email,
              url: "mailto:support@godofwar.sec",
              color: const Color(0xFFEA4335),
            ),
            _buildContactCard(
              title: "Website",
              icon: Icons.language,
              url: "https://t.me/remzz4you",
              color: cyanNeon,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactCard({
    required String title,
    required IconData icon,
    required String url,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openUrl(url),
        borderRadius: BorderRadius.circular(24),
        child: _buildGlassCard(
          borderRadius: 24,
          borderColor: color.withOpacity(0.35),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== FOOTER ====================
  Widget _buildFooter(ThemeProvider theme) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 3,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [cyanNeon, magentaNeon],
            ),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: cyanNeon.withOpacity(0.8),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.copyright,
              color: Colors.white54,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              "2026 GOD OF WAR",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.code,
              color: cyanNeon,
              size: 16,
            ),
            const SizedBox(width: 6),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [cyanNeon, magentaNeon],
              ).createShader(bounds),
              child: const Text(
                "Powered by Remzz4you",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== HELPER BUILDERS ====================
  Widget _buildSectionTitle({required String title, required IconData icon}) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [cyanNeon, magentaNeon]),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: cyanNeon.withOpacity(0.8),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: cyanNeon, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard({
    required Widget child,
    double borderRadius = 20,
    Color? borderColor,
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: darkSurface.withOpacity(0.55),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.12),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── 🎨 PAINTER UNTUK BACKGROUND FUTURISTIK BERGERAK ───────────────────────
class _CyberBackgroundPainter extends CustomPainter {
  final double progress;

  _CyberBackgroundPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF080A10);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 1. Glow Circles Aurora / Nebulae
    final double offsetVal = math.sin(progress * math.pi * 2);

    final glow1 = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90);
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.15 + (offsetVal * 20)),
      160,
      glow1,
    );

    final glow2 = Paint()
      ..color = const Color(0xFFFF2D75).withOpacity(0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.6 - (offsetVal * 30)),
      180,
      glow2,
    );

    final glow3 = Paint()
      ..color = const Color(0xFF7C4DFF).withOpacity(0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 110);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.85 + (offsetVal * 15)),
      200,
      glow3,
    );

    // 2. Animated Cyber Grid Lines
    final gridPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.04)
      ..strokeWidth = 1.0;

    const double gridSpacing = 40.0;
    final double shift = (progress * gridSpacing);

    for (double x = 0; x <= size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    for (double y = shift; y <= size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 3. Floating Neon Particles
    final particlePaint = Paint()..style = PaintingStyle.fill;

    final particles = [
      Offset(size.width * 0.15, size.height * 0.25 + (offsetVal * 10)),
      Offset(size.width * 0.82, size.height * 0.18 - (offsetVal * 15)),
      Offset(size.width * 0.35, size.height * 0.55 + (offsetVal * 20)),
      Offset(size.width * 0.75, size.height * 0.78 - (offsetVal * 12)),
      Offset(size.width * 0.12, size.height * 0.82 + (offsetVal * 8)),
    ];

    for (int i = 0; i < particles.length; i++) {
      particlePaint.color = (i % 2 == 0 ? const Color(0xFF00E5FF) : const Color(0xFFFF2D75))
          .withOpacity(0.4);
      canvas.drawCircle(particles[i], 2.5, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
