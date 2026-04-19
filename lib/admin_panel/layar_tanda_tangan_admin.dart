import 'package:flutter/material.dart';

import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';
import 'package:apdcpp/widgets/widget_tanda_tangan.dart';

/// Layar untuk admin mengelola tanda tangan digital.
/// Tanda tangan disimpan sebagai base64 PNG di kolom `tanda_tangan` tabel admin.
class LayarTandaTanganAdmin extends StatefulWidget {
  final String username;

  const LayarTandaTanganAdmin({super.key, required this.username});

  @override
  State<LayarTandaTanganAdmin> createState() => _LayarTandaTanganAdminState();
}

class _LayarTandaTanganAdminState extends State<LayarTandaTanganAdmin> {
  final ApiApdService _api = const ApiApdService();
  final GlobalKey<WidgetTandaTanganState> _ttdKey = GlobalKey();

  bool _loading = true;
  bool _saving = false;
  String _ttdTersimpan = '';

  @override
  void initState() {
    super.initState();
    _loadTandaTangan();
  }

  Future<void> _loadTandaTangan() async {
    setState(() => _loading = true);
    final response = await _api.ambilTandaTanganAdmin(widget.username);
    if (!mounted) return;

    if (_api.isSuccess(response)) {
      final data = _api.extractMapData(response);
      setState(() {
        _ttdTersimpan = data['tanda_tangan']?.toString() ?? '';
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _simpanTandaTangan() async {
    final ttdState = _ttdKey.currentState;
    if (ttdState == null || !ttdState.sudahDigambar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buat tanda tangan terlebih dahulu')),
      );
      return;
    }

    setState(() => _saving = true);
    final base64 = await ttdState.eksporBase64();
    if (base64 == null || base64.isEmpty) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengekspor tanda tangan')),
        );
      }
      return;
    }

    final response = await _api.simpanTandaTanganAdmin(
      username: widget.username,
      tandaTanganBase64: base64,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (_api.isSuccess(response)) {
      setState(() => _ttdTersimpan = base64);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanda tangan berhasil disimpan!'),
          backgroundColor: TemaAplikasi.sukses,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_api.message(response))),
      );
    }
  }

  Future<void> _hapusTandaTangan() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Tanda Tangan?'),
        content: const Text(
          'Tanda tangan yang tersimpan akan dihapus. Anda perlu membuat tanda tangan baru.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal',
                style: TextStyle(color: TemaAplikasi.netral)),
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
      setState(() => _saving = true);
      final response = await _api.simpanTandaTanganAdmin(
        username: widget.username,
        tandaTanganBase64: '',
      );
      if (!mounted) return;
      setState(() => _saving = false);

      if (_api.isSuccess(response)) {
        setState(() => _ttdTersimpan = '');
        _ttdKey.currentState?.bersihkan();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tanda tangan berhasil dihapus')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tanda Tangan Admin')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: TemaAplikasi.biruMuda,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: TemaAplikasi.biruTua),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tanda tangan ini akan otomatis ditambahkan ke dokumen pengajuan APD saat Anda menyetujui permohonan karyawan.',
                          style: TextStyle(
                            color: TemaAplikasi.biruTua,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Tanda tangan tersimpan
                if (_ttdTersimpan.isNotEmpty) ...[
                  const Text(
                    'Tanda Tangan Tersimpan',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TampilanTandaTangan(
                    base64Ttd: _ttdTersimpan,
                    tinggi: 150,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: _saving ? null : _hapusTandaTangan,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Hapus'),
                        style: TextButton.styleFrom(
                          foregroundColor: TemaAplikasi.bahaya,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 20),
                ],

                // Form tanda tangan baru
                Text(
                  _ttdTersimpan.isNotEmpty
                      ? 'Ganti Tanda Tangan'
                      : 'Buat Tanda Tangan',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                WidgetTandaTangan(
                  key: _ttdKey,
                  tinggi: 220,
                  labelPetunjuk: 'Gambar tanda tangan Anda di area ini',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _simpanTandaTangan,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Menyimpan...' : 'Simpan Tanda Tangan'),
                  ),
                ),
              ],
            ),
    );
  }
}
