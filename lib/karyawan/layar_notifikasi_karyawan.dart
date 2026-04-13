import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';

class LayarNotifikasiKaryawan extends StatefulWidget {
  final String username;

  const LayarNotifikasiKaryawan({super.key, required this.username});

  @override
  State<LayarNotifikasiKaryawan> createState() =>
      _LayarNotifikasiKaryawanState();
}

class _LayarNotifikasiKaryawanState extends State<LayarNotifikasiKaryawan> {
  final ApiApdService _api = const ApiApdService();
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  bool _loading = true;
  bool _preferensiSiap = false;
  List<Map<String, dynamic>> _items = [];
  Set<String> _hiddenIds = <String>{};

  String get _hiddenStorageKey =>
      'notifikasi_karyawan_hidden_${widget.username}';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _pastikanPreferensiSiap() async {
    if (_preferensiSiap) return;
    final prefs = await SharedPreferences.getInstance();
    _hiddenIds = (prefs.getStringList(_hiddenStorageKey) ?? const <String>[])
        .toSet();
    _preferensiSiap = true;
  }

  Future<void> _simpanHiddenIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenStorageKey, _hiddenIds.toList()..sort());
  }

  Future<void> _loadData() async {
    await _pastikanPreferensiSiap();
    setState(() => _loading = true);

    final response = await _api.notifikasiKaryawan(widget.username);
    if (!mounted) return;

    if (_api.isSuccess(response)) {
      setState(() {
        _items = _api
            .extractListData(response)
            .where(
              (item) => !_hiddenIds.contains('${item['id_notifikasi'] ?? ''}'),
            )
            .toList();
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

  Future<void> _tandaiDibaca(Map<String, dynamic> item) async {
    final sudahBaca = int.tryParse('${item['status_baca'] ?? 0}') == 1;
    if (sudahBaca) return;

    final response = await _api.tandaiNotifikasiDibaca(
      idNotifikasi: '${item['id_notifikasi']}',
      username: widget.username,
    );

    if (!_api.isSuccess(response) || !mounted) return;
    setState(() => item['status_baca'] = 1);
  }

  Future<void> _hapusNotifikasi(Map<String, dynamic> item) async {
    final id = '${item['id_notifikasi'] ?? ''}';
    if (id.isEmpty) return;

    setState(() {
      _hiddenIds.add(id);
      _items = _items
          .where((e) => '${e['id_notifikasi'] ?? ''}' != id)
          .toList();
    });
    await _simpanHiddenIds();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notifikasi dihapus dari perangkat ini')),
    );
  }

  Future<void> _hapusSemuaNotifikasi() async {
    if (_items.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Semua Notifikasi'),
        content: const Text(
          'Semua notifikasi akan disembunyikan dari perangkat ini. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      for (final item in _items) {
        final id = '${item['id_notifikasi'] ?? ''}';
        if (id.isNotEmpty) _hiddenIds.add(id);
      }
      _items = [];
    });
    await _simpanHiddenIds();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Semua notifikasi dihapus dari perangkat ini'),
      ),
    );
  }

  // Helpers
  bool _isBeritaNotif(Map<String, dynamic> item) {
    final tipe = item['tipe_notifikasi']?.toString().toLowerCase() ?? '';
    return tipe == 'info' || tipe == 'berita';
  }

  bool _isApdDisetujui(Map<String, dynamic> item) {
    final judul = item['judul']?.toString() ?? '';
    return judul.contains('Disetujui') &&
        (item['lokasi_pengambilan']?.toString() ?? '').isNotEmpty;
  }

  bool _isApdDitolak(Map<String, dynamic> item) {
    final judul = item['judul']?.toString() ?? '';
    return judul.contains('Ditolak');
  }

  bool _isApdSelesai(Map<String, dynamic> item) {
    final judul = item['judul']?.toString() ?? '';
    return judul.contains('Diserahkan');
  }

  Color _notifColor(Map<String, dynamic> item) {
    if (_isApdDisetujui(item)) return Colors.green;
    if (_isApdDitolak(item)) return TemaAplikasi.bahaya;
    if (_isApdSelesai(item)) return TemaAplikasi.biruTua;
    return TemaAplikasi.emasTua;
  }

  IconData _notifIcon(Map<String, dynamic> item) {
    if (_isApdDisetujui(item)) return Icons.check_circle_outline;
    if (_isApdDitolak(item)) return Icons.cancel_outlined;
    if (_isApdSelesai(item)) return Icons.inventory_2_outlined;
    if (_isBeritaNotif(item)) return Icons.article_outlined;
    return Icons.notifications_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Notifikasi'),
        backgroundColor: TemaAplikasi.biruTua,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _items.isEmpty ? null : _hapusSemuaNotifikasi,
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Hapus semua notifikasi',
          ),
        ],
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
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Belum ada notifikasi untuk Anda',
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
                itemCount: _items.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Ketuk notifikasi untuk menandai sudah dibaca. '
                        'Tombol hapus hanya menyembunyikan dari perangkat ini.',
                        style: TextStyle(height: 1.4, fontSize: 12),
                      ),
                    );
                  }
                  final item = _items[i - 1];
                  return _buildNotifCard(item);
                },
              ),
      ),
    );
  }

  // Card Notifikasi

  Widget _buildNotifCard(Map<String, dynamic> item) {
    final sudahBaca = int.tryParse('${item['status_baca'] ?? 0}') == 1;
    final createdAtText = item['created_at']?.toString() ?? '';
    final createdAt = DateTime.tryParse(createdAtText.replaceFirst(' ', 'T'));
    final lokasi = item['lokasi_pengambilan']?.toString() ?? '';
    final warna = _notifColor(item);
    final isDisetujui = _isApdDisetujui(item);

    // Card spesial untuk APD disetujui (ada lokasi pengambilan)
    if (isDisetujui) {
      return _buildLokasiCard(item, sudahBaca, createdAt, lokasi, warna);
    }

    // Card standar
    return Card(
      elevation: sudahBaca ? 0 : 2,
      color: sudahBaca ? Colors.white : const Color(0xFFFFF8E8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _tandaiDibaca(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (sudahBaca ? Colors.grey : warna).withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _notifIcon(item),
                  color: sudahBaca ? Colors.grey : warna,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item['judul']?.toString() ?? '-',
                            style: TextStyle(
                              fontWeight: sudahBaca
                                  ? FontWeight.w500
                                  : FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (!sudahBaca)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['pesan']?.toString() ?? '',
                      style: const TextStyle(
                        height: 1.4,
                        color: TemaAplikasi.teksUtama,
                        fontSize: 13,
                      ),
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _dateFormat.format(createdAt),
                        style: const TextStyle(
                          color: TemaAplikasi.netral,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => _hapusNotifikasi(item),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 20,
                ),
                tooltip: 'Hapus notifikasi',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Card khusus APD disetujui (lokasi pengambilan menonjol)
  Widget _buildLokasiCard(
    Map<String, dynamic> item,
    bool sudahBaca,
    DateTime? createdAt,
    String lokasi,
    Color warna,
  ) {
    // Pisahkan pesan utama dari bagian lokasi/catatan.
    final pesanRaw = item['pesan']?.toString() ?? '';
    // Ambil bagian sebelum baris lokasi untuk tampilan ringkas
    final barisPesan = pesanRaw.split('\n');
    final pesanPertama = barisPesan.isNotEmpty
        ? barisPesan.first.trim()
        : pesanRaw;
    final catatanBaris = barisPesan
        .where((b) => b.trim().toLowerCase().startsWith('catatan admin:'))
        .join('\n')
        .trim();

    return Card(
      elevation: sudahBaca ? 0 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: sudahBaca
            ? BorderSide.none
            : const BorderSide(color: Colors.green, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _tandaiDibaca(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.check_circle_outline,
                      color: Colors.green.shade700,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['judul']?.toString() ?? 'Disetujui',
                          style: TextStyle(
                            fontWeight: sudahBaca
                                ? FontWeight.w500
                                : FontWeight.w800,
                            fontSize: 14,
                            color: Colors.green.shade800,
                          ),
                        ),
                        Text(
                          pesanPertama,
                          style: const TextStyle(
                            fontSize: 12,
                            color: TemaAplikasi.teksUtama,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!sudahBaca)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  IconButton(
                    onPressed: () => _hapusNotifikasi(item),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // LOKASI PENGAMBILAN (menonjol)
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
                      size: 22,
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
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lokasi,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Catatan tambahan jika ada
              if (catatanBaris.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TemaAplikasi.emas.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: TemaAplikasi.emas.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    catatanBaris,
                    style: const TextStyle(
                      height: 1.45,
                      color: TemaAplikasi.teksUtama,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],

              if (createdAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  _dateFormat.format(createdAt),
                  style: const TextStyle(
                    color: TemaAplikasi.netral,
                    fontSize: 11,
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
