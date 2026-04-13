import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:apdcpp/konfigurasi_api.dart';
import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/services/notifikasi_laporan_admin_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';

// ============================================================
// Layar Laporan Gabungan Admin
//   - Tab 1: Laporan Pengajuan APD (existing)
//   - Tab 2: Laporan Kendala/Kerusakan (baru)
// ============================================================

class LayarLaporanApdAdmin extends StatefulWidget {
  final String usernameAdmin;

  const LayarLaporanApdAdmin({
    super.key,
    required this.usernameAdmin,
  });

  @override
  State<LayarLaporanApdAdmin> createState() => _LayarLaporanApdAdminState();
}

class _LayarLaporanApdAdminState extends State<LayarLaporanApdAdmin>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiApdService _api = const ApiApdService();
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  // Filter bersama
  DateTime? _startDate;
  DateTime? _endDate;
  bool _loading = false;

  // Tab Pengajuan
  String _statusPengajuan = '';
  List<Map<String, dynamic>> _rowsPengajuan = [];

  // Tab Kendala
  String _statusLaporan = '';
  List<Map<String, dynamic>> _rowsKendala = [];
  int _kendalaMenunggu = 0;
  int _kendalaDitindaklanjuti = 0;
  int _kendalaselesai = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGabungan();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Load data gabungan

  Future<void> _loadGabungan() async {
    setState(() => _loading = true);
    final res = await _api.laporanGabunganAdmin(
      start: _startDate,
      end: _endDate,
      statusPengajuan: _statusPengajuan.isEmpty ? null : _statusPengajuan,
      statusLaporan: _statusLaporan.isEmpty ? null : _statusLaporan,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!_api.isSuccess(res)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_api.message(res))));
      return;
    }

    final data = _api.extractMapData(res);
    final pData = data['pengajuan'];
    final kData = data['kendala'];

    await NotifikasiLaporanAdminService.tandaiSemuaSudahDilihat(
      usernameAdmin: widget.usernameAdmin,
    );
    if (!mounted) return;

    setState(() {
      // Pengajuan
      final rowsP = pData is Map ? pData['rows'] : null;
      _rowsPengajuan = rowsP is List
          ? rowsP
                .whereType<Map>()
                .map((e) => e.map((k, v) => MapEntry('$k', v)))
                .toList()
          : [];

      // Kendala
      final rowsK = kData is Map ? kData['rows'] : null;
      _rowsKendala = rowsK is List
          ? rowsK
                .whereType<Map>()
                .map((e) => e.map((k, v) => MapEntry('$k', v)))
                .toList()
          : [];
      _kendalaMenunggu =
          int.tryParse('${kData is Map ? (kData['menunggu'] ?? 0) : 0}') ?? 0;
      _kendalaDitindaklanjuti =
          int.tryParse(
            '${kData is Map ? (kData['ditindaklanjuti'] ?? 0) : 0}',
          ) ??
          0;
      _kendalaselesai =
          int.tryParse('${kData is Map ? (kData['selesai'] ?? 0) : 0}') ?? 0;
    });
  }

  // Date pickers

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _startDate ?? DateTime.now(),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _endDate ?? DateTime.now(),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  // Tindak lanjut laporan kendala

  Future<void> _tindakLanjutKendala(
    Map<String, dynamic> item,
    String usernameAdmin,
  ) async {
    String selectedStatus = item['status_laporan']?.toString() ?? 'Menunggu';
    final catatanCtrl = TextEditingController(
      text: item['catatan_admin']?.toString() ?? '',
    );

    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Tindak Lanjut Laporan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['nama_apd']?.toString() ?? '-',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${item['nama_lengkap'] ?? item['username_karyawan'] ?? '-'}',
                style: const TextStyle(color: TemaAplikasi.netral),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status Tindak Lanjut',
                ),
                items: const [
                  DropdownMenuItem(value: 'Menunggu', child: Text('Menunggu')),
                  DropdownMenuItem(
                    value: 'Ditindaklanjuti',
                    child: Text('Ditindaklanjuti'),
                  ),
                  DropdownMenuItem(value: 'Selesai', child: Text('Selesai')),
                ],
                onChanged: (v) =>
                    setStateDialog(() => selectedStatus = v ?? selectedStatus),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: catatanCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Catatan Admin',
                  hintText: 'Tindakan yang dilakukan, penjelasan, dll',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: TemaAplikasi.biruTua,
                foregroundColor: Colors.white,
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (konfirmasi != true) {
      catatanCtrl.dispose();
      return;
    }

    final res = await _api.tindakLanjutLaporan(
      idLaporan: item['id_laporan']?.toString() ?? '',
      statusLaporan: selectedStatus,
      usernameAdmin: usernameAdmin,
      catatanAdmin: catatanCtrl.text.trim(),
    );
    catatanCtrl.dispose();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_api.message(res)),
        backgroundColor: _api.isSuccess(res)
            ? TemaAplikasi.sukses
            : TemaAplikasi.bahaya,
      ),
    );
    if (_api.isSuccess(res)) await _loadGabungan();
  }

  // Export CSV pengajuan

  String _toCsvPengajuan() {
    final buf = StringBuffer();
    buf.writeln(
      'id_pengajuan,tanggal_pengajuan,username_karyawan,nama_lengkap,departemen,nama_apd,ukuran,jumlah,alasan,status,catatan_admin,tanggal_diproses',
    );
    for (final r in _rowsPengajuan) {
      final vals = [
        '${r['id_pengajuan'] ?? ''}',
        '${r['tanggal_pengajuan'] ?? ''}',
        '${r['username_karyawan'] ?? ''}',
        '${r['nama_lengkap'] ?? ''}',
        '${r['departemen'] ?? ''}',
        '${r['nama_apd'] ?? ''}',
        '${r['ukuran'] ?? ''}',
        '${r['jumlah_pengajuan'] ?? ''}',
        '${r['alasan_pengajuan'] ?? ''}',
        '${r['status_pengajuan'] ?? ''}',
        '${r['catatan_admin'] ?? ''}',
        '${r['tanggal_diproses'] ?? ''}',
      ].map(_escapeCsv).join(',');
      buf.writeln(vals);
    }
    return buf.toString();
  }

  String _toCsvKendala() {
    final buf = StringBuffer();
    buf.writeln(
      'id_laporan,tanggal_laporan,username_karyawan,nama_lengkap,departemen,nama_apd,keterangan,status_laporan,catatan_admin,tanggal_tindak',
    );
    for (final r in _rowsKendala) {
      final vals = [
        '${r['id_laporan'] ?? ''}',
        '${r['tanggal_laporan'] ?? ''}',
        '${r['username_karyawan'] ?? ''}',
        '${r['nama_lengkap'] ?? ''}',
        '${r['departemen'] ?? ''}',
        '${r['nama_apd'] ?? ''}',
        '${r['keterangan'] ?? ''}',
        '${r['status_laporan'] ?? ''}',
        '${r['catatan_admin'] ?? ''}',
        '${r['tanggal_tindak'] ?? ''}',
      ].map(_escapeCsv).join(',');
      buf.writeln(vals);
    }
    return buf.toString();
  }

  String _escapeCsv(String s) => '"${s.replaceAll('"', '""')}"';

  Future<void> _exportPengajuan() async {
    if (_rowsPengajuan.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tidak ada data pengajuan')));
      return;
    }
    await _shareFile(_toCsvPengajuan(), 'Laporan_Pengajuan_APD');
  }

  Future<void> _exportKendala() async {
    if (_rowsKendala.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data laporan kendala')),
      );
      return;
    }
    await _shareFile(_toCsvKendala(), 'Laporan_Kendala_APD');
  }

  Future<void> _shareFile(String csv, String prefix) async {
    try {
      final dir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = '${dir.path}/${prefix}_$dateStr.csv';
      final file = File(path);
      await file.writeAsString(csv);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], text: prefix.replaceAll('_', ' ')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal export: $e')));
    }
  }

  // Helpers

  Color _statusPengajuanColor(String s) {
    switch (s) {
      case 'Disetujui':
      case 'Selesai':
        return TemaAplikasi.sukses;
      case 'Ditolak':
        return TemaAplikasi.bahaya;
      case 'Menunggu':
        return Colors.blue;
      default:
        return TemaAplikasi.netral;
    }
  }

  Color _statusKendalaColor(String s) {
    switch (s) {
      case 'Ditindaklanjuti':
        return Colors.indigo;
      case 'Selesai':
        return TemaAplikasi.sukses;
      default:
        return TemaAplikasi.emasTua;
    }
  }

  String _tanggal(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final t = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    return t == null ? raw : _dateFormat.format(t);
  }

  Widget _chip(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$title: $value',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  // Filter panel (shared)

  Widget _filterPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Tanggal',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 158,
                  child: OutlinedButton.icon(
                    onPressed: _pickStart,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _startDate == null
                          ? 'Dari Tanggal'
                          : DateFormat('dd/MM/yyyy').format(_startDate!),
                    ),
                  ),
                ),
                SizedBox(
                  width: 158,
                  child: OutlinedButton.icon(
                    onPressed: _pickEnd,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _endDate == null
                          ? 'Sampai'
                          : DateFormat('dd/MM/yyyy').format(_endDate!),
                    ),
                  ),
                ),
                if (_startDate != null || _endDate != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Reset Tanggal'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _loadGabungan,
                icon: const Icon(Icons.filter_alt),
                label: Text(_loading ? 'Memuat...' : 'Terapkan Filter'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // BUILD

  @override
  Widget build(BuildContext context) {
    final badgeKendala = _kendalaMenunggu;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan APD'),
        backgroundColor: TemaAplikasi.biruTua,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: TemaAplikasi.emas,
          tabs: [
            const Tab(
              icon: Icon(Icons.assignment_outlined),
              text: 'Pengajuan APD',
            ),
            Tab(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.report_problem_outlined),
                  if (badgeKendala > 0)
                    Positioned(
                      top: -4,
                      right: -12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badgeKendala > 99 ? '99+' : '$badgeKendala',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              text: 'Laporan Kendala',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildTabPengajuan(), _buildTabKendala()],
      ),
    );
  }

  //   - Tab 1: Laporan Pengajuan APD (existing)

  Widget _buildTabPengajuan() {
    final total = _rowsPengajuan.length;
    final menunggu = _rowsPengajuan
        .where((e) => e['status_pengajuan'] == 'Menunggu')
        .length;
    final disetujui = _rowsPengajuan
        .where((e) => e['status_pengajuan'] == 'Disetujui')
        .length;
    final ditolak = _rowsPengajuan
        .where((e) => e['status_pengajuan'] == 'Ditolak')
        .length;

    return RefreshIndicator(
      onRefresh: _loadGabungan,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        children: [
          _filterPanel(),
          const SizedBox(height: 10),
          // Filter status pengajuan
          DropdownButtonFormField<String>(
            initialValue: _statusPengajuan,
            decoration: const InputDecoration(labelText: 'Status Pengajuan'),
            items: const [
              DropdownMenuItem(value: '', child: Text('Semua Status')),
              DropdownMenuItem(value: 'Menunggu', child: Text('Menunggu')),
              DropdownMenuItem(value: 'Disetujui', child: Text('Disetujui')),
              DropdownMenuItem(value: 'Ditolak', child: Text('Ditolak')),
              DropdownMenuItem(value: 'Selesai', child: Text('Selesai')),
            ],
            onChanged: (v) => setState(() => _statusPengajuan = v ?? ''),
          ),
          const SizedBox(height: 10),
          // Summary chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Total', '$total', Colors.black87),
              _chip('Menunggu', '$menunggu', Colors.blue),
              _chip('Disetujui', '$disetujui', TemaAplikasi.sukses),
              _chip('Ditolak', '$ditolak', TemaAplikasi.bahaya),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _exportPengajuan,
              icon: const Icon(Icons.ios_share),
              label: const Text('Bagikan CSV'),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_rowsPengajuan.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('Tidak ada data pengajuan.'),
              ),
            )
          else
            ..._rowsPengajuan.map((row) => _pengajuanCard(row)),
        ],
      ),
    );
  }

  Widget _pengajuanCard(Map<String, dynamic> row) {
    final status = row['status_pengajuan']?.toString() ?? '-';
    final color = _statusPengajuanColor(status);
    final fotoUrl = buildUploadUrl(row['bukti_foto']?.toString());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetailPengajuan(row),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${row['nama_apd'] ?? '-'} - ${row['nama_lengkap'] ?? '-'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${row['username_karyawan'] ?? '-'} - ${row['jabatan'] ?? '-'} - ${row['departemen'] ?? '-'}',
                style: const TextStyle(
                  color: TemaAplikasi.netral,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _chip(
                    'Jumlah',
                    '${row['jumlah_pengajuan'] ?? 0}',
                    TemaAplikasi.biruTua,
                  ),
                  _chip(
                    'Alasan',
                    row['alasan_pengajuan']?.toString() ?? '-',
                    TemaAplikasi.netral,
                  ),
                  if (fotoUrl.isNotEmpty) _chip('Foto', 'Ada', Colors.teal),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _tanggal(row['tanggal_pengajuan']?.toString()),
                style: const TextStyle(
                  color: TemaAplikasi.netral,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailPengajuan(Map<String, dynamic> row) {
    final fotoUrl = buildUploadUrl(row['bukti_foto']?.toString());
    final fotoProfil = buildUploadUrl(row['foto_profil']?.toString());

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
              const SizedBox(height: 16),
              // Header identitas
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: fotoProfil.isEmpty
                        ? null
                        : NetworkImage(fotoProfil),
                    child: fotoProfil.isEmpty
                        ? const Icon(Icons.person, color: TemaAplikasi.netral)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row['nama_lengkap']?.toString() ?? '-',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          '${row['username_karyawan'] ?? '-'} - ${row['jabatan'] ?? '-'}',
                          style: const TextStyle(
                            color: TemaAplikasi.netral,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _detailSectionAdmin('Detail Pengajuan', [
                _detailRowAdmin('APD', row['nama_apd']?.toString() ?? '-'),
                _detailRowAdmin('Ukuran', row['ukuran']?.toString() ?? '-'),
                _detailRowAdmin('Jumlah', '${row['jumlah_pengajuan'] ?? '-'}'),
                _detailRowAdmin(
                  'Alasan',
                  row['alasan_pengajuan']?.toString() ?? '-',
                ),
                _detailRowAdmin(
                  'Status',
                  row['status_pengajuan']?.toString() ?? '-',
                ),
                _detailRowAdmin(
                  'Lokasi',
                  row['lokasi_kerja']?.toString() ?? '-',
                ),
                _detailRowAdmin(
                  'Departemen',
                  row['departemen']?.toString() ?? '-',
                ),
                _detailRowAdmin(
                  'Tgl Pengajuan',
                  _tanggal(row['tanggal_pengajuan']?.toString()),
                ),
                if ((row['catatan_admin']?.toString() ?? '').isNotEmpty)
                  _detailRowAdmin(
                    'Catatan Admin',
                    row['catatan_admin'].toString(),
                  ),
                if ((row['tanggal_diproses']?.toString() ?? '').isNotEmpty)
                  _detailRowAdmin(
                    'Tgl Diproses',
                    _tanggal(row['tanggal_diproses']?.toString()),
                  ),
              ]),
              if (fotoUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                _detailSectionAdmin('Bukti Foto Pengajuan', [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      fotoUrl,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 60,
                        child: Center(
                          child: Text('Foto tidak dapat ditampilkan'),
                        ),
                      ),
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

  //   - Tab 2: Laporan Kendala/Kerusakan (baru)

  Widget _buildTabKendala() {
    return RefreshIndicator(
      onRefresh: _loadGabungan,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        children: [
          _filterPanel(),
          const SizedBox(height: 10),
          // Filter status kendala
          DropdownButtonFormField<String>(
            initialValue: _statusLaporan,
            decoration: const InputDecoration(
              labelText: 'Status Laporan Kendala',
            ),
            items: const [
              DropdownMenuItem(value: '', child: Text('Semua Status')),
              DropdownMenuItem(value: 'Menunggu', child: Text('Menunggu')),
              DropdownMenuItem(
                value: 'Ditindaklanjuti',
                child: Text('Ditindaklanjuti'),
              ),
              DropdownMenuItem(value: 'Selesai', child: Text('Selesai')),
            ],
            onChanged: (v) => setState(() => _statusLaporan = v ?? ''),
          ),
          const SizedBox(height: 10),
          // Summary
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Total', '${_rowsKendala.length}', Colors.black87),
              _chip('Menunggu', '$_kendalaMenunggu', TemaAplikasi.emasTua),
              _chip(
                'Ditindaklanjuti',
                '$_kendalaDitindaklanjuti',
                Colors.indigo,
              ),
              _chip('Selesai', '$_kendalaselesai', TemaAplikasi.sukses),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _exportKendala,
              icon: const Icon(Icons.ios_share),
              label: const Text('Bagikan CSV'),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_rowsKendala.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('Tidak ada laporan kendala.'),
              ),
            )
          else
            ..._rowsKendala.map((row) => _kendalaCard(row)),
        ],
      ),
    );
  }

  Widget _kendalaCard(Map<String, dynamic> row) {
    final status = row['status_laporan']?.toString() ?? 'Menunggu';
    final color = _statusKendalaColor(status);
    final fotoUrl = buildUploadUrl(row['foto_laporan']?.toString());
    final fotoProfil = buildUploadUrl(row['foto_profil_karyawan']?.toString());
    final catatan = row['catatan_admin']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetailKendala(row),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar karyawan
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: fotoProfil.isEmpty
                        ? null
                        : NetworkImage(fotoProfil),
                    child: fotoProfil.isEmpty
                        ? const Icon(
                            Icons.person,
                            color: TemaAplikasi.netral,
                            size: 20,
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row['nama_apd']?.toString() ?? '-',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${row['nama_lengkap'] ?? row['username_karyawan'] ?? '-'}'
                          ' - ${row['jabatan'] ?? '-'}',
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
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                row['keterangan']?.toString() ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.4),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _chip(
                    'Laporan',
                    _tanggal(row['tanggal_laporan']?.toString()),
                    TemaAplikasi.netral,
                  ),
                  if (fotoUrl.isNotEmpty) _chip('Foto', 'Ada', Colors.teal),
                  if (catatan.isNotEmpty && status != 'Menunggu')
                    _chip('Catatan', 'Ada', Colors.indigo),
                ],
              ),
              const SizedBox(height: 10),
              // Tombol tindak lanjut
              if (status == 'Menunggu' || status == 'Ditindaklanjuti')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _tindakLanjutKendala(row, widget.usernameAdmin),
                    icon: const Icon(Icons.engineering_outlined, size: 18),
                    label: const Text('Tindak Lanjut'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TemaAplikasi.biruTua,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailKendala(Map<String, dynamic> row) {
    final status = row['status_laporan']?.toString() ?? 'Menunggu';
    final color = _statusKendalaColor(status);
    final fotoUrl = buildUploadUrl(row['foto_laporan']?.toString());
    final fotoProfil = buildUploadUrl(row['foto_profil_karyawan']?.toString());
    final catatan = row['catatan_admin']?.toString() ?? '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.80,
        maxChildSize: 0.96,
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
              const SizedBox(height: 16),
              // APD + status
              Text(
                row['nama_apd']?.toString() ?? '-',
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
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 16),
              // Identitas karyawan
              _detailSectionAdmin('Identitas Pelapor', [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: fotoProfil.isEmpty
                          ? null
                          : NetworkImage(fotoProfil),
                      child: fotoProfil.isEmpty
                          ? const Icon(Icons.person, color: TemaAplikasi.netral)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row['nama_lengkap']?.toString() ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${row['username_karyawan'] ?? '-'} - ${row['jabatan'] ?? '-'}',
                            style: const TextStyle(
                              color: TemaAplikasi.netral,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _detailRowAdmin(
                  'Departemen',
                  row['departemen']?.toString() ?? '-',
                ),
                _detailRowAdmin(
                  'Lokasi',
                  row['lokasi_kerja']?.toString() ?? '-',
                ),
              ]),
              const SizedBox(height: 12),
              _detailSectionAdmin('Keterangan Kendala', [
                Text(
                  row['keterangan']?.toString() ?? '-',
                  style: const TextStyle(height: 1.5),
                ),
              ]),
              const SizedBox(height: 12),
              _detailSectionAdmin('Waktu Laporan', [
                _detailRowAdmin(
                  'Tgl Laporan',
                  _tanggal(row['tanggal_laporan']?.toString()),
                ),
                if ((row['tanggal_tindak']?.toString() ?? '').isNotEmpty)
                  _detailRowAdmin(
                    'Tgl Tindak',
                    _tanggal(row['tanggal_tindak']?.toString()),
                  ),
                if ((row['nama_admin_tindak']?.toString() ?? '').isNotEmpty)
                  _detailRowAdmin(
                    'Ditindak Oleh',
                    row['nama_admin_tindak'].toString(),
                  ),
              ]),
              if (catatan.isNotEmpty) ...[
                const SizedBox(height: 12),
                _detailSectionAdmin('Catatan Admin', [
                  Text(catatan, style: const TextStyle(height: 1.45)),
                ]),
              ],
              if (fotoUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                _detailSectionAdmin('Foto Kondisi Barang', [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      fotoUrl,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 60,
                        child: Center(
                          child: Text('Foto tidak dapat ditampilkan'),
                        ),
                      ),
                    ),
                  ),
                ]),
              ],
              const SizedBox(height: 18),
              if (status == 'Menunggu' || status == 'Ditindaklanjuti')
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _tindakLanjutKendala(row, widget.usernameAdmin);
                  },
                  icon: const Icon(Icons.engineering_outlined),
                  label: const Text('Tindak Lanjut'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TemaAplikasi.biruTua,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Shared helpers (detail section / row)

  Widget _detailSectionAdmin(String title, List<Widget> children) {
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

  Widget _detailRowAdmin(String label, String value) {
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
