import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';
import 'package:apdcpp/utils/pdf_helper.dart';
import 'package:apdcpp/karyawan/layar_preview_dokumen_penerimaan.dart';

class LayarDaftarDokumenPenerimaanKaryawan extends StatefulWidget {
  final String username;

  const LayarDaftarDokumenPenerimaanKaryawan({super.key, required this.username});

  @override
  State<LayarDaftarDokumenPenerimaanKaryawan> createState() =>
      _LayarDaftarDokumenPenerimaanKaryawanState();
}

class _LayarDaftarDokumenPenerimaanKaryawanState
    extends State<LayarDaftarDokumenPenerimaanKaryawan> {
  final ApiApdService _api = const ApiApdService();
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  bool _loading = true;
  List<Map<String, dynamic>> _dokumenList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final response = await _api.dokumenPenerimaanKaryawan(widget.username);
    if (!mounted) return;

    if (_api.isSuccess(response)) {
      final allItems = _api.extractListData(response);
      setState(() {
        _dokumenList = allItems;
        _loading = false;
      });
      return;
    }

    setState(() {
      _dokumenList = [];
      _loading = false;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_api.message(response))));
  }

  String _tanggal(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final t = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (t == null) return raw;
    return _dateFormat.format(t);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemaAplikasi.latar,
      appBar: AppBar(
        title: const Text('Dokumen Penerimaan APD'),
        backgroundColor: TemaAplikasi.biruTua,
        foregroundColor: Colors.white,
        actions: [
          if (_dokumenList.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _dokumenList.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.3,
                  ),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: TemaAplikasi.biruTua.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Icon(
                            Icons.description_outlined,
                            size: 42,
                            color: TemaAplikasi.biruTua,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Belum ada dokumen penerimaan',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: TemaAplikasi.teksUtama,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Dokumen akan muncul setelah pengajuan APD disetujui',
                          style: TextStyle(
                            fontSize: 13,
                            color: TemaAplikasi.netral,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14),
                itemCount: _dokumenList.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, index) => _buildCard(_dokumenList[index]),
              ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> dokumen) {
    final tanggal = _tanggal(dokumen['tanggal_pengajuan']?.toString());
    final tanggalDiterima = _tanggal(dokumen['tanggal_proses']?.toString());
    final itemCount = dokumen['item_count'] ?? 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: TemaAplikasi.biruTua.withValues(alpha: 0.2), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _bukaDetail(dokumen),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dokumen Penerimaan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: TemaAplikasi.netral,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$itemCount item APD',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.done_all, color: Colors.green, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Diterima',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade50, Colors.teal.shade50],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_available, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tanggal Penerimaan',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            tanggalDiterima.isNotEmpty ? tanggalDiterima : tanggal,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.visibility_outlined,
                      label: 'Lihat',
                      color: TemaAplikasi.biruTua,
                      onTap: () => _bukaDetail(dokumen),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.picture_as_pdf_outlined,
                      label: 'PDF',
                      color: Colors.red.shade700,
                      onTap: () => _generatePdf(dokumen),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.print_outlined,
                      label: 'Print',
                      color: Colors.purple.shade700,
                      onTap: () => _printDokumen(dokumen),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Ketuk kartu untuk detail ->',
                  style: TextStyle(
                    color: TemaAplikasi.biruTua.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _bukaDetail(Map<String, dynamic> dokumen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LayarPreviewDokumenPenerimaan(
          dokumen: dokumen,
          username: widget.username,
        ),
      ),
    );
    _loadData();
  }

  Future<void> _generatePdf(Map<String, dynamic> dokumen) async {
    final idDokumen = dokumen['id']?.toString() ?? '';

    if (idDokumen.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID dokumen tidak valid')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final detail = await _api.detailDokumenPenerimaan(idDokumen);
      if (!mounted) return;
      Navigator.pop(context);

      if (!_api.isSuccess(detail)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_api.message(detail))),
        );
        return;
      }

      final dataDokumen = _api.extractMapData(detail);
      final karyawan = dataDokumen['karyawan'] ?? {};
      final admin = dataDokumen['admin'] ?? {};
      final items = List<Map<String, dynamic>>.from(dataDokumen['items'] ?? []);

      await PdfHelper.generateDokumenApdPdf(
        isPenerimaan: true,
        dokumen: dataDokumen,
        karyawan: karyawan,
        admin: admin,
        items: items,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat PDF: $e')),
      );
    }
  }

  Future<void> _printDokumen(Map<String, dynamic> dokumen) async {
    final idDokumen = dokumen['id']?.toString() ?? '';

    if (idDokumen.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID dokumen tidak valid')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final detail = await _api.detailDokumenPenerimaan(idDokumen);
      if (!mounted) return;
      Navigator.pop(context);

      if (!_api.isSuccess(detail)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_api.message(detail))),
        );
        return;
      }

      final dataDokumen = _api.extractMapData(detail);
      final karyawan = dataDokumen['karyawan'] ?? {};
      final admin = dataDokumen['admin'] ?? {};
      final items = List<Map<String, dynamic>>.from(dataDokumen['items'] ?? []);

      await PdfHelper.generateDokumenApdPdf(
        isPenerimaan: true,
        dokumen: dataDokumen,
        karyawan: karyawan,
        admin: admin,
        items: items,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mencetak dokumen: $e')),
      );
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
