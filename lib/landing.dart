import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeInOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
      backgroundColor: theme.backgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.8,
            colors: [
              theme.primaryColor.withOpacity(0.12),
              theme.backgroundColor,
              theme.backgroundColor,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(accentColor: theme.primaryColor),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 40),

                        // ─── HEADER: LOGO & JUDUL ──────────────────────────
                        _buildHeader(theme),

                        const SizedBox(height: 40),

                        // ─── KARTU FITUR (4 HORIZONTAL) ──────────────────
                        _buildFeatureRow(theme),

                        const SizedBox(height: 40),

                        // ─── TOMBOL MASUK ──────────────────────────────────
                        _buildSignInButton(theme),

                        const SizedBox(height: 14),

                        // ─── TOMBOL BELI AKSES ────────────────────────────
                        _buildBuyButton(theme),

                        const SizedBox(height: 40),

                        // ─── SEKSI KONTAK ──────────────────────────────────
                        _buildContactSection(theme),

                        const SizedBox(height: 32),

                        // ─── FOOTER ─────────────────────────────────────────
                        _buildFooter(theme),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== HEADER ====================
  Widget _buildHeader(ThemeProvider theme) {
    return Column(
      children: [
        // Logo dengan efek pulse dan glow
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [theme.primaryColor, theme.accentColor],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    "assets/images/logo.png",
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(Icons.person, size: 50, color: theme.textPrimaryColor),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 28),

        // Judul utama dengan gradien
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [theme.primaryColor, theme.accentColor],
          ).createShader(bounds),
          child: const Text(
            "GOD OF WAR",
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Subtitle dengan badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: theme.glassSecondary,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.textPrimaryColor.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: theme.primaryColor.withOpacity(0.05),
                blurRadius: 8,
              ),
            ],
          ),
          child: Text(
            "Sistem Keamanan Tingkat Lanjut",
            style: TextStyle(
              fontSize: 13,
              color: theme.textSecondaryColor,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Powered by
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: theme.primaryColor,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: theme.primaryColor, blurRadius: 8)],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "Ditenagai oleh @Team CRK",
              style: TextStyle(
                fontSize: 11,
                color: theme.textSecondaryColor.withOpacity(0.7),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: theme.primaryColor,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: theme.primaryColor, blurRadius: 8)],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== BARIS FITUR (4 KARTU) ====================
  Widget _buildFeatureRow(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "MENGAPA HARUS KAMI",
              style: TextStyle(
                color: theme.textSecondaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFeatureCard(
                  icon: Icons.security_rounded,
                  title: "AMAN",
                  desc: "Enkripsi",
                  delay: 0,
                  theme: theme,
                ),
                const SizedBox(width: 12),
                _buildFeatureCard(
                  icon: Icons.speed_rounded,
                  title: "CEPAT",
                  desc: "Respons",
                  delay: 100,
                  theme: theme,
                ),
                const SizedBox(width: 12),
                _buildFeatureCard(
                  icon: Icons.verified_rounded,
                  title: "TERPERCAYA",
                  desc: "Andal",
                  delay: 200,
                  theme: theme,
                ),
                const SizedBox(width: 12),
                _buildFeatureCard(
                  icon: Icons.support_agent_rounded,
                  title: "24/7",
                  desc: "Dukungan",
                  delay: 300,
                  theme: theme,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String desc,
    required int delay,
    required ThemeProvider theme,
  }) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 400 + delay),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.glassPrimary,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.textPrimaryColor.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: theme.primaryColor.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.textPrimaryColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style: TextStyle(
                fontSize: 9,
                color: theme.textSecondaryColor,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== TOMBOL MASUK ====================
  Widget _buildSignInButton(ThemeProvider theme) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 500),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, "/login");
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 14),
                  Text(
                    "MASUK",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
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

  // ==================== TOMBOL BELI AKSES ====================
  Widget _buildBuyButton(ThemeProvider theme) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 600),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: GestureDetector(
          onTap: () => _openUrl("https://t.me/remzz4you"),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.primaryColor.withOpacity(0.5), width: 1.8),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(FontAwesomeIcons.telegram, color: theme.primaryColor, size: 20),
                  const SizedBox(width: 14),
                  Text(
                    "BELI AKSES",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                      letterSpacing: 1.8,
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

  // ==================== SEKSI KONTAK ====================
  Widget _buildContactSection(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "HUBUNGI KAMI",
              style: TextStyle(
                color: theme.textSecondaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _buildContactCard(
                icon: FontAwesomeIcons.telegram,
                label: "Telegram",
                url: "https://t.me/remzz4you",
                color: const Color(0xFF0088cc),
                delay: 0,
                theme: theme,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildContactCard(
                icon: FontAwesomeIcons.whatsapp,
                label: "WhatsApp",
                url: "https://wa.me//",
                color: const Color(0xFF25D366),
                delay: 100,
                theme: theme,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String label,
    required String url,
    required Color color,
    required int delay,
    required ThemeProvider theme,
  }) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 400 + delay),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _openUrl(url),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: theme.glassPrimary,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.textPrimaryColor.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: theme.primaryColor.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FaIcon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: theme.textPrimaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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
          width: 60,
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          "© 2026 GOD OF WAR — @TeamCRK",
          style: TextStyle(
            color: theme.textSecondaryColor.withOpacity(0.4),
            fontSize: 11,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ─── PAINTER GRID (dengan warna tema) ──────────────────────────────
class _GridPainter extends CustomPainter {
  final Color accentColor;

  _GridPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const gridSize = 30.0;

    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final accentPaint = Paint()
      ..color = accentColor.withOpacity(0.08)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (double x = 0; x <= size.width; x += gridSize * 5) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), accentPaint);
    }

    for (double y = 0; y <= size.height; y += gridSize * 5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), accentPaint);
    }

    final dotPaint = Paint()
      ..color = accentColor.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    for (double x = 0; x <= size.width; x += gridSize) {
      for (double y = 0; y <= size.height; y += gridSize) {
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}