import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:apdcpp/konfigurasi_api.dart';
import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/services/notifikasi_lokal_service.dart';
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
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
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

    try {
      final response = await _api.semuaPengajuan(
        jabatan: _selectedJabatan.isEmpty ? null : _selectedJabatan,
        tanggal: _selectedTanggal,
      );
      if (!mounted) return;

      if (_api.isSuccess(response)) {
        setState(() {
          final allItems = _api.extractListData(response);
          // Filter: hanya tampilkan item yang masih menunggu persetujuan
          _items = allItems.where((item) {
            final tipe = item['tipe']?.toString() ?? 'single';
            if (tipe == 'dokumen') {
              // Untuk dokumen: cek jumlah item menunggu
              final menunggu = int.tryParse('${item['jumlah_item_menunggu'] ?? -1}') ?? -1;
              if (menunggu == 0) return false; // Semua item sudah diproses
              return true;
            } else {
              // Untuk single: cek status pengajuan
              final status = item['status_pengajuan']?.toString().toLowerCase() ?? 'menunggu';
              return status == 'menunggu' || status == 'pending';
            }
          }).toList();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_api.message(response)),
            backgroundColor: TemaAplikasi.bahaya,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _syncing = false;
      });
      if (silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data: $e'),
          backgroundColor: TemaAplikasi.bahaya,
        ),
      );
    }
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

    // Simpan item untuk recovery jika gagal
    final itemId = '${item['id_pengajuan']}';

    // Set loading state BEFORE async
    if (!mounted) return;
    setState(() {
      _prosesLoading = true;
    });

    try {
      // Cek tipe pengajuan (single vs dokumen)
      final tipe = item['tipe']?.toString() ?? 'single';

      // Normalisasi status menjadi lowercase untuk konsistensi
      final statusLower = status.toLowerCase();
      final statusDokumen = statusLower == 'disetujui' ? 'diterima' : statusLower;

      final response = tipe == 'dokumen'
          ? await _api.prosesDokumenPengajuan(
              idDokumen: itemId,
              status: statusDokumen,
              usernameAdmin: widget.usernameAdmin,
              catatan: catatan,
              lokasiPengambilan: lokasiPengambilan,
            )
          : await _api.prosesPengajuan(
              idPengajuan: itemId,
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
        // Kirim notifikasi lokal ke HP (opsional - jika gagal tetap lanjut)
        final namaApd = item['nama_apd']?.toString() ?? 'APD';

        try {
          if (status.toLowerCase() == 'disetujui' || status.toLowerCase() == 'diterima') {
            final lokasi = lokasiPengambilan ?? 'lokasi yang ditentukan';
            await NotifikasiLokalService.tampilkanNotifikasiStatusPengajuan(
              status: 'Disetujui',
              keterangan: 'Pengajuan $namaApd Anda telah disetujui. Silakan ambil di $lokasi.',
            );
          } else if (status.toLowerCase() == 'ditolak') {
            await NotifikasiLokalService.tampilkanNotifikasiStatusPengajuan(
              status: 'Ditolak',
              keterangan: catatan ?? 'Pengajuan $namaApd Anda ditolak. Silakan ajukan ulang.',
            );
          }
        } catch (_) {
          // Abaikan error notifikasi - proses persetujuan tetap berhasil
        }

        // Refresh data setelah sukses - item akan hilang karena status berubah
        if (mounted) {
          await _loadData(preserveVisibleData: false);
        }
      } else {
        // Jika gagal, tetap reload untuk memastikan data konsisten
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
        // Reload data untuk recovery
        await _loadData(preserveVisibleData: true);
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

  String _cooldownLabel(Map<String, dynamic> item) {
    final hari = _toInt(item['cooldown_pengajuan_hari'], fallback: 30);
    if (hari == 0) return 'Tanpa masa tunggu';
    if (hari == 1) return 'Pending 1 hari';
    return 'Pending $hari hari';
  }

  String _getItemLabel(Map<String, dynamic> item) {
    final tipe = item['tipe']?.toString() ?? 'single';
    if (tipe == 'dokumen') {
      final totalItem = _toInt(item['jumlah_item'], fallback: 0);
      final menunggu = _toInt(item['jumlah_item_menunggu'], fallback: 0);
      if (menunggu > 0) {
        return '$totalItem item APD ($menunggu menunggu)';
      }
      return '$totalItem item APD';
    }
    // Single item
    final nama = item['nama_apd']?.toString() ?? '-';
    final jumlah = _toInt(item['jumlah_pengajuan'], fallback: 1);
    return '$nama ($jumlah)';
  }

  /// Parse data alasan dari format JSON atau string biasa
  Map<String, dynamic> _parseAlasan(String? alasanRaw) {
    if (alasanRaw == null || alasanRaw.isEmpty) {
      return {'jenis_alasan': 'Karyawan Baru', 'penjelasan': ''};
    }

    // Cek apakah format JSON
    if (alasanRaw.startsWith('{') && alasanRaw.endsWith('}')) {
      try {
        final cleaned = alasanRaw
            .replaceAll(RegExp(r"[^{]*\{"), '{')
            .replaceAll(RegExp(r"\}[^}]*"), '}');
        // Parse JSON manual untuk menghindari import dart:convert
        final result = <String, dynamic>{};
        final pairs = cleaned
            .substring(1, cleaned.length - 1)
            .split(',');
        for (final pair in pairs) {
          final parts = pair.split(':');
          if (parts.length == 2) {
            final key = parts[0].trim().replaceAll("'", '').replaceAll('"', '');
            final value = parts[1].trim().replaceAll("'", '').replaceAll('"', '');
            result[key] = value;
          }
        }
        return result.isNotEmpty ? result : {'jenis_alasan': alasanRaw, 'penjelasan': ''};
      } catch (_) {
        return {'jenis_alasan': alasanRaw, 'penjelasan': ''};
      }
    }

    return {'jenis_alasan': alasanRaw, 'penjelasan': ''};
  }

  String _getJenisAlasan(Map<String, dynamic> item) {
    final alasanRaw = item['alasan_pengajuan']?.toString() ?? '';
    final alasanData = _parseAlasan(alasanRaw);
    return alasanData['jenis_alasan']?.toString() ?? alasanRaw;
  }

  String _getPenjelasanAlasan(Map<String, dynamic> item) {
    final alasanRaw = item['alasan_pengajuan']?.toString() ?? '';
    final alasanData = _parseAlasan(alasanRaw);
    return alasanData['penjelasan']?.toString() ?? '';
  }

  String? _getFotoBukti(Map<String, dynamic> item) {
    final alasanRaw = item['alasan_pengajuan']?.toString() ?? '';
    final alasanData = _parseAlasan(alasanRaw);
    return alasanData['foto_bukti']?.toString();
  }

  void _bukaDetail(Map<String, dynamic> item) {
    final tipe = item['tipe']?.toString() ?? 'single';

    if (tipe == 'dokumen') {
      // Sistem baru: Dokumen dengan banyak item - buka persetujuan per item
      _bukaDetailDokumen(item);
    } else {
      // Sistem lama: Single item
      _bukaDetailSingle(item);
    }
  }

  /// Detail pengajuan single item (sistem lama)
  void _bukaDetailSingle(Map<String, dynamic> item) {
    final tanggalText = item['tanggal_pengajuan']?.toString() ?? '';
    final tanggal = DateTime.tryParse(tanggalText.replaceFirst(' ', 'T'));
    final buktiFoto = buildUploadUrl(item['bukti_foto']?.toString());

    // Parse data alasan
    final jenisAlasan = _getJenisAlasan(item);
    final penjelasanAlasan = _getPenjelasanAlasan(item);
    final fotoBuktiUrl = _getFotoBukti(item);

    // Tentukan warna dan icon berdasarkan jenis alasan
    Color alasanColor;
    IconData alasanIcon;
    if (jenisAlasan == 'Karyawan Baru') {
      alasanColor = Colors.blue;
      alasanIcon = Icons.person_add;
    } else if (jenisAlasan == 'APD Lama Rusak') {
      alasanColor = Colors.orange;
      alasanIcon = Icons.build;
    } else if (jenisAlasan == 'Hilang') {
      alasanColor = Colors.red;
      alasanIcon = Icons.help_outline;
    } else {
      alasanColor = Colors.grey;
      alasanIcon = Icons.info_outline;
    }

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
                      // Alasan dengan format baru
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 92,
                              child: Text(
                                'Alasan',
                                style: const TextStyle(
                                  color: TemaAplikasi.netral,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: alasanColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          alasanIcon,
                                          size: 16,
                                          color: alasanColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          jenisAlasan,
                                          style: TextStyle(
                                            color: alasanColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (penjelasanAlasan.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      penjelasanAlasan,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (tanggal != null)
                        _DetailRow(
                          label: 'Tanggal',
                          value: _dateFormat.format(tanggal),
                        ),
                    ],
                  ),
                  // Foto bukti dari data alasan (jika ada)
                  if (fotoBuktiUrl != null && fotoBuktiUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _DetailSection(
                      title: 'Bukti Foto Kerusakan',
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            fotoBuktiUrl,
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
                  // Foto bukti legacy (jika ada)
                  if (buktiFoto.isNotEmpty && fotoBuktiUrl == null) ...[
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
                  // Tombol aksi untuk single item
                  _buildTombolAksi(item),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Detail dokumen pengajuan dengan banyak item (sistem baru)
  void _bukaDetailDokumen(Map<String, dynamic> item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => _DetailDokumenSheet(
        item: item,
        api: _api,
        usernameAdmin: widget.usernameAdmin,
        onProsesSelesai: () {
          _loadData(preserveVisibleData: false);
        },
      ),
    );
  }

  Widget _buildTombolAksi(Map<String, dynamic> item) {
    final tipe = item['tipe']?.toString() ?? 'single';
    final statusItem = item['status_item']?.toString().toLowerCase() ?? '';

    // Cek apakah item sudah diproses (untuk sistem baru)
    final sudahDiproses = statusItem == 'diterima' || statusItem == 'ditolak';

    if (tipe == 'dokumen') {
      // Sistem baru: Dokumen Pengajuan - Terima dengan input lokasi
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _prosesLoading || sudahDiproses
                  ? null
                  : () async {
                      // Input lokasi pengambilan + catatan
                      final hasil = await _inputPenerimaanPengajuan();
                      if (hasil == null) return; // User batal
                      if (!mounted) return;

                      // Tutup bottom sheet
                      Navigator.of(context).pop();

                      // Tunggu sedikit agar Navigator stack stabil
                      await Future.delayed(const Duration(milliseconds: 50));

                      // Kirim ke server via API (hanya jika masih mounted)
                      if (!mounted) return;
                      await _prosesStatus(
                        item: item,
                        status: 'Disetujui',
                        catatan: hasil.catatan.isEmpty
                            ? 'Silakan ambil di ${hasil.lokasi}'
                            : 'Silakan ambil di ${hasil.lokasi}. ${hasil.catatan}',
                        lokasiPengambilan: hasil.lokasi,
                      );
                    },
              icon: const Icon(
                Icons.check_circle_outline,
                size: 18,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: sudahDiproses
                    ? Colors.grey.shade400
                    : TemaAplikasi.sukses,
                foregroundColor: Colors.white,
              ),
              label: Text(sudahDiproses ? 'Sudah Diproses' : 'Terima'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _prosesLoading || sudahDiproses
                  ? null
                  : () async {
                      // Input alasan penolakan
                      final alasan = await _inputCatatanPenolakan();
                      if (alasan == null || alasan.isEmpty) return;
                      if (!mounted) return;

                      // Tutup bottom sheet
                      Navigator.of(context).pop();

                      // Tunggu sedikit
                      await Future.delayed(const Duration(milliseconds: 50));

                      // Proses penolakan
                      if (!mounted) return;
                      await _prosesStatus(
                        item: item,
                        status: 'Ditolak',
                        catatan: alasan,
                      );
                    },
              icon: const Icon(
                Icons.cancel_outlined,
                size: 18,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: sudahDiproses
                    ? Colors.grey.shade400
                    : TemaAplikasi.bahaya,
                foregroundColor: Colors.white,
              ),
              label: Text(sudahDiproses ? 'Sudah Diproses' : 'Tolak'),
            ),
          ),
        ],
      );
    } else {
      // Sistem lama: Pengajuan Single - Perlu input lokasi
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _prosesLoading
                  ? null
                  : () async {
                      // Munculkan dialog konfirmasi/input
                      final hasil = await _inputPenerimaanPengajuan();
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
            child: ElevatedButton.icon(
              onPressed: _prosesLoading
                  ? null
                  : () async {
                      // Input alasan penolakan
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
              icon: const Icon(
                Icons.cancel_outlined,
                size: 18,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: TemaAplikasi.bahaya,
                foregroundColor: Colors.white,
              ),
              label: const Text('Tolak'),
            ),
          ),
        ],
      );
    }
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
                                      _getItemLabel(item),
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

/// Widget untuk detail dokumen dengan persetujuan per item
class _DetailDokumenSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final ApiApdService api;
  final String usernameAdmin;
  final VoidCallback onProsesSelesai;

  const _DetailDokumenSheet({
    required this.item,
    required this.api,
    required this.usernameAdmin,
    required this.onProsesSelesai,
  });

  @override
  State<_DetailDokumenSheet> createState() => _DetailDokumenSheetState();
}

class _DetailDokumenSheetState extends State<_DetailDokumenSheet> {
  bool _loading = true;
  bool _prosesLoading = false;
  Map<String, dynamic> _dokumen = {};
  Map<String, dynamic> _karyawan = {};
  List<Map<String, dynamic>> _items = [];

  // Status per item: 'menunggu', 'diterima', 'ditolak'
  final Map<String, String> _statusItem = {};

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);
    final idDokumen = widget.item['id_pengajuan']?.toString() ?? '';
    if (idDokumen.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final response = await widget.api.detailDokumenPengajuan(idDokumen);
    if (!mounted) return;

    if (widget.api.isSuccess(response)) {
      final data = widget.api.extractMapData(response);
      final items = (data['items'] as List?)
              ?.whereType<Map>()
              .map((e) => e.map((k, v) => MapEntry('$k', v)))
              .toList() ??
          [];

      setState(() {
        _dokumen = Map<String, dynamic>.from(data);
        _dokumen.remove('karyawan');
        _dokumen.remove('items');
        _karyawan = (data['karyawan'] as Map?)
                ?.map((k, v) => MapEntry('$k', v)) ??
            {};
        _items = items;
        _loading = false;

        // Inisialisasi status item dari data
        for (final item in items) {
          final id = item['id']?.toString() ?? '';
          final status = item['status']?.toString().toLowerCase() ?? 'menunggu';
          _statusItem[id] = status;
        }
      });
    } else {
      setState(() => _loading = false);
    }
  }

  String _formatTanggal(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final dt = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (dt == null) return raw;
    return DateFormat('dd MMM yyyy, HH:mm').format(dt);
  }

  void _toggleItemStatus(String id) {
    setState(() {
      final current = _statusItem[id] ?? 'menunggu';
      if (current == 'menunggu' || current == 'ditolak') {
        _statusItem[id] = 'diterima';
      } else {
        _statusItem[id] = 'ditolak';
      }
    });
  }

  Future<void> _lanjutkanProses() async {
    if (_prosesLoading) return;

    // Hitung item yang dipilih
    final itemsDiterima = <String>[];
    final itemsDitolak = <String>[];

    _statusItem.forEach((id, status) {
      if (status == 'diterima') {
        itemsDiterima.add(id);
      } else if (status == 'ditolak') {
        itemsDitolak.add(id);
      }
    });

    if (itemsDiterima.isEmpty && itemsDitolak.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal satu item untuk diterima atau ditolak'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Input lokasi pengambilan jika ada item yang diterima
    String? lokasiPengambilan;
    String? catatanUmum;

    if (itemsDiterima.isNotEmpty) {
      final hasil = await _inputLokasiPengambilan();
      if (hasil == null) return; // User batal
      lokasiPengambilan = hasil.lokasi;
      catatanUmum = hasil.catatan;
    }

    // Input alasan penolakan untuk item yang ditolak
    String? alasanPenolakan;
    if (itemsDitolak.isNotEmpty) {
      alasanPenolakan = await _inputAlasanPenolakan();
      if (alasanPenolakan == null) return; // User batal
    }

    setState(() => _prosesLoading = true);

    try {
      // Proses item yang diterima
      if (itemsDiterima.isNotEmpty) {
        await widget.api.prosesBatchItemPengajuan(
          idsItem: itemsDiterima,
          status: 'diterima',
          usernameAdmin: widget.usernameAdmin,
          catatanAdmin: catatanUmum?.isEmpty ?? true
              ? 'Silakan ambil di $lokasiPengambilan'
              : 'Silakan ambil di $lokasiPengambilan. $catatanUmum',
          lokasiPengambilan: lokasiPengambilan,
        );
      }

      // Proses item yang ditolak
      if (itemsDitolak.isNotEmpty) {
        await widget.api.prosesBatchItemPengajuan(
          idsItem: itemsDitolak,
          status: 'ditolak',
          usernameAdmin: widget.usernameAdmin,
          catatanAdmin: alasanPenolakan ?? '',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${itemsDiterima.length} item diterima, ${itemsDitolak.length} item ditolak',
          ),
          backgroundColor: TemaAplikasi.sukses,
        ),
      );

      // Tutup modal dan refresh data
      Navigator.of(context).pop();
      widget.onProsesSelesai();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memproses: $e'),
          backgroundColor: TemaAplikasi.bahaya,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _prosesLoading = false);
      }
    }
  }

  Future<({String lokasi, String catatan})?> _inputLokasiPengambilan() async {
    final lokasiCtrl = TextEditingController();
    final catatanCtrl = TextEditingController();

    final result = await showDialog<({String lokasi, String catatan})>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 10),
            Text('Lokasi Pengambilan'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masukkan lokasi pengambilan APD untuk item yang diterima.',
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
              if (lokasi.isEmpty) return;
              Navigator.pop(dialogCtx, (
                lokasi: lokasi,
                catatan: catatanCtrl.text.trim(),
              ));
            },
            icon: const Icon(Icons.check),
            label: const Text('Lanjut'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    return result;
  }

  Future<String?> _inputAlasanPenolakan() async {
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
              hintText: 'Contoh: stok ukuran L habis, ajukan ulang minggu depan',
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
              child: const Text('Tolak Item'),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: TemaAplikasi.biruMuda,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.description_outlined,
                          color: TemaAplikasi.biruTua),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pengajuan: ${_karyawan['nama_lengkap'] ?? '-'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: TemaAplikasi.biruTua,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_items.length} item APD',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: TemaAplikasi.biruTua,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Info Karyawan
                          _InfoSection(
                            title: 'Informasi Karyawan',
                            child: Column(
                              children: [
                                _InfoRow('Nama',
                                    _karyawan['nama_lengkap'] ?? '-'),
                                _InfoRow('Jabatan', _karyawan['jabatan'] ?? '-'),
                                _InfoRow(
                                    'Departemen', _karyawan['departemen'] ?? '-'),
                                _InfoRow('Tanggal',
                                    _formatTanggal(_dokumen['tanggal_pengajuan']?.toString())),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Daftar Item dengan Checkbox
                          const Text(
                            'Pilih Item untuk Disetujui/Ditolak',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: TemaAplikasi.biruTua,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Ketuk item untuk mengubah: Diterima ↔ Ditolak',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),

                          ...List.generate(_items.length, (i) {
                            final item = _items[i];
                            final id = item['id']?.toString() ?? '';
                            final status = _statusItem[id] ?? 'menunggu';

                            return _ItemPilihCard(
                              item: item,
                              status: status,
                              onTap: () => _toggleItemStatus(id),
                            );
                          }),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),

            // Footer dengan tombol lanjutkan
            Container(
              padding: const EdgeInsets.all(18),
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
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _prosesLoading ? null : _lanjutkanProses,
                      icon: _prosesLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_forward),
                      label: Text(_prosesLoading ? 'Memproses...' : 'Lanjutkan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TemaAplikasi.biruTua,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
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
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: TemaAplikasi.biruTua,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemPilihCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String status;
  final VoidCallback onTap;

  const _ItemPilihCard({
    required this.item,
    required this.status,
    required this.onTap,
  });

  Color _getStatusColor() {
    if (status == 'diterima') return TemaAplikasi.sukses;
    if (status == 'ditolak') return TemaAplikasi.bahaya;
    return Colors.grey;
  }

  IconData _getStatusIcon() {
    if (status == 'diterima') return Icons.check_circle;
    if (status == 'ditolak') return Icons.cancel;
    return Icons.radio_button_unchecked;
  }

  String _getStatusLabel() {
    if (status == 'diterima') return 'Diterima';
    if (status == 'ditolak') return 'Ditolak';
    return 'Menunggu';
  }

  @override
  Widget build(BuildContext context) {
    final warna = _getStatusColor();
    final icon = _getStatusIcon();
    final label = _getStatusLabel();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: status == 'menunggu'
              ? Colors.white
              : warna.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: status == 'menunggu'
                ? Colors.grey.shade300
                : warna.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Status Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: warna.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: warna, size: 24),
            ),
            const SizedBox(width: 12),

            // Item Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['nama_apd']?.toString() ?? '-',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ukuran: ${item['ukuran'] ?? '-'} · Jumlah: ${item['jumlah'] ?? 1}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Status Label
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: warna.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: warna,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
