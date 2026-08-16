import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dashboard_page.dart';
import 'login_page.dart';
import 'theme_provider.dart';

// ─── Model Particle untuk Animasi Background ──────────────────────────────
class Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  Particle({required this.x, required this.y, required this.size, required this.speed});
}

class SplashScreen extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String sessionKey;
  final String expiredDate;
  final List<Map<String, dynamic>> listBug;
  final List<dynamic> news;

  const SplashScreen({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.sessionKey,
    required this.expiredDate,
    required this.listBug,
    required this.news,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // ─── Animasi Controllers ──────────────────────────────────────────────
  late AnimationController _introController;
  late Animation<double> _introFade;
  late Animation<double> _introScale;
  late Animation<Offset> _bottomSlide;

  late AnimationController _loopController;
  late AnimationController _progressController;
  late AnimationController _typewriterController;

  // ─── Cyber Futuristic Colors ──────────────────────────────────────────
  final Color neonBlue = const Color(0xFF00F0FF);
  final Color neonPurple = const Color(0xFF8A2BE2);
  final Color darkBlack = const Color(0xFF05050A);

  // ─── Data Multi Language & Loading Status ─────────────────────────────
  final List<String> _greetings = [
    '🇮🇩 Selamat Datang',
    '🇺🇸 Welcome',
    '🇯🇵 ようこそ',
    '🇰🇷 환영합니다',
    '🇨🇳 欢迎',
    '🇫🇷 Bienvenue',
    '🇩🇪 Willkommen',
    '🇪🇸 Bienvenido',
    '🇷🇺 Добро пожаловать',
    '🇸🇦 أهلاً وسهلاً'
  ];

  final List<Map<String, dynamic>> _loadingStates = [
    {'text': '⚙ Initializing...', 'icon': Icons.settings_suggest},
    {'text': '📦 Loading Assets...', 'icon': Icons.memory},
    {'text': '🌐 Connecting Server...', 'icon': Icons.router},
    {'text': '🔐 Authenticating...', 'icon': Icons.security_rounded},
    {'text': '📡 Synchronizing...', 'icon': Icons.sync_lock},
    {'text': '🚀 Preparing Dashboard...', 'icon': Icons.rocket_launch},
    {'text': '✅ Ready...', 'icon': Icons.verified},
  ];

  int _greetingIndex = 0;
  int _statusIndex = 0;
  Timer? _switcherTimer;
  late List<Particle> _particles;

  @override
  void initState() {
    super.initState();
    _initParticles();
    _initAnimations();
    _startDataSwitchers();
    _goToDashboard();
  }

  void _initParticles() {
    final random = math.Random();
    _particles = List.generate(40, (index) {
      return Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 2.5 + 1,
        speed: random.nextDouble() * 0.4 + 0.1,
      );
    });
  }

  void _initAnimations() {
    // 1. Intro Transisi (Fade, Scale, Slide)
    _introController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _introFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutExpo),
    );

    _introScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.elasticOut),
    );

    _bottomSlide = Tween<Offset>(begin: const Offset(0, 2.0), end: Offset.zero).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
    );

    // 2. Looping (Rotation, Pulse, Breathing, Particles)
    _loopController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    // 3. Progress Loading Bar (0% - 100%)
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 6500), // Disesuaikan dengan durasi splash
      vsync: this,
    )..forward();

    // 4. Typewriter Effect
    _typewriterController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _introController.forward().then((_) => _typewriterController.forward());
  }

  void _startDataSwitchers() {
    _switcherTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _greetingIndex = (_greetingIndex + 1) % _greetings.length;
          if (_statusIndex < _loadingStates.length - 1) {
            _statusIndex++;
          }
        });
      }
    });
  }

  // ─── Navigasi ke Dashboard ────────────────────────────────────────────
  void _goToDashboard() async {
    // Waktu tunggu disesuaikan agar seluruh animasi premium dan loading bar 100% selesai
    await Future.delayed(const Duration(milliseconds: 6500));
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1000),
        pageBuilder: (context, animation, secondaryAnimation) => DashboardPage(
          username: widget.username,
          password: widget.password,
          role: widget.role,
          expiredDate: widget.expiredDate,
          listBug: widget.listBug,
          sessionKey: widget.sessionKey,
          news: widget.news,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Transisi Premium (Fade + Scale)
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.1, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _switcherTimer?.cancel();
    _introController.dispose();
    _loopController.dispose();
    _progressController.dispose();
    _typewriterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBlack,
      body: Stack(
        children: [
          // ─── 1. Animated Gradient Background ────────────────────────────────
          AnimatedBuilder(
            animation: _loopController,
            builder: (context, child) {
              final sinValue = math.sin(_loopController.value * 2 * math.pi);
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, sinValue * 0.1),
                    radius: 1.5,
                    colors: [
                      neonPurple.withOpacity(0.15),
                      darkBlack,
                      darkBlack,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              );
            },
          ),

          // ─── 2. Blur Bubble ───────────────────────────────────────────────
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: neonBlue.withOpacity(0.1),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: neonPurple.withOpacity(0.1),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // ─── 3. Particles & Cyber Grid ────────────────────────────────────
          AnimatedBuilder(
            animation: _loopController,
            builder: (context, child) {
              return CustomPaint(
                painter: _CyberBackgroundPainter(
                  progress: _loopController.value,
                  particles: _particles,
                  color1: neonBlue,
                  color2: neonPurple,
                ),
                size: Size.infinite,
              );
            },
          ),

          // ─── 4. Main UI Content ───────────────────────────────────────────
          Center(
            child: FadeTransition(
              opacity: _introFade,
              child: ScaleTransition(
                scale: _introScale,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    
                    // ─── Multi Language Auto-Switcher ───────────────────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 800),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.5),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        _greetings[_greetingIndex],
                        key: ValueKey<int>(_greetingIndex),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: neonBlue.withOpacity(0.9),
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ─── Premium Logo dengan Glassmorphism & Neon Glow ───────
                    Hero(
                      tag: 'cyber_shield',
                      child: AnimatedBuilder(
                        animation: _loopController,
                        builder: (context, child) {
                          final pulse = math.sin(_loopController.value * math.pi * 2);
                          final scale = 1.0 + (0.03 * pulse);
                          
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: neonBlue.withOpacity(0.4),
                                    blurRadius: 30 + (10 * pulse),
                                    spreadRadius: 5 + (2 * pulse),
                                  ),
                                  BoxShadow(
                                    color: neonPurple.withOpacity(0.3),
                                    blurRadius: 20 + (10 * pulse),
                                    spreadRadius: -5,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(80),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.05),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(Icons.shield, size: 100, color: neonBlue.withOpacity(0.2)),
                                        Icon(Icons.security_rounded, size: 80, color: neonBlue.withOpacity(0.5)),
                                        Icon(Icons.bolt, size: 45, color: Colors.white),
                                        Positioned(
                                          top: 30, right: 30,
                                          child: Icon(Icons.auto_awesome, size: 20, color: neonPurple),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ─── Text: GOD OF WAR ───────────────────────────────────
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [neonBlue, Colors.white, neonPurple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: const Text(
                        "GOD OF WAR",
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 6,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 5)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),

                    // ─── Status Loading dengan Ikon ─────────────────────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Row(
                        key: ValueKey<int>(_statusIndex),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_loadingStates[_statusIndex]['icon'], color: neonPurple, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            _loadingStates[_statusIndex]['text'],
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),

                    // ─── Progress Bar & Persentase (0-100%) ────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 60),
                      child: AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, child) {
                          return Column(
                            children: [
                              // Text Persentase
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  "${(_progressController.value * 100).toInt()}%",
                                  style: TextStyle(
                                    color: neonBlue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Bar
                              Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: Stack(
                                  children: [
                                    // Animated fill bar
                                    FractionallySizedBox(
                                      widthFactor: _progressController.value,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          gradient: LinearGradient(
                                            colors: [neonPurple, neonBlue],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: neonBlue.withOpacity(0.6),
                                              blurRadius: 10,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── 5. Powered By Text (Typewriter & Slide Up) ───────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: SlideTransition(
                position: _bottomSlide,
                child: FadeTransition(
                  opacity: _introFade,
                  child: AnimatedBuilder(
                    animation: _typewriterController,
                    builder: (context, child) {
                      const fullText = "Powered by Remzz4you";
                      final currentLength = (fullText.length * _typewriterController.value).toInt();
                      final displayText = fullText.substring(0, currentLength);

                      return ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [Colors.white70, neonBlue],
                        ).createShader(bounds),
                        child: Text(
                          displayText,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom Painter untuk Cyber Grid & Particles ────────────────────────
class _CyberBackgroundPainter extends CustomPainter {
  final double progress;
  final List<Particle> particles;
  final Color color1;
  final Color color2;

  _CyberBackgroundPainter({
    required this.progress,
    required this.particles,
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Grid Cyber Futuristic
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.015)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const gridSize = 40.0;
    
    // Animasi pergerakan grid perlahan ke bawah
    final dy = (progress * gridSize) % gridSize;

    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = -gridSize; y <= size.height + gridSize; y += gridSize) {
      canvas.drawLine(Offset(0, y + dy), Offset(size.width, y + dy), gridPaint);
    }

    // 2. Floating Light Particles
    final particlePaint = Paint()..style = PaintingStyle.fill;

    for (var particle in particles) {
      // Y bergerak ke atas perlahan
      double currentY = (particle.y - (progress * particle.speed)) % 1.0;
      if (currentY < 0) currentY += 1.0;

      // X diberikan sedikit goyangan (breathing/floating)
      final xWobble = math.sin(progress * math.pi * 4 + particle.x * 10) * 0.02;
      double currentX = particle.x + xWobble;

      final position = Offset(currentX * size.width, currentY * size.height);

      particlePaint.color = (particle.size > 2 ? color1 : color2).withOpacity(0.5);
      
      // Glow partikel
      final glowPaint = Paint()
        ..color = particlePaint.color.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

      canvas.drawCircle(position, particle.size * 2, glowPaint);
      canvas.drawCircle(position, particle.size, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
