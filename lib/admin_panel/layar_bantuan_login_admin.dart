import 'package:flutter/material.dart';

import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';

class LayarBantuanLoginAdmin extends StatefulWidget {
  const LayarBantuanLoginAdmin({super.key});

  @override
  State<LayarBantuanLoginAdmin> createState() => _LayarBantuanLoginAdminState();
}

class _LayarBantuanLoginAdminState extends State<LayarBantuanLoginAdmin> {
  final ApiApdService _api = const ApiApdService();
  List<Map<String, dynamic>> _daftarPesan = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPesan();
  }

  Future<void> _loadPesan() async {
    setState(() => _loading = true);
    final response = await _api.daftarBantuanLogin();
    if (!mounted) return;

    if (_api.isSuccess(response)) {
      final listRaw = _api.extractListData(response);
      setState(() {
        _daftarPesan = listRaw
            .whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry('$k', v)))
            .toList();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_api.message(response))));
    }
  }

  Future<void> _ubahStatus(String idBantuan, String aksi) async {
    // tandai_baca atau hapus
    setState(() => _loading = true);
    final response = await _api.ubahStatusBantuanLogin(
      idBantuan: idBantuan,
      aksi: aksi,
    );
    if (!mounted) return;

    if (_api.isSuccess(response)) {
      await _loadPesan();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_api.message(response)),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_api.message(response)),
          backgroundColor: TemaAplikasi.bahaya,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Banding & Bantuan Login'),
        backgroundColor: Colors.white,
        foregroundColor: TemaAplikasi.biruTua,
        elevation: 0,
      ),
      body: _loading && _daftarPesan.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPesan,
              child: _daftarPesan.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.mark_email_read_outlined,
                            size: 64,
                            color: TemaAplikasi.netral.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Belum ada pesan bantuan/banding',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: TemaAplikasi.netral,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Karyawan yang terkunci akan muncul di sini.',
                            style: TextStyle(color: TemaAplikasi.netral),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _daftarPesan.length,
                      itemBuilder: (context, index) {
                        final pesan = _daftarPesan[index];
                        final idBantuan =
                            pesan['id_bantuan']?.toString().trim() ?? '';
                        final isDibaca = (pesan['status_baca'] ?? 0) == 1;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isDibaca
                                  ? Colors.grey.withValues(alpha: 0.2)
                                  : TemaAplikasi.emas.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          elevation: isDibaca ? 0 : 2,
                          color: isDibaca ? Colors.white70 : Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: isDibaca
                                          ? Colors.grey.withValues(alpha: 0.2)
                                          : TemaAplikasi.emas.withValues(
                                              alpha: 0.2,
                                            ),
                                      child: Icon(
                                        Icons.person_off_outlined,
                                        color: isDibaca
                                            ? Colors.grey
                                            : TemaAplikasi.emasTua,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pesan['nama_lengkap'] ?? '-',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: TemaAplikasi.biruTua,
                                            ),
                                          ),
                                          Text(
                                            '@${pesan['username_karyawan']}',
                                            style: const TextStyle(
                                              color: TemaAplikasi.netral,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      pesan['created_at']
                                              ?.toString()
                                              .split(' ')
                                              .first ??
                                          '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: TemaAplikasi.netral.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 8),
                                const Text(
                                  'Password Terakhir Diingat:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: TemaAplikasi.netral,
                                  ),
                                ),
                                Text(
                                  pesan['password_diingat'] ?? '-',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Penjelasan/Kendala:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: TemaAplikasi.netral,
                                  ),
                                ),
                                Text(
                                  pesan['alasan_kendala'] ?? '-',
                                  style: const TextStyle(height: 1.4),
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () =>
                                          _ubahStatus(idBantuan, 'hapus'),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                      ),
                                      label: const Text('Hapus'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: TemaAplikasi.bahaya,
                                      ),
                                    ),
                                    if (!isDibaca) ...[
                                      OutlinedButton.icon(
                                        onPressed: () => _ubahStatus(
                                          idBantuan,
                                          'tandai_baca',
                                        ),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text('Abaikan'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: TemaAplikasi.netral,
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _ubahStatus(idBantuan, 'aktifkan'),
                                        icon: const Icon(
                                          Icons.lock_open,
                                          size: 18,
                                        ),
                                        label: const Text('Aktifkan Akun'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: TemaAplikasi.biruTua,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
