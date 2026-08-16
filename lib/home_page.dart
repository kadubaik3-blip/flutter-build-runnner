import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class HomePage extends StatefulWidget {
  final String username;
  final String password;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final String role;
  final String expiredDate;

  const HomePage({
    super.key,
    required this.username,
    required this.password,
    required this.sessionKey,
    required this.listBug,
    required this.role,
    required this.expiredDate,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final TextEditingController targetController = TextEditingController();
  late final AnimationController _pulseController;
  String selectedBugId = "";
  String _selectedBugMode = "number";
  bool isSending = false;
  String? responseMessage;

  // Private Sender
  List<Map<String, dynamic>> _privateSenders = [];
  bool _isLoadingSenders = false;
  bool _isAddingSender = false;
  Timer? _senderPollingTimer;
  final TextEditingController _senderInputController = TextEditingController();
  static const String baseUrl = "http://public-gacor67.zone.id:2357";
  static const _pollingInterval = Duration(seconds: 10);

  // Global Sender
  bool _showGlobalSenderPanel = false;
  final TextEditingController _globalSenderNumberController = TextEditingController();
  final TextEditingController _globalMessageController = TextEditingController();
  bool _isSendingGlobal = false;
  List<Map<String, dynamic>> _globalSenders = [];
  bool _isLoadingGlobalSenders = false;

  String _selectedSenderType = 'private'; // 'private' atau 'global'

  // Video Player
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool isVideoInitialized = false;

  bool get _isMember => widget.role.toLowerCase() == 'member';
  bool get _canSendBug => _privateSenders.isNotEmpty;
  bool get _isVip => widget.role.toLowerCase() == 'vip';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    if (widget.listBug.isNotEmpty) {
      selectedBugId = widget.listBug[0]['bug_id'];
    }

    _initializeVideoPlayer();
    _fetchSenders();
    _fetchGlobalSenders();
    _startPolling();
  }

  void _startPolling() {
    _senderPollingTimer = Timer.periodic(_pollingInterval, (_) {
      if (mounted) {
        _fetchSendersSilent();
        _fetchGlobalSendersSilent();
      }
    });
  }

  Future<void> _fetchSendersSilent() async {
    try {
      final res = await http
          .get(Uri.parse("$baseUrl/mySender?key=${widget.sessionKey}"))
          .timeout(const Duration(seconds: 8));
      final data = jsonDecode(res.body);
      if (data["valid"] == true && mounted) {
        final newPrivate = List<Map<String, dynamic>>.from(data["privateConnections"] ?? []);
        if (_listChanged(_privateSenders, newPrivate)) {
          setState(() {
            _privateSenders = newPrivate;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchGlobalSendersSilent() async {
    if (!_isVip) return;
    try {
      final res = await http
          .get(Uri.parse("$baseUrl/mySender?key=${widget.sessionKey}"))
          .timeout(const Duration(seconds: 8));
      final data = jsonDecode(res.body);
      if (data["valid"] == true && mounted) {
        final newGlobal = List<Map<String, dynamic>>.from(data["globalConnections"] ?? []);
        if (_listChanged(_globalSenders, newGlobal)) {
          setState(() {
            _globalSenders = newGlobal;
          });
        }
      }
    } catch (_) {}
  }

  bool _listChanged(List<Map<String, dynamic>> oldList, List<Map<String, dynamic>> newList) {
    if (oldList.length != newList.length) return true;
    final oldIds = oldList.map((e) => e['id']?.toString() ?? '').toSet();
    final newIds = newList.map((e) => e['id']?.toString() ?? '').toSet();
    return !oldIds.containsAll(newIds) || !newIds.containsAll(oldIds);
  }

  void _initializeVideoPlayer() {
    _videoController = VideoPlayerController.asset('assets/videos/banner.mp4');

    _videoController.initialize().then((_) {
      if (mounted) {
        setState(() {
          _videoController.setVolume(0.5);
          _chewieController = ChewieController(
            videoPlayerController: _videoController,
            autoPlay: true,
            looping: true,
            showControls: false,
            autoInitialize: true,
          );
          isVideoInitialized = true;
        });
      }
    }).catchError((error) {
      debugPrint("Video error: $error");
      if (mounted) {
        setState(() {
          isVideoInitialized = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _senderPollingTimer?.cancel();
    _pulseController.dispose();
    targetController.dispose();
    _videoController.dispose();
    _chewieController?.dispose();
    _senderInputController.dispose();
    _globalSenderNumberController.dispose();
    _globalMessageController.dispose();
    super.dispose();
  }

  Future<void> _fetchSenders() async {
    setState(() => _isLoadingSenders = true);
    try {
      final res = await http.get(Uri.parse("$baseUrl/mySender?key=${widget.sessionKey}"));
      final data = jsonDecode(res.body);
      if (data["valid"] == true) {
        setState(() {
          _privateSenders = List<Map<String, dynamic>>.from(data["privateConnections"] ?? []);
        });
      }
    } catch (_) {
      _showAlert("❌ Error", "Gagal memuat data private sender.");
    } finally {
      setState(() => _isLoadingSenders = false);
    }
  }

  Future<void> _fetchGlobalSenders() async {
    if (!_isVip) return;
    setState(() => _isLoadingGlobalSenders = true);
    try {
      final res = await http.get(Uri.parse("$baseUrl/mySender?key=${widget.sessionKey}"));
      final data = jsonDecode(res.body);
      if (data["valid"] == true) {
        setState(() {
          _globalSenders = List<Map<String, dynamic>>.from(data["globalConnections"] ?? []);
        });
      }
    } catch (_) {
      _showAlert("❌ Error", "Gagal memuat data global sender.");
    } finally {
      setState(() => _isLoadingGlobalSenders = false);
    }
  }

  Future<void> _addSender(String number) async {
    if (number.isEmpty) {
      _showAlert("❌ Error", "Nomor sender tidak boleh kosong.");
      return;
    }
    String formatted = number.trim();
    if (formatted.startsWith('0')) {
      formatted = '62${formatted.substring(1)}';
    } else if (formatted.startsWith('+')) {
      formatted = formatted.replaceAll('+', '');
    } else if (!formatted.startsWith('62')) {
      formatted = '62$formatted';
    }
    setState(() => _isAddingSender = true);
    try {
      final uri = Uri.parse("$baseUrl/getPairing?key=${widget.sessionKey}&number=$formatted&global=0");
      final res = await http.get(uri).timeout(const Duration(seconds: 30));
      final data = jsonDecode(res.body);
      if (data["valid"] == true && data["pairingCode"] != null) {
        _senderInputController.clear();
        if (mounted) {
          _showPairingDialog(
            number: formatted,
            pairingCode: data["pairingCode"].toString(),
          );
        }
      } else {
        final msg = data["message"] ?? data["error"] ?? "Gagal mendapatkan pairing code.";
        _showAlert("❌ Gagal", msg);
      }
    } on SocketException {
      _showAlert("❌ Error", "Tidak ada koneksi internet.");
    } catch (e) {
      _showAlert("❌ Error", "Terjadi kesalahan: $e");
    } finally {
      if (mounted) setState(() => _isAddingSender = false);
    }
  }

  void _showPairingDialog({
    required String number,
    required String pairingCode,
  }) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final formatted = pairingCode.length == 8
        ? '${pairingCode.substring(0, 4)}-${pairingCode.substring(4)}'
        : pairingCode;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: scale.clamp(0.0, 1.0),
              child: AlertDialog(
                backgroundColor: theme.backgroundColor.withOpacity(0.9),
                elevation: 24,
                shadowColor: theme.primaryColor.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(color: theme.primaryColor.withOpacity(0.5), width: 1.5),
                ),
                title: Row(children: [
                  const Icon(FontAwesomeIcons.whatsapp, color: Colors.greenAccent, size: 24),
                  const SizedBox(width: 12),
                  Text("Pairing Private Sender",
                      style: TextStyle(color: theme.textPrimaryColor, fontFamily: 'Orbitron', fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text("Masukkan kode ini di WhatsApp nomor:",
                      style: TextStyle(color: theme.textSecondaryColor, fontFamily: 'ShareTechMono', fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                    ),
                    child: Text(number,
                        style: TextStyle(color: theme.primaryColor, fontFamily: 'ShareTechMono', fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                  Hero(
                    tag: 'pairing_code',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [theme.primaryColor.withOpacity(0.15), theme.accentColor.withOpacity(0.15)]),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: theme.primaryColor.withOpacity(0.6), width: 2),
                        boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.2), blurRadius: 15, spreadRadius: 2)],
                      ),
                      child: Center(
                        child: SelectableText(formatted,
                            style: TextStyle(color: theme.textPrimaryColor, fontFamily: 'Orbitron', fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.glassSecondary, 
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _pairingStep("1", "Buka WhatsApp di HP nomor $number", theme),
                      _pairingStep("2", "Ketuk ⋮ Menu → Perangkat Tertaut", theme),
                      _pairingStep("3", "Ketuk \"Tautkan dengan nomor telepon\"", theme),
                      _pairingStep("4", "Masukkan kode di atas", theme),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(FontAwesomeIcons.clock, color: theme.textSecondaryColor, size: 12),
                      const SizedBox(width: 6),
                      Text("Kode berlaku ±60 detik.",
                          style: TextStyle(color: theme.textSecondaryColor, fontFamily: 'ShareTechMono', fontSize: 11)),
                    ],
                  ),
                ]),
                actions: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _fetchSenders();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text("SELESAI", style: TextStyle(color: Colors.white, fontFamily: 'Orbitron', fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pairingStep(String step, String text, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 4)]
          ),
          child: Text(step, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(text, style: TextStyle(color: theme.textSecondaryColor, fontFamily: 'ShareTechMono', fontSize: 12)),
          ),
        ),
      ]),
    );
  }

  Future<void> _deleteSender(String number) async {
    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/deleteSender?key=${widget.sessionKey}&id=$number&scope=private"),
      );
      final data = jsonDecode(res.body);
      if (data["valid"] == true) {
        _showAlert("✅ Berhasil", "Private sender berhasil dihapus.");
        await _fetchSenders();
      } else {
        _showAlert("❌ Gagal", data["message"] ?? "Gagal menghapus sender.");
      }
    } catch (_) {
      _showAlert("❌ Error", "Terjadi kesalahan saat menghapus sender.");
    }
  }

  void _showDeleteConfirmation(String number, {bool isGlobal = false}) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (_) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 200),
        builder: (context, val, child) => Transform.scale(
          scale: val,
          child: Opacity(
            opacity: val,
            child: AlertDialog(
              backgroundColor: theme.backgroundColor.withOpacity(0.9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.redAccent.withOpacity(0.5), width: 1.5),
              ),
              title: Row(
                children: [
                  const Icon(FontAwesomeIcons.triangleExclamation, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 10),
                  Text("Konfirmasi Hapus",
                      style: TextStyle(color: theme.textPrimaryColor, fontFamily: 'Orbitron', fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text("Hapus ${isGlobal ? 'global' : 'private'} sender $number dari daftar?",
                  style: TextStyle(color: theme.textSecondaryColor, fontFamily: 'ShareTechMono', fontSize: 14)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("BATAL", style: TextStyle(color: theme.textSecondaryColor, fontWeight: FontWeight.bold))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.2),
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    if (isGlobal) {
                      _deleteGlobalSender(number);
                    } else {
                      _deleteSender(number);
                    }
                  },
                  child: const Text("HAPUS", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteGlobalSender(String number) async {
    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/deleteSender?key=${widget.sessionKey}&id=$number&scope=global"),
      );
      final data = jsonDecode(res.body);
      if (data["valid"] == true) {
        _showAlert("✅ Berhasil", "Global sender berhasil dihapus.");
        await _fetchGlobalSenders();
      } else {
        _showAlert("❌ Gagal", data["message"] ?? "Gagal menghapus global sender.");
      }
    } catch (_) {
      _showAlert("❌ Error", "Terjadi kesalahan saat menghapus global sender.");
    }
  }

  String? _formatPhoneNumber(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleaned.startsWith('+') || cleaned.length < 8) return null;
    return cleaned;
  }

  bool isValidGroupLink(String input) {
    return input.contains('chat.whatsapp.com') && input.contains('https://');
  }

  Future<void> _sendBug() async {
    final rawInput = targetController.text.trim();
    final key = widget.sessionKey;

    if (_selectedBugMode == "number") {
      final target = _formatPhoneNumber(rawInput);
      if (target == null || key.isEmpty) {
        _showMessageDialog(
          "Format Nomor Salah",
          "Gunakan format internasional (contoh: +62, +1, +44)",
        );
        return;
      }
    } else {
      if (!isValidGroupLink(rawInput)) {
        _showMessageDialog(
          "Link Tidak Valid",
          "Masukkan link grup WhatsApp yang valid",
        );
        return;
      }
    }

    if (_selectedSenderType == 'private' && !_canSendBug) {
      _showAlert("❌ Tidak Ada Sender", "Tambahkan private sender terlebih dahulu!");
      return;
    }
    if (_selectedSenderType == 'global' && _globalSenders.isEmpty) {
      _showAlert("❌ Global Kosong", "Belum ada global sender aktif. Hubungi owner!");
      return;
    }

    setState(() {
      isSending = true;
      responseMessage = null;
    });

    try {
      final res = await http.get(
        Uri.parse(
          "$baseUrl/sendBug?key=$key&target=$rawInput&bug=$selectedBugId&senderType=$_selectedSenderType",
        ),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(res.body);

      if (!mounted) return;

      if (data["cooldown"] == true) {
        final wait = data["wait"];
        setState(() => responseMessage = wait == null
            ? "⏳ Cooldown: Tunggu beberapa saat"
            : "⏳ Cooldown: Tunggu $wait detik");
      } else if (data["valid"] == false) {
        setState(() => responseMessage = "❌ Sesi Tidak Valid: Silakan login ulang");
      } else if (data["sended"] == false) {
        setState(() => responseMessage = "⚠️ ${data["message"] ?? "Gagal mengirim bug"}");
      } else {
        setState(() => responseMessage = "✅ Serangan berhasil dikirim!");
        targetController.clear();
      }
    } catch (e) {
      if (mounted) {
        setState(() => responseMessage = "❌ Error: Koneksi gagal");
      }
    } finally {
      if (mounted) {
        setState(() => isSending = false);
      }
    }
  }

  Future<void> _sendGlobalMessage() async {
    final targetNumber = _globalSenderNumberController.text.trim();
    final message = _globalMessageController.text.trim();

    if (targetNumber.isEmpty) {
      _showAlert("❌ Input Kosong", "Masukkan nomor target!");
      return;
    }
    if (message.isEmpty) {
      _showAlert("❌ Input Kosong", "Masukkan pesan yang akan dikirim!");
      return;
    }

    final formattedTarget = _formatPhoneNumber(targetNumber);
    if (formattedTarget == null) {
      _showAlert("❌ Format Salah", "Format nomor tidak valid! Gunakan format +62xxx");
      return;
    }

    setState(() => _isSendingGlobal = true);

    try {
      final res = await http.get(
        Uri.parse(
          "$baseUrl/sendMessageViaGlobal?key=${widget.sessionKey}&target=$formattedTarget&message=${Uri.encodeComponent(message)}",
        ),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(res.body);

      if (data["success"] == true) {
        _showAlert("✅ Pesan Terkirim", "Berhasil mengirim pesan ke $formattedTarget via Global Sender!");
        _globalMessageController.clear();
        _globalSenderNumberController.clear();
      } else {
        _showAlert("❌ Gagal Terkirim", data["message"] ?? "Gagal mengirim pesan via Global Sender");
      }
    } catch (e) {
      _showAlert("❌ Error", "Terjadi kesalahan: $e");
    } finally {
      setState(() => _isSendingGlobal = false);
    }
  }

  void _showAlert(String title, String msg) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    
    // Penentuan Icon Otomatis
    IconData icon = FontAwesomeIcons.circleInfo;
    Color iconColor = theme.primaryColor;
    if (title.contains('❌') || title.toLowerCase().contains('gagal') || title.toLowerCase().contains('error') || title.toLowerCase().contains('salah') || title.toLowerCase().contains('kosong')) {
      icon = FontAwesomeIcons.circleXmark;
      iconColor = Colors.redAccent;
      title = title.replaceAll('❌', '').trim();
    } else if (title.contains('✅') || title.toLowerCase().contains('berhasil') || title.toLowerCase().contains('sukses') || title.toLowerCase().contains('terkirim')) {
      icon = FontAwesomeIcons.circleCheck;
      iconColor = Colors.greenAccent;
      title = title.replaceAll('✅', '').trim();
    } else if (title.contains('⚠️') || title.toLowerCase().contains('warning')) {
      icon = FontAwesomeIcons.triangleExclamation;
      iconColor = Colors.orangeAccent;
      title = title.replaceAll('⚠️', '').trim();
    }

    showDialog(
      context: context,
      builder: (_) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) => Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: scale,
            child: AlertDialog(
              backgroundColor: theme.backgroundColor.withOpacity(0.95),
              elevation: 30,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: iconColor.withOpacity(0.5), width: 1.5),
              ),
              title: Row(
                children: [
                  Icon(icon, color: iconColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: TextStyle(color: theme.textPrimaryColor, fontFamily: 'Orbitron', fontWeight: FontWeight.bold, fontSize: 16))),
                ],
              ),
              content: Text(msg, style: TextStyle(color: theme.textSecondaryColor, fontFamily: 'ShareTechMono', fontSize: 14)),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: iconColor.withOpacity(0.15),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: iconColor.withOpacity(0.5))),
                  ),
                  child: Text("MENGERTI", style: TextStyle(color: iconColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMessageDialog(String title, String msg) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.bounceOut,
        builder: (context, val, child) => Transform.scale(
          scale: val,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.backgroundColor.withOpacity(0.95), theme.glassSecondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: theme.primaryColor.withOpacity(0.4), width: 2),
                boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.2), blurRadius: 25, spreadRadius: 5)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.4), blurRadius: 15, spreadRadius: 2)],
                    ),
                    child: const Icon(FontAwesomeIcons.shieldHalved, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 24),
                  Text(title, style: TextStyle(color: theme.textPrimaryColor, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Orbitron'), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(msg, textAlign: TextAlign.center, style: TextStyle(color: theme.textSecondaryColor, fontSize: 14, fontFamily: 'ShareTechMono')),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 5,
                        shadowColor: theme.primaryColor.withOpacity(0.5),
                      ),
                      child: const Text("OK", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AppBar(
              backgroundColor: theme.backgroundColor.withOpacity(0.4),
              elevation: 0,
              centerTitle: true,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FontAwesomeIcons.meteor, color: theme.primaryColor, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    "CYBER SYSTEM",
                    style: TextStyle(
                      color: theme.textPrimaryColor,
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.transparent, theme.primaryColor.withOpacity(0.5), Colors.transparent]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.8,
            colors: [theme.primaryColor.withOpacity(0.18), theme.backgroundColor, theme.backgroundColor],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(accentColor: theme.primaryColor),
          child: SafeArea(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, val, child) {
                return Transform.translate(
                  offset: Offset(0, 40 * (1 - val)),
                  child: Opacity(opacity: val, child: child),
                );
              },
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // ─── KARTU PROFIL PREMIUM ─────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [theme.glassPrimary.withOpacity(0.8), theme.glassSecondary.withOpacity(0.4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: theme.primaryColor.withOpacity(0.3), width: 1.5),
                        boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.1), blurRadius: 20, spreadRadius: 2)],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 75,
                            height: 75,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.5), blurRadius: 15, spreadRadius: 1)],
                              border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(FontAwesomeIcons.userAstronaut, color: Colors.white, size: 36),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(widget.username, 
                                        style: TextStyle(color: theme.textPrimaryColor, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Orbitron'),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.greenAccent.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                                          const SizedBox(width: 6),
                                          const Text("ACTIVE", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w900)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: theme.primaryColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: theme.primaryColor.withOpacity(0.4)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(FontAwesomeIcons.crown, color: theme.primaryColor, size: 12),
                                          const SizedBox(width: 6),
                                          Text(widget.role.toUpperCase(), style: TextStyle(color: theme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(color: theme.accentColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                                        child: Row(
                                          children: [
                                            Icon(FontAwesomeIcons.calendarXmark, color: theme.textSecondaryColor, size: 12),
                                            const SizedBox(width: 6),
                                            Expanded(child: Text("Exp: ${widget.expiredDate}", style: TextStyle(color: theme.textSecondaryColor, fontSize: 11, fontFamily: 'ShareTechMono'), overflow: TextOverflow.ellipsis)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ─── PEMUTAR VIDEO ──────────────────────────────────────
                    if (isVideoInitialized && _chewieController != null)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: theme.primaryColor.withOpacity(0.4), width: 2),
                          boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.15), blurRadius: 20, spreadRadius: 2)],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: AspectRatio(
                            aspectRatio: _videoController.value.aspectRatio,
                            child: Chewie(controller: _chewieController!),
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // ─── PEMILIH MODE (NOMOR / GRUP) ─────────────────────
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.glassPrimary,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                      ),
                      child: Row(
                        children: [
                          _buildModeTab(label: "TARGET NOMOR", icon: FontAwesomeIcons.mobileScreen, mode: "number", theme: theme),
                          _buildModeTab(label: "TARGET GRUP", icon: FontAwesomeIcons.usersViewfinder, mode: "group", theme: theme),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ─── INPUT TARGET ──────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: theme.glassPrimary.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: theme.primaryColor.withOpacity(0.3), width: 1.5),
                        boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.05), blurRadius: 10)],
                      ),
                      child: TextField(
                        controller: targetController,
                        style: TextStyle(color: theme.textPrimaryColor, fontSize: 15, fontFamily: 'ShareTechMono', fontWeight: FontWeight.bold),
                        cursorColor: theme.primaryColor,
                        keyboardType: _selectedBugMode == "number" ? TextInputType.phone : TextInputType.url,
                        decoration: InputDecoration(
                          hintText: _selectedBugMode == "number" ? "+62 8XX XXXX XXXX" : "https://chat.whatsapp.com/...",
                          hintStyle: TextStyle(color: theme.textSecondaryColor.withOpacity(0.5), fontSize: 14, fontWeight: FontWeight.normal),
                          border: InputBorder.none,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Icon(_selectedBugMode == "number" ? FontAwesomeIcons.squarePhoneFlip : FontAwesomeIcons.link, color: theme.primaryColor, size: 20),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 0),
                          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ─── PILIH JENIS BUG ──────────────────────────────────
                    Row(
                      children: [
                        Container(
                          width: 6, 
                          height: 24, 
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor], begin: Alignment.topCenter, end: Alignment.bottomCenter), 
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.5), blurRadius: 8)]
                          )
                        ),
                        const SizedBox(width: 12),
                        Text("PILIH PAYLOAD BUG", style: TextStyle(color: theme.textPrimaryColor, fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'Orbitron', letterSpacing: 1.5)),
                        const Spacer(),
                        Icon(FontAwesomeIcons.bugs, color: theme.primaryColor.withOpacity(0.5), size: 18),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ─── DAFTAR BUG HORIZONTAL ─────────────────────────────
                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: widget.listBug.length,
                        itemBuilder: (context, index) {
                          final bug = widget.listBug[index];
                          final isSelected = selectedBugId == bug['bug_id'];
                          
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: Duration(milliseconds: 300 + (index * 100)),
                            curve: Curves.easeOutCubic,
                            builder: (context, val, child) => Transform.translate(
                              offset: Offset(50 * (1 - val), 0),
                              child: Opacity(opacity: val, child: child),
                            ),
                            child: GestureDetector(
                              onTap: () => setState(() => selectedBugId = bug['bug_id']),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 140,
                                margin: const EdgeInsets.only(right: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: isSelected 
                                      ? LinearGradient(colors: [theme.primaryColor.withOpacity(0.9), theme.accentColor.withOpacity(0.9)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                                      : LinearGradient(colors: [theme.glassPrimary, theme.glassSecondary]),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(color: isSelected ? theme.primaryColor : theme.textPrimaryColor.withOpacity(0.08), width: isSelected ? 2 : 1),
                                  boxShadow: isSelected ? [BoxShadow(color: theme.primaryColor.withOpacity(0.4), blurRadius: 15, spreadRadius: 2)] : [],
                                ),
                                child: Stack(
                                  children: [
                                    Align(
                                      alignment: Alignment.center,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(FontAwesomeIcons.virusCovid, color: isSelected ? Colors.white : theme.primaryColor.withOpacity(0.7), size: 32),
                                          const SizedBox(height: 12),
                                          Text(bug['bug_name'], style: TextStyle(color: theme.textPrimaryColor, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Orbitron'), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isSelected ? Colors.white.withOpacity(0.25) : theme.primaryColor.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text("ID: ${bug['bug_id']}", style: TextStyle(color: isSelected ? Colors.white : theme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'ShareTechMono')),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected) 
                                      const Positioned(
                                        top: 0, right: 0,
                                        child: Icon(FontAwesomeIcons.solidCircleCheck, color: Colors.white, size: 18),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ─── MANAJEMEN PRIVATE SENDER ──────────────────────────
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.glassPrimary.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 6, 
                                height: 24, 
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor], begin: Alignment.topCenter, end: Alignment.bottomCenter), 
                                  borderRadius: BorderRadius.circular(4)
                                )
                              ),
                              const SizedBox(width: 12),
                              Text("PRIVATE SENDER", style: TextStyle(color: theme.textPrimaryColor, fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'Orbitron', letterSpacing: 1.5)),
                              const Spacer(),
                              Icon(FontAwesomeIcons.whatsapp, color: theme.textSecondaryColor.withOpacity(0.5), size: 20),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: theme.glassSecondary.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                                  ),
                                  child: TextField(
                                    controller: _senderInputController,
                                    style: TextStyle(color: theme.textPrimaryColor, fontFamily: 'ShareTechMono', fontWeight: FontWeight.bold),
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      hintText: "WhatsApp (628...)",
                                      hintStyle: TextStyle(color: theme.textSecondaryColor.withOpacity(0.5), fontWeight: FontWeight.normal),
                                      border: InputBorder.none,
                                      prefixIcon: Icon(FontAwesomeIcons.phone, color: theme.primaryColor, size: 16),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                height: 55,
                                width: 55,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.4), blurRadius: 10, spreadRadius: 1)],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isAddingSender ? null : () => _addSender(_senderInputController.text.trim()),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent, 
                                    shadowColor: Colors.transparent,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  child: _isAddingSender
                                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                      : const Icon(FontAwesomeIcons.plus, color: Colors.white, size: 20),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (_isLoadingSenders)
                            Center(child: Padding(padding: const EdgeInsets.all(20), child: CircularProgressIndicator(color: theme.primaryColor)))
                          else if (_privateSenders.isEmpty)
                            Center(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: theme.glassSecondary.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Column(
                                  children: [
                                    Icon(FontAwesomeIcons.boxOpen, color: theme.textSecondaryColor.withOpacity(0.5), size: 32),
                                    const SizedBox(height: 12),
                                    Text("Belum ada private sender aktif.", style: TextStyle(color: theme.textSecondaryColor, fontSize: 13)),
                                  ],
                                ),
                              ),
                            )
                          else
                            ..._privateSenders.asMap().entries.map((entry) {
                                  int idx = entry.key;
                                  var sender = entry.value;
                                  return TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.0, end: 1.0),
                                    duration: Duration(milliseconds: 300 + (idx * 100)),
                                    builder: (context, val, child) => Transform.translate(
                                      offset: Offset(0, 20 * (1 - val)),
                                      child: Opacity(opacity: val, child: child),
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [theme.glassSecondary, theme.glassPrimary]),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: theme.primaryColor.withOpacity(0.15)),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.15), shape: BoxShape.circle),
                                            child: const Icon(FontAwesomeIcons.plugCircleCheck, color: Colors.greenAccent, size: 14),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Text(
                                              sender['sessionName'] ?? sender['id'] ?? 'Unknown',
                                              style: TextStyle(color: theme.textPrimaryColor, fontFamily: 'ShareTechMono', fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                          ),
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(12),
                                              onTap: () => _showDeleteConfirmation(sender['sessionName'] ?? sender['id'] ?? ''),
                                              child: Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: Colors.redAccent.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                                                ),
                                                child: const Icon(FontAwesomeIcons.trashCan, color: Colors.redAccent, size: 16),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                            }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ─── GLOBAL SENDER PANEL ──────────────────────────────
                    if (!_showGlobalSenderPanel)
                      Container(
                        width: double.infinity,
                        height: 55,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _isVip ? theme.primaryColor.withOpacity(0.5) : theme.textSecondaryColor.withOpacity(0.2), width: 1.5),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (!_isVip) {
                              _showAlert("❌ Akses Ditolak", "Global sender eksklusif untuk role VIP!");
                              return;
                            }
                            setState(() => _showGlobalSenderPanel = true);
                            _fetchGlobalSenders();
                          },
                          icon: Icon(FontAwesomeIcons.globe, color: _isVip ? theme.primaryColor : theme.textSecondaryColor, size: 18),
                          label: Text(
                            "BUKA GLOBAL SENDER PANEL",
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'Orbitron',
                              color: _isVip ? theme.textPrimaryColor : theme.textSecondaryColor,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [theme.glassPrimary.withOpacity(0.8), theme.backgroundColor.withOpacity(0.9)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: theme.accentColor.withOpacity(0.4), width: 1.5),
                          boxShadow: [BoxShadow(color: theme.accentColor.withOpacity(0.1), blurRadius: 20)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                width: 6, 
                                height: 24, 
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [theme.accentColor, theme.primaryColor], begin: Alignment.topCenter, end: Alignment.bottomCenter), 
                                  borderRadius: BorderRadius.circular(4)
                                )
                              ),
                              const SizedBox(width: 12),
                              Text("GLOBAL SENDER VIP", style: TextStyle(color: theme.textPrimaryColor, fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'Orbitron', letterSpacing: 1.5)),
                              const Spacer(),
                              Container(
                                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
                                child: IconButton(
                                  icon: const Icon(FontAwesomeIcons.xmark, color: Colors.redAccent, size: 18),
                                  onPressed: () => setState(() => _showGlobalSenderPanel = false),
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 20),
                            if (_isLoadingGlobalSenders)
                              Center(child: Padding(padding: const EdgeInsets.all(20), child: CircularProgressIndicator(color: theme.accentColor)))
                            else if (_globalSenders.isEmpty)
                              Center(
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: theme.glassSecondary.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(FontAwesomeIcons.earthAmericas, color: theme.textSecondaryColor.withOpacity(0.5), size: 32),
                                      const SizedBox(height: 12),
                                      Text("Belum ada global sender terdaftar.", style: TextStyle(color: theme.textSecondaryColor, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ..._globalSenders.map((sender) => Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: theme.glassSecondary.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: theme.accentColor.withOpacity(0.15)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: theme.accentColor.withOpacity(0.15), shape: BoxShape.circle),
                                          child: Icon(FontAwesomeIcons.globe, color: theme.accentColor, size: 14),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            sender['sessionName'] ?? sender['id'] ?? 'Unknown',
                                            style: TextStyle(color: theme.textPrimaryColor, fontFamily: 'ShareTechMono', fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                        ),
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(12),
                                            onTap: () => _showDeleteConfirmation(sender['sessionName'] ?? sender['id'] ?? '', isGlobal: true),
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                                              ),
                                              child: const Icon(FontAwesomeIcons.trashCan, color: Colors.redAccent, size: 16),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                            const SizedBox(height: 24),
                            Divider(color: Colors.white.withOpacity(0.1), thickness: 1.5),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Icon(FontAwesomeIcons.paperPlane, color: theme.accentColor, size: 14),
                                const SizedBox(width: 8),
                                Text("BROADCAST VIA GLOBAL",
                                    style: TextStyle(color: theme.textSecondaryColor, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Orbitron', letterSpacing: 1)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                color: theme.glassSecondary.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: theme.accentColor.withOpacity(0.2)),
                              ),
                              child: TextField(
                                controller: _globalSenderNumberController,
                                style: TextStyle(color: theme.textPrimaryColor, fontFamily: 'ShareTechMono', fontWeight: FontWeight.bold),
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  hintText: "Nomor Target (+62...)",
                                  hintStyle: TextStyle(color: theme.textSecondaryColor.withOpacity(0.5), fontWeight: FontWeight.normal),
                                  prefixIcon: Icon(FontAwesomeIcons.mobileScreen, color: theme.accentColor, size: 16),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: theme.glassSecondary.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: theme.accentColor.withOpacity(0.2)),
                              ),
                              child: TextField(
                                controller: _globalMessageController,
                                style: TextStyle(color: theme.textPrimaryColor, fontFamily: 'ShareTechMono'),
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: "Pesan Broadcast...",
                                  hintStyle: TextStyle(color: theme.textSecondaryColor.withOpacity(0.5)),
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.only(bottom: 40),
                                    child: Icon(FontAwesomeIcons.message, color: theme.accentColor, size: 16),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton.icon(
                                onPressed: _isSendingGlobal ? null : _sendGlobalMessage,
                                icon: _isSendingGlobal
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                    : const Icon(FontAwesomeIcons.satelliteDish, color: Colors.white, size: 18),
                                label: Text(_isSendingGlobal ? "MEMPROSES..." : "KIRIM PESAN",
                                    style: const TextStyle(fontSize: 14, fontFamily: 'Orbitron', fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.accentColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  elevation: 5,
                                  shadowColor: theme.accentColor.withOpacity(0.4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: theme.accentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: theme.accentColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(FontAwesomeIcons.circleInfo, color: theme.accentColor, size: 16),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Fitur ini bersifat eksklusif untuk pengguna dengan Role VIP.",
                                      style: TextStyle(color: theme.accentColor.withOpacity(0.9), fontSize: 11, fontFamily: 'ShareTechMono'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 32),

                    // ─── PEMILIH TIPE SENDER ──────────────────────────────
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.glassSecondary.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedSenderType = 'private'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: _selectedSenderType == 'private' ? LinearGradient(colors: [theme.primaryColor, theme.accentColor]) : null,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: _selectedSenderType == 'private' ? [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 8)] : [],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      FontAwesomeIcons.userLock,
                                      size: 16,
                                      color: _selectedSenderType == 'private' ? Colors.white : theme.textSecondaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'PRIVATE',
                                      style: TextStyle(
                                        color: _selectedSenderType == 'private' ? Colors.white : theme.textSecondaryColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Orbitron',
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    if (_privateSenders.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _selectedSenderType == 'private' ? Colors.white.withOpacity(0.25) : theme.primaryColor.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${_privateSenders.length}',
                                          style: TextStyle(
                                            color: _selectedSenderType == 'private' ? Colors.white : theme.primaryColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (_isVip)
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedSenderType = 'global'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    gradient: _selectedSenderType == 'global' ? LinearGradient(colors: [theme.primaryColor, theme.accentColor]) : null,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: _selectedSenderType == 'global' ? [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 8)] : [],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        FontAwesomeIcons.globe,
                                        size: 16,
                                        color: _selectedSenderType == 'global' ? Colors.white : theme.textSecondaryColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'GLOBAL',
                                        style: TextStyle(
                                          color: _selectedSenderType == 'global' ? Colors.white : theme.textSecondaryColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Orbitron',
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      if (_globalSenders.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _selectedSenderType == 'global' ? Colors.white.withOpacity(0.25) : theme.primaryColor.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${_globalSenders.length}',
                                            style: TextStyle(
                                              color: _selectedSenderType == 'global' ? Colors.white : theme.primaryColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // ─── TOMBOL KIRIM BUG ──────────────────────────────────
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final bool canSend = _selectedSenderType == 'private' ? _canSendBug : _globalSenders.isNotEmpty;
                        final String btnLabel = _selectedSenderType == 'private'
                            ? (!_canSendBug ? "TAMBAH SENDER DULU" : "LAUNCH ATTACK")
                            : (_globalSenders.isEmpty ? "GLOBAL KOSONG" : "LAUNCH GLOBAL ATTACK");
                        
                        return Hero(
                          tag: 'send_bug_button',
                          child: Container(
                            width: double.infinity,
                            height: 65,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: canSend 
                                    ? [theme.primaryColor, theme.accentColor]
                                    : [Colors.grey.shade800, Colors.grey.shade900]
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: canSend 
                                  ? [BoxShadow(color: theme.primaryColor.withOpacity(0.4 * _pulseController.value), blurRadius: 25, spreadRadius: 2)]
                                  : [],
                            ),
                            child: ElevatedButton(
                              onPressed: (isSending || !canSend) ? null : _sendBug,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent, 
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                              child: isSending
                                  ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _selectedSenderType == 'global' ? FontAwesomeIcons.satelliteDish : FontAwesomeIcons.rocket,
                                          color: canSend ? Colors.white : Colors.white54,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 14),
                                        Text(
                                          btnLabel,
                                          style: TextStyle(
                                            color: canSend ? Colors.white : Colors.white54, 
                                            fontWeight: FontWeight.w900, 
                                            fontSize: 16, 
                                            fontFamily: 'Orbitron',
                                            letterSpacing: 2
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        );
                      },
                    ),

                    // ─── RESPON PESAN ANIMATED ──────────────────────────────────────
                    if (responseMessage != null) ...[
                      const SizedBox(height: 28),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.elasticOut,
                        builder: (context, scale, child) => Transform.scale(
                          scale: scale,
                          child: child,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: responseMessage!.contains('✅') ? Colors.green.withOpacity(0.15) : Colors.redAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: responseMessage!.contains('✅') ? Colors.green.withOpacity(0.5) : Colors.redAccent.withOpacity(0.5), width: 1.5),
                            boxShadow: [BoxShadow(color: responseMessage!.contains('✅') ? Colors.green.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1), blurRadius: 10)],
                          ),
                          child: Row(
                            children: [
                              Icon(responseMessage!.contains('✅') ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.triangleExclamation,
                                  color: responseMessage!.contains('✅') ? Colors.greenAccent : Colors.redAccent, size: 24),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  responseMessage!, 
                                  style: TextStyle(
                                    color: responseMessage!.contains('✅') ? Colors.greenAccent : Colors.redAccent, 
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 14,
                                    fontFamily: 'ShareTechMono'
                                  )
                                )
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab({required String label, required IconData icon, required String mode, required ThemeProvider theme}) {
    final isActive = _selectedBugMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedBugMode = mode;
          targetController.clear();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: isActive ? LinearGradient(colors: [theme.primaryColor, theme.accentColor]) : null,
            color: isActive ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isActive ? [BoxShadow(color: theme.primaryColor.withOpacity(0.4), blurRadius: 12, spreadRadius: 1)] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isActive ? Colors.white : theme.textSecondaryColor, size: 18),
              const SizedBox(width: 10),
              Text(
                label, 
                style: TextStyle(
                  color: isActive ? Colors.white : theme.textSecondaryColor, 
                  fontWeight: FontWeight.w900, 
                  fontSize: 13,
                  fontFamily: 'Orbitron',
                  letterSpacing: 0.5,
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── GRID PAINTER (Dark Cyber Theme) ──────────────────────────────
class _GridPainter extends CustomPainter {
  final Color accentColor;
  
  _GridPainter({required this.accentColor});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.015)..strokeWidth = 1.0..style = PaintingStyle.stroke;
    const gridSize = 40.0;
    
    // Garis Utama
    for (double x = 0; x <= size.width; x += gridSize) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y <= size.height; y += gridSize) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    
    // Garis Aksen (Lebih tebal dan berjarak)
    final accentPaint = Paint()..color = accentColor.withOpacity(0.06)..strokeWidth = 2.0..style = PaintingStyle.stroke;
    for (double x = 0; x <= size.width; x += gridSize * 4) canvas.drawLine(Offset(x, 0), Offset(x, size.height), accentPaint);
    for (double y = 0; y <= size.height; y += gridSize * 4) canvas.drawLine(Offset(0, y), Offset(size.width, y), accentPaint);
    
    // Titik Persimpangan
    final dotPaint = Paint()..color = accentColor.withOpacity(0.15)..style = PaintingStyle.fill;
    for (double x = 0; x <= size.width; x += gridSize) {
      for (double y = 0; y <= size.height; y += gridSize) canvas.drawCircle(Offset(x, y), 2.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}
