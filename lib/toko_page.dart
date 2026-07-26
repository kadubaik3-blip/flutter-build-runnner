import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class TokoPage extends StatelessWidget {
  const TokoPage({super.key});

  // LIST PRODUK
  final List<Map<String, dynamic>> products = const [
    {
      "title": "APK GOD OF WAR",
      "desc":
          "List Akses Price GOD OF WAR, canggih dan multi fungsi",
      "price": "BENEFIT PV",
      "badge": "GOD OF WAR",
      "icon": FontAwesomeIcons.infinity,
      "features": [
        "Member 1Bulan 15K",
        "Member Perma 20K",
        "Reseller 40K",
        "Vip Perma 60K",
        "Owner Perma 100K",
        "High Owner 150K",
        "Ceo Perma 300K",
      ],
      "link": "https://wa.me/6287869250421"
    },
  ];

  Future<void> openLink(String url) async {
    final Uri uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: theme.primaryColor.withOpacity(0.4),
                blurRadius: 15,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text(
                "TEAM CRK STORE",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.glassSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.textPrimaryColor.withOpacity(0.08),
              ),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              color: theme.primaryColor,
              size: 18,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [
              theme.primaryColor.withOpacity(0.15),
              theme.backgroundColor,
              theme.backgroundColor
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(accentColor: theme.primaryColor),
          child: ListView.builder(
            padding: const EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: 40,
            ),
            physics: const BouncingScrollPhysics(),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final item = products[index];

              return TweenAnimationBuilder(
                duration: Duration(milliseconds: 400 + (index * 150)),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 28),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: theme.glassPrimary,
                    border: Border.all(
                      color: theme.primaryColor.withOpacity(0.7),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withOpacity(0.18),
                        blurRadius: 30,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: theme.primaryColor.withOpacity(0.5),
                                blurRadius: 15,
                              ),
                            ],
                          ),
                          child: Text(
                            item["badge"],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                          boxShadow: [
                            BoxShadow(
                              color: theme.primaryColor.withOpacity(0.5),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                        child: Icon(
                          item["icon"],
                          color: Colors.white,
                          size: 35,
                        ),
                      ),

                      const SizedBox(height: 25),

                      Text(
                        item["title"],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.textPrimaryColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        item["desc"],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.textSecondaryColor.withOpacity(0.95),
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),

                      const SizedBox(height: 24),

                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(colors: [theme.primaryColor, theme.accentColor]).createShader(bounds),
                        child: Text(
                          item["price"],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // LIHAT DETAIL
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: theme.primaryColor.withOpacity(0.8),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (_) {
                                return _DetailModal(
                                  item: item,
                                  theme: theme,
                                  openLink: openLink,
                                );
                              },
                            );
                          },
                          child: Text(
                            "Lihat Detail",
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // PESAN SEKARANG
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: theme.primaryColor.withOpacity(0.5),
                            elevation: 15,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () {
                            openLink(item["link"]);
                          },
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: const Text(
                                "Pesan Sekarang",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ================= DETAIL MODAL =================

class _DetailModal extends StatelessWidget {
  final Map<String, dynamic> item;
  final ThemeProvider theme;
  final Function(String) openLink;

  const _DetailModal({
    required this.item,
    required this.theme,
    required this.openLink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(18),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.glassPrimary,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: theme.primaryColor.withOpacity(0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.2),
            blurRadius: 30,
          ),
        ],
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withOpacity(0.5),
                      blurRadius: 25,
                    ),
                  ],
                ),
                child: Icon(
                  item["icon"],
                  color: Colors.white,
                  size: 35,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                item["title"],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textPrimaryColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                item["desc"],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textSecondaryColor,
                  fontSize: 16,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 30),

              Column(
                children: List.generate(
                  item["features"].length,
                  (index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      child: Row(
                        children: [
                          Icon(
                            FontAwesomeIcons.burst,
                            color: theme.primaryColor,
                            size: 16,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              item["features"][index],
                              style: TextStyle(
                                color: theme.textPrimaryColor,
                                fontSize: 17,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(colors: [theme.primaryColor, theme.accentColor]).createShader(bounds),
                child: Text(
                  item["price"],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    elevation: 12,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    openLink(item["link"]);
                  },
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Center(
                      child: Text(
                        "Pesan Sekarang",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= GRID BACKGROUND =================

class _GridPainter extends CustomPainter {
  final Color accentColor;
  
  _GridPainter({required this.accentColor});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 0.8;

    const gridSize = 30.0;

    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    final accentPaint = Paint()
      ..color = accentColor.withOpacity(0.08)
      ..strokeWidth = 1.5;

    for (double x = 0; x <= size.width; x += gridSize * 5) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        accentPaint,
      );
    }

    for (double y = 0; y <= size.height; y += gridSize * 5) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        accentPaint,
      );
    }

    final dotPaint = Paint()
      ..color = accentColor.withOpacity(0.1);

    for (double x = 0; x <= size.width; x += gridSize) {
      for (double y = 0; y <= size.height; y += gridSize) {
        canvas.drawCircle(
          Offset(x, y),
          1.5,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}