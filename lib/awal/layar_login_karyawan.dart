import 'package:flutter/material.dart';

import 'package:apdcpp/awal/layar_pilih_peran.dart';
import 'package:apdcpp/karyawan/layar_dashboard_karyawan.dart';
import 'package:apdcpp/karyawan/layar_hubungi_admin.dart';
import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/services/sesi_aplikasi_service.dart';
import 'package:apdcpp/services/single_device_session_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';
import 'package:apdcpp/utils/navigasi_kembali.dart';
import 'package:apdcpp/widgets/dialog_koneksi_internet.dart';

class LayarLoginKaryawan extends StatefulWidget {
  const LayarLoginKaryawan({super.key});

  @override
  State<LayarLoginKaryawan> createState() => _LayarLoginKaryawanState();
}

class _LayarLoginKaryawanState extends State<LayarLoginKaryawan> {
  final ApiApdService _api = const ApiApdService();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _sedangLoading = false;
  bool _sembunyikanPassword = true;
  bool _akunTerkunci = false;

  Future<void> _prosesLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username dan password wajib diisi')),
      );
      return;
    }

    final koneksiTersedia = await _api.cekKoneksiServer();
    if (!mounted) return;

    if (!koneksiTersedia) {
      await tampilkanDialogKoneksiInternet(context);
      return;
    }

    setState(() => _sedangLoading = true);

    // Ambil device ID untuk single device login
    final deviceId = await SingleDeviceSessionService.getDeviceId();

    final response = await _api.loginKaryawan(
      username: username,
      password: password,
      deviceId: deviceId,
      deviceName: 'Flutter App', // Bisa diubah dengan nama device yang lebih spesifik
    );
    if (!mounted) return;

    setState(() => _sedangLoading = false);

    if (_api.isSuccess(response)) {
      final data = _api.extractMapData(response);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selamat datang, ${data['nama_lengkap'] ?? username}!'),
        ),
      );

      // Simpan device ID untuk single device session
      final deviceId = await SingleDeviceSessionService.getDeviceId();
      await SingleDeviceSessionService.simpanDeviceIdSesi(deviceId);

      await SesiAplikasiService.simpanSesi(
        peran: 'karyawan',
        username: data['username']?.toString() ?? username,
        namaLengkap: data['nama_lengkap']?.toString() ?? 'Karyawan',
        fotoProfil: data['foto_profil']?.toString(),
        sessionToken: data['session_token']?.toString(),
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => LayarDashboardKaryawan(
            namaLengkap: data['nama_lengkap']?.toString() ?? 'Karyawan',
            username: data['username']?.toString() ?? username,
            fotoProfil: data['foto_profil']?.toString(),
          ),
        ),
        (_) => false,
      );
      return;
    }

    final pesanAsli = _api.message(response);
    final pesanLower = pesanAsli.toLowerCase();

    if (pesanAsli.startsWith('TUNGGU_BANDING|')) {
      final textBersih = pesanAsli.split('|').last;
      setState(() => _akunTerkunci = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(textBersih),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (pesanLower.contains('nonaktif') ||
        pesanLower.contains('hubungi admin') ||
        pesanLower.contains('3 kali')) {
      setState(() => _akunTerkunci = true);
    } else {
      setState(() => _akunTerkunci = false);
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(pesanAsli)));
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await kembaliAtauKe(context, const LayarPilihPeran());
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [TemaAplikasi.biruTua, Color(0xFF09182A)],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () async {
                      await kembaliAtauKe(context, const LayarPilihPeran());
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                    ),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Login Karyawan',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Masuk untuk mengajukan APD, memantau status, dan membaca informasi perusahaan.',
                    style: TextStyle(height: 1.5, color: Color(0xFFD4DCE7)),
                  ),
                  const SizedBox(height: 24),
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
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: TemaAplikasi.emas.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.badge_outlined,
                            size: 30,
                            color: TemaAplikasi.emasTua,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Akses Akun',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Gunakan username dan password resmi dari admin perusahaan.',
                          style: TextStyle(
                            height: 1.45,
                            color: TemaAplikasi.netral,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _usernameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          obscureText: _sembunyikanPassword,
                          onSubmitted: (_) =>
                              _sedangLoading ? null : _prosesLogin(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _sembunyikanPassword = !_sembunyikanPassword;
                                });
                              },
                              icon: Icon(
                                _sembunyikanPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _sedangLoading ? null : _prosesLogin,
                            child: _sedangLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Masuk ke Dashboard'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_akunTerkunci) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: TemaAplikasi.bahaya.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: TemaAplikasi.bahaya.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.lock_person,
                                      color: TemaAplikasi.bahaya,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Akun Anda dinonaktifkan.',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: TemaAplikasi.bahaya,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => LayarHubungiAdmin(
                                            usernameAwal: _usernameController
                                                .text
                                                .trim(),
                                          ),
                                        ),
                                      );
                                      if (result == true) {
                                        setState(() {
                                          _akunTerkunci = false;
                                        });
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: TemaAplikasi.bahaya,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.support_agent),
                                    label: const Text(
                                      'Hubungi Admin / Banding',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: TemaAplikasi.biruMuda,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                color: TemaAplikasi.biruTua,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Status akun, masa tunggu pengajuan, dan hak akses ditentukan dari panel admin.',
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

