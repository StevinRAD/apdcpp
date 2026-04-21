import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';
import 'package:apdcpp/karyawan/layar_preview_dokumen_pengajuan.dart';

/// Layar daftar dokumen pengajuan APD untuk admin.
/// HANYA untuk melihat dokumen (view-only). TIDAK ada tombol terima/tolak.
/// Untuk persetujuan, gunakan menu "Persetujuan APD".
class LayarDaftarDokumenAdmin extends StatefulWidget {
  final String username;

  const LayarDaftarDokumenAdmin({super.key, required this.username});

  @override
  State<LayarDaftarDokumenAdmin> createState() =>
      _LayarDaftarDokumenAdminState();
}

class _LayarDaftarDokumenAdminState extends State<LayarDaftarDokumenAdmin> {
  final ApiApdService _api = const ApiApdService();

  bool _loading = true;
  List<Map<String, dynamic>> _dokumenList = [];
  String _filterStatus = ''; // '' = semua

  @override
  void initState() {
    super.initState();
    _loadDokumen();
  }

  Future<void> _loadDokumen() async {
    setState(() => _loading = true);
    final response = await _api.daftarDokumenPengajuan(
      filterStatus: _filterStatus.isEmpty ? null : _filterStatus,
    );
    if (!mounted) return;

    if (_api.isSuccess(response)) {
      setState(() {
        _dokumenList = _api.extractListData(response);
        _loading = false;
      });
    } else {
      setState(() {
        _dokumenList = [];
        _loading = false;
      });
    }
  }

  String _formatTanggal(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final dt = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (dt == null) return raw;
    return DateFormat('dd MMM yyyy, HH:mm').format(dt);
  }

  /// Menghitung status tampilan berdasarkan data dokumen.
  /// Jika status backend masih 'menunggu' tapi sudah ada item diproses,
  /// tampilkan 'selesai' atau 'diproses'.
  String _computeDisplayStatus(Map<String, dynamic> dok) {
    final rawStatus = dok['status']?.toString().toLowerCase() ?? 'menunggu';
    if (rawStatus != 'menunggu') return rawStatus;

    // Cek dari jumlah item yang sudah diproses (jika API menyediakan)
    final jumlahItem = int.tryParse('${dok['jumlah_item'] ?? 0}') ?? 0;
    final jumlahDiterima = int.tryParse('${dok['jumlah_diterima'] ?? 0}') ?? 0;
    final jumlahDitolak = int.tryParse('${dok['jumlah_ditolak'] ?? 0}') ?? 0;
    final totalDiproses = jumlahDiterima + jumlahDitolak;

    if (totalDiproses > 0 && totalDiproses >= jumlahItem && jumlahItem > 0) {
      return 'selesai';
    }
    if (totalDiproses > 0) {
      return 'diproses'; 
    }
    return rawStatus;
  }

  Color _statusColor(String s) {
    if (s == 'diterima') return TemaAplikasi.sukses;
    if (s == 'ditolak') return TemaAplikasi.bahaya;
    if (s == 'selesai' || s == 'diproses') return TemaAplikasi.biruTua;
    return Colors.orange;
  }

  String _statusLabel(String s) {
    if (s == 'diterima') return 'Diterima';
    if (s == 'ditolak') return 'Ditolak';
    if (s == 'selesai') return 'Selesai';
    if (s == 'diproses') return 'Diproses';
    return 'Menunggu';
  }

  IconData _statusIcon(String s) {
    if (s == 'diterima') return Icons.check_circle;
    if (s == 'ditolak') return Icons.cancel;
    if (s == 'selesai' || s == 'diproses') return Icons.task_alt;
    return Icons.hourglass_empty;
  }

  void _lihatDokumen(Map<String, dynamic> dok) {
    // Selalu tampilkan preview pengajuan yang menunjukkan status per item
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LayarPreviewDokumenPengajuan(
          idDokumen: dok['id']?.toString() ?? '',
          username: widget.username,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dokumen Pengajuan APD'),
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Semua',
                  aktif: _filterStatus.isEmpty,
                  onTap: () {
                    _filterStatus = '';
                    _loadDokumen();
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Menunggu',
                  aktif: _filterStatus == 'menunggu',
                  warna: Colors.orange,
                  onTap: () {
                    _filterStatus = 'menunggu';
                    _loadDokumen();
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Diterima',
                  aktif: _filterStatus == 'diterima',
                  warna: TemaAplikasi.sukses,
                  onTap: () {
                    _filterStatus = 'diterima';
                    _loadDokumen();
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Ditolak',
                  aktif: _filterStatus == 'ditolak',
                  warna: TemaAplikasi.bahaya,
                  onTap: () {
                    _filterStatus = 'ditolak';
                    _loadDokumen();
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Selesai',
                  aktif: _filterStatus == 'selesai',
                  warna: TemaAplikasi.biruTua,
                  onTap: () {
                    _filterStatus = 'selesai';
                    _loadDokumen();
                  },
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _dokumenList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.description_outlined,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada dokumen pengajuan',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadDokumen,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: _dokumenList.length,
                          itemBuilder: (_, i) => _buildDokumenCard(
                            _dokumenList[i],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDokumenCard(Map<String, dynamic> dok) {
    final status = _computeDisplayStatus(dok);
    final warna = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: warna.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: () => _lihatDokumen(dok),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: nama + status
              Row(
                children: [
                  Icon(_statusIcon(status), color: warna, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dok['nama_karyawan']?.toString() ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: warna.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        color: warna,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Info
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _InfoItem(
                    icon: Icons.business_outlined,
                    text: dok['departemen']?.toString() ?? '-',
                  ),
                  _InfoItem(
                    icon: Icons.inventory_2_outlined,
                    text: '${dok['jumlah_item'] ?? 0} item APD',
                  ),
                  _InfoItem(
                    icon: Icons.schedule_outlined,
                    text: _formatTanggal(
                        dok['tanggal_pengajuan']?.toString()),
                  ),
                ],
              ),

              // Catatan admin jika ada
              if ((dok['catatan_admin']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TemaAplikasi.emas.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: TemaAplikasi.emas.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.note_outlined,
                              size: 16, color: TemaAplikasi.emasTua),
                          const SizedBox(width: 6),
                          Text(
                            'Catatan Admin',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: TemaAplikasi.emasTua,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dok['catatan_admin']?.toString() ?? '',
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],

              // Info untuk persetujuan
              if (status == 'menunggu') ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: TemaAplikasi.biruMuda.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: TemaAplikasi.biruTua),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Untuk menyetujui/menolak, gunakan menu "Persetujuan APD"',
                          style: TextStyle(
                            fontSize: 12,
                            color: TemaAplikasi.biruTua,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool aktif;
  final Color warna;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.aktif,
    this.warna = TemaAplikasi.biruTua,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: aktif ? warna : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: aktif ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
