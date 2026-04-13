import 'package:flutter/material.dart';
import 'package:apdcpp/services/izin_perangkat_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';

/// Layar untuk request semua izin yang diperlukan
/// Ditampilkan saat pertama kali aplikasi dibuka
class LayarRequestIzin extends StatefulWidget {
  final VoidCallback onSelesai;

  const LayarRequestIzin({
    super.key,
    required this.onSelesai,
  });

  @override
  State<LayarRequestIzin> createState() => _LayarRequestIzinState();
}

class _LayarRequestIzinState extends State<LayarRequestIzin> {
  bool _sedangRequest = false;
  final Map<String, bool> _hasilIzin = {
    'notifikasi': false,
    'kamera': false,
    'galeri': false,
  };

  Future<void> _requestSemuaIzin() async {
    setState(() => _sedangRequest = true);

    final hasil = await IzinPerangkatService.requestSemuaIzin(context);

    if (mounted) {
      setState(() {
        _hasilIzin.clear();
        _hasilIzin.addAll(hasil);
        _sedangRequest = false;
      });
    }
  }

  void _lanjutkan() async {
    // Simpan bahwa izin sudah diberikan (meskipun ada yang ditolak)
    final semuaDiberikan = _hasilIzin.values.every((e) => e);

    if (!semuaDiberikan) {
      // Tampilkan konfirmasi bahwa beberapa izin ditolak
      final lanjut = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Beberapa Izin Ditolak'),
          content: const Text(
            'Beberapa fitur mungkin tidak berfungsi dengan baik. '
            'Anda dapat mengaktifkan izin kapan saja melalui pengaturan aplikasi.\n\n'
            'Lanjutkan ke aplikasi?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cek Lagi'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Lanjutkan'),
            ),
          ],
        ),
      );

      if (lanjut != true) {
        return;
      }
    }

    widget.onSelesai();
  }

  @override
  Widget build(BuildContext context) {
    final sudahRequest = _hasilIzin.values.any((e) => e) ||
        _hasilIzin.values.any((e) => !e);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [TemaAplikasi.biruTua, Color(0xFF09182A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon aplikasi
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: TemaAplikasi.emas.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      size: 50,
                      color: TemaAplikasi.emasTua,
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Izin Aplikasi',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'Untuk pengalaman terbaik, aplikasi ini memerlukan beberapa izin.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFFD4DCE7),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Daftar izin yang diperlukan
                  _buildIzinItem(
                    icon: Icons.notifications_active,
                    judul: 'Notifikasi',
                    deskripsi:
                        'Menerima notifikasi tentang update dan informasi penting',
                    status: _hasilIzin['notifikasi'] ?? false,
                  ),
                  const SizedBox(height: 12),

                  _buildIzinItem(
                    icon: Icons.camera_alt,
                    judul: 'Kamera',
                    deskripsi: 'Mengambil foto profil dan bukti APD',
                    status: _hasilIzin['kamera'] ?? false,
                  ),
                  const SizedBox(height: 12),

                  _buildIzinItem(
                    icon: Icons.photo_library,
                    judul: 'Galeri',
                    deskripsi: 'Memilih foto dari galeri',
                    status: _hasilIzin['galeri'] ?? false,
                  ),
                  const SizedBox(height: 12),

                  const SizedBox(height: 32),

                  // Tombol
                  if (!sudahRequest)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _sedangRequest ? null : _requestSemuaIzin,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: TemaAplikasi.emas,
                          foregroundColor: TemaAplikasi.biruTua,
                        ),
                        child: _sedangRequest
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: TemaAplikasi.biruTua,
                                ),
                              )
                            : const Text(
                                'Berikan Izin',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _hasilIzin.values.every((e) => e)
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _hasilIzin.values.every((e) => e)
                                  ? Colors.green.withValues(alpha: 0.5)
                                  : Colors.orange.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _hasilIzin.values.every((e) => e)
                                    ? Icons.check_circle
                                    : Icons.info,
                                color: _hasilIzin.values.every((e) => e)
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _hasilIzin.values.every((e) => e)
                                      ? 'Semua izin diberikan!'
                                      : 'Beberapa izin belum diberikan',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _sedangRequest
                                    ? null
                                    : _requestSemuaIzin,
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  foregroundColor: TemaAplikasi.emas,
                                  side: const BorderSide(
                                    color: TemaAplikasi.emas,
                                  ),
                                ),
                                child: const Text('Cek Lagi'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _sedangRequest ? null : _lanjutkan,
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: TemaAplikasi.emas,
                                  foregroundColor: TemaAplikasi.biruTua,
                                ),
                                child: const Text(
                                  'Lanjutkan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIzinItem({
    required IconData icon,
    required String judul,
    required String deskripsi,
    required bool status,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status
              ? Colors.green.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: status
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: status ? Colors.green : Colors.white70,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  judul,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  deskripsi,
                  style: const TextStyle(
                    color: Color(0xFFD4DCE7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (status)
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 24,
            )
          else
            Icon(
              Icons.circle_outlined,
              color: Colors.white.withValues(alpha: 0.3),
              size: 24,
            ),
        ],
      ),
    );
  }
}
