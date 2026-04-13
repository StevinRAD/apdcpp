import 'package:flutter/material.dart';
import 'package:apdcpp/admin_panel/layar_lupa_sandi_admin.dart';

import 'package:apdcpp/admin_panel/layar_dashboard_admin.dart';
import 'package:apdcpp/awal/layar_pilih_peran.dart';
import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/services/sesi_aplikasi_service.dart';
import 'package:apdcpp/services/single_device_session_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';
import 'package:apdcpp/utils/navigasi_kembali.dart';
import 'package:apdcpp/widgets/dialog_koneksi_internet.dart';

class LayarLoginAdmin extends StatefulWidget {
  const LayarLoginAdmin({super.key});

  @override
  State<LayarLoginAdmin> createState() => _LayarLoginAdminState();
}

class _LayarLoginAdminState extends State<LayarLoginAdmin> {
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

    final response = await _api.loginAdmin(
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
        peran: 'admin',
        username: data['username']?.toString() ?? username,
        namaLengkap: data['nama_lengkap']?.toString() ?? 'Admin',
        fotoProfil: data['foto_profil']?.toString(),
        sessionToken: data['session_token']?.toString(),
        peranAdmin: data['peran_admin']?.toString() ?? 'biasa',
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => LayarDashboardAdmin(
            namaLengkap: data['nama_lengkap']?.toString() ?? 'Admin',
            username: data['username']?.toString() ?? username,
            fotoProfil: data['foto_profil']?.toString(),
          ),
        ),
        (_) => false,
      );
      return;
    }

    if (response['status'] == 'terkunci') {
      setState(() {
        _akunTerkunci = true;
      });
    } else {
      setState(() {
        _akunTerkunci = false;
      });
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_api.message(response))));
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
                    'Login Admin',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Masuk untuk memverifikasi pengajuan, mengelola stok APD, karyawan, berita, dan kalender perusahaan.',
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
                            Icons.admin_panel_settings_outlined,
                            size: 30,
                            color: TemaAplikasi.emasTua,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Akses Panel Admin',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Gunakan akun admin resmi agar proses persetujuan dan pengaturan aplikasi tetap aman.',
                          style: TextStyle(
                            height: 1.45,
                            color: TemaAplikasi.netral,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _usernameController,
                          textInputAction: TextInputAction.next,
                          readOnly: _akunTerkunci,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          obscureText: _sembunyikanPassword,
                          readOnly: _akunTerkunci,
                          onSubmitted: (_) => (_sedangLoading || _akunTerkunci)
                              ? null
                              : _prosesLogin(),
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
                            onPressed: (_sedangLoading || _akunTerkunci)
                                ? null
                                : _prosesLogin,
                            child: _sedangLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Masuk'),
                          ),
                        ),
                        if (_akunTerkunci) ...[
                          const SizedBox(height: 10),
                          Center(
                            child: TextButton(
                              onPressed: () async {
                                final result = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LayarLupaSandiAdmin(
                                      username: _usernameController.text.trim(),
                                    ),
                                  ),
                                );

                                if (result == true) {
                                  if (!mounted) return;
                                  setState(() {
                                    _akunTerkunci = false;
                                    _usernameController.clear();
                                    _passwordController.clear();
                                  });
                                }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: TemaAplikasi.biruTua,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              child: const Text('Lupa Sandi Admin?'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
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
                                Icons.rule_folder_outlined,
                                color: TemaAplikasi.emasTua,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Admin mengontrol status akun, masa tunggu pengajuan per karyawan, dan alur persetujuan APD.',
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

