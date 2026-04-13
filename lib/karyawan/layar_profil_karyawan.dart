import 'package:flutter/material.dart';

import 'package:apdcpp/konfigurasi_api.dart';
import 'package:apdcpp/karyawan/layar_edit_profil_karyawan.dart';
import 'package:apdcpp/karyawan/layar_kalender_karyawan.dart';
import 'package:apdcpp/awal/layar_pilih_peran.dart';
import 'package:apdcpp/karyawan/layar_notifikasi_karyawan.dart';
import 'package:apdcpp/karyawan/layar_panduan_k3.dart';
import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/services/sesi_aplikasi_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';

class LayarProfilKaryawan extends StatefulWidget {
  final String namaLengkap;
  final String username;
  final String? fotoProfil;

  const LayarProfilKaryawan({
    super.key,
    required this.namaLengkap,
    required this.username,
    this.fotoProfil,
  });

  @override
  State<LayarProfilKaryawan> createState() => _LayarProfilKaryawanState();
}

class _LayarProfilKaryawanState extends State<LayarProfilKaryawan> {
  final ApiApdService _api = const ApiApdService();

  late String _namaLengkap;
  late String _username;
  String? _fotoProfil;
  String _jabatan = '-';
  String _departemen = '-';
  String _lokasiKerja = '-';

  @override
  void initState() {
    super.initState();
    _namaLengkap = widget.namaLengkap;
    _username = widget.username;
    _fotoProfil = widget.fotoProfil;
    _loadProfil();
  }

  Future<void> _loadProfil() async {
    final response = await _api.profilKaryawan(_username);
    if (!_api.isSuccess(response) || !mounted) return;

    final data = _api.extractMapData(response);
    setState(() {
      _namaLengkap = data['nama_lengkap']?.toString() ?? _namaLengkap;
      _username = data['username']?.toString() ?? _username;
      _fotoProfil = data['foto_profil']?.toString() ?? _fotoProfil;
      _jabatan = _safeText(data['jabatan']);
      _departemen = _safeText(data['departemen']);
      _lokasiKerja = _safeText(data['lokasi_kerja']);
    });
  }

  String _safeText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return '-';
    return text;
  }

  void _kembali({bool mulaiTutorial = false}) {
    Navigator.pop(context, {
      'namaLengkap': _namaLengkap,
      'username': _username,
      'fotoProfil': _fotoProfil,
      'mulaiTutorial': mulaiTutorial,
    });
  }

  @override
  Widget build(BuildContext context) {
    final fotoUrl = buildUploadUrl(_fotoProfil);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _kembali();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          leading: IconButton(
            onPressed: _kembali,
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Profil Karyawan'),
          backgroundColor: const Color(0xFFD2A92B),
          foregroundColor: Colors.white,
        ),
        body: RefreshIndicator(
          onRefresh: _loadProfil,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: const Color(0xFFD2A92B),
                        backgroundImage: fotoUrl.isEmpty
                            ? null
                            : NetworkImage(fotoUrl),
                        child: fotoUrl.isEmpty
                            ? const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 46,
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _namaLengkap,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '@$_username',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final result =
                              await Navigator.push<Map<String, dynamic>>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LayarEditProfilKaryawan(
                                    namaLengkap: _namaLengkap,
                                    username: _username,
                                  ),
                                ),
                              );
                          if (result != null) {
                            setState(() {
                              _namaLengkap =
                                  result['namaLengkap']?.toString() ??
                                  _namaLengkap;
                              _username =
                                  result['username']?.toString() ?? _username;
                              _fotoProfil =
                                  result['fotoProfil']?.toString() ??
                                  _fotoProfil;
                            });
                          }
                          _loadProfil();
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Profil'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informasi Kerja',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _infoTile(Icons.badge_outlined, 'Jabatan', _jabatan),
                      _infoTile(
                        Icons.account_tree_outlined,
                        'Departemen',
                        _departemen,
                      ),
                      _infoTile(
                        Icons.location_on_outlined,
                        'Lokasi Kerja',
                        _lokasiKerja,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _menuButton(
                icon: Icons.health_and_safety_outlined,
                title: 'Panduan K3',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LayarPanduanK3()),
                  );
                },
              ),
              const SizedBox(height: 10),
              _menuButton(
                icon: Icons.notifications_outlined,
                title: 'Notifikasi',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          LayarNotifikasiKaryawan(username: _username),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _menuButton(
                icon: Icons.calendar_month_outlined,
                title: 'Kalender',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          LayarKalenderKaryawan(username: _username),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _menuButton(
                icon: Icons.play_circle_outline,
                title: 'Mulai Tutorial',
                onTap: () => _kembali(mulaiTutorial: true),
              ),
              const SizedBox(height: 10),
              _menuButton(
                icon: Icons.logout,
                title: 'Keluar',
                textColor: Colors.red,
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Keluar Aplikasi?'),
                      content: const Text(
                        'Sesi login Anda saat ini akan dihapus dari sistem. Anda harus memasukkan username dan password kembali untuk bisa masuk ke dalam akun Anda.',
                        style: TextStyle(height: 1.45),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
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
                      this.context,
                      MaterialPageRoute(
                        builder: (_) => const LayarPilihPeran(),
                      ),
                      (_) => false,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFD2A92B), size: 20),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _menuButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color textColor = Colors.black87,
  }) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: const Color(0xFFD2A92B)),
        title: Text(
          title,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
