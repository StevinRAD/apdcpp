import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:apdcpp/konfigurasi_api.dart';
import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';

class LayarPersetujuanApdAdmin extends StatefulWidget {
  final String usernameAdmin;

  const LayarPersetujuanApdAdmin({super.key, required this.usernameAdmin});

  @override
  State<LayarPersetujuanApdAdmin> createState() =>
      _LayarPersetujuanApdAdminState();
}

class _LayarPersetujuanApdAdminState extends State<LayarPersetujuanApdAdmin> {
  final ApiApdService _api = const ApiApdService();
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, HH:mm');
  Timer? _autoRefreshTimer;

  bool _loading = true;
  bool _syncing = false;
  bool _prosesLoading = false;

  List<Map<String, dynamic>> _items = [];
  List<String> _opsiJabatan = [];
  String _selectedJabatan = '';
  DateTime? _selectedTanggal;

  @override
  void initState() {
    super.initState();
    _loadInit();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (!mounted || _loading || _prosesLoading) return;
      _loadData(preserveVisibleData: true, silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInit() async {
    await Future.wait([_loadJabatan(), _loadData()]);
  }

  Future<void> _loadJabatan() async {
    final response = await _api.opsiJabatanKaryawan();
    if (!_api.isSuccess(response) || !mounted) return;

    final list = _api.extractListData(response);
    setState(() {
      _opsiJabatan =
          list
              .map((e) => e['jabatan']?.toString() ?? '')
              .where((e) => e.trim().isNotEmpty)
              .toSet()
              .toList()
            ..sort();
    });
  }

  Future<void> _loadData({
    bool preserveVisibleData = false,
    bool silent = false,
  }) async {
    final keepVisibleData = preserveVisibleData && _items.isNotEmpty;
    setState(() {
      _loading = !keepVisibleData;
      _syncing = keepVisibleData;
    });

    final response = await _api.semuaPengajuan(
      statusPengajuan: 'Menunggu',
      jabatan: _selectedJabatan.isEmpty ? null : _selectedJabatan,
      tanggal: _selectedTanggal,
    );
    if (!mounted) return;

    if (_api.isSuccess(response)) {
      setState(() {
        _items = _api.extractListData(response);
        _loading = false;
        _syncing = false;
      });
      return;
    }

    setState(() {
      if (!keepVisibleData) {
        _items = [];
      }
      _loading = false;
      _syncing = false;
    });
    if (silent) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_api.message(response))));
  }

  Future<void> _pickTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedTanggal ?? DateTime.now(),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;

    setState(() => _selectedTanggal = picked);
    _loadData(preserveVisibleData: true);
  }

  Future<String?> _inputCatatanPenolakan() async {
    final controller = TextEditingController();
    String? errorText;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setStateDialog) => AlertDialog(
          title: const Text('Alasan Penolakan'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            autofocus: true,
            onChanged: (value) {
              if (errorText != null && value.trim().isNotEmpty) {
                setStateDialog(() => errorText = null);
              }
            },
            decoration: InputDecoration(
              hintText:
                  'Contoh: stok ukuran L habis, ajukan ulang minggu depan',
              errorText: errorText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final alasan = controller.text.trim();
                if (alasan.isEmpty) {
                  setStateDialog(
                    () => errorText = 'Alasan penolakan wajib diisi',
                  );
                  return;
                }
                Navigator.pop(dialogContext, alasan);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TemaAplikasi.bahaya,
                foregroundColor: Colors.white,
              ),
              child: const Text('Tolak'),
            ),
          ],
        ),
      ),
    );
    // Jangan dispose controller di sini karena bisa menyebabkan error
    // Controller akan otomatis di-dispose oleh framework
    return result;
  }

  Future<void> _prosesStatus({
    required Map<String, dynamic> item,
    required String status,
    String? catatan,
    String? lokasiPengambilan,
  }) async {
    if (_prosesLoading) return;

    // Set loading state BEFORE async
    if (!mounted) return;
    setState(() {
      _prosesLoading = true;
    });

    try {
      final response = await _api.prosesPengajuan(
        idPengajuan: '${item['id_pengajuan']}',
        statusPengajuan: status,
        usernameAdmin: widget.usernameAdmin,
        catatanAdmin: catatan,
        lokasiPengambilan: lokasiPengambilan,
      );

      // Tampilkan feedback setelah async selesai
      if (!mounted) return;
      final pesan = _api.message(response);
      final isSuccess = _api.isSuccess(response);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pesan),
            backgroundColor: isSuccess ? TemaAplikasi.sukses : TemaAplikasi.bahaya,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      if (isSuccess) {
        if (mounted) {
          await _loadData(preserveVisibleData: true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: $e'),
            backgroundColor: TemaAplikasi.bahaya,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // Reset loading state (paling aman: cek mounted dulu)
      if (mounted) {
        setState(() {
          _prosesLoading = false;
        });
      }
    }
  }

  /// Dialog untuk input lokasi pengambilan (wajib) + catatan opsional saat menyetujui
  Future<({String lokasi, String catatan})?> _inputPenerimaanPengajuan() async {
    final lokasiCtrl = TextEditingController();
    final catatanCtrl = TextEditingController();

    final result = await showDialog<({String lokasi, String catatan})>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 10),
            Text('Setujui Pengajuan'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Karyawan akan menerima notifikasi berisi lokasi pengambilan APD.',
                style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: lokasiCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Lokasi Pengambilan *',
                  hintText: 'Contoh: Gudang APD Lt. 2, Ruang K3',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: catatanCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Catatan Tambahan (opsional)',
                  hintText: 'Contoh: Ambil hari Senin-Jumat jam 08.00-16.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final lokasi = lokasiCtrl.text.trim();
              if (lokasi.isEmpty) return; // lokasi wajib
              Navigator.pop(dialogCtx, (
                lokasi: lokasi,
                catatan: catatanCtrl.text.trim(),
              ));
            },
            icon: const Icon(Icons.check),
            label: const Text('Setujui & Kirim Notifikasi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    // Jangan dispose controller di sini karena bisa menyebabkan error
    // Controller akan otomatis di-dispose oleh framework
    return result;
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? fallback}') ?? fallback;
  }

  Color _stokColor(Map<String, dynamic> item) {
    final stok = _toInt(item['stok_tersedia']);
    final minStok = _toInt(item['min_stok'], fallback: 1);
    if (stok <= 0) return TemaAplikasi.bahaya;
    if (stok <= minStok) return TemaAplikasi.emasTua;
    return TemaAplikasi.sukses;
  }

  String _stokLabel(Map<String, dynamic> item) {
    final stok = _toInt(item['stok_tersedia']);
    final minStok = _toInt(item['min_stok']);
    if (stok <= 0) return 'Stok kosong';
    if (stok <= minStok) return 'Stok menipis';
    return 'Stok aman';
  }

  String _cooldownLabel(Map<String, dynamic> item) {
    final hari = _toInt(item['cooldown_pengajuan_hari'], fallback: 30);
    if (hari == 0) return 'Tanpa masa tunggu';
    if (hari == 1) return 'Pending 1 hari';
    return 'Pending $hari hari';
  }

  void _bukaDetail(Map<String, dynamic> item) {
    final tanggalText = item['tanggal_pengajuan']?.toString() ?? '';
    final tanggal = DateTime.tryParse(tanggalText.replaceFirst(' ', 'T'));
    final buktiFoto = buildUploadUrl(item['bukti_foto']?.toString());
    final stokWarna = _stokColor(item);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 18,
              right: 18,
              top: 18,
              bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 52,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD5DDE7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    item['nama_apd']?.toString() ?? '-',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DetailChip(
                        warna: Colors.blue,
                        label: 'Menunggu Persetujuan',
                      ),
                      _DetailChip(
                        warna: stokWarna,
                        label:
                            '${_stokLabel(item)} (${_toInt(item['stok_tersedia'])})',
                      ),
                      _DetailChip(
                        warna: TemaAplikasi.emasTua,
                        label: _cooldownLabel(item),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _DetailSection(
                    title: 'Informasi Karyawan',
                    children: [
                      _DetailRow(
                        label: 'Nama',
                        value:
                            '${item['nama_lengkap'] ?? item['username_karyawan']}',
                      ),
                      _DetailRow(
                        label: 'Username',
                        value: '${item['username_karyawan'] ?? '-'}',
                      ),
                      _DetailRow(
                        label: 'Jabatan',
                        value: '${item['jabatan'] ?? '-'}',
                      ),
                      _DetailRow(
                        label: 'Departemen',
                        value: '${item['departemen'] ?? '-'}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _DetailSection(
                    title: 'Informasi Pengajuan',
                    children: [
                      _DetailRow(
                        label: 'Jumlah',
                        value: '${item['jumlah_pengajuan'] ?? '-'}',
                      ),
                      _DetailRow(
                        label: 'Ukuran',
                        value: '${item['ukuran'] ?? '-'}',
                      ),
                      _DetailRow(
                        label: 'Alasan',
                        value: '${item['alasan_pengajuan'] ?? '-'}',
                      ),
                      if (tanggal != null)
                        _DetailRow(
                          label: 'Tanggal',
                          value: _dateFormat.format(tanggal),
                        ),
                    ],
                  ),
                  if (buktiFoto.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _DetailSection(
                      title: 'Bukti Foto',
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            buktiFoto,
                            width: double.infinity,
                            height: 190,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  height: 110,
                                  color: Colors.grey.shade100,
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'Foto tidak bisa ditampilkan',
                                  ),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _prosesLoading
                              ? null
                              : () async {
                                  // Munculkan dialog konfirmasi/input
                                  final hasil =
                                      await _inputPenerimaanPengajuan();
                                  if (hasil == null) return;
                                  if (!mounted) return;

                                  // Tutup keyboard
                                  FocusManager.instance.primaryFocus?.unfocus();

                                  // Tutup bottom sheet SEKARANG
                                  if (!mounted) return;
                                  Navigator.of(context).pop();

                                  // Tunggu sedikit agar Navigator stack stabil
                                  await Future.delayed(const Duration(milliseconds: 50));

                                  // Kirim ke server via API (hanya jika masih mounted)
                                  if (!mounted) return;
                                  await _prosesStatus(
                                    item: item,
                                    status: 'Disetujui',
                                    catatan: hasil.catatan.isEmpty
                                        ? 'Pengajuan disetujui'
                                        : hasil.catatan,
                                    lokasiPengambilan: hasil.lokasi,
                                  );
                                },
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TemaAplikasi.sukses,
                            foregroundColor: Colors.white,
                          ),
                          label: const Text('Terima'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _prosesLoading
                              ? null
                              : () async {
                                  // Munculkan dialog konfirmasi alasan
                                  final alasan = await _inputCatatanPenolakan();
                                  if (alasan == null || alasan.isEmpty) return;
                                  if (!mounted) return;

                                  // Tutup keyboard
                                  FocusManager.instance.primaryFocus?.unfocus();

                                  // Tutup bottom sheet SEKARANG
                                  if (!mounted) return;
                                  Navigator.of(context).pop();

                                  // Tunggu sedikit agar Navigator stack stabil
                                  await Future.delayed(const Duration(milliseconds: 50));

                                  // Kirim ke server via API (hanya jika masih mounted)
                                  if (!mounted) return;
                                  await _prosesStatus(
                                    item: item,
                                    status: 'Ditolak',
                                    catatan: alasan,
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TemaAplikasi.bahaya,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Tolak'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi & Persetujuan APD')),
      body: RefreshIndicator(
        onRefresh: () => _loadData(preserveVisibleData: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_syncing)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filter Persetujuan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Total menunggu saat ini: ${_items.length} pengajuan',
                      style: const TextStyle(color: TemaAplikasi.netral),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedJabatan,
                      decoration: const InputDecoration(labelText: 'Jabatan'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Semua Jabatan'),
                        ),
                        ..._opsiJabatan.map(
                          (jabatan) => DropdownMenuItem(
                            value: jabatan,
                            child: Text(jabatan),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedJabatan = value ?? '';
                        });
                        _loadData();
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickTanggal,
                            icon: const Icon(Icons.date_range_outlined),
                            label: Text(
                              _selectedTanggal == null
                                  ? 'Filter Hari'
                                  : DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(_selectedTanggal!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedTanggal = null;
                              _selectedJabatan = '';
                            });
                            _loadData();
                          },
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 72),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 72),
                child: Center(
                  child: Text('Tidak ada pengajuan menunggu saat ini'),
                ),
              )
            else
              ..._items.map((item) {
                final tanggalText = item['tanggal_pengajuan']?.toString() ?? '';
                final tanggal = DateTime.tryParse(
                  tanggalText.replaceFirst(' ', 'T'),
                );
                final stokWarna = _stokColor(item);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _bukaDetail(item),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item['nama_apd']} (${item['jumlah_pengajuan']})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item['nama_lengkap'] ?? item['username_karyawan']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: TemaAplikasi.netral,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: TemaAplikasi.emas,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _DetailChip(
                                warna: Colors.blue,
                                label: '${item['jabatan'] ?? '-'}',
                              ),
                              _DetailChip(
                                warna: stokWarna,
                                label:
                                    '${_stokLabel(item)} (${_toInt(item['stok_tersedia'])})',
                              ),
                              _DetailChip(
                                warna: TemaAplikasi.emasTua,
                                label: _cooldownLabel(item),
                              ),
                            ],
                          ),
                          if (tanggal != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _dateFormat.format(tanggal),
                              style: const TextStyle(
                                color: TemaAplikasi.netral,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TemaAplikasi.latar,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD8E0EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: TemaAplikasi.netral,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
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
}

class _DetailChip extends StatelessWidget {
  final Color warna;
  final String label;

  const _DetailChip({required this.warna, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: warna,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
