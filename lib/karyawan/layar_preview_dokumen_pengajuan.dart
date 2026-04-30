import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';
import 'package:apdcpp/utils/pdf_helper.dart';

/// Preview Formulir Permintaan APD - Dokumen formal dengan header PT,
/// data karyawan, daftar APD, dan area tanda tangan.
class LayarPreviewDokumenPengajuan extends StatefulWidget {
  final String idDokumen;
  final String username;

  const LayarPreviewDokumenPengajuan({
    super.key,
    required this.idDokumen,
    required this.username,
  });

  @override
  State<LayarPreviewDokumenPengajuan> createState() =>
      _LayarPreviewDokumenPengajuanState();
}

class _LayarPreviewDokumenPengajuanState
    extends State<LayarPreviewDokumenPengajuan> {
  final ApiApdService _api = const ApiApdService();

  bool _loading = true;
  Map<String, dynamic> _dokumen = {};
  Map<String, dynamic> _karyawan = {};
  Map<String, dynamic> _admin = {};
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);
    final response = await _api.detailDokumenPengajuan(widget.idDokumen);
    if (!mounted) return;

    if (_api.isSuccess(response)) {
      final data = _api.extractMapData(response);
      setState(() {
        _dokumen = (data['dokumen'] as Map?)
                ?.map((k, v) => MapEntry('$k', v)) ??
            {};
        _karyawan = (data['karyawan'] as Map?)
                ?.map((k, v) => MapEntry('$k', v)) ??
            {};
        _admin = (data['admin'] as Map?)
                ?.map((k, v) => MapEntry('$k', v)) ??
            {};
        _items = (data['items'] as List?)
                ?.whereType<Map>()
                .map((e) => e.map((k, v) => MapEntry('$k', v)))
                .toList() ??
            [];
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_api.message(response))),
        );
      }
    }
  }

  String _formatTanggal(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final dt = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (dt == null) return raw;
    return DateFormat('dd MMMM yyyy', 'id_ID').format(dt);
  }

  /// Menghitung status tampilan berdasarkan data dokumen.
  /// Jika status backend masih 'menunggu' tapi sudah ada item diproses,
  /// tampilkan 'selesai' atau 'diproses'.
  String _computeDisplayStatus() {
    final rawStatus = _dokumen['status']?.toString().toLowerCase() ?? 'menunggu';
    if (rawStatus != 'menunggu') return rawStatus;

    // Cek dari item yang sudah diproses
    final jumlahItem = int.tryParse('${_dokumen['jumlah_item'] ?? 0}') ?? 0;

    // Hitung dari status item individual
    int jumlahDiterima = 0;
    int jumlahDitolak = 0;

    for (final item in _items) {
      final statusItem = item['status']?.toString().toLowerCase() ?? '';
      if (statusItem == 'diterima') jumlahDiterima++;
      if (statusItem == 'ditolak') jumlahDitolak++;
    }

    final totalDiproses = jumlahDiterima + jumlahDitolak;

    if (totalDiproses > 0 && totalDiproses >= jumlahItem && jumlahItem > 0) {
      return 'selesai';
    }
    if (totalDiproses > 0) {
      return 'diproses';
    }
    return rawStatus;
  }

  String _statusLabel(String s) {
    if (s == 'diterima') return 'DITERIMA';
    if (s == 'ditolak') return 'DITOLAK';
    if (s == 'selesai' || s == 'diproses') return 'SELESAI';
    if (s == 'diproses') return 'DIPROSES';
    return 'MENUNGGU';
  }

  Color _statusColor(String s) {
    if (s == 'diterima') return TemaAplikasi.sukses;
    if (s == 'ditolak') return TemaAplikasi.bahaya;
    if (s == 'selesai' || s == 'diproses') return TemaAplikasi.biruTua;
    return Colors.orange;
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

  Future<void> _exportPdf() async {
    await PdfHelper.generateDokumenApdPdf(
      isPenerimaan: false,
      dokumen: _dokumen,
      karyawan: _karyawan,
      admin: _admin,
      items: _items,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Formulir Permintaan APD'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildDokumen(),
            ),
      bottomNavigationBar: _loading
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exportPdf,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Export PDF'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Selesai'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDokumen() {
    // Gunakan status yang dihitung untuk menampilkan status yang akurat
    final status = _computeDisplayStatus();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ─── HEADER PERUSAHAAN ─────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: TemaAplikasi.biruTua.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                // Logo placeholder
                Image.asset(
                  'assets/images/logo_preview.png',
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: TemaAplikasi.biruTua,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'CPP',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'PT. CENTRAL PROTEINA PRIMA, Tbk',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: TemaAplikasi.biruTua,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'FORMULIR PERMINTAAN APD',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: TemaAplikasi.biruTua.withValues(alpha: 0.7),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 2,
                  color: TemaAplikasi.biruTua.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── STATUS BADGE ─────
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _statusColor(status).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        color: _statusColor(status),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ─── DATA KARYAWAN ─────
                const Text(
                  'DATA PEMOHON',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 1,
                    color: TemaAplikasi.biruTua,
                  ),
                ),
                const SizedBox(height: 10),
                _buildInfoRow('Nama', _karyawan['nama_lengkap'] ?? '-'),
                _buildInfoRow('Jabatan', _karyawan['jabatan'] ?? '-'),
                _buildInfoRow('Departemen', _karyawan['departemen'] ?? '-'),
                _buildInfoRow('Lokasi Kerja',
                    _karyawan['lokasi_kerja'] ?? '-'),
                _buildInfoRow('Tanggal Pengajuan',
                    _formatTanggal(_dokumen['tanggal_pengajuan']?.toString())),

                const SizedBox(height: 20),
                Container(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 20),

                // ─── DAFTAR APD ─────
                const Text(
                  'DAFTAR APD YANG DIMINTA',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 1,
                    color: TemaAplikasi.biruTua,
                  ),
                ),
                const SizedBox(height: 12),

                // Tabel APD
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: TemaAplikasi.biruTua.withValues(alpha: 0.08),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(7),
                            topRight: Radius.circular(7),
                          ),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 30,
                              child: Text('No',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12)),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text('Nama APD',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12)),
                            ),
                            SizedBox(
                              width: 50,
                              child: Text('Ukuran',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12)),
                            ),
                            SizedBox(
                              width: 40,
                              child: Text('Jml',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12)),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text('Status',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      // Rows
                      ...List.generate(_items.length, (i) {
                        final item = _items[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 30,
                                child: Text('${i + 1}',
                                    style: const TextStyle(fontSize: 13)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['nama_apd']?.toString() ?? '-',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if ((item['alasan']?.toString() ?? '')
                                        .isNotEmpty)
                                      Text(
                                        'Alasan: ${_formatAlasan(item['alasan']?.toString())}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                          height: 1.4,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 50,
                                child: Text(
                                  item['ukuran']?.toString() ?? '-',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              SizedBox(
                                width: 40,
                                child: Text(
                                  '${item['jumlah'] ?? 1}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              // Status per item
                              SizedBox(
                                width: 70,
                                child: _buildItemStatusBadge(
                                  item['status']?.toString() ?? 'menunggu',
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Container(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 24),

                // ─── AREA TANDA TANGAN ─────
                const Text(
                  'TANDA TANGAN',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 1,
                    color: TemaAplikasi.biruTua,
                  ),
                ),
                const SizedBox(height: 16),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final isSmall = constraints.maxWidth < 360;
                    final ttdWidgets = [
                      _buildTtdBox(
                        'Pemohon',
                        _karyawan['nama_lengkap'] ?? '-',
                        _dokumen['tanda_tangan_karyawan']?.toString(),
                      ),
                      _buildTtdBox(
                        'Safety / Admin',
                        _admin['nama_lengkap'] ?? '...................',
                        _dokumen['tanda_tangan_admin']?.toString(),
                      ),
                      _buildTtdBox(
                        'Atasan',
                        '...................',
                        null,
                      ),
                    ];

                    if (isSmall) {
                      return Column(
                        children: ttdWidgets
                            .map((w) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: w,
                                ))
                            .toList(),
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: ttdWidgets[0]),
                        const SizedBox(width: 12),
                        Expanded(child: ttdWidgets[1]),
                        const SizedBox(width: 12),
                        Expanded(child: ttdWidgets[2]),
                      ],
                    );
                  },
                ),

                // Catatan admin (jika ada)
                if ((_dokumen['catatan_admin']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Catatan Admin:',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dokumen['catatan_admin']?.toString() ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemStatusBadge(String status) {
    final statusLower = status.toLowerCase();
    String label;
    Color color;

    if (statusLower == 'diterima') {
      label = 'Diterima';
      color = TemaAplikasi.sukses;
    } else if (statusLower == 'ditolak') {
      label = 'Ditolak';
      color = TemaAplikasi.bahaya;
    } else {
      label = 'Menunggu';
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildTtdBox(String role, String nama, String? base64Ttd) {
    return Column(
      children: [
        Text(
          role,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade50,
          ),
          child: base64Ttd != null && base64Ttd.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: _buildTtdImage(base64Ttd),
                )
              : Center(
                  child: Text(
                    '(kosong)',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: 1,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 4),
        Text(
          nama,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildTtdImage(String base64Str) {
    try {
      final bytes = base64Decode(base64Str);
      return Image.memory(
        Uint8List.fromList(bytes),
        fit: BoxFit.contain,
        width: double.infinity,
      );
    } catch (_) {
      return Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.grey.shade400,
          size: 24,
        ),
      );
    }
  }
}
