import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';
import 'package:apdcpp/utils/pdf_helper.dart';

/// Preview Dokumen Penerimaan APD - Dokumen formal yang muncul setelah
/// admin menyetujui pengajuan. Berisi data APD yang diterima,
/// komitmen penggunaan, dan area tanda tangan penerima + penyerah.
class LayarPreviewDokumenPenerimaan extends StatefulWidget {
  final Map<String, dynamic> dokumen;
  final String username;

  const LayarPreviewDokumenPenerimaan({
    super.key,
    required this.dokumen,
    required this.username,
  });

  @override
  State<LayarPreviewDokumenPenerimaan> createState() =>
      _LayarPreviewDokumenPenerimaanState();
}

class _LayarPreviewDokumenPenerimaanState
    extends State<LayarPreviewDokumenPenerimaan> {
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
    final idDokumen = widget.dokumen['id']?.toString() ?? '';
    if (idDokumen.isEmpty) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ID dokumen tidak valid')),
        );
      }
      return;
    }

    final response = await _api.detailDokumenPenerimaan(idDokumen);
    if (!mounted) return;

    if (_api.isSuccess(response)) {
      final data = _api.extractMapData(response);
      setState(() {
        _dokumen = Map<String, dynamic>.from(data);
        _dokumen.remove('karyawan');
        _dokumen.remove('admin');
        _dokumen.remove('items');
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

  Future<void> _exportPdf() async {
    await PdfHelper.generateDokumenApdPdf(
      isPenerimaan: true,
      dokumen: _dokumen,
      karyawan: _karyawan,
      admin: _admin,
      items: _items,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Penerimaan Pengajuan APD')),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ─── HEADER PERUSAHAAN ─────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: TemaAplikasi.sukses.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(
                  color: TemaAplikasi.sukses.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Perusahaan
                Hero(
                  tag: 'company_logo',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 75,
                      height: 75,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 65,
                          height: 65,
                          decoration: BoxDecoration(
                            color: TemaAplikasi.biruTua,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: TemaAplikasi.biruTua.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'CPP',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              letterSpacing: 2,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                // Company Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PT. CENTRAL PROTEINA PRIMA, Tbk',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: TemaAplikasi.biruTua,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: TemaAplikasi.sukses,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'PENERIMAAN PENGAJUAN APD',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: TemaAplikasi.sukses,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 2.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              TemaAplikasi.sukses.withValues(alpha: 0.2),
                              TemaAplikasi.sukses,
                              TemaAplikasi.sukses.withValues(alpha: 0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── BADGE DITERIMA ─────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        TemaAplikasi.sukses.withValues(alpha: 0.15),
                        TemaAplikasi.sukses.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: TemaAplikasi.sukses.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: TemaAplikasi.sukses,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PENGAJUAN DITERIMA',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: TemaAplikasi.sukses,
                                fontSize: 15,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Diproses pada ${_formatTanggal(_dokumen['tanggal_proses']?.toString())}',
                              style: TextStyle(
                                color: TemaAplikasi.sukses.withValues(alpha: 0.85),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.verified,
                        color: TemaAplikasi.sukses.withValues(alpha: 0.3),
                        size: 40,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ─── DATA KARYAWAN ─────
                _SectionTitle('DATA PENERIMA'),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow('Nama Lengkap', _karyawan['nama_lengkap'] ?? '-'),
                      _buildInfoRow('Jabatan', _karyawan['jabatan'] ?? '-'),
                      _buildInfoRow('Departemen', _karyawan['departemen'] ?? '-'),
                      _buildInfoRow('Lokasi Kerja', _karyawan['lokasi_kerja'] ?? '-'),
                      _buildInfoRow('Tanggal Pengajuan',
                          _formatTanggal(_dokumen['tanggal_pengajuan']?.toString())),
                      _buildInfoRow('Tanggal Diterima',
                          _formatTanggal(_dokumen['tanggal_proses']?.toString())),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Container(
                  height: 1,
                  color: Colors.grey.shade200,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                const SizedBox(height: 24),

                // ─── DAFTAR APD DITERIMA ─────
                _SectionTitle('DAFTAR APD YANG DITERIMA'),
                const SizedBox(height: 14),

                ...List.generate(_items.length, (i) {
                  final item = _items[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          TemaAplikasi.sukses.withValues(alpha: 0.03),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: TemaAplikasi.sukses.withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: TemaAplikasi.sukses.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                TemaAplikasi.sukses,
                                TemaAplikasi.sukses.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: TemaAplikasi.sukses.withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['nama_apd']?.toString() ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  _InfoChip(
                                    'Ukuran: ${item['ukuran'] ?? '-'}',
                                    Icons.straighten,
                                  ),
                                  const SizedBox(width: 8),
                                  _InfoChip(
                                    'Jumlah: ${item['jumlah'] ?? 1}',
                                    Icons.inventory_2_outlined,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 24),
                Container(
                  height: 1,
                  color: Colors.grey.shade200,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                const SizedBox(height: 24),

                // ─── KOMITMEN PENGGUNAAN ─────
                _SectionTitle('PERNYATAAN KOMITMEN'),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        TemaAplikasi.biruMuda,
                        TemaAplikasi.biruMuda.withValues(alpha: 0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: TemaAplikasi.biruTua.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: TemaAplikasi.biruTua,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                '!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'KOMITMEN PENGGUNAAN APD',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: TemaAplikasi.biruTua,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Dengan ini saya menyatakan telah menerima APD sesuai daftar di atas '
                        'dan berkomitmen untuk menggunakan APD tersebut sesuai dengan '
                        'ketentuan keselamatan kerja yang berlaku di lingkungan '
                        'PT. Central Proteina Prima, Tbk.\n\n'
                        'Saya memahami bahwa penggunaan APD adalah kewajiban '
                        'untuk menjaga keselamatan diri sendiri dan rekan kerja.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: TemaAplikasi.teksUtama,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),
                Container(
                  height: 1,
                  color: Colors.grey.shade200,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                const SizedBox(height: 28),

                // ─── AREA TANDA TANGAN ─────
                _SectionTitle('TANDA TANGAN'),
                const SizedBox(height: 18),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TTD Karyawan (Diterima oleh)
                    Expanded(
                      child: _buildTtdBox(
                        'Diterima oleh',
                        _karyawan['nama_lengkap'] ?? '-',
                        _dokumen['tanda_tangan_karyawan']?.toString(),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // TTD Admin (Diserahkan oleh)
                    Expanded(
                      child: _buildTtdBox(
                        'Diserahkan oleh',
                        _admin['nama_lengkap'] ?? '...................',
                        _dokumen['tanda_tangan_admin']?.toString(),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // TTD Diketahui oleh (Atasan)
                    Expanded(
                      child: _buildTtdBox(
                        'Diketahui oleh',
                        '...................',
                        null,
                      ),
                    ),
                  ],
                ),

                // Catatan admin
                if ((_dokumen['catatan_admin']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.note_alt_outlined,
                              color: Colors.amber.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Catatan Admin',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _dokumen['catatan_admin']?.toString() ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
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

  Widget _SectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 14,
        letterSpacing: 1.5,
        color: TemaAplikasi.biruTua,
      ),
    );
  }

  Widget _InfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: TemaAplikasi.sukses.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: TemaAplikasi.sukses.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: TemaAplikasi.sukses),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: TemaAplikasi.sukses,
              fontWeight: FontWeight.w700,
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
            width: 140,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          ),
          const Text(': ', style: TextStyle(fontSize: 13)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildTtdBox(String role, String nama, String? base64Ttd) {
    return Column(
      children: [
        Text(
          role,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
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
        Container(width: double.infinity, height: 1, color: Colors.grey.shade400),
        const SizedBox(height: 4),
        Text(
          nama,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
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
        child: Icon(Icons.broken_image_outlined,
            color: Colors.grey.shade400, size: 24),
      );
    }
  }
}
