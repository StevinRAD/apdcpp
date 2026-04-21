import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:apdcpp/konfigurasi_api.dart';
import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/services/izin_perangkat_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';

// ============================================================
// Layar Lapor Kendala/Kerusakan APD - Karyawan
// ============================================================

class LayarLaporKendalaKaryawan extends StatefulWidget {
  final String username;
  const LayarLaporKendalaKaryawan({super.key, required this.username});

  @override
  State<LayarLaporKendalaKaryawan> createState() =>
      _LayarLaporKendalaKaryawanState();
}

class _LayarLaporKendalaKaryawanState extends State<LayarLaporKendalaKaryawan>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiApdService _api = const ApiApdService();
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  // Tab Form
  final _formKey = GlobalKey<FormState>();
  final _namaApdCtrl = TextEditingController();
  final _keteranganCtrl = TextEditingController();
  File? _fotoLaporan;
  bool _loadingPengajuan = false;
  bool _submitting = false;
  List<Map<String, dynamic>> _daftarPengajuan = [];
  String? _selectedIdPengajuan;

  // Tab Riwayat
  bool _loadingRiwayat = false;
  List<Map<String, dynamic>> _riwayat = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _riwayat.isEmpty) {
        _loadRiwayat();
      }
    });
    _loadPengajuanKaryawan();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _namaApdCtrl.dispose();
    _keteranganCtrl.dispose();
    super.dispose();
  }

  // Ambil daftar pengajuan karyawan untuk dipilih
  Future<void> _loadPengajuanKaryawan() async {
    setState(() => _loadingPengajuan = true);
    final res = await _api.pengajuanKaryawanUntukLaporan(widget.username);
    if (!mounted) return;
    if (_api.isSuccess(res)) {
      final data = res['data'];
      final rows = data is Map ? data['rows'] : null;
      setState(() {
        _daftarPengajuan = rows is List
            ? rows
                  .whereType<Map>()
                  .map((e) => e.map((k, v) => MapEntry('$k', v)))
                  .toList()
            : [];
        if (_selectedIdPengajuan != null &&
            !_daftarPengajuan.any(
              (e) => e['id_pengajuan']?.toString() == _selectedIdPengajuan,
            )) {
          _selectedIdPengajuan = null;
          _namaApdCtrl.clear();
        }
      });
    }
    setState(() => _loadingPengajuan = false);
  }

  // Riwayat laporan
  Future<void> _loadRiwayat() async {
    setState(() => _loadingRiwayat = true);
    final res = await _api.riwayatLaporanKendalaKaryawan(widget.username);
    if (!mounted) return;
    if (_api.isSuccess(res)) {
      final data = res['data'];
      final rows = data is Map ? data['rows'] : null;
      setState(() {
        _riwayat = rows is List
            ? rows
                  .whereType<Map>()
                  .map((e) => e.map((k, v) => MapEntry('$k', v)))
                  .toList()
            : [];
      });
    }
    setState(() => _loadingRiwayat = false);
  }

  Future<bool> _pastikanIzinPerangkat(ImageSource source) {
    if (!mounted) return Future.value(false);
    if (source == ImageSource.camera) {
      return IzinPerangkatService.pastikanAksesKamera(context);
    }
    return IzinPerangkatService.pastikanAksesGaleri(context);
  }

  // Pilih foto
  Future<void> _pilihFoto(ImageSource source) async {
    final izin = await _pastikanIzinPerangkat(source);
    if (!mounted || !izin) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 50,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked != null && mounted) {
      setState(() => _fotoLaporan = File(picked.path));
    }
  }

  void _showFotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil Foto (Kamera)'),
              onTap: () {
                Navigator.pop(context);
                _pilihFoto(ImageSource.camera);
              },
            ),
            if (_fotoLaporan != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Hapus Foto',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  setState(() => _fotoLaporan = null);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  // Kirim laporan
  Future<void> _kirimLaporan() async {
    if (_daftarPengajuan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Belum ada APD yang sudah diterima/disetujui untuk dilaporkan',
          ),
        ),
      );
      return;
    }

    if ((_selectedIdPengajuan ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih APD yang sudah diterima sebelum kirim laporan'),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    // Jika pilih dari pengajuan, gunakan nama APD dari pengajuan tsb
    String namaApd = _namaApdCtrl.text.trim();
    final p = _daftarPengajuan.firstWhere(
      (e) => e['id_pengajuan']?.toString() == _selectedIdPengajuan,
      orElse: () => {},
    );
    if (p.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data pengajuan tidak valid. Coba muat ulang halaman'),
        ),
      );
      return;
    }
    namaApd = '${p['nama_apd'] ?? namaApd}';
    if (_namaApdCtrl.text.trim().isEmpty && namaApd.isNotEmpty) {
      _namaApdCtrl.text = namaApd;
    }

    setState(() => _submitting = true);
    final res = await _api.kirimLaporanKendala(
      username: widget.username,
      namaApd: namaApd,
      keterangan: _keteranganCtrl.text.trim(),
      idPengajuan: _selectedIdPengajuan,
      fotoLaporan: _fotoLaporan,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_api.message(res)),
        backgroundColor: _api.isSuccess(res)
            ? TemaAplikasi.sukses
            : TemaAplikasi.bahaya,
      ),
    );

    if (_api.isSuccess(res)) {
      _formKey.currentState!.reset();
      _namaApdCtrl.clear();
      _keteranganCtrl.clear();
      setState(() {
        _fotoLaporan = null;
        _selectedIdPengajuan = null;
      });
      // Tab Riwayat
      _tabController.animateTo(1);
      await _loadRiwayat();
    }
  }

  // Helpers
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ditindaklanjuti':
        return Colors.blue;
      case 'selesai':
        return TemaAplikasi.sukses;
      default:
        return TemaAplikasi.emasTua;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'ditindaklanjuti':
        return Icons.engineering_outlined;
      case 'selesai':
        return Icons.check_circle_outline;
      default:
        return Icons.hourglass_top_outlined;
    }
  }

  String _tanggalRingkas(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final t = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    return t == null ? raw : _dateFormat.format(t);
  }

  // =========================================================
  // BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemaAplikasi.latar,
      appBar: AppBar(
        title: const Text('Lapor Kendala / Kerusakan'),
        backgroundColor: TemaAplikasi.biruTua,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: TemaAplikasi.emas,
          tabs: const [
            Tab(
              icon: Icon(Icons.report_problem_outlined),
              text: 'Buat Laporan',
            ),
            Tab(icon: Icon(Icons.history_outlined), text: 'Riwayat Laporan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildTabForm(), _buildTabRiwayat()],
      ),
    );
  }

  // Tab Form
  Widget _buildTabForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Keterangan banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: TemaAplikasi.emas.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: TemaAplikasi.emas.withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: TemaAplikasi.emasTua),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Laporkan kendala APD yang sudah diterima/disetujui. '
                      'Pengajuan status menunggu atau ditolak tidak masuk daftar.',
                      style: TextStyle(
                        color: TemaAplikasi.teksUtama,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Pilih dari pengajuan yang sudah diterima/disetujui
            _sectionTitle('Pilih APD yang Sudah Diterima *'),
            const SizedBox(height: 8),
            _loadingPengajuan
                ? const LinearProgressIndicator()
                : DropdownButtonFormField<String>(
                    value: _selectedIdPengajuan,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Pengajuan APD',
                      prefixIcon: Icon(Icons.link_outlined),
                      hintText: 'Pilih APD yang sudah diterima',
                    ),
                    items: _daftarPengajuan.map((p) {
                      final id = p['id_pengajuan']?.toString() ?? '';
                      final nama = p['nama_apd']?.toString() ?? '-';
                      final status = p['status']?.toString() ?? p['status_pengajuan']?.toString() ?? '';
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text(
                          '$nama - $status',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedIdPengajuan = val;
                        if (val != null && val.isNotEmpty) {
                          final p = _daftarPengajuan.firstWhere(
                            (e) => e['id_pengajuan']?.toString() == val,
                            orElse: () => {},
                          );
                          if (p.isNotEmpty) {
                            _namaApdCtrl.text = p['nama_apd']?.toString() ?? '';
                          }
                        } else {
                          _namaApdCtrl.clear();
                        }
                      });
                    },
                  ),
            if (!_loadingPengajuan && _daftarPengajuan.isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Belum ada APD berstatus diterima/disetujui yang bisa dilaporkan.',
                style: TextStyle(color: TemaAplikasi.netral, fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),

            // Nama APD
            _sectionTitle('Nama APD yang Dilaporkan *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _namaApdCtrl,
              readOnly: true,
              enableInteractiveSelection: false,
              decoration: const InputDecoration(
                labelText: 'Nama APD',
                hintText: 'Terisi otomatis dari pengajuan yang dipilih',
                prefixIcon: Icon(Icons.shield_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Nama APD wajib diisi'
                  : null,
            ),
            const SizedBox(height: 14),

            // Keterangan kendala
            _sectionTitle('Keterangan Kendala / Kerusakan *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _keteranganCtrl,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Keterangan',
                hintText:
                    'Jelaskan kondisi barang, jenis kerusakan, atau kendala yang dihadapi ...',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 64),
                  child: Icon(Icons.description_outlined),
                ),
              ),
              validator: (v) => (v == null || v.trim().length < 10)
                  ? 'Keterangan minimal 10 karakter'
                  : null,
            ),
            const SizedBox(height: 18),

            // Foto kondisi barang
            _sectionTitle('Foto Kondisi Barang (Opsional)'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showFotoOptions,
              child: Container(
                width: double.infinity,
                height: _fotoLaporan != null ? 200 : 110,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: TemaAplikasi.biruTua.withValues(alpha: 0.20),
                    style: BorderStyle.solid,
                  ),
                ),
                child: _fotoLaporan != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(_fotoLaporan!, fit: BoxFit.cover),
                            Positioned(
                              right: 8,
                              top: 8,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _fotoLaporan = null),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 36,
                            color: TemaAplikasi.netral,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Ketuk untuk ambil foto\n(Kamera)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: TemaAplikasi.netral,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Tombol kirim
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _kirimLaporan,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(_submitting ? 'Mengirim...' : 'Kirim Laporan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TemaAplikasi.biruTua,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Tab Riwayat
  Widget _buildTabRiwayat() {
    return RefreshIndicator(
      onRefresh: _loadRiwayat,
      child: _loadingRiwayat
          ? const Center(child: CircularProgressIndicator())
          : _riwayat.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Belum ada laporan kendala.',
                        style: TextStyle(color: TemaAplikasi.netral),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Buat laporan di tab "Buat Laporan"',
                        style: TextStyle(
                          color: TemaAplikasi.netral,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(14),
              itemCount: _riwayat.length,
              itemBuilder: (_, i) => _buildRiwayatCard(_riwayat[i]),
            ),
    );
  }

  Widget _buildRiwayatCard(Map<String, dynamic> item) {
    final status = item['status_laporan']?.toString() ?? 'Menunggu';
    final warna = _statusColor(status);
    final icon = _statusIcon(status);
    final fotoUrl = buildUploadUrl(item['foto_laporan']?.toString());
    final tglLapor = _tanggalRingkas(item['tanggal_laporan']?.toString());
    final tglTindak = _tanggalRingkas(item['tanggal_tindak']?.toString());
    final catatan = item['catatan_admin']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _bukaDetailLaporan(item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: warna.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: warna, size: 22),
                  ),
                  const SizedBox(width: 12),
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
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: warna.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: warna,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: TemaAplikasi.netral),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item['keterangan']?.toString() ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: TemaAplikasi.teksUtama,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _chip(
                    Icons.access_time_outlined,
                    tglLapor,
                    TemaAplikasi.netral,
                  ),
                  if (fotoUrl.isNotEmpty)
                    _chip(Icons.photo_camera_outlined, 'Ada Foto', Colors.teal),
                  if (catatan.isNotEmpty && status != 'Menunggu')
                    _chip(
                      Icons.comment_outlined,
                      'Ada Catatan Admin',
                      Colors.indigo,
                    ),
                  if (status == 'Selesai' && tglTindak != '-')
                    _chip(
                      Icons.check_circle_outline,
                      'Selesai: $tglTindak',
                      TemaAplikasi.sukses,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _bukaDetailLaporan(Map<String, dynamic> item) {
    final status = item['status_laporan']?.toString() ?? 'Menunggu';
    final warna = _statusColor(status);
    final fotoUrl = buildUploadUrl(item['foto_laporan']?.toString());
    final catatan = item['catatan_admin']?.toString() ?? '';
    final tglLapor = _tanggalRingkas(item['tanggal_laporan']?.toString());
    final tglTindak = _tanggalRingkas(item['tanggal_tindak']?.toString());

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: ListView(
            controller: scrollCtrl,
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
                  color: warna.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon(status), color: warna, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: TextStyle(
                        color: warna,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _detailSection('Keterangan Laporan', [
                Text(
                  item['keterangan']?.toString() ?? '-',
                  style: const TextStyle(height: 1.5),
                ),
              ]),
              const SizedBox(height: 12),
              _detailSection('Informasi Waktu', [
                _detailRow('Tanggal Lapor', tglLapor),
                if (tglTindak != '-') _detailRow('Tanggal Tindak', tglTindak),
              ]),
              if (catatan.isNotEmpty) ...[
                const SizedBox(height: 12),
                _detailSection('Catatan Admin', [
                  Text(catatan, style: const TextStyle(height: 1.45)),
                ]),
              ],
              if (fotoUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                _detailSection('Foto Kondisi Barang', [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      fotoUrl,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 90,
                        color: Colors.grey.shade100,
                        alignment: Alignment.center,
                        child: const Text('Foto tidak dapat ditampilkan'),
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

  Widget _detailSection(String title, List<Widget> children) {
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

  Widget _detailRow(String label, String value) {
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
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: TemaAplikasi.biruTua,
      ),
    );
  }
}
