import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:apdcpp/konfigurasi_api.dart';
import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';

class LayarRiwayatPengajuanKaryawan extends StatefulWidget {
  final String username;

  const LayarRiwayatPengajuanKaryawan({super.key, required this.username});

  @override
  State<LayarRiwayatPengajuanKaryawan> createState() =>
      _LayarRiwayatPengajuanKaryawanState();
}

class _LayarRiwayatPengajuanKaryawanState
    extends State<LayarRiwayatPengajuanKaryawan> {
  final ApiApdService _api = const ApiApdService();
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  String _namaHari(int weekday) {
    switch (weekday) {
      case 1:
        return 'Senin';
      case 2:
        return 'Selasa';
      case 3:
        return 'Rabu';
      case 4:
        return 'Kamis';
      case 5:
        return 'Jumat';
      case 6:
        return 'Sabtu';
      case 7:
        return 'Minggu';
      default:
        return '';
    }
  }

  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final response = await _api.riwayatPengajuanKaryawan(widget.username);
    if (!mounted) return;

    if (_api.isSuccess(response)) {
      final allItems = _api.extractListData(response);
      setState(() {
        _items = allItems;
        _loading = false;
      });
      return;
    }

    setState(() {
      _items = [];
      _loading = false;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_api.message(response))));
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'disetujui':
      case 'diterima':
        return Colors.green;
      case 'ditolak':
        return TemaAplikasi.bahaya;
      case 'selesai':
        return TemaAplikasi.biruTua;
      case 'menunggu':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  /// Parse alasan JSON dan return format readable
  String _formatAlasan(String? alasanRaw) {
    if (alasanRaw == null || alasanRaw.isEmpty) return '-';

    // Jika format JSON baru
    if (alasanRaw.contains('{') && alasanRaw.contains('}')) {
      try {
        final jenisRegex = RegExp(r'"jenis_alasan"\s*:\s*"([^"]+)"');
        final penjelasanRegex = RegExp(r'"penjelasan"\s*:\s*"([^"]*)"');
        final jenisMatch = jenisRegex.firstMatch(alasanRaw);
        final penjelasanMatch = penjelasanRegex.firstMatch(alasanRaw);

        final jenis = jenisMatch?.group(1) ?? alasanRaw;
        final penjelasan = penjelasanMatch?.group(1) ?? '';

        if (penjelasan.isNotEmpty) return '$jenis - $penjelasan';
        return jenis;
      } catch (_) {
        // Fallback ke raw string jika error parsing
      }
    }

    return alasanRaw;
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'disetujui':
      case 'diterima':
        return Icons.check_circle_outline;
      case 'ditolak':
        return Icons.cancel_outlined;
      case 'selesai':
        return Icons.inventory_2_outlined;
      case 'menunggu':
        return Icons.hourglass_top_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'disetujui':
      case 'diterima':
        return 'Disetujui';
      case 'ditolak':
        return 'Ditolak';
      case 'selesai':
        return 'Selesai';
      case 'menunggu':
        return 'Menunggu';
      default:
        return status;
    }
  }

  String _tanggal(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final t = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (t == null) return raw;
    return '${_namaHari(t.weekday)}, ${_dateFormat.format(t)}';
  }

  bool _statusDisetujui(String status) {
    final s = status.toLowerCase();
    return s == 'disetujui' ||
        s == 'diterima' ||
        s == 'diproses' ||
        s == 'selesai';
  }

  String _tanggalDiproses(Map<String, dynamic> item) {
    return item['tanggal_diproses']?.toString() ??
        item['tanggal_proses']?.toString() ??
        '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemaAplikasi.latar,
      appBar: AppBar(
        title: const Text('Riwayat Pengajuan APD'),
        backgroundColor: TemaAplikasi.biruTua,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey),
                        SizedBox(height: 14),
                        Text(
                          'Belum ada riwayat pengajuan APD',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, index) => _buildCard(_items[index]),
              ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final tipe = item['tipe']?.toString() ?? 'single';
    final statusRaw = item['status_pengajuan']?.toString() ?? '-';
    final status = _statusLabel(statusRaw);
    final statusColor = _statusColor(statusRaw);
    final statusIcon = _statusIcon(statusRaw);
    final lokasi = item['lokasi_pengambilan']?.toString() ?? '';
    final catatan = item['catatan_admin']?.toString() ?? '';
    final disetujui = _statusDisetujui(statusRaw);
    final ditolak = statusRaw.toLowerCase() == 'ditolak';
    final menunggu = statusRaw.toLowerCase() == 'menunggu';
    final tanggalDiproses = _tanggalDiproses(item);

    // Untuk tipe dokumen, tampilkan detail items
    final itemsData = item['items_data'] as List?;
    final statusDetail = item['status_detail']?.toString() ?? '';

    return Card(
      elevation: disetujui ? 2 : (menunggu ? 1 : 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: disetujui
            ? const BorderSide(color: Colors.green, width: 1.5)
            : (menunggu
                  ? BorderSide(
                      color: Colors.orange.withValues(alpha: 0.5),
                      width: 1,
                    )
                  : BorderSide.none),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _bukaDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: nama APD + badge status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: Icon(statusIcon, color: statusColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['nama_apd']?.toString() ?? '-',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (tipe == 'dokumen' && statusDetail.isNotEmpty)
                          Text(
                            statusDetail,
                            style: const TextStyle(
                              color: TemaAplikasi.netral,
                              fontSize: 11,
                            ),
                          )
                        else
                          Text(
                            '${item['jumlah_pengajuan'] ?? '-'} ${item['satuan'] ?? ''}'
                            '${(item['ukuran']?.toString() ?? '').isNotEmpty ? '· Ukuran: ${item['ukuran']}' : ''}',
                            style: const TextStyle(
                              color: TemaAplikasi.netral,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: menunggu
                          ? Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                            )
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (menunggu)
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                statusColor,
                              ),
                            ),
                          ),
                        if (menunggu) const SizedBox(width: 4),
                        Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Detail items untuk tipe dokumen
              if (tipe == 'dokumen' &&
                  itemsData != null &&
                  itemsData.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TemaAplikasi.latar,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail Item:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...itemsData.map<Widget>((itemData) {
                        final itemStatus =
                            itemData['status']?.toString().toLowerCase() ??
                            'menunggu';
                        final itemStatusColor = itemStatus == 'diterima'
                            ? Colors.green
                            : (itemStatus == 'ditolak'
                                  ? Colors.red
                                  : Colors.orange);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                itemStatus == 'diterima'
                                    ? Icons.check_circle
                                    : (itemStatus == 'ditolak'
                                          ? Icons.cancel
                                          : Icons.hourglass_empty),
                                size: 14,
                                color: itemStatusColor,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${itemData['nama_apd']} (${itemData['jumlah']}x - ${itemData['ukuran']})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                itemStatus == 'diterima'
                                    ? 'Diterima'
                                    : (itemStatus == 'ditolak'
                                          ? 'Ditolak'
                                          : 'Menunggu'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: itemStatusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],

              // Info Menunggu - tampil menonjol jika status menunggu
              if (menunggu) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.hourglass_top_outlined,
                        size: 18,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pengajuan Anda sedang diproses oleh admin. Silakan tunggu persetujuan.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // LOKASI PENGAMBILAN (tampil menonjol jika disetujui)
              if (disetujui && lokasi.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade50, Colors.teal.shade50],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 20,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lokasi Pengambilan APD',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.green,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              lokasi,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Catatan admin jika ada
              if (catatan.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        (ditolak
                                ? TemaAplikasi.bahaya
                                : (menunggu
                                      ? Colors.orange
                                      : TemaAplikasi.emas))
                            .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          (ditolak
                                  ? TemaAplikasi.bahaya
                                  : (menunggu
                                        ? Colors.orange
                                        : TemaAplikasi.emas))
                              .withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        ditolak
                            ? Icons.info_outline
                            : (menunggu
                                  ? Icons.access_time
                                  : Icons.sticky_note_2_outlined),
                        size: 15,
                        color: ditolak
                            ? TemaAplikasi.bahaya
                            : (menunggu ? Colors.orange : TemaAplikasi.emasTua),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ditolak
                              ? 'Alasan: $catatan'
                              : (menunggu
                                    ? 'Catatan: $catatan'
                                    : 'Catatan: $catatan'),
                          style: TextStyle(
                            color: ditolak
                                ? TemaAplikasi.bahaya
                                : (menunggu
                                      ? Colors.orange.shade900
                                      : TemaAplikasi.teksUtama),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),
              // Tanggal pengajuan
              Text(
                'Diajukan: ${_tanggal(item['tanggal_pengajuan']?.toString())}',
                style: const TextStyle(
                  color: TemaAplikasi.netral,
                  fontSize: 11,
                ),
              ),
              if (tanggalDiproses.isNotEmpty)
                Text(
                  'Diproses: ${_tanggal(tanggalDiproses)}',
                  style: const TextStyle(
                    color: TemaAplikasi.netral,
                    fontSize: 11,
                  ),
                ),

              // Tap hint
              const SizedBox(height: 6),
              Text(
                'Ketuk untuk detail ->',
                style: TextStyle(
                  color: TemaAplikasi.biruTua.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _bukaDetail(Map<String, dynamic> item) {
    final statusRaw = item['status_pengajuan']?.toString() ?? '-';
    final status = _statusLabel(statusRaw);
    final statusColor = _statusColor(statusRaw);
    final statusIcon = _statusIcon(statusRaw);
    final lokasi = item['lokasi_pengambilan']?.toString() ?? '';
    final catatan = item['catatan_admin']?.toString() ?? '';
    final buktiFoto = buildUploadUrl(item['bukti_foto']?.toString());
    final disetujui = _statusDisetujui(statusRaw);
    final ditolak = statusRaw.toLowerCase() == 'ditolak';
    final menunggu = statusRaw.toLowerCase() == 'menunggu';
    final tanggalDiproses = _tanggalDiproses(item);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Nama APD + Status
              Text(
                item['nama_apd']?.toString() ?? '-',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: menunggu
                      ? Border.all(color: statusColor.withValues(alpha: 0.3))
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (menunggu)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            statusColor,
                          ),
                        ),
                      ),
                    if (menunggu) const SizedBox(width: 6),
                    Icon(statusIcon, color: statusColor, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Info Menunggu - tampil menonjol jika status menunggu
              if (menunggu) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.hourglass_top_outlined,
                            size: 22,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Menunggu Persetujuan',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.orange.shade900,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pengajuan APD Anda sedang dalam proses review oleh admin. '
                        'Anda akan menerima notifikasi setelah pengajuan disetujui atau ditolak.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade900,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ' Pantau status pengajuan secara berkala di dashboard karyawan.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade900,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // LOKASI PENGAMBILAN - menonjol di atas jika disetujui
              if (disetujui && lokasi.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade50, Colors.teal.shade50],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.location_on_outlined,
                            size: 20,
                            color: Colors.green,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Lokasi Pengambilan APD',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.green,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lokasi,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Segera ambil APD Anda di lokasi tersebut.',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Detail pengajuan
              _section('Detail Pengajuan', [
                _row('APD', item['nama_apd']?.toString() ?? '-'),
                _row(
                  'Jumlah',
                  '${item['jumlah_pengajuan'] ?? '-'} ${item['satuan'] ?? ''}',
                ),
                _row('Ukuran', item['ukuran']?.toString() ?? '-'),
                _row(
                  'Alasan',
                  _formatAlasan(item['alasan_pengajuan']?.toString()),
                ),
                _row(
                  'Tgl Pengajuan',
                  _tanggal(item['tanggal_pengajuan']?.toString()),
                ),
                if (tanggalDiproses.isNotEmpty)
                  _row('Tgl Diproses', _tanggal(tanggalDiproses)),
              ]),

              // Catatan admin
              if (catatan.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:
                        (ditolak
                                ? TemaAplikasi.bahaya
                                : (menunggu
                                      ? Colors.orange
                                      : TemaAplikasi.emas))
                            .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          (ditolak
                                  ? TemaAplikasi.bahaya
                                  : (menunggu
                                        ? Colors.orange
                                        : TemaAplikasi.emas))
                              .withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ditolak
                            ? 'Alasan Penolakan'
                            : (menunggu ? 'Catatan' : 'Catatan Admin'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: ditolak
                              ? TemaAplikasi.bahaya
                              : (menunggu
                                    ? Colors.orange
                                    : TemaAplikasi.emasTua),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(catatan, style: const TextStyle(height: 1.45)),
                    ],
                  ),
                ),
              ],

              // Bukti foto
              if (buktiFoto.isNotEmpty) ...[
                const SizedBox(height: 12),
                _section('Bukti Foto', [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      buktiFoto,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TemaAplikasi.latar,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E0EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: TemaAplikasi.netral,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
