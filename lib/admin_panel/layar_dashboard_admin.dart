import 'dart:math' as math;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:apdcpp/konfigurasi_api.dart';
import 'package:apdcpp/admin_panel/layar_admin_berita.dart';
import 'package:apdcpp/admin_panel/layar_admin_kalender.dart';
import 'package:apdcpp/admin_panel/layar_admin_karyawan.dart';
import 'package:apdcpp/admin_panel/layar_admin_profil.dart';
import 'package:apdcpp/admin_panel/layar_bantuan_login_admin.dart';
import 'package:apdcpp/admin_panel/layar_laporan_apd_admin.dart';
import 'package:apdcpp/admin_panel/layar_master_apd_admin.dart';
import 'package:apdcpp/admin_panel/layar_persetujuan_apd_admin.dart';
import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/services/notifikasi_laporan_admin_service.dart';
import 'package:apdcpp/services/sesi_aplikasi_service.dart';
import 'package:apdcpp/awal/layar_pilih_peran.dart';
import 'package:apdcpp/tema_aplikasi.dart';
import 'package:apdcpp/services/tutorial_aplikasi_service.dart';
import 'package:apdcpp/widgets/dialog_tutorial_aplikasi.dart';
import 'package:apdcpp/services/single_device_session_service.dart';
import 'package:apdcpp/services/notifikasi_lokal_service.dart';

class LayarDashboardAdmin extends StatefulWidget {
  final String namaLengkap;
  final String username;
  final String? fotoProfil;

  const LayarDashboardAdmin({
    super.key,
    required this.namaLengkap,
    required this.username,
    this.fotoProfil,
  });

  @override
  State<LayarDashboardAdmin> createState() => _LayarDashboardAdminState();
}

class _LayarDashboardAdminState extends State<LayarDashboardAdmin> {
  int _selectedIndex = 0;
  late String _namaLengkap;
  late String _username;
  String? _fotoProfil;
  bool _tutorialSudahDicek = false;
  final List<int> _riwayatTab = [];
  final GlobalKey _tutorialAdminProfilCardKey = GlobalKey();
  final GlobalKey _tutorialAdminMenuCepatKey = GlobalKey();
  final GlobalKey _tutorialAdminRingkasanKey = GlobalKey();
  final GlobalKey _tutorialAdminGrafikKey = GlobalKey();
  final GlobalKey _tutorialAdminPengajuanKey = GlobalKey();
  final GlobalKey _tutorialAdminBottomNavKey = GlobalKey();
  final GlobalKey _tutorialAdminKaryawanKey = GlobalKey();
  final GlobalKey _tutorialAdminKalenderKey = GlobalKey();
  final GlobalKey _tutorialAdminBeritaKey = GlobalKey();
  final GlobalKey _tutorialAdminProfilTabKey = GlobalKey();

  Timer? _sesiTimer;
  Timer? _notifikasiTimer;
  int _notifikasiTerakhirCount = 0;
  final ApiApdService _api = const ApiApdService();
  @override
  void initState() {
    super.initState();
    _namaLengkap = widget.namaLengkap;
    _username = widget.username;
    _fotoProfil = widget.fotoProfil;
    _cekTutorialAdminPertamaKali();
    _mulaiCekSesi();
    _mulaiPollingNotifikasi();
  }

  void _mulaiCekSesi() {
    _sesiTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final sesi = await SesiAplikasiService.ambilSesi();
      if (sesi == null || !mounted) return;

      final token = sesi['session_token'];
      if (token == null) return;

      final res = await _api.cekSesi(
        peran: 'admin',
        username: _username,
        sessionToken: token,
      );

      if (!mounted) return;

      if (res['status'] == 'gagal' || res['status'] == 'expired') {
        _sesiTimer?.cancel();
        _paksaLogout();
      }
    });
  }

  void _mulaiPollingNotifikasi() {
    // Polling notifikasi setiap 20 detik
    _notifikasiTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (!mounted) return;

      // Cek dashboard untuk pengajuan baru
      final response = await _api.dashboardAdmin(_username);

      if (_api.isSuccess(response) && mounted) {
        final data = _api.extractMapData(response);
        final pengajuanMenunggu =
            int.tryParse('${data['jumlah_pengajuan'] ?? 0}') ?? 0;

        // Jika ada pengajuan baru dan bukan pertama kali
        if (pengajuanMenunggu > _notifikasiTerakhirCount &&
            _notifikasiTerakhirCount > 0) {
          await NotifikasiLokalService.tampilkanNotifikasi(
            id: DateTime.now().millisecondsSinceEpoch % 100000,
            judul: 'Pengajuan Baru',
            isi: 'Ada $pengajuanMenunggu pengajuan yang menunggu persetujuan',
            payload: 'pengajuan_baru_admin',
          );
        }

        if (mounted) {
          _notifikasiTerakhirCount = pengajuanMenunggu;
        }
      }
    });
  }

  void _paksaLogout() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
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
    );
  }

  List<TutorialLangkahAplikasi> get _langkahTutorialAdmin => [
    TutorialLangkahAplikasi(
      icon: Icons.space_dashboard_outlined,
      judul: 'Beranda Admin',
      deskripsi:
          'Area ini adalah titik awal admin. Di sini kamu bisa melihat identitas akun yang aktif dan mulai memantau dashboard.',
      warna: const Color(0xFFD2A92B),
      targetKey: _tutorialAdminProfilCardKey,
      onSebelumTampil: () => _arahkanTutorialKeTab(0),
    ),
    TutorialLangkahAplikasi(
      icon: Icons.widgets_outlined,
      judul: 'Menu Cepat Admin',
      deskripsi:
          'Tombol Persetujuan APD, Stok APD, dan Laporan dipakai untuk masuk ke proses utama tanpa harus mencari menu lain.',
      warna: Colors.indigo,
      targetKey: _tutorialAdminMenuCepatKey,
      onSebelumTampil: () => _arahkanTutorialKeTab(0),
    ),
    TutorialLangkahAplikasi(
      icon: Icons.query_stats_outlined,
      judul: 'Ringkasan Harian',
      deskripsi:
          'Bagian ini merangkum jumlah pengajuan menunggu, data yang sudah disetujui, dan stok APD yang mulai menipis.',
      warna: Colors.blue,
      targetKey: _tutorialAdminRingkasanKey,
      onSebelumTampil: () => _arahkanTutorialKeTab(0),
    ),
    TutorialLangkahAplikasi(
      icon: Icons.insert_chart_outlined,
      judul: 'Grafik Dashboard',
      deskripsi:
          'Grafik membantu membaca tren pengajuan. Admin bisa mengganti mode periode untuk melihat pola mingguan, bulanan, atau tahunan.',
      warna: Colors.teal,
      targetKey: _tutorialAdminGrafikKey,
      onSebelumTampil: () => _arahkanTutorialKeTab(0),
    ),
    TutorialLangkahAplikasi(
      icon: Icons.pending_actions_outlined,
      judul: 'Pengajuan Terbaru',
      deskripsi:
          'Daftar ini menampilkan pengajuan APD yang masih perlu diperhatikan. Sentuh item untuk masuk ke halaman persetujuan.',
      warna: Colors.orange,
      targetKey: _tutorialAdminPengajuanKey,
      onSebelumTampil: () => _arahkanTutorialKeTab(0),
    ),
    TutorialLangkahAplikasi(
      icon: Icons.navigation_outlined,
      judul: 'Navigasi Dashboard',
      deskripsi:
          'Navigasi bawah dipakai untuk berpindah ke tampilan Karyawan, Kalender, Berita, dan Profil. Tutorial akan menelusuri semuanya.',
      warna: Colors.deepOrange,
      targetKey: _tutorialAdminBottomNavKey,
      onSebelumTampil: () => _arahkanTutorialKeTab(0),
    ),
    TutorialLangkahAplikasi(
      icon: Icons.groups_outlined,
      judul: 'Kelola Karyawan',
      deskripsi:
          'Tab ini dipakai untuk menambah, mengedit, mencari, dan menghapus data akun karyawan dari satu tempat.',
      warna: Colors.redAccent,
      targetKey: _tutorialAdminKaryawanKey,
      onSebelumTampil: () => _arahkanTutorialKeTab(1),
    ),
    TutorialLangkahAplikasi(
      icon: Icons.calendar_month_outlined,
      judul: 'Kalender Admin',
      deskripsi:
          'Di sini admin mengelola agenda perusahaan dan memantau jadwal pribadi. Tampilan ini jadi pusat aktivitas kalender.',
      warna: Colors.green,
      targetKey: _tutorialAdminKalenderKey,
      onSebelumTampil: () => _arahkanTutorialKeTab(2),
    ),
    TutorialLangkahAplikasi(
      icon: Icons.article_outlined,
      judul: 'Kelola Berita',
      deskripsi:
          'Tab Berita digunakan untuk membuat pengumuman atau informasi yang akan tampil ke karyawan dan bisa diperbarui kapan saja.',
      warna: Colors.purple,
      targetKey: _tutorialAdminBeritaKey,
      onSebelumTampil: () => _arahkanTutorialKeTab(3),
    ),
    TutorialLangkahAplikasi(
      icon: Icons.person_outline,
      judul: 'Profil Admin',
      deskripsi:
          'Pada tab Profil, admin bisa memperbarui akun dan menjalankan tutorial lagi kapan saja jika perlu panduan ulang.',
      warna: Colors.brown,
      targetKey: _tutorialAdminProfilTabKey,
      onSebelumTampil: () => _arahkanTutorialKeTab(4),
    ),
  ];

  void _cekTutorialAdminPertamaKali() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _tutorialSudahDicek) {
        return;
      }

      _tutorialSudahDicek = true;
      final perluTampil =
          await TutorialAplikasiService.perluTampilkanTutorialAdmin();
      if (!mounted || !perluTampil) {
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) {
        return;
      }

      await _tampilkanTutorialAdmin();
    });
  }

  Future<void> _arahkanTutorialKeTab(int index) async {
    if (!mounted) return;
    _pindahTab(index, catatRiwayat: false, resetRiwayat: index == 0);
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  Future<void> _tampilkanTutorialAdmin({int? kembaliKeTab}) async {
    final targetTabAkhir = kembaliKeTab ?? _selectedIndex;
    await tampilkanDialogTutorialAplikasi(
      context: context,
      judul: 'Tutorial Admin',
      langkah: _langkahTutorialAdmin,
    );
    if (mounted) {
      _pindahTab(
        targetTabAkhir,
        catatRiwayat: false,
        resetRiwayat: targetTabAkhir == 0,
      );
    }
    await TutorialAplikasiService.tandaiTutorialAdminSudahDilihat();
  }

  void _mulaiTutorialDariProfil() {
    final tabSaatIni = _selectedIndex;
    if (_selectedIndex != 0) {
      _pindahTab(0, catatRiwayat: false, resetRiwayat: true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) {
        return;
      }

      await _tampilkanTutorialAdmin(kembaliKeTab: tabSaatIni);
    });
  }

  void _pindahTab(
    int index, {
    bool catatRiwayat = true,
    bool resetRiwayat = false,
  }) {
    if (index == _selectedIndex && !resetRiwayat) {
      return;
    }

    setState(() {
      if (resetRiwayat) {
        _riwayatTab.clear();
      } else if (catatRiwayat && index != _selectedIndex) {
        _riwayatTab.add(_selectedIndex);
      }

      _selectedIndex = index;
    });
  }

  Future<void> _tanganiTombolKembali() async {
    if (_riwayatTab.isNotEmpty) {
      final indexSebelumnya = _riwayatTab.removeLast();
      setState(() {
        _selectedIndex = indexSebelumnya;
      });
      return;
    }

    if (_selectedIndex != 0) {
      _pindahTab(0, catatRiwayat: false, resetRiwayat: true);
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    await SystemNavigator.pop();
  }

  @override
  void dispose() {
    _sesiTimer?.cancel();
    _notifikasiTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const titles = [
      'Beranda Admin',
      'Karyawan',
      'Kalender',
      'Berita',
      'Profil',
    ];

    return SingleDeviceMonitor(
      username: _username,
      peran: 'admin',
      onSessionInvalid: _paksaLogout,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await _tanganiTombolKembali();
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(titles[_selectedIndex]),
          ),
          body: _buildCurrentPage(),
          bottomNavigationBar: BottomNavigationBar(
            key: _tutorialAdminBottomNavKey,
            currentIndex: _selectedIndex,
            onTap: (index) {
              if (index == 0) {
                _pindahTab(0, catatRiwayat: false, resetRiwayat: true);
                return;
              }

              _pindahTab(index);
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
              BottomNavigationBarItem(
                icon: Icon(Icons.groups),
                label: 'Karyawan',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month),
                label: 'Kalender',
              ),
              BottomNavigationBarItem(icon: Icon(Icons.article), label: 'Berita'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return TabAdminBeranda(
          username: _username,
          namaLengkap: _namaLengkap,
          fotoProfil: _fotoProfil,
          tutorialProfilKey: _tutorialAdminProfilCardKey,
          tutorialMenuCepatKey: _tutorialAdminMenuCepatKey,
          tutorialRingkasanKey: _tutorialAdminRingkasanKey,
          tutorialGrafikKey: _tutorialAdminGrafikKey,
          tutorialPengajuanKey: _tutorialAdminPengajuanKey,
        );
      case 1:
        return TabAdminKaryawan(tutorialAksiKey: _tutorialAdminKaryawanKey);
      case 2:
        return TabAdminKalender(
          usernameAdmin: _username,
          tutorialKalenderKey: _tutorialAdminKalenderKey,
        );
      case 3:
        return TabAdminBerita(
          usernameAdmin: _username,
          tutorialAksiKey: _tutorialAdminBeritaKey,
        );
      case 4:
        return TabAdminProfil(
          username: _username,
          namaLengkap: _namaLengkap,
          fotoProfil: _fotoProfil,
          tutorialProfilKey: _tutorialAdminProfilTabKey,
          onMulaiTutorial: _mulaiTutorialDariProfil,
          onProfileUpdated: (data) {
            setState(() {
              _username = data['username'] ?? _username;
              _namaLengkap = data['nama_lengkap'] ?? _namaLengkap;
              _fotoProfil = data['foto_profil'] ?? _fotoProfil;
            });
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class TabAdminBeranda extends StatefulWidget {
  final String username;
  final String namaLengkap;
  final String? fotoProfil;
  final GlobalKey? tutorialProfilKey;
  final GlobalKey? tutorialMenuCepatKey;
  final GlobalKey? tutorialRingkasanKey;
  final GlobalKey? tutorialGrafikKey;
  final GlobalKey? tutorialPengajuanKey;

  const TabAdminBeranda({
    super.key,
    required this.username,
    required this.namaLengkap,
    this.fotoProfil,
    this.tutorialProfilKey,
    this.tutorialMenuCepatKey,
    this.tutorialRingkasanKey,
    this.tutorialGrafikKey,
    this.tutorialPengajuanKey,
  });

  @override
  State<TabAdminBeranda> createState() => _TabAdminBerandaState();
}

class _TabAdminBerandaState extends State<TabAdminBeranda> {
  final ApiApdService _api = const ApiApdService();
  Timer? _autoRefreshTimer;
  final int _tahunSekarang = DateTime.now().year;
  static const List<String> _namaBulan = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  bool _loading = true;
  bool _refreshing = false;
  bool _animateChart = false;
  String _modeGrafik = 'mingguan';
  int _tahunGrafik = DateTime.now().year;
  int _bulanGrafik = DateTime.now().month;
  List<int> _opsiTahunGrafik = [];
  int _pengajuanMenunggu = 0;
  int _disetujuiBulanIni = 0;
  int _stokMenipis = 0;
  int _laporanBaru = 0;
  int _bandingLoginMenunggu = 0;
  List<Map<String, dynamic>> _pengajuanTerbaru = [];
  List<Map<String, dynamic>> _grafikBulanan = [];

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final cleaned = value.toString().replaceAll(RegExp(r'[^0-9\-]'), '').trim();
    return int.tryParse(cleaned) ?? fallback;
  }

  int _pickInt(
    Map<String, dynamic> item,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      if (!item.containsKey(key)) continue;
      final parsed = _toInt(item[key], fallback: fallback);
      return parsed;
    }
    return fallback;
  }

  String _pickLabel(Map<String, dynamic> item) {
    final keys = ['label', 'bulan', 'periode', 'tanggal', 'date'];
    for (final key in keys) {
      final raw = item[key];
      if (raw == null) continue;
      final text = raw.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '-';
  }

  List<Map<String, dynamic>> _extractGrafik(dynamic grafikRaw) {
    final source = grafikRaw is List
        ? grafikRaw
        : (grafikRaw is Map
              ? (grafikRaw['data'] ?? grafikRaw['items'] ?? grafikRaw['list'])
              : null);
    if (source is! List) return [];
    return source
        .whereType<Map>()
        .map((e) => e.map((key, value) => MapEntry('$key', value)))
        .toList();
  }

  String get _judulGrafik {
    if (_modeGrafik == 'mingguan') return 'Grafik Minggu Ini';
    if (_modeGrafik == 'bulanan') return 'Grafik Bulanan';
    if (_modeGrafik == 'tahunan') return 'Grafik Tahunan';
    return 'Grafik Minggu Ini';
  }

  String _namaBulanByIndex(int month) {
    if (month < 1 || month > 12) return '-';
    return _namaBulan[month - 1];
  }

  String _labelPeriodeAktif() {
    if (_modeGrafik == 'mingguan') {
      final now = DateTime.now();
      final start = now.subtract(Duration(days: now.weekday - 1));
      final end = start.add(const Duration(days: 6));
      final labelStart = '${start.day} ${_namaBulanByIndex(start.month)}';
      final labelEnd = '${end.day} ${_namaBulanByIndex(end.month)} ${end.year}';
      return '$labelStart - $labelEnd';
    }
    if (_modeGrafik == 'bulanan') {
      return '${_namaBulanByIndex(_bulanGrafik)} $_tahunGrafik';
    }
    return 'Januari - Desember $_tahunGrafik';
  }

  String _teksDataGrafikKosong() {
    if (_modeGrafik == 'mingguan') {
      return 'Data grafik minggu ini belum tersedia';
    }
    if (_modeGrafik == 'bulanan') {
      return 'Data grafik ${_namaBulanByIndex(_bulanGrafik)} $_tahunGrafik belum tersedia';
    }
    return 'Data grafik tahun $_tahunGrafik belum tersedia';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!mounted || _loading || _refreshing) return;
      _loadData(preserveVisibleData: true, silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({
    bool preserveVisibleData = false,
    bool silent = false,
  }) async {
    final keepVisibleData =
        preserveVisibleData &&
        (_pengajuanTerbaru.isNotEmpty ||
            _grafikBulanan.isNotEmpty ||
            _pengajuanMenunggu > 0 ||
            _disetujuiBulanIni > 0 ||
            _stokMenipis > 0 ||
            _laporanBaru > 0);
    setState(() {
      _loading = !keepVisibleData;
      _refreshing = keepVisibleData;
      _animateChart = false;
    });

    final response = await _api.dashboardAdmin(
      widget.username,
      modeGrafik: _modeGrafik,
      tahunGrafik: _tahunGrafik,
      bulanGrafik: _bulanGrafik,
    );
    if (!mounted) return;

    if (_api.isSuccess(response)) {
      final data = _api.extractMapData(response);
      final stat = data['statistik'];
      final terbaru = data['pengajuan_terbaru'];
      final opsiTahun = data['opsi_tahun'];
      final laporanMenungguTimestamps =
          data['laporan_kendala_menunggu_timestamps'];
      final grafik =
          data['grafik_bulanan'] ??
          data['grafik_mingguan'] ??
          data['grafik'] ??
          data['data_grafik'];
      final laporanBaru = await NotifikasiLaporanAdminService.hitungLaporanBaru(
        usernameAdmin: widget.username,
        waktuLaporanAktif: laporanMenungguTimestamps is List
            ? laporanMenungguTimestamps.map((e) => '$e')
            : const <String>[],
      );
      if (!mounted) return;

      setState(() {
        if (stat is Map) {
          final statMap = stat.map((key, value) => MapEntry('$key', value));
          _pengajuanMenunggu =
              int.tryParse('${statMap['pengajuan_menunggu'] ?? 0}') ?? 0;
          _disetujuiBulanIni =
              int.tryParse('${statMap['total_disetujui_bulan_ini'] ?? 0}') ?? 0;
          _stokMenipis =
              int.tryParse('${statMap['stok_apd_menipis'] ?? 0}') ?? 0;
          _laporanBaru =
              int.tryParse('${statMap['laporan_kendala_menunggu'] ?? 0}') ?? 0;
          _bandingLoginMenunggu =
              int.tryParse('${statMap['banding_login_menunggu'] ?? 0}') ?? 0;
        }
        _laporanBaru = laporanBaru;

        _pengajuanTerbaru = terbaru is List
            ? terbaru
                  .whereType<Map>()
                  .map((e) => e.map((key, value) => MapEntry('$key', value)))
                  .toList()
            : [];

        _opsiTahunGrafik = opsiTahun is List
            ? opsiTahun
                  .map((e) => _toInt(e, fallback: 0))
                  .where((e) => e >= 2000 && e <= _tahunSekarang)
                  .toSet()
                  .toList()
            : [];
        if (_opsiTahunGrafik.isEmpty) {
          _opsiTahunGrafik = [_tahunSekarang];
        }
        _opsiTahunGrafik.sort((a, b) => b.compareTo(a));
        if (!_opsiTahunGrafik.contains(_tahunGrafik)) {
          _tahunGrafik = _opsiTahunGrafik.first;
        }

        _grafikBulanan = _extractGrafik(grafik);

        _loading = false;
        _refreshing = false;
      });

      Future.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        setState(() => _animateChart = true);
      });
      return;
    }

    setState(() {
      _loading = false;
      _refreshing = false;
      _animateChart = false;
    });
    if (silent) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_api.message(response))));
  }

  @override
  Widget build(BuildContext context) {
    final fotoUrl = buildUploadUrl(widget.fotoProfil);

    return RefreshIndicator(
      onRefresh: () => _loadData(preserveVisibleData: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [TemaAplikasi.biruTua, Color(0xFF173D67)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KeyedSubtree(
                  key: widget.tutorialProfilKey,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white,
                          backgroundImage: fotoUrl.isEmpty
                              ? null
                              : NetworkImage(fotoUrl),
                          child: fotoUrl.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: TemaAplikasi.emas,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.namaLengkap,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '@${widget.username}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Pantau pengajuan, stok APD, dan aktivitas operasional dari satu dashboard.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.84),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _AdminHeaderPill(
                      ikon: Icons.pending_actions_outlined,
                      label: '$_pengajuanMenunggu menunggu proses',
                      warna: Colors.blue,
                    ),
                    _AdminHeaderPill(
                      ikon: Icons.inventory_2_outlined,
                      label: '$_stokMenipis stok perlu dipantau',
                      warna: TemaAplikasi.emas,
                    ),
                    _AdminHeaderPill(
                      ikon: Icons.verified_outlined,
                      label: '$_disetujuiBulanIni disetujui bulan ini',
                      warna: Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                KeyedSubtree(
                  key: widget.tutorialMenuCepatKey,
                  child: Row(
                    children: [
                      Expanded(
                        child: _menuButton(
                          icon: Icons.fact_check_outlined,
                          label: 'Persetujuan\nAPD',
                          badgeCount: _pengajuanMenunggu,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LayarPersetujuanApdAdmin(
                                  usernameAdmin: widget.username,
                                ),
                              ),
                            ).then((_) => _loadData());
                          },
                        ),
                      ),
                      Expanded(
                        child: _menuButton(
                          icon: Icons.inventory_2_outlined,
                          label: 'Stok\nAPD',
                          badgeCount: _stokMenipis,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LayarMasterApdAdmin(),
                              ),
                            ).then((_) => _loadData());
                          },
                        ),
                      ),
                      Expanded(
                        child: _menuButton(
                          icon: Icons.assessment_outlined,
                          label: 'Laporan',
                          badgeCount: _laporanBaru,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LayarLaporanApdAdmin(
                                  usernameAdmin: widget.username,
                                ),
                              ),
                            ).then((_) => _loadData());
                          },
                        ),
                      ),
                      Expanded(
                        child: _menuButton(
                          icon: Icons.support_agent_outlined,
                          label: 'Banding\nLogin',
                          badgeCount: _bandingLoginMenunggu,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LayarBantuanLoginAdmin(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_refreshing) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(
                  'Ringkasan Operasional',
                  'Pantau fokus utama admin sebelum masuk ke proses detail.',
                ),
                const SizedBox(height: 10),
                KeyedSubtree(
                  key: widget.tutorialRingkasanKey,
                  child: _loading
                      ? const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _summaryCard(
                                title: 'Menunggu',
                                value: _pengajuanMenunggu,
                                color: Colors.blue,
                                icon: Icons.hourglass_top_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _summaryCard(
                                title: 'Disetujui',
                                value: _disetujuiBulanIni,
                                color: Colors.green,
                                icon: Icons.task_alt_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _summaryCard(
                                title: 'Stok Menipis',
                                value: _stokMenipis,
                                color: TemaAplikasi.emas,
                                icon: Icons.warning_amber_rounded,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 18),
                KeyedSubtree(
                  key: widget.tutorialGrafikKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(
                        _judulGrafik,
                        'Periode aktif: ${_labelPeriodeAktif()}',
                      ),
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment<String>(
                                    value: 'mingguan',
                                    label: Text('Mingguan'),
                                  ),
                                  ButtonSegment<String>(
                                    value: 'bulanan',
                                    label: Text('Bulanan'),
                                  ),
                                  ButtonSegment<String>(
                                    value: 'tahunan',
                                    label: Text('Tahunan'),
                                  ),
                                ],
                                selected: {_modeGrafik},
                                onSelectionChanged: (selection) {
                                  final selected = selection.first;
                                  if (selected == _modeGrafik) return;
                                  setState(() {
                                    _modeGrafik = selected;
                                    if (_modeGrafik == 'mingguan') {
                                      final now = DateTime.now();
                                      _tahunGrafik = now.year;
                                      _bulanGrafik = now.month;
                                    }
                                  });
                                  _loadData(preserveVisibleData: true);
                                },
                              ),
                              if (_modeGrafik == 'mingguan')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF2FF),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFCEDDF8),
                                    ),
                                  ),
                                  child: Text(
                                    _labelPeriodeAktif(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: TemaAplikasi.biruTua,
                                    ),
                                  ),
                                ),
                              if (_modeGrafik == 'bulanan')
                                SizedBox(
                                  width: 160,
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _bulanGrafik,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      labelText: 'Bulan',
                                    ),
                                    items: List.generate(12, (index) {
                                      final month = index + 1;
                                      return DropdownMenuItem<int>(
                                        value: month,
                                        child: Text(_namaBulanByIndex(month)),
                                      );
                                    }),
                                    onChanged: (value) {
                                      if (value == null ||
                                          value == _bulanGrafik) {
                                        return;
                                      }
                                      setState(() => _bulanGrafik = value);
                                      _loadData(preserveVisibleData: true);
                                    },
                                  ),
                                ),
                              if (_modeGrafik == 'bulanan' ||
                                  _modeGrafik == 'tahunan')
                                SizedBox(
                                  width: 128,
                                  child: DropdownButtonFormField<int>(
                                    initialValue:
                                        _opsiTahunGrafik.contains(_tahunGrafik)
                                        ? _tahunGrafik
                                        : null,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      labelText: 'Tahun',
                                    ),
                                    items: _opsiTahunGrafik
                                        .map(
                                          (tahun) => DropdownMenuItem<int>(
                                            value: tahun,
                                            child: Text('$tahun'),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value == null ||
                                          value == _tahunGrafik) {
                                        return;
                                      }
                                      setState(() => _tahunGrafik = value);
                                      _loadData(preserveVisibleData: true);
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _buildGrafikBulanan(),
                const SizedBox(height: 18),
                KeyedSubtree(
                  key: widget.tutorialPengajuanKey,
                  child: _sectionTitle(
                    'Pengajuan Menunggu Terbaru',
                    'Masuk cepat ke approval tanpa perlu membuka daftar penuh.',
                  ),
                ),
                const SizedBox(height: 10),
                if (_pengajuanTerbaru.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('Belum ada pengajuan menunggu.'),
                    ),
                  )
                else
                  ..._pengajuanTerbaru.map(
                    (item) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LayarPersetujuanApdAdmin(
                                usernameAdmin: widget.username,
                              ),
                            ),
                          ).then((_) => _loadData());
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: TemaAplikasi.emas.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: TemaAplikasi.emasTua,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item['nama_apd'] ?? '-'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${item['nama_lengkap'] ?? item['username_karyawan'] ?? '-'} - '
                                      '${item['jabatan'] ?? '-'}',
                                      style: const TextStyle(
                                        color: TemaAplikasi.netral,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: TemaAplikasi.biruMuda,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: TemaAplikasi.biruTua,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: TemaAplikasi.netral, height: 1.4),
        ),
      ],
    );
  }

  Widget _menuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: const Color(0xFFD2A92B), size: 28),
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
    );
  }

  Widget _summaryCard({
    required String title,
    required int value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 14),
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGrafikBulanan() {
    if (_grafikBulanan.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(_teksDataGrafikKosong()),
        ),
      );
    }

    final points = _grafikBulanan.map((item) {
      final menunggu = _pickInt(item, [
        'menunggu',
        'total_menunggu',
        'pending',
      ]);
      final disetujui = _pickInt(item, [
        'disetujui',
        'total_disetujui',
        'approved',
      ]);
      final stokMenipis = _pickInt(item, [
        'stok_menipis',
        'stok_apd_menipis',
        'low_stock',
      ]);
      final totalMasuk = _pickInt(item, [
        'total_masuk',
        'masuk',
        'total_pengajuan',
        'total',
      ], fallback: menunggu + disetujui);
      final periodKey =
          item['bulan']?.toString() ??
          item['periode']?.toString() ??
          item['periode_key']?.toString() ??
          item['tanggal']?.toString() ??
          item['date']?.toString() ??
          '';
      final label = _pickLabel(item);
      return _GrafikPoint(
        periodKey: periodKey,
        label: label,
        menunggu: menunggu,
        disetujui: disetujui,
        stokMenipis: stokMenipis,
        totalMasuk: totalMasuk,
      );
    }).toList()..sort((a, b) => a.periodKey.compareTo(b.periodKey));

    final maxValue = points.fold<int>(1, (current, item) {
      return math.max(
        current,
        math.max(
          item.totalMasuk,
          math.max(item.menunggu, math.max(item.disetujui, item.stokMenipis)),
        ),
      );
    });
    final safeMax = maxValue <= 0 ? 1 : maxValue;
    final chartWidth = math.max((points.length * 82), 380).toDouble();
    final totalMasukSemua = points.fold<int>(
      0,
      (sum, item) => sum + item.totalMasuk,
    );
    final totalMasukTerakhir = points.isNotEmpty ? points.last.totalMasuk : 0;
    final totalMasukSebelumnya = points.length > 1
        ? points[points.length - 2].totalMasuk
        : 0;
    final perubahanMasuk = totalMasukTerakhir - totalMasukSebelumnya;
    final trenNaik = perubahanMasuk >= 0;
    final barHeightMax = 120.0;
    final tinggiPlot = barHeightMax + 22;
    final axisValues = List<int>.generate(5, (index) {
      final ratio = (4 - index) / 4;
      return (safeMax * ratio).round();
    });

    double hitungBarHeight(int value) {
      if (!_animateChart) return 0;
      if (value <= 0) return 0;
      final ratio = value / safeMax;
      return math.max(6, ratio * barHeightMax).toDouble();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricPill(
                  title: 'Total Masuk',
                  value: '$totalMasukSemua',
                  color: Colors.indigo,
                  subtitle: '${points.length} periode',
                ),
                _MetricPill(
                  title: 'Periode Terakhir',
                  value: '$totalMasukTerakhir',
                  color: Colors.teal,
                  subtitle: points.isNotEmpty ? points.last.label : '-',
                ),
                _MetricPill(
                  title: 'Arah Tren',
                  value: trenNaik ? 'Naik' : 'Turun',
                  color: trenNaik ? Colors.green : Colors.red,
                  subtitle: '${perubahanMasuk >= 0 ? '+' : ''}$perubahanMasuk',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF2F7FF), Color(0xFFFFF9EF)],
                ),
                border: Border.all(color: const Color(0xFFE6ECF7)),
              ),
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
              child: SizedBox(
                height: 210,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 38,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2, right: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: axisValues
                              .map(
                                (value) => Text(
                                  '$value',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF5D6778),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: chartWidth,
                          child: Column(
                            children: [
                              SizedBox(
                                height: tinggiPlot,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: List.generate(
                                          axisValues.length,
                                          (index) => Container(
                                            height: 1,
                                            color:
                                                index == axisValues.length - 1
                                                ? const Color(0xFFBFCBDA)
                                                : const Color(0xFFDCE5F4),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          for (final item in points)
                                            SizedBox(
                                              width: chartWidth / points.length,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  _MiniBar(
                                                    color: Colors.indigo,
                                                    height: hitungBarHeight(
                                                      item.totalMasuk,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  _MiniBar(
                                                    color: Colors.blue,
                                                    height: hitungBarHeight(
                                                      item.menunggu,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  _MiniBar(
                                                    color: Colors.green,
                                                    height: hitungBarHeight(
                                                      item.disetujui,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  _MiniBar(
                                                    color: const Color(
                                                      0xFFD2A92B,
                                                    ),
                                                    height: hitungBarHeight(
                                                      item.stokMenipis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  for (final item in points)
                                    SizedBox(
                                      width: chartWidth / points.length,
                                      child: Text(
                                        item.label,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _LegendItem(color: Colors.indigo, text: 'Total Masuk'),
                _LegendItem(color: Colors.blue, text: 'Menunggu'),
                _LegendItem(color: Colors.green, text: 'Disetujui'),
                _LegendItem(color: Color(0xFFD2A92B), text: 'Stok Menipis'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GrafikPoint {
  final String periodKey;
  final String label;
  final int menunggu;
  final int disetujui;
  final int stokMenipis;
  final int totalMasuk;

  const _GrafikPoint({
    required this.periodKey,
    required this.label,
    required this.menunggu,
    required this.disetujui,
    required this.stokMenipis,
    required this.totalMasuk,
  });
}

class _AdminHeaderPill extends StatelessWidget {
  final IconData ikon;
  final String label;
  final Color warna;

  const _AdminHeaderPill({
    required this.ikon,
    required this.label,
    required this.warna,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 16, color: warna),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final Color color;
  final double height;

  const _MiniBar({required this.color, required this.height});

  @override
  Widget build(BuildContext context) {
    final tampilMarker = height > 0;

    return SizedBox(
      width: 10,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 350),
            opacity: tampilMarker ? 1 : 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.3),
              ),
            ),
          ),
          SizedBox(height: tampilMarker ? 4 : 0),
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            width: 8,
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final String subtitle;

  const _MetricPill({
    required this.title,
    required this.value,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

