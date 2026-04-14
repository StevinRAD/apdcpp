import 'package:flutter/material.dart';

import 'package:apdcpp/admin_panel/layar_dashboard_admin.dart';
import 'package:apdcpp/awal/layar_pilih_peran.dart';
import 'package:apdcpp/karyawan/layar_dashboard_karyawan.dart';
import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/services/sesi_aplikasi_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';

class LayarMemuat extends StatefulWidget {
  const LayarMemuat({super.key});

  @override
  State<LayarMemuat> createState() => _LayarMemuatState();
}

class _LayarMemuatState extends State<LayarMemuat> {
  final ApiApdService _api = const ApiApdService();

  @override
  void initState() {
    super.initState();
    lanjutKePilihPeran();
  }

  Future<void> lanjutKePilihPeran() async {
    final koneksiAwalFuture = _api.cekKoneksiServer();

    // Periksa sesi dari Shared Preferences
    final sesiFuture = SesiAplikasiService.ambilSesi();

    // Pastikan memuat minimal 2,5 detik agar Splashscreen terlihat cantik
    final resultList = await Future.wait([
      koneksiAwalFuture,
      sesiFuture,
      Future.delayed(const Duration(milliseconds: 2500)),
    ]);

    if (!mounted) {
      return;
    }

    final dataSesi = resultList[1] as Map<String, dynamic>?;
    bool sesiValid = false;

    if (dataSesi != null) {
      final peran = dataSesi['peran']?.toString();
      final username = dataSesi['username']?.toString() ?? '';
      final token = dataSesi['session_token']?.toString();

      if (token != null && peran != null) {
        // Cek validitas sesi ke server
        final res = await _api.cekSesi(
          peran: peran,
          username: username,
          sessionToken: token,
        );
        if (res['status'] == 'sukses') {
          sesiValid = true;
        } else {
          // Sesi tidak valid lagi (expired atau di-kick device lain)
          await SesiAplikasiService.hapusSesi();
        }
      }

      if (sesiValid) {
        final namaLengkap = dataSesi['nama_lengkap']?.toString() ?? '';
        final fotoProfil = dataSesi['foto_profil']?.toString();

        if (peran == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => LayarDashboardAdmin(
                username: username,
                namaLengkap: namaLengkap,
                fotoProfil: fotoProfil,
              ),
            ),
          );
          return;
        } else if (peran == 'karyawan') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => LayarDashboardKaryawan(
                username: username,
                namaLengkap: namaLengkap,
                fotoProfil: fotoProfil,
              ),
            ),
          );
          return;
        }
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LayarPilihPeran(koneksiAwalFuture: koneksiAwalFuture),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [TemaAplikasi.biruTua, Color(0xFF071426)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 136,
                  height: 136,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: TemaAplikasi.emas.withValues(alpha: 0.22),
                        blurRadius: 34,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Prima Safety Care',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Sistem pengajuan, persetujuan, dan pemantauan APD untuk operasional perusahaan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFFD3DCE8),
                  ),
                ),
                const SizedBox(height: 26),
                Container(
                  width: 220,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 124,
                      decoration: BoxDecoration(
                        color: TemaAplikasi.emas,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Menyiapkan akses aplikasi...',
                  style: TextStyle(
                    color: Color(0xFFE0E6EF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

