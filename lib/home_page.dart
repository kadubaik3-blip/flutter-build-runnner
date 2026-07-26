import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  static const String baseUrl = "http://server.lynzzofficial.com:2014";
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
      builder: (_) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: theme.primaryColor.withOpacity(0.4), width: 1),
        ),
        title: Row(children: [
          Icon(FontAwesomeIcons.whatsapp, color: theme.primaryColor, size: 20),
          const SizedBox(width: 10),
          Text("Pairing Private Sender",
              style: TextStyle(color: theme.textPrimaryColor, fontFamily: 'Orbitron', fontSize: 14)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("Masukkan kode ini di WhatsApp nomor:",
              style: TextStyle(color: theme.textSecondaryColor, fontFamily: 'ShareTechMono', fontSize: 12)),
          const SizedBox(height: 4),
          Text(number,
              style: TextStyle(color: theme.primaryColor, fontFamily: 'ShareTechMono', fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.primaryColor.withOpacity(0.4)),
            ),
            child: Text(formatted,
                style: TextStyle(color: theme.textPrimaryColor, fontFamily: 'Orbitron', fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 8)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: theme.glassSecondary, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _pairingStep("1", "Buka WhatsApp di HP nomor $number", theme),
              _pairingStep("2", "Ketuk ⋮ Menu → Perangkat Tertaut", theme),
              _pairingStep("3", "Ketuk \"Tautkan dengan nomor telepon\"", theme),
              _pairingStep("4", "Masukkan kode di atas", theme),
            ]),
          ),
          const SizedBox(height: 12),
          Text("Kode berlaku ±60 detik.",
              style: TextStyle(color: theme.textSecondaryColor, fontFamily: 'ShareTechMono', fontSize: 10),
              textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _fetchSenders();
            },
            child: Text("Selesai", style: TextStyle(color: theme.primaryColor, fontFamily: 'Orbitron'))),
        ],
      ),
    );
  }

  Widget _pairingStep(String step, String text, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.2), shape: BoxShape.circle),
          child: Text(step,
              style: TextStyle(color: theme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(color: theme.textSecondaryColor, fontFamily: 'ShareTechMono', fontSize: 11)),
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
      builder: (_) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: theme.primaryColor.withOpacity(0.4), width: 1),
        ),
        title: Text("⚠️ Konfirmasi Hapus",
            style: TextStyle(color: theme.textPrimaryColor, fontFamily: 'Orbitron', fontSize: 15)),
        content: Text("Hapus ${isGlobal ? 'global' : 'private'} sender $number dari daftar?",
            style: TextStyle(color: theme.textSecondaryColor, fontFamily: 'ShareTechMono')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Batal", style: TextStyle(color: theme.textSecondaryColor))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (isGlobal) {
                _deleteGlobalSender(number);
              } else {
                _deleteSender(number);
              }
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red))),
        ],
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
          "Nomor Tidak Valid",
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
      _showAlert("❌ Tidak Ada Private Sender", "Tambahkan private sender terlebih dahulu!");
      return;
    }
    if (_selectedSenderType == 'global' && _globalSenders.isEmpty) {
      _showAlert("❌ Tidak Ada Global Sender", "Belum ada global sender aktif. Hubungi owner!");
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
      _showAlert("❌ Error", "Masukkan nomor target!");
      return;
    }
    if (message.isEmpty) {
      _showAlert("❌ Error", "Masukkan pesan yang akan dikirim!");
      return;
    }

    final formattedTarget = _formatPhoneNumber(targetNumber);
    if (formattedTarget == null) {
      _showAlert("❌ Error", "Format nomor tidak valid! Gunakan format +62xxx");
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
        _showAlert("✅ Berhasil", "Pesan berhasil dikirim ke $formattedTarget via Global Sender!");
        _globalMessageController.clear();
        _globalSenderNumberController.clear();
      } else {
        _showAlert("❌ Gagal", data["message"] ?? "Gagal mengirim pesan via Global Sender");
      }
    } catch (e) {
      _showAlert("❌ Error", "Terjadi kesalahan: $e");
    } finally {
      setState(() => _isSendingGlobal = false);
    }
  }

  void _showAlert(String title, String msg) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: theme.primaryColor.withOpacity(0.3), width: 1),
        ),
        title: Text(title, style: TextStyle(color: theme.textPrimaryColor, fontFamily: 'Orbitron')),
        content: Text(msg, style: TextStyle(color: theme.textSecondaryColor, fontFamily: 'ShareTechMono')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: TextStyle(color: theme.primaryColor))),
        ],
      ),
    );
  }

  void _showMessageDialog(String title, String msg) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.backgroundColor, theme.backgroundColor.withOpacity(0.95)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: theme.primaryColor.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 20),
              Text(title, style: TextStyle(color: theme.textPrimaryColor, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(msg, textAlign: TextAlign.center, style: TextStyle(color: theme.textSecondaryColor, fontSize: 14)),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(child: Text("OK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ),
              ),
            ],
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
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [theme.primaryColor.withOpacity(0.15), theme.backgroundColor, theme.backgroundColor],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _GridPainter(accentColor: theme.primaryColor),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ─── KARTU PROFIL ─────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [theme.glassPrimary, theme.glassSecondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.4), blurRadius: 20)],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.person, color: theme.textPrimaryColor, size: 40),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.username, style: TextStyle(color: theme.textPrimaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                                    ),
                                    child: Text(widget.role.toUpperCase(), style: TextStyle(color: theme.primaryColor, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(color: theme.accentColor.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                                    child: Text("Exp: ${widget.expiredDate}", style: TextStyle(color: theme.textSecondaryColor, fontSize: 11)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── PEMUTAR VIDEO ──────────────────────────────────────
                  if (isVideoInitialized && _chewieController != null)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: theme.primaryColor.withOpacity(0.3), width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: AspectRatio(
                          aspectRatio: _videoController.value.aspectRatio,
                          child: Chewie(controller: _chewieController!),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // ─── PEMILIH MODE (NOMOR / GRUP) ─────────────────────
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.glassPrimary,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        _buildModeTab(label: "NOMOR", icon: Icons.phone_android_rounded, mode: "number", theme: theme),
                        _buildModeTab(label: "GRUP", icon: Icons.group_rounded, mode: "group", theme: theme),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── INPUT TARGET ──────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: theme.glassPrimary,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                    ),
                    child: TextField(
                      controller: targetController,
                      style: TextStyle(color: theme.textPrimaryColor, fontSize: 14),
                      cursorColor: theme.primaryColor,
                      keyboardType: _selectedBugMode == "number" ? TextInputType.phone : TextInputType.url,
                      decoration: InputDecoration(
                        hintText: _selectedBugMode == "number" ? "+62xxxxxxxxxx" : "https://chat.whatsapp.com/...",
                        hintStyle: TextStyle(color: theme.textSecondaryColor.withOpacity(0.5), fontSize: 13),
                        border: InputBorder.none,
                        prefixIcon: Icon(_selectedBugMode == "number" ? Icons.phone_android_rounded : Icons.link_rounded, color: theme.primaryColor, size: 20),
                        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── PILIH JENIS BUG ──────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 4, 
                        height: 20, 
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]), 
                          borderRadius: BorderRadius.circular(2)
                        )
                      ),
                      const SizedBox(width: 8),
                      Text("PILIH JENIS BUG", style: TextStyle(color: theme.textSecondaryColor, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ─── DAFTAR BUG HORIZONTAL ─────────────────────────────
                  SizedBox(
                    height: 130,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: widget.listBug.length,
                      itemBuilder: (context, index) {
                        final bug = widget.listBug[index];
                        final isSelected = selectedBugId == bug['bug_id'];
                        return GestureDetector(
                          onTap: () => setState(() => selectedBugId = bug['bug_id']),
                          child: Container(
                            width: 140,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: isSelected 
                                  ? LinearGradient(colors: [theme.primaryColor, theme.accentColor])
                                  : LinearGradient(colors: [theme.glassPrimary, theme.glassSecondary]),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: isSelected ? theme.primaryColor : theme.textPrimaryColor.withOpacity(0.08), width: isSelected ? 1.5 : 1),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: isSelected 
                                        ? LinearGradient(colors: [theme.primaryColor, theme.accentColor])
                                        : null,
                                    color: isSelected ? null : theme.glassSecondary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.bug_report, color: isSelected ? Colors.white : theme.primaryColor, size: 24),
                                ),
                                const SizedBox(height: 8),
                                Text(bug['bug_name'], style: TextStyle(color: theme.textPrimaryColor, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center, maxLines: 2),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white.withOpacity(0.2) : theme.primaryColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text("ID: ${bug['bug_id']}", style: TextStyle(color: isSelected ? Colors.white : theme.primaryColor, fontSize: 9, fontWeight: FontWeight.w600)),
                                ),
                                if (isSelected) const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.check_circle, color: Colors.green, size: 14)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── MANAJEMEN PRIVATE SENDER ──────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.glassPrimary,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 4, 
                              height: 20, 
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]), 
                                borderRadius: BorderRadius.circular(2)
                              )
                            ),
                            const SizedBox(width: 8),
                            Text("PRIVATE SENDER (WHATSAPP)", style: TextStyle(color: theme.textSecondaryColor, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.glassSecondary,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: theme.textPrimaryColor.withOpacity(0.1)),
                                ),
                                child: TextField(
                                  controller: _senderInputController,
                                  style: TextStyle(color: theme.textPrimaryColor),
                                  decoration: InputDecoration(
                                    hintText: "Nomor WhatsApp (628xxxx)",
                                    hintStyle: TextStyle(color: theme.textSecondaryColor.withOpacity(0.5)),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 8)],
                              ),
                              child: ElevatedButton(
                                onPressed: _isAddingSender ? null : () => _addSender(_senderInputController.text.trim()),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                                child: _isAddingSender
                                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.add, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isLoadingSenders)
                          Center(child: CircularProgressIndicator(color: theme.primaryColor))
                        else if (_privateSenders.isEmpty)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: theme.glassSecondary, borderRadius: BorderRadius.circular(16)),
                              child: Text("Belum ada private sender terdaftar", style: TextStyle(color: theme.textSecondaryColor, fontSize: 12)),
                            ),
                          )
                        else
                          ..._privateSenders.map((sender) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: theme.glassSecondary,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: theme.textPrimaryColor.withOpacity(0.05)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        sender['sessionName'] ?? sender['id'] ?? 'Unknown',
                                        style: TextStyle(color: theme.textPrimaryColor),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _showDeleteConfirmation(sender['sessionName'] ?? sender['id'] ?? ''),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: theme.primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                                        ),
                                        child: Icon(Icons.delete_outline, color: theme.primaryColor, size: 18),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── GLOBAL SENDER PANEL ──────────────────────────────
                  if (!_showGlobalSenderPanel)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          if (!_isVip) {
                            _showAlert("❌ Akses Ditolak", "Global sender hanya untuk role VIP!");
                            return;
                          }
                          setState(() => _showGlobalSenderPanel = true);
                          _fetchGlobalSenders();
                        },
                        icon: Icon(FontAwesomeIcons.globe, color: theme.textSecondaryColor, size: 15),
                        label: Text(
                          "BUKA GLOBAL SENDER",
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Orbitron',
                            color: _isVip ? theme.textSecondaryColor : theme.textSecondaryColor.withOpacity(0.5),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: theme.textSecondaryColor.withOpacity(_isVip ? 0.2 : 0.1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.glassPrimary,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              width: 4, 
                              height: 20, 
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]), 
                                borderRadius: BorderRadius.circular(2)
                              )
                            ),
                            const SizedBox(width: 8),
                            Text("GLOBAL SENDER (WHATSAPP)", style: TextStyle(color: theme.textPrimaryColor, fontSize: 14, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            IconButton(
                              icon: Icon(Icons.close, color: theme.textSecondaryColor, size: 18),
                              onPressed: () => setState(() => _showGlobalSenderPanel = false),
                              padding: EdgeInsets.zero,
                            ),
                          ]),
                          const SizedBox(height: 12),
                          if (_isLoadingGlobalSenders)
                            Center(child: CircularProgressIndicator(color: theme.primaryColor))
                          else if (_globalSenders.isEmpty)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: theme.glassSecondary, borderRadius: BorderRadius.circular(16)),
                                child: Text("Belum ada global sender terdaftar", style: TextStyle(color: theme.textSecondaryColor, fontSize: 12)),
                              ),
                            )
                          else
                            ..._globalSenders.map((sender) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: theme.glassSecondary,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: theme.textPrimaryColor.withOpacity(0.05)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          sender['sessionName'] ?? sender['id'] ?? 'Unknown',
                                          style: TextStyle(color: theme.textPrimaryColor),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => _showDeleteConfirmation(sender['sessionName'] ?? sender['id'] ?? '', isGlobal: true),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: theme.primaryColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                                          ),
                                          child: Icon(Icons.delete_outline, color: theme.primaryColor, size: 18),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          const SizedBox(height: 16),
                          const Divider(color: Colors.white12),
                          const SizedBox(height: 12),
                          Text("KIRIM PESAN VIA GLOBAL SENDER",
                              style: TextStyle(color: theme.textSecondaryColor, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: theme.glassSecondary,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: theme.textPrimaryColor.withOpacity(0.1)),
                            ),
                            child: TextField(
                              controller: _globalSenderNumberController,
                              style: TextStyle(color: theme.textPrimaryColor),
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                hintText: "Nomor Target (+62xxxxxxxxxx)",
                                hintStyle: TextStyle(color: theme.textSecondaryColor.withOpacity(0.5)),
                                prefixIcon: Icon(Icons.phone, color: theme.primaryColor, size: 20),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: theme.glassSecondary,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: theme.textPrimaryColor.withOpacity(0.1)),
                            ),
                            child: TextField(
                              controller: _globalMessageController,
                              style: TextStyle(color: theme.textPrimaryColor),
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: "Pesan yang akan dikirim",
                                hintStyle: TextStyle(color: theme.textSecondaryColor.withOpacity(0.5)),
                                prefixIcon: Icon(Icons.message, color: theme.primaryColor, size: 20),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: _isSendingGlobal ? null : _sendGlobalMessage,
                              icon: _isSendingGlobal
                                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(FontAwesomeIcons.paperPlane, color: Colors.white, size: 14),
                              label: Text(_isSendingGlobal ? "MENGIRIM..." : "KIRIM PESAN",
                                  style: const TextStyle(fontSize: 12, fontFamily: 'Orbitron', fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.withOpacity(0.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.green.withOpacity(0.4))),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: theme.primaryColor, size: 14),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Global sender hanya bisa digunakan oleh role VIP",
                                    style: TextStyle(color: theme.primaryColor.withOpacity(0.8), fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // ─── PEMILIH TIPE SENDER ──────────────────────────────
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.glassSecondary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedSenderType = 'private'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedSenderType == 'private'
                                    ? theme.primaryColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_rounded,
                                    size: 14,
                                    color: _selectedSenderType == 'private'
                                        ? Colors.white
                                        : theme.textSecondaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'PRIVATE',
                                    style: TextStyle(
                                      color: _selectedSenderType == 'private'
                                          ? Colors.white
                                          : theme.textSecondaryColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  if (_privateSenders.isNotEmpty) ...[
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: _selectedSenderType == 'private'
                                            ? Colors.white24
                                            : theme.primaryColor.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${_privateSenders.length}',
                                        style: TextStyle(
                                          color: _selectedSenderType == 'private'
                                              ? Colors.white
                                              : theme.primaryColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
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
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _selectedSenderType == 'global'
                                      ? theme.primaryColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.public_rounded,
                                      size: 14,
                                      color: _selectedSenderType == 'global'
                                          ? Colors.white
                                          : theme.textSecondaryColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'GLOBAL',
                                      style: TextStyle(
                                        color: _selectedSenderType == 'global'
                                            ? Colors.white
                                            : theme.textSecondaryColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    if (_globalSenders.isNotEmpty) ...[
                                      const SizedBox(width: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: _selectedSenderType == 'global'
                                              ? Colors.white24
                                              : theme.primaryColor.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${_globalSenders.length}',
                                          style: TextStyle(
                                            color: _selectedSenderType == 'global'
                                                ? Colors.white
                                                : theme.primaryColor,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
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
                      final bool canSend = _selectedSenderType == 'private'
                          ? _canSendBug
                          : _globalSenders.isNotEmpty;
                      final String btnLabel = _selectedSenderType == 'private'
                          ? (!_canSendBug ? "TAMBAH PRIVATE SENDER DULU" : "KIRIM SERANGAN BUG")
                          : (_globalSenders.isEmpty ? "GLOBAL SENDER KOSONG" : "KIRIM BUG (GLOBAL)");
                      return Container(
                        width: double.infinity,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [theme.primaryColor, theme.accentColor]),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.3 * _pulseController.value), blurRadius: 20, spreadRadius: 1)],
                        ),
                        child: ElevatedButton(
                          onPressed: (isSending || !canSend) ? null : _sendBug,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                          child: isSending
                              ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _selectedSenderType == 'global'
                                          ? Icons.public_rounded
                                          : Icons.rocket_launch_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      btnLabel,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),

                  // ─── RESPON PESAN ──────────────────────────────────────
                  if (responseMessage != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: responseMessage!.contains('✅') ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: responseMessage!.contains('✅') ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(responseMessage!.contains('✅') ? Icons.check_circle : Icons.error,
                              color: responseMessage!.contains('✅') ? Colors.green : Colors.red, size: 22),
                          const SizedBox(width: 14),
                          Expanded(child: Text(responseMessage!, style: TextStyle(color: responseMessage!.contains('✅') ? Colors.green : Colors.red, fontWeight: FontWeight.w600, fontSize: 13))),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),
                ],
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isActive ? LinearGradient(colors: [theme.primaryColor, theme.accentColor]) : null,
            color: isActive ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            boxShadow: isActive ? [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 8)] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isActive ? Colors.white : theme.textSecondaryColor, size: 18),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(color: isActive ? Colors.white : theme.textSecondaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── GRID PAINTER (menggunakan warna tema) ──────────────────────────────
class _GridPainter extends CustomPainter {
  final Color accentColor;
  
  _GridPainter({required this.accentColor});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.02)..strokeWidth = 0.8..style = PaintingStyle.stroke;
    const gridSize = 30.0;
    for (double x = 0; x <= size.width; x += gridSize) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y <= size.height; y += gridSize) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    
    final accentPaint = Paint()..color = accentColor.withOpacity(0.08)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    for (double x = 0; x <= size.width; x += gridSize * 5) canvas.drawLine(Offset(x, 0), Offset(x, size.height), accentPaint);
    for (double y = 0; y <= size.height; y += gridSize * 5) canvas.drawLine(Offset(0, y), Offset(size.width, y), accentPaint);
    
    final dotPaint = Paint()..color = accentColor.withOpacity(0.1)..style = PaintingStyle.fill;
    for (double x = 0; x <= size.width; x += gridSize) {
      for (double y = 0; y <= size.height; y += gridSize) canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}