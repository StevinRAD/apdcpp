import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:apdcpp/konfigurasi_api.dart';
import 'package:apdcpp/karyawan/dashboard_karyawan_aturan_helper.dart';
import 'package:apdcpp/karyawan/layar_detail_berita_karyawan.dart';
import 'package:apdcpp/karyawan/layar_kalender_karyawan.dart';
import 'package:apdcpp/karyawan/layar_pengajuan_dokumen_apd.dart';
import 'package:apdcpp/karyawan/layar_katalog_apd_karyawan.dart';
import 'package:apdcpp/karyawan/layar_notifikasi_karyawan.dart';
import 'package:apdcpp/karyawan/layar_profil_karyawan.dart';
import 'package:apdcpp/karyawan/layar_lapor_kendala_karyawan.dart';
import 'package:apdcpp/karyawan/layar_riwayat_pengajuan_karyawan.dart';
import 'package:apdcpp/karyawan/layar_daftar_dokumen_penerimaan_karyawan.dart';
import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/services/sesi_aplikasi_service.dart';
import 'package:apdcpp/awal/layar_pilih_peran.dart';
import 'package:apdcpp/services/tutorial_aplikasi_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';
import 'package:apdcpp/widgets/dialog_tutorial_aplikasi.dart';
import 'package:apdcpp/services/single_device_session_service.dart';
import 'package:apdcpp/services/notifikasi_lokal_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LayarDashboardKaryawan extends StatefulWidget {
  final String namaLengkap;
  final String username;
  final String? fotoProfil;

  const LayarDashboardKaryawan({
    super.key,
    required this.namaLengkap,
    required this.username,
    this.fotoProfil,
  });

  @override
  State<LayarDashboardKaryawan> createState() => _LayarDashboardKaryawanState();
}

class _LayarDashboardKaryawanState extends State<LayarDashboardKaryawan> {
  final ApiApdService _api = const ApiApdService();
  final PageController _beritaPageController = PageController(
    viewportFraction: 0.92,
  );
  final GlobalKey _tutorialHeaderKey = GlobalKey();
  final GlobalKey _tutorialQuickActionKey = GlobalKey();
  final GlobalKey _tutorialStatusKey = GlobalKey();
  final GlobalKey _tutorialBottomNavKey = GlobalKey();

  bool _loading = true;
  int _selectedIndex = 0;
  late String _namaLengkap;
  late String _username;
  String? _fotoProfil;
  Map<String, dynamic>? _pengajuanTerakhir;
  Map<String, dynamic> _aturanPengajuan = const {};
  List<Map<String, dynamic>> _beritaUtamaData = [];
  Timer? _beritaAutoSlideTimer;
  int _beritaAktifIndex = 0;
  bool _tutorialSudahDicek = false;

  int _notifBelumDibaca = 0;

  Timer? _sesiTimer;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _namaLengkap = widget.namaLengkap;
    _username = widget.username;
    _fotoProfil = widget.fotoProfil;
    _loadDashboard();
    _cekTutorialKaryawanPertamaKali();
    _mulaiCekSesi();
    _mulaiRealtimeNotifikasi();
  }

  @override
  void dispose() {
    _sesiTimer?.cancel();
    _beritaAutoSlideTimer?.cancel();
    _beritaPageController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _mulaiCekSesi() {
    _sesiTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final sesi = await SesiAplikasiService.ambilSesi();
      if (sesi == null || !mounted) return;

      final token = sesi['session_token'];
      if (token == null) return;

      final res = await _api.cekSesi(
        peran: 'karyawan',
        username: _username,
        sessionToken: token,
      );

      if (!mounted) return;

      if (res['status'] == 'expired') {
        _sesiTimer?.cancel();
        _paksaLogout();
      }
    });
  }

  void _mulaiRealtimeNotifikasi() async {
    _realtimeChannel?.unsubscribe();

    // Pastikan session ada untuk ambil ID Karyawan untuk filter realtime
    final sesi = await SesiAplikasiService.ambilSesi();
    if (sesi == null || !mounted) return;
    final String? idKaryawan = sesi['user_id']?.toString();
    if (idKaryawan == null) return;

    _realtimeChannel = _api.supabase.channel('public:karyawan_updates');

    // Listener 1: Notifikasi Personal Karyawan
    _realtimeChannel?.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifikasi_karyawan',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id_karyawan',
        value: idKaryawan,
      ),
      callback: (payload) async {
        if (!mounted) return;
        final dataJson = payload.newRecord['isi']?.toString() ?? '{}';
        Map<String, dynamic> isiMap = {};
        try {
          isiMap = Map<String, dynamic>.from(jsonDecode(dataJson));
        } catch (_) {}

        final judul = isiMap['judul'] ?? 'Notifikasi Baru';
        final pesan = isiMap['pesan'] ?? 'Ada pembaruan data untuk Anda.';

        await NotifikasiLokalService.tampilkanNotifikasi(
          id: DateTime.now().millisecondsSinceEpoch % 100000,
          judul: judul,
          isi: pesan,
          payload: 'notifikasi_baru',
        );
        _loadDashboard();
      },
    );

    // Listener 2: Update Kalender Perusahaan
    _realtimeChannel?.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'kalender_perusahaan',
      callback: (payload) async {
        if (!mounted) return;

        // Jika ada penambahan baru, munculkan notifikasi
        if (payload.eventType == PostgresChangeEvent.insert) {
          final judul = payload.newRecord['judul']?.toString() ?? 'Agenda Baru';
          await NotifikasiLokalService.tampilkanNotifikasi(
            id: DateTime.now().millisecondsSinceEpoch % 100000,
            judul: 'Agenda Perusahaan Baru',
            isi: 'Ada agenda baru: $judul. Cek kalender Anda.',
            payload: 'kalender_baru',
          );
        }

        // Selalu refresh dashboard agar info kalender terbaru muncul
        _loadDashboard();
      },
    );

    // Listener 3: Update Dokumen Pengajuan (untuk real-time status pengajuan)
    _realtimeChannel?.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'dokumen_pengajuan',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id_karyawan',
        value: idKaryawan,
      ),
      callback: (payload) async {
        if (!mounted) return;
        // Refresh dashboard agar status pengajuan terbaru muncul
        _loadDashboard();
      },
    );

    _realtimeChannel?.subscribe();
  }

  void _paksaLogout() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false, // Menghalangi tombol kembali untuk menutup dialog ini
        child: AlertDialog(
          title: const Text(
            'Sesi Berakhir',
            style: TextStyle(color: TemaAplikasi.bahaya),
          ),
          content: const Text(
            'Akun sedang digunakan di device berbeda atau sesi telah berakhir. Silakan login kembali.',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: TemaAplikasi.bahaya,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await SesiAplikasiService.hapusSesi();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LayarPilihPeran()),
                    (_) => false,
                  );
                }
              },
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }

  void _tampilkanPopupPengajuanMenunggu() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: TemaAplikasi.emasTua),
            const SizedBox(width: 8),
            const Text('Pengajuan Sedang Diproses'),
          ],
        ),
        content: const Text(
          'Anda masih memiliki pengajuan APD yang menunggu konfirmasi dari admin. Silakan tunggu sampai pengajuan selesai diproses (diterima atau ditolak) sebelum membuat pengajuan baru.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  List<TutorialLangkahAplikasi> get _langkahTutorialKaryawan => [
    TutorialLangkahAplikasi(
      icon: Icons.home_outlined,
      judul: 'Header Dashboard',
      deskripsi:
          'Bagian atas menampilkan sapaan pengguna aktif dan akses cepat ke notifikasi karyawan.',
      warna: const Color(0xFFD2A92B),
      targetKey: _tutorialHeaderKey,
    ),
    TutorialLangkahAplikasi(
      icon: Icons.note_add_outlined,
      judul: 'Aksi Cepat',
      deskripsi:
          'Empat tombol ini dipakai untuk membuat pengajuan, melihat riwayat, membuka katalog APD, dan melihat dokumen penerimaan.',
      warna: Colors.indigo,
      targetKey: _tutorialQuickActionKey,
    ),
    TutorialLangkahAplikasi(
      icon: Icons.verified_outlined,
      judul: 'Status Pengajuan',
      deskripsi:
          'Di sini karyawan bisa langsung melihat status pengajuan APD terakhir tanpa membuka riwayat lengkap.',
      warna: Colors.green,
      targetKey: _tutorialStatusKey,
    ),
    TutorialLangkahAplikasi(
      icon: Icons.navigation_outlined,
      judul: 'Navigasi Bawah',
      deskripsi:
          'Gunakan navigasi bawah untuk kembali ke beranda, melaporkan kendala APD, membuka kalender kerja, dan mengatur profil akun.',
      warna: Colors.deepOrange,
      targetKey: _tutorialBottomNavKey,
    ),
  ];

  void _cekTutorialKaryawanPertamaKali() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _tutorialSudahDicek) {
        return;
      }

      _tutorialSudahDicek = true;
      final perluTampil =
          await TutorialAplikasiService.perluTampilkanTutorialKaryawan();
      if (!mounted || !perluTampil) {
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) {
        return;
      }

      await _tampilkanTutorialKaryawan();
    });
  }

  Future<void> _tampilkanTutorialKaryawan() async {
    await tampilkanDialogTutorialAplikasi(
      context: context,
      judul: 'Tutorial Karyawan',
      langkah: _langkahTutorialKaryawan,
    );
    await TutorialAplikasiService.tandaiTutorialKaryawanSudahDilihat();
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);

    final response = await _api.dashboardKaryawan(_username);
    if (!mounted) return;

    if (_api.isSuccess(response)) {
      final data = _api.extractMapData(response);
      final notifCount =
          int.tryParse('${data['notifikasi_belum_dibaca'] ?? 0}') ?? 0;
      setState(() {
        final profil = data['profil'] as Map<String, dynamic>?;
        _namaLengkap = profil?['nama_lengkap']?.toString() ?? _namaLengkap;
        _username = profil?['username']?.toString() ?? _username;
        _fotoProfil = profil?['foto_profil']?.toString();

        _notifBelumDibaca = notifCount;

        final rawPengajuanTerakhir = data['pengajuan_terakhir'];
        _pengajuanTerakhir = rawPengajuanTerakhir is Map
            ? rawPengajuanTerakhir.map((key, value) => MapEntry('$key', value))
            : null;

        final rawAturan = data['aturan_pengajuan'];
        _aturanPengajuan = rawAturan is Map
            ? rawAturan.map((key, value) => MapEntry('$key', value))
            : const {};

        final rawBerita = data['berita'] as List?;
        _beritaUtamaData =
            rawBerita
                ?.whereType<Map>()
                .map((e) => e.map((key, value) => MapEntry('$key', value)))
                .toList() ??
            [];

        _beritaAktifIndex = 0;
        _loading = false;
      });
      _syncBeritaCarousel();
      return;
    }

    _syncBeritaCarousel();
    setState(() => _loading = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_api.message(response))));
  }

  List<Map<String, dynamic>> get _beritaUtama => _beritaUtamaData;

  Color _statusColor(String status) {
    final text = status.toLowerCase();
    if (text == 'disetujui' || text == 'diterima') return Colors.green;
    if (text == 'ditolak') return Colors.red;
    if (text == 'selesai') return Colors.black87;
    if (text == 'sedang_diproses' || text == 'sedang diproses')
      return Colors.orange;
    if (text == 'sebagian_diterima' || text == 'sebagian diterima')
      return Colors.deepOrange;
    return Colors.blue;
  }

  String _statusLabel(String status) {
    final text = status.toLowerCase();
    if (text == 'disetujui' || text == 'Pengajuan Diterima') return 'Disetujui';
    if (text == 'ditolak') return 'Pengajuan Ditolak';
    if (text == 'selesai') return 'Sebagian Pengajuan Ditolak/Diterima';
    if (text == 'sedang_diproses' || text == 'Pengajuan sedang diproses')
      return 'Sedang Diproses';
    if (text == 'sebagian_diterima' || text == 'sebagian diterima')
      return 'Sebagian Diterima';
    return 'Menunggu Konfirmasi';
  }

  int _cooldownHariAkun() {
    return cooldownHariAkun(_aturanPengajuan);
  }

  int _sisaHariCooldown() {
    return sisaHariCooldown(_aturanPengajuan);
  }

  bool _bisaAjukanSekarang() {
    return bisaAjukanSekarang(_aturanPengajuan);
  }

  Color _warnaAturanPengajuan() {
    return warnaAturanPengajuan(_aturanPengajuan);
  }

  String _labelAturanPengajuan() {
    return labelAturanPengajuan(_aturanPengajuan);
  }

  String _tanggalBolehAjukanLabel() {
    final raw = _aturanPengajuan['tanggal_boleh_ajukan']?.toString() ?? '';
    if (raw.isEmpty) return '-';
    final tanggal = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (tanggal == null) return raw;
    return DateFormat('dd MMM yyyy, HH:mm').format(tanggal);
  }

  String _tanggalRingkas(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final tanggal = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (tanggal == null) return raw;
    return DateFormat('dd MMM yyyy').format(tanggal);
  }

  void _syncBeritaCarousel() {
    _beritaAutoSlideTimer?.cancel();
    final totalBerita = _beritaUtama.length;
    if (totalBerita <= 1) {
      if (mounted && _beritaAktifIndex != 0) {
        setState(() => _beritaAktifIndex = 0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_beritaPageController.hasClients) {
          _beritaPageController.jumpToPage(0);
        }
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_beritaPageController.hasClients) {
        _beritaPageController.jumpToPage(0);
      }
    });

    _beritaAutoSlideTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_beritaPageController.hasClients) {
        return;
      }
      final nextIndex = (_beritaAktifIndex + 1) % totalBerita;
      _beritaPageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _bukaDetailBerita(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LayarDetailBeritaKaryawan(berita: item),
      ),
    );
  }

  Future<void> _bukaProfil() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => LayarProfilKaryawan(
          namaLengkap: _namaLengkap,
          username: _username,
          fotoProfil: _fotoProfil,
        ),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _selectedIndex = 0;
        _namaLengkap = result['namaLengkap']?.toString() ?? _namaLengkap;
        _username = result['username']?.toString() ?? _username;
        _fotoProfil = result['fotoProfil']?.toString() ?? _fotoProfil;
      });
    } else {
      setState(() {
        _selectedIndex = 0;
      });
    }

    await _loadDashboard();

    if (result?['mulaiTutorial'] == true && mounted) {
      await _tampilkanTutorialKaryawan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fotoUrl = buildUploadUrl(_fotoProfil);
    // Gunakan status_pengajuan (display status) untuk tampilan
    final lastStatus =
        _pengajuanTerakhir?['status_pengajuan']?.toString() ?? '';
    final lastStatusColor = _statusColor(lastStatus);
    final warnaAturan = _warnaAturanPengajuan();
    final beritaUtama = _beritaUtama;

    return SingleDeviceMonitor(
      username: _username,
      peran: 'karyawan',
      onSessionInvalid: _paksaLogout,
      child: Scaffold(
        backgroundColor: TemaAplikasi.latar,
        body: RefreshIndicator(
          onRefresh: _loadDashboard,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              KeyedSubtree(
                key: _tutorialHeaderKey,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 54, 20, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [TemaAplikasi.biruTua, Color(0xFF173D67)],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.white,
                            backgroundImage: fotoUrl.isEmpty
                                ? null
                                : NetworkImage(fotoUrl),
                            child: fotoUrl.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    color: Color(0xFFD2A92B),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Halo, $_namaLengkap',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LayarNotifikasiKaryawan(
                                        username: _username,
                                      ),
                                    ),
                                  ).then((_) => _loadDashboard());
                                },
                                icon: const Icon(Icons.notifications_none),
                                color: Colors.white,
                              ),
                              if (_notifBelumDibaca > 0)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      _notifBelumDibaca > 99
                                          ? '99+'
                                          : _notifBelumDibaca.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      KeyedSubtree(
                        key: _tutorialQuickActionKey,
                        child: _quickActions(context),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _HeaderInfoPill(
                            ikon: Icons.rule_folder_outlined,
                            label: _labelAturanPengajuan(),
                            warna: warnaAturan,
                          ),
                          _HeaderInfoPill(
                            ikon: Icons.schedule_outlined,
                            label: _cooldownHariAkun() == 0
                                ? 'Tanpa Pending Pengajuan'
                                : 'Pending Pengajuan ${_cooldownHariAkun()} hari',
                            warna: TemaAplikasi.emas,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              KeyedSubtree(
                key: _tutorialStatusKey,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: const [
                          Text(
                            'Status Pengajuan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _loading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_pengajuanTerakhir == null)
                                      const Text(
                                        'Belum ada pengajuan APD. Gunakan menu "Buat Pengajuan" untuk mulai.',
                                      )
                                    else ...[
                                      Text(
                                        '${_pengajuanTerakhir?['nama_apd'] ?? '-'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: lastStatusColor.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              _statusLabel(lastStatus),
                                              style: TextStyle(
                                                color: lastStatusColor,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          if (_pengajuanTerakhir?['tanggal_pengajuan'] !=
                                              null)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: TemaAplikasi.biruMuda,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                'Terakhir: ${_tanggalRingkas(_pengajuanTerakhir?['tanggal_pengajuan']?.toString())}',
                                                style: const TextStyle(
                                                  color: TemaAplikasi.biruTua,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 14),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: _warnaAturanPengajuan()
                                            .withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: _warnaAturanPengajuan()
                                              .withValues(alpha: 0.16),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                _bisaAjukanSekarang()
                                                    ? Icons.verified_outlined
                                                    : Icons.timelapse_outlined,
                                                color: _warnaAturanPengajuan(),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  _labelAturanPengajuan(),
                                                  style: TextStyle(
                                                    color:
                                                        _warnaAturanPengajuan(),
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _aturanPengajuan['pesan']
                                                    ?.toString() ??
                                                'Aturan pengajuan akun akan muncul di sini.',
                                            style: const TextStyle(
                                              height: 1.45,
                                              color: TemaAplikasi.teksUtama,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _InfoStatusChip(
                                                warna: TemaAplikasi.biruTua,
                                                label: _cooldownHariAkun() == 0
                                                    ? 'Tanpa Pending Pengajuan'
                                                    : 'Pending Pengajuan ${_cooldownHariAkun()} hari',
                                              ),
                                              if ((_aturanPengajuan['status']
                                                          ?.toString() ??
                                                      '') ==
                                                  'cooldown')
                                                _InfoStatusChip(
                                                  warna: TemaAplikasi.emasTua,
                                                  label: _sisaHariCooldown() > 0
                                                      ? 'Sisa ${_sisaHariCooldown()} hari'
                                                      : 'Masih pending',
                                                ),
                                              if ((_aturanPengajuan['tanggal_boleh_ajukan']
                                                          ?.toString() ??
                                                      '')
                                                  .isNotEmpty)
                                                _InfoStatusChip(
                                                  warna: TemaAplikasi.emasTua,
                                                  label:
                                                      'Ajukan lagi ${_tanggalBolehAjukanLabel()}',
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: const [
                        Text(
                          'Berita',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _loading
                        ? const SizedBox.shrink()
                        : beritaUtama.isEmpty
                        ? const Card(
                            child: Padding(
                              padding: EdgeInsets.all(14),
                              child: Text(
                                'Belum ada berita terbaru dari admin.',
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              SizedBox(
                                height: 280,
                                child: PageView.builder(
                                  controller: _beritaPageController,
                                  itemCount: beritaUtama.length,
                                  onPageChanged: (index) {
                                    if (!mounted) return;
                                    setState(() => _beritaAktifIndex = index);
                                  },
                                  itemBuilder: (_, index) {
                                    final item = beritaUtama[index];
                                    final gambarUrl = buildUploadUrl(
                                      item['gambar']?.toString(),
                                    );
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        right: index == beritaUtama.length - 1
                                            ? 0
                                            : 12,
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(24),
                                        onTap: () => _bukaDetailBerita(item),
                                        child: Card(
                                          clipBehavior: Clip.antiAlias,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: gambarUrl.isEmpty
                                                    ? Container(
                                                        decoration:
                                                            const BoxDecoration(
                                                              gradient: LinearGradient(
                                                                begin: Alignment
                                                                    .topLeft,
                                                                end: Alignment
                                                                    .bottomRight,
                                                                colors: [
                                                                  TemaAplikasi
                                                                      .biruTua,
                                                                  Color(
                                                                    0xFF355C8A,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                        alignment:
                                                            Alignment.center,
                                                        child: const Icon(
                                                          Icons
                                                              .article_outlined,
                                                          size: 44,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : Image.network(
                                                        gambarUrl,
                                                        fit: BoxFit.cover,
                                                        width: double.infinity,
                                                        errorBuilder:
                                                            (
                                                              context,
                                                              error,
                                                              stackTrace,
                                                            ) => Container(
                                                              color: Colors
                                                                  .grey
                                                                  .shade100,
                                                              alignment:
                                                                  Alignment
                                                                      .center,
                                                              child: const Icon(
                                                                Icons
                                                                    .broken_image_outlined,
                                                                color:
                                                                    TemaAplikasi
                                                                        .netral,
                                                              ),
                                                            ),
                                                      ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      16,
                                                      14,
                                                      16,
                                                      16,
                                                    ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 10,
                                                                vertical: 5,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: TemaAplikasi
                                                                .biruMuda,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  999,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            item['kategori']
                                                                    ?.toString() ??
                                                                'Berita',
                                                            style: const TextStyle(
                                                              color:
                                                                  TemaAplikasi
                                                                      .biruTua,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          _tanggalRingkas(
                                                            item['tanggal']
                                                                ?.toString(),
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                color:
                                                                    TemaAplikasi
                                                                        .netral,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      item['judul']
                                                              ?.toString() ??
                                                          '-',
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      item['ringkasan']
                                                              ?.toString() ??
                                                          '',
                                                      maxLines: 3,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: TemaAplikasi
                                                            .teksUtama,
                                                        height: 1.45,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    const Text(
                                                      'Geser untuk berita lain - tekan untuk buka detail',
                                                      style: TextStyle(
                                                        color:
                                                            TemaAplikasi.netral,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
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
                                  },
                                ),
                              ),
                              if (beritaUtama.length > 1) ...[
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(beritaUtama.length, (
                                    index,
                                  ) {
                                    final aktif = index == _beritaAktifIndex;
                                    return AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      width: aktif ? 20 : 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: aktif
                                            ? const Color(0xFFD2A92B)
                                            : Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          key: _tutorialBottomNavKey,
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFFD2A92B),
          onTap: (index) {
            if (index == 0) {
              setState(() {
                _selectedIndex = 0;
              });
              return;
            }

            if (index == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      LayarLaporKendalaKaryawan(username: _username),
                ),
              ).then((_) {
                if (!mounted) return;
                setState(() => _selectedIndex = 0);
              });
              return;
            }

            if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LayarKalenderKaryawan(username: _username),
                ),
              ).then((_) {
                if (!mounted) return;
                setState(() => _selectedIndex = 0);
              });
              return;
            }

            if (index == 3) {
              _bukaProfil();
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
            BottomNavigationBarItem(
              icon: Icon(Icons.report_problem_outlined),
              label: 'Lapor',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month),
              label: 'Kalender',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    // Cek apakah ada pengajuan yang masih menunggu konfirmasi
    // Gunakan status_pengajuan_raw yang dikirim dari API
    final statusPengajuanTerakhir =
        _pengajuanTerakhir?['status_pengajuan_raw']?.toString().toLowerCase() ??
        _pengajuanTerakhir?['status']?.toString().toLowerCase() ?? '';
    final adaPengajuanMenunggu = statusPengajuanTerakhir == 'menunggu' ||
        statusPengajuanTerakhir == 'pending';

    return Row(
      children: [
        Expanded(
          child: _quickActionButton(
            icon: Icons.assignment_add,
            label: 'Buat\nPengajuan',
            isDisabled: adaPengajuanMenunggu,
            onTap: () {
              if (adaPengajuanMenunggu) {
                _tampilkanPopupPengajuanMenunggu();
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LayarPengajuanDokumenApd(username: _username),
                ),
              ).then((_) => _loadDashboard());
            },
          ),
        ),
        Expanded(
          child: _quickActionButton(
            icon: Icons.history,
            label: 'Riwayat\nPengajuan',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      LayarRiwayatPengajuanKaryawan(username: _username),
                ),
              ).then((_) => _loadDashboard());
            },
          ),
        ),
        Expanded(
          child: _quickActionButton(
            icon: Icons.inventory_2_outlined,
            label: 'Katalog\nAPD',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LayarKatalogApdKaryawan(username: _username),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: _quickActionButton(
            icon: Icons.description_outlined,
            label: 'Dokumen\nPenerimaan',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      LayarDaftarDokumenPenerimaanKaryawan(username: _username),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int badgeCount = 0,
    bool isDisabled = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: isDisabled ? Colors.grey.shade300 : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color: isDisabled ? Colors.grey.shade500 : const Color(0xFFD2A92B),
                      size: 28,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: TemaAplikasi.latar, width: 2),
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            height: 1,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 30,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

class _HeaderInfoPill extends StatelessWidget {
  final IconData ikon;
  final String label;
  final Color warna;

  const _HeaderInfoPill({
    required this.ikon,
    required this.label,
    required this.warna,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, color: warna, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoStatusChip extends StatelessWidget {
  final Color warna;
  final String label;

  const _InfoStatusChip({required this.warna, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: warna,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
