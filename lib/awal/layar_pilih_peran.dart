import 'package:flutter/material.dart';

import 'package:apdcpp/awal/layar_login_admin.dart';
import 'package:apdcpp/awal/layar_login_karyawan.dart';
import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';
import 'package:apdcpp/widgets/dialog_koneksi_internet.dart';

class LayarPilihPeran extends StatefulWidget {
  const LayarPilihPeran({super.key, this.koneksiAwalFuture});

  final Future<bool>? koneksiAwalFuture;

  @override
  State<LayarPilihPeran> createState() => _LayarPilihPeranState();
}

class _LayarPilihPeranState extends State<LayarPilihPeran> {
  final ApiApdService _api = const ApiApdService();
  bool serverTerhubung = false;
  bool _dialogKoneksiSedangTampil = false;

  @override
  void initState() {
    super.initState();
    _inisialisasiKoneksiServer();
  }

  Future<void> _inisialisasiKoneksiServer() async {
    final terhubung =
        await (widget.koneksiAwalFuture ?? _api.cekKoneksiServer());

    if (!mounted) {
      return;
    }

    setState(() {
      serverTerhubung = terhubung;
    });

    if (!terhubung) {
      _tampilkanPopupKoneksiJikaPerlu();
    } else {
      _dialogKoneksiSedangTampil = false;
    }
  }

  Future<void> cekKoneksiServer() async {
    final terhubung = await _api.cekKoneksiServer();

    if (!mounted) {
      return;
    }

    setState(() {
      serverTerhubung = terhubung;
    });

    if (!terhubung) {
      _tampilkanPopupKoneksiJikaPerlu();
    } else {
      _dialogKoneksiSedangTampil = false;
    }
  }

  Future<void> _tampilkanPopupKoneksiJikaPerlu() async {
    if (_dialogKoneksiSedangTampil || !mounted) {
      return;
    }

    _dialogKoneksiSedangTampil = true;

    await Future<void>.delayed(Duration.zero);

    if (!mounted) {
      return;
    }

    await tampilkanDialogKoneksiInternet(context);

    if (!mounted) {
      return;
    }

    _dialogKoneksiSedangTampil = false;
  }

  @override
  Widget build(BuildContext context) {
    final ukuran = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [TemaAplikasi.biruTua, Color(0xFF08172A)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: ukuran.height - 46),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: _StatusServerBadge(
                      terhubung: serverTerhubung,
                      onRefresh: cekKoneksiServer,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Container(
                        width: 66,
                        height: 66,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Image.asset(
                          'assets/images/logobg.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Prima Safety Care',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Pilih akses sesuai peran untuk masuk ke sistem pengelolaan APD perusahaan.',
                              style: TextStyle(
                                height: 1.45,
                                color: Color(0xFFD6DEE8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Masuk Sebagai',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: TemaAplikasi.teksUtama,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Gunakan akun sesuai tanggung jawab kerja agar data pengajuan, persetujuan, dan monitoring APD tetap aman dan terstruktur.',
                          style: TextStyle(
                            height: 1.5,
                            color: TemaAplikasi.netral,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _RoleCard(
                          title: 'Karyawan',
                          subtitle:
                              'Ajukan APD, lihat status, cek informasi, dan pantau kalender kerja.',
                          icon: Icons.badge_outlined,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const LayarLoginKaryawan(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        _RoleCard(
                          title: 'Admin',
                          subtitle:
                              'Kelola pengajuan, stok, karyawan, berita, dan kalender perusahaan.',
                          icon: Icons.admin_panel_settings_outlined,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LayarLoginAdmin(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: TemaAplikasi.emas.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                color: TemaAplikasi.emasTua,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Gunakan akun resmi perusahaan. Pengaturan masa tunggu pengajuan dan status akun dikelola Perusahaan.',
                                  style: TextStyle(
                                    height: 1.45,
                                    color: TemaAplikasi.teksUtama,
                                  ),
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
          ),
        ),
      ),
    );
  }
}

class _StatusServerBadge extends StatelessWidget {
  final bool terhubung;
  final VoidCallback onRefresh;

  const _StatusServerBadge({required this.terhubung, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final warna = terhubung ? TemaAplikasi.sukses : TemaAplikasi.bahaya;
    final label = terhubung ? 'Server Online' : 'Server Offline';

    return InkWell(
      onTap: onRefresh,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.refresh, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: TemaAplikasi.latar,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFDCE3EE)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: TemaAplikasi.emas.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: TemaAplikasi.emasTua),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      height: 1.45,
                      color: TemaAplikasi.netral,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.arrow_forward_rounded,
              color: TemaAplikasi.biruTua,
            ),
          ],
        ),
      ),
    );
  }
}

