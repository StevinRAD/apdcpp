import 'dart:async';
import 'package:flutter/material.dart';

import 'package:apdcpp/konfigurasi_api.dart';
import 'package:apdcpp/admin_panel/layar_edit_profil_admin.dart';
import 'package:apdcpp/admin_panel/layar_manajemen_admin.dart';
import 'package:apdcpp/awal/layar_pilih_peran.dart';
import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/services/sesi_aplikasi_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';

class TabAdminProfil extends StatefulWidget {
  final String username;
  final String namaLengkap;
  final String? fotoProfil;
  final GlobalKey? tutorialProfilKey;
  final VoidCallback? onMulaiTutorial;
  final ValueChanged<Map<String, String>>? onProfileUpdated;

  const TabAdminProfil({
    super.key,
    required this.username,
    required this.namaLengkap,
    this.fotoProfil,
    this.tutorialProfilKey,
    this.onMulaiTutorial,
    this.onProfileUpdated,
  });

  @override
  State<TabAdminProfil> createState() => _TabAdminProfilState();
}

class _TabAdminProfilState extends State<TabAdminProfil> {
  final ApiApdService _api = const ApiApdService();

  bool _loading = true;
  String _username = '';
  String _namaLengkap = '';
  String _fotoProfil = '';
  String _peranAdmin = 'biasa';

  @override
  void initState() {
    super.initState();
    _username = widget.username;
    _namaLengkap = widget.namaLengkap;
    _fotoProfil = widget.fotoProfil ?? '';
    _loadSesiLokal();
    _loadProfil();
  }

  Future<void> _loadSesiLokal() async {
    final sesi = await SesiAplikasiService.ambilSesi();
    if (sesi != null && mounted) {
      setState(() {
        _peranAdmin = sesi['peran_admin'] ?? 'biasa';
      });
    }
  }

  Future<void> _loadProfil() async {
    setState(() => _loading = true);

    final response = await _api.profilAdmin(_username);
    if (!mounted) return;

    if (_api.isSuccess(response)) {
      final data = _api.extractMapData(response);
      setState(() {
        _username = data['username']?.toString() ?? _username;
        _namaLengkap = data['nama_lengkap']?.toString() ?? _namaLengkap;
        _fotoProfil = data['foto_profil']?.toString() ?? _fotoProfil;
        _loading = false;
      });
      return;
    }

    setState(() => _loading = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_api.message(response))));
  }

  Future<void> _bukaEditProfil() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => LayarEditProfilAdmin(
          username: _username,
          namaLengkap: _namaLengkap,
          fotoProfil: _fotoProfil,
        ),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _username = result['username']?.toString() ?? _username;
      _namaLengkap = result['nama_lengkap']?.toString() ?? _namaLengkap;
      _fotoProfil = result['foto_profil']?.toString() ?? _fotoProfil;
    });

    widget.onProfileUpdated?.call({
      'username': _username,
      'nama_lengkap': _namaLengkap,
      'foto_profil': _fotoProfil,
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar Aplikasi?'),
        content: const Text(
          'Sesi login Anda saat ini akan dihapus dari sistem. Anda harus memasukkan username dan password kembali untuk bisa masuk ke dalam akun Anda.',
          style: TextStyle(height: 1.45),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: TemaAplikasi.netral),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: TemaAplikasi.bahaya,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Keluar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SesiAplikasiService.hapusSesi();
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LayarPilihPeran()),
        (_) => false,
      );
    }
  }

  Widget _tombolHapusData(String label, String jenis) {
    return ElevatedButton(
      onPressed: () => _konfirmasiHapus(label, jenis),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: TemaAplikasi.bahaya,
        side: BorderSide(color: TemaAplikasi.bahaya.withValues(alpha: 0.5)),
        elevation: 0,
      ),
      child: Text(label),
    );
  }

  Future<void> _konfirmasiHapus(String label, String jenis) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus $label?'),
        content: Text(
          'Apakah Anda yakin ingin menghapus semua data $label? Tindakan ini tidak dapat dibatalkan.',
          style: const TextStyle(height: 1.45),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: TemaAplikasi.netral),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: TemaAplikasi.bahaya,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      _prosesHapusData(jenis);
    }
  }

  Future<void> _prosesHapusData(String jenis) async {
    setState(() => _loading = true);
    final response = await _api.hapusDataSpesifik(jenis);
    if (!mounted) return;
    setState(() => _loading = false);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_api.message(response))));
  }

  Future<void> _konfirmasiHapusSemua() async {
    // Popup 1
    final konfirmasi1 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'PERINGATAN BAHAYA!',
          style: TextStyle(color: TemaAplikasi.bahaya),
        ),
        content: const Text(
          'Anda akan menghapus SEMUA data di aplikasi termasuk akun karyawan, riwayat pengajuan, stok, dan notifikasi.\n\nAplikasi akan kembali seperti saat pertama kali diinstal. (Data Admin tetap utuh)\n\nApakah Anda sungguh yakin ingin melanjutkan?',
          style: TextStyle(height: 1.45),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: TemaAplikasi.netral),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: TemaAplikasi.bahaya,
              foregroundColor: Colors.white,
            ),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );

    if (konfirmasi1 == true && mounted) {
      // Popup 2 with countdown
      final konfirmasi2 = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _DialogHitundurHapusSemua(),
      );

      if (konfirmasi2 == true && mounted) {
        setState(() => _loading = true);
        final response = await _api.resetAplikasi();
        if (!mounted) return;
        setState(() => _loading = false);

        if (_api.isSuccess(response)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Aplikasi berhasil direset. Data Admin tidak terhapus.',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_api.message(response))));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fotoUrl = buildUploadUrl(_fotoProfil);

    return RefreshIndicator(
      onRefresh: _loadProfil,
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
            child: KeyedSubtree(
              key: widget.tutorialProfilKey,
              child: _loading
                  ? Container(
                      height: 220,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.white,
                            backgroundImage: fotoUrl.isEmpty
                                ? null
                                : NetworkImage(fotoUrl),
                            child: fotoUrl.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    size: 42,
                                    color: TemaAplikasi.emas,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _namaLengkap,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@$_username',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.76),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Kelola identitas akun admin dan akses tutorial kapan saja saat dibutuhkan.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.84),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _bukaEditProfil,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: TemaAplikasi.biruTua,
                                  ),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Edit Profil'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: widget.onMulaiTutorial,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.play_circle_outline),
                                  label: const Text('Tutorial'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informasi Akun',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Data utama akun admin yang sedang aktif di aplikasi.',
                          style: TextStyle(
                            color: TemaAplikasi.netral,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _profilInfoTile(
                          icon: Icons.badge_outlined,
                          label: 'Nama lengkap',
                          value: _namaLengkap,
                        ),
                        const SizedBox(height: 12),
                        _profilInfoTile(
                          icon: Icons.alternate_email,
                          label: 'Username',
                          value: '@$_username',
                        ),
                        const SizedBox(height: 12),
                        _profilInfoTile(
                          icon: Icons.admin_panel_settings_outlined,
                          label: 'Peran',
                          value: _peranAdmin == 'master'
                              ? 'Admin Master'
                              : 'Admin',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: TemaAplikasi.bahaya.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: TemaAplikasi.bahaya.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pusat Kontrol Data',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: TemaAplikasi.bahaya,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Hapus data spesifik atau atur ulang aplikasi menjadi seperti baru.',
                        style: TextStyle(
                          color: TemaAplikasi.netral,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Karyawan',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: TemaAplikasi.netral,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _tombolHapusData('Akun Karyawan', 'karyawan'),
                                const SizedBox(height: 8),
                                _tombolHapusData('Notifikasi Seluruh Karyawan', 'notifikasi'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Admin',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: TemaAplikasi.netral,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _tombolHapusData('Pengajuan APD', 'pengajuan'),
                                const SizedBox(height: 8),
                                _tombolHapusData('Laporan Kendala APD', 'laporan_kendala'),
                                const SizedBox(height: 8),
                                _tombolHapusData('Stok APD', 'master_apd'),
                                const SizedBox(height: 8),
                                _tombolHapusData('Kalender Terhubung Karyawan', 'kalender'),
                                const SizedBox(height: 8),
                                _tombolHapusData('Berita Terhubung Karyawan', 'berita'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_peranAdmin == 'master') ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _konfirmasiHapusSemua,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: TemaAplikasi.bahaya,
                              side: const BorderSide(color: TemaAplikasi.bahaya),
                            ),
                            icon: const Icon(Icons.warning_amber_rounded),
                            label: const Text('Hapus Semua Data Aplikasi (Reset Pabrik)'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_peranAdmin == 'master') ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: TemaAplikasi.emas.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: TemaAplikasi.emas.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Manajemen Admin Master',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: TemaAplikasi.emasTua,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tambahkan akun admin baru (master atau biasa).',
                          style: TextStyle(
                            color: TemaAplikasi.netral,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LayarManajemenAdmin(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TemaAplikasi.emas,
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Buat Akun Admin'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: TemaAplikasi.bahaya.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: TemaAplikasi.bahaya.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Keluar dari akun',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: TemaAplikasi.bahaya,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Gunakan saat admin selesai memakai aplikasi agar akses tetap aman.',
                        style: TextStyle(
                          color: TemaAplikasi.netral,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _logout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TemaAplikasi.bahaya,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text('Keluar'),
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
    );
  }

  Widget _profilInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: TemaAplikasi.biruMuda,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: TemaAplikasi.biruTua),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: TemaAplikasi.netral,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DialogHitundurHapusSemua extends StatefulWidget {
  @override
  State<_DialogHitundurHapusSemua> createState() =>
      _DialogHitundurHapusSemuaState();
}

class _DialogHitundurHapusSemuaState extends State<_DialogHitundurHapusSemua> {
  int _detikSisa = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_detikSisa > 0) {
        setState(() => _detikSisa--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tombolAktif = _detikSisa == 0;
    return AlertDialog(
      title: const Text(
        'Konfirmasi Terakhir',
        style: TextStyle(color: TemaAplikasi.bahaya),
      ),
      content: Text(
        'Tindakan ini permanen. Semua data akan terhapus. Yakin?\n\n${tombolAktif ? "Sekarang Anda dapat melanjutkan." : "Tunggu $_detikSisa detik..."}',
        style: const TextStyle(height: 1.45),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Batal',
            style: TextStyle(color: TemaAplikasi.netral),
          ),
        ),
        ElevatedButton(
          onPressed: tombolAktif ? () => Navigator.pop(context, true) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: TemaAplikasi.bahaya,
            foregroundColor: Colors.white,
          ),
          child: const Text('Hapus Semua'),
        ),
      ],
    );
  }
}

