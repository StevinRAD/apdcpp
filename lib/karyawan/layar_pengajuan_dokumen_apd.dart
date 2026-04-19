import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:apdcpp/konfigurasi_api.dart';
import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';
import 'package:apdcpp/widgets/widget_tanda_tangan.dart';
import 'package:apdcpp/karyawan/layar_preview_dokumen_pengajuan.dart';

/// Layar pengajuan dokumen APD multi-item.
/// Karyawan memilih beberapa APD, mengisi ukuran & alasan per item,
/// lalu membubuhkan tanda tangan sebelum preview dan kirim.
class LayarPengajuanDokumenApd extends StatefulWidget {
  final String username;
  final Map<String, dynamic>? initialApd;

  const LayarPengajuanDokumenApd({
    super.key,
    required this.username,
    this.initialApd,
  });

  @override
  State<LayarPengajuanDokumenApd> createState() =>
      _LayarPengajuanDokumenApdState();
}

class _LayarPengajuanDokumenApdState extends State<LayarPengajuanDokumenApd> {
  final ApiApdService _api = const ApiApdService();
  final GlobalKey<WidgetTandaTanganState> _ttdKey = GlobalKey();

  bool _loadingApd = true;
  bool _submitting = false;
  List<Map<String, dynamic>> _semuaApd = [];
  final Map<String, _ItemPengajuan> _itemDipilih = {};
  int _stepAktif = 0; // 0: pilih APD, 1: isi detail, 2: tanda tangan
  Map<String, dynamic> _aturanPengajuan = const {};

  @override
  void initState() {
    super.initState();
    if (widget.initialApd != null) {
      final apd = widget.initialApd!;
      final id = apd['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        _itemDipilih[id] = _ItemPengajuan(
          idApd: id,
          namaApd: apd['nama_apd']?.toString() ?? '-',
          satuan: apd['satuan']?.toString() ?? 'pcs',
          stokTersedia: int.tryParse('${apd['stok'] ?? 0}') ?? 0,
        );
      }
    }
    _loadDaftarApd();
    _loadAturanPengajuan();
  }

  Future<void> _loadAturanPengajuan() async {
    final response = await _api.dashboardKaryawan(widget.username);
    if (!_api.isSuccess(response) || !mounted) return;

    final data = _api.extractMapData(response);
    final aturanRaw = data['aturan_pengajuan'];
    if (mounted) {
      setState(() {
        _aturanPengajuan = aturanRaw is Map
            ? aturanRaw.map((key, value) => MapEntry('$key', value))
            : const {};
      });
    }
  }

  String _formatTanggalBolehAjukan() {
    final raw = _aturanPengajuan['tanggal_boleh_ajukan']?.toString() ?? '';
    if (raw.isEmpty) return '-';
    final tanggal = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (tanggal == null) return raw;
    return DateFormat('dd MMM yyyy, HH:mm').format(tanggal);
  }

  int _cooldownHari() {
    final raw = _aturanPengajuan['cooldown_pengajuan_hari'];
    if (raw is int) return raw;
    return int.tryParse('${raw ?? 30}') ?? 30;
  }

  Future<void> _loadDaftarApd() async {
    setState(() => _loadingApd = true);
    final response = await _api.daftarApd();
    if (!mounted) return;

    if (_api.isSuccess(response)) {
      final items = _api.extractListData(response);
      setState(() {
        _semuaApd = items
            .where((a) => (int.tryParse('${a['stok'] ?? 0}') ?? 0) > 0)
            .toList();
        _loadingApd = false;
      });
    } else {
      setState(() => _loadingApd = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_api.message(response))),
        );
      }
    }
  }

  void _togglePilihApd(Map<String, dynamic> apd) {
    final id = apd['id']?.toString() ?? '';
    setState(() {
      if (_itemDipilih.containsKey(id)) {
        _itemDipilih.remove(id);
      } else {
        _itemDipilih[id] = _ItemPengajuan(
          idApd: id,
          namaApd: apd['nama_apd']?.toString() ?? '-',
          satuan: apd['satuan']?.toString() ?? 'pcs',
          stokTersedia: int.tryParse('${apd['stok'] ?? 0}') ?? 0,
        );
      }
    });
  }

  bool _validasiStep1() {
    if (_itemDipilih.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 APD untuk diajukan')),
      );
      return false;
    }
    return true;
  }

  bool _validasiStep2() {
    for (final entry in _itemDipilih.entries) {
      final item = entry.value;
      if (item.ukuranController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ukuran untuk "${item.namaApd}" belum diisi'),
          ),
        );
        return false;
      }
      if (item.alasanController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alasan untuk "${item.namaApd}" belum diisi'),
          ),
        );
        return false;
      }
    }
    return true;
  }

  void _lanjutStep() {
    if (_stepAktif == 0 && _validasiStep1()) {
      // Cek apakah karyawan bisa mengajukan sebelum lanjut
      if (!_aturanPengajuan.containsKey('bisa_ajukan') ||
          _aturanPengajuan['bisa_ajukan'] == true) {
        setState(() => _stepAktif = 1);
      } else {
        // Tampilkan popup peringatan
        _tampilkanDialogPeringatanPengajuan();
      }
    } else if (_stepAktif == 1 && _validasiStep2()) {
      setState(() => _stepAktif = 2);
    }
  }

  void _tampilkanDialogPeringatanPengajuan() {
    final status = _aturanPengajuan['status']?.toString() ?? '';
    final pesan = _aturanPengajuan['pesan']?.toString() ??
        'Anda tidak dapat mengajukan APD saat ini.';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              status == 'menunggu_proses'
                  ? Icons.hourglass_empty
                  : Icons.block_outlined,
              color: status == 'menunggu_proses'
                  ? TemaAplikasi.biruTua
                  : TemaAplikasi.bahaya,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                status == 'menunggu_proses'
                    ? 'Menunggu Persetujuan Admin'
                    : 'Pengajuan Ditahan',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pesan,
              style: const TextStyle(height: 1.45, fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (status == 'menunggu_proses')
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: TemaAplikasi.biruMuda.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 20,
                      color: TemaAplikasi.biruTua,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Masih ada barang yang diajukan sebelumnya dan sedang menunggu persetujuan admin. Silakan tunggu sampai diproses.',
                        style: TextStyle(
                          fontSize: 13,
                          color: TemaAplikasi.biruTua,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (status == 'cooldown')
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: TemaAplikasi.emas.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 20,
                          color: TemaAplikasi.emasTua,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Masa tunggu: ${_cooldownHari()} hari',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: TemaAplikasi.emasTua,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Anda bisa mengajukan lagi pada: ${_formatTanggalBolehAjukan()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: TemaAplikasi.emasTua,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: TemaAplikasi.biruTua,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  void _kembaliStep() {
    if (_stepAktif > 0) {
      setState(() => _stepAktif--);
    }
  }

  Future<void> _kirimPengajuan() async {
    final ttdState = _ttdKey.currentState;
    if (ttdState == null || !ttdState.sudahDigambar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan buat tanda tangan terlebih dahulu')),
      );
      return;
    }

    setState(() => _submitting = true);

    final ttdBase64 = await ttdState.eksporBase64();
    if (ttdBase64 == null || ttdBase64.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengekspor tanda tangan')),
        );
        setState(() => _submitting = false);
      }
      return;
    }

    final items = _itemDipilih.values.map((item) => {
      'id_apd': item.idApd,
      'ukuran': item.ukuranController.text.trim(),
      'alasan': item.alasanController.text.trim(),
      'jumlah': item.jumlah,
    }).toList();

    final response = await _api.simpanDokumenPengajuan(
      username: widget.username,
      items: items,
      tandaTanganKaryawan: ttdBase64,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (_api.isSuccess(response)) {
      final data = _api.extractMapData(response);
      final idDokumen = data['id_pengajuan']?.toString() ?? '';

      // Navigate ke preview dokumen
      if (idDokumen.isNotEmpty && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LayarPreviewDokumenPengajuan(
              idDokumen: idDokumen,
              username: widget.username,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengajuan berhasil dikirim!')),
        );
        Navigator.pop(context, true);
      }
    } else {
      // Tampilkan pesan error dengan lebih jelas
      final pesanError = _api.message(response);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pesanError),
          backgroundColor: TemaAplikasi.bahaya,
          duration: const Duration(seconds: 5),
        ),
      );

      // Debug: print error ke console
      debugPrint('ERROR PENGIRIMAN PENGAJUAN: $pesanError');
      debugPrint('RESPONSE LENGKAP: $response');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _stepAktif == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _stepAktif > 0) {
          _kembaliStep();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pengajuan Dokumen APD'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_stepAktif > 0) {
                _kembaliStep();
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: Column(
          children: [
            // Stepper indicator
            _buildStepIndicator(),
            // Content
            Expanded(child: _buildStepContent()),
            // Bottom button
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    const labels = ['Pilih APD', 'Isi Detail', 'Tanda Tangan'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(3, (i) {
          final aktif = i == _stepAktif;
          final selesai = i < _stepAktif;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selesai
                        ? TemaAplikasi.sukses
                        : (aktif ? TemaAplikasi.biruTua : Colors.grey.shade300),
                  ),
                  alignment: Alignment.center,
                  child: selesai
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: aktif ? Colors.white : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: aktif ? FontWeight.w800 : FontWeight.w600,
                      color: aktif
                          ? TemaAplikasi.biruTua
                          : Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (i < 2)
                  Container(
                    width: 12,
                    height: 1.5,
                    color: selesai
                        ? TemaAplikasi.sukses
                        : Colors.grey.shade300,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_stepAktif) {
      case 0:
        return _buildStep1PilihApd();
      case 1:
        return _buildStep2IsiDetail();
      case 2:
        return _buildStep3TandaTangan();
      default:
        return const SizedBox();
    }
  }

  // ─── STEP 1: Pilih APD ─────────────────────
  Widget _buildStep1PilihApd() {
    if (_loadingApd) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_semuaApd.isEmpty) {
      return const Center(child: Text('Tidak ada APD yang tersedia saat ini'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TemaAplikasi.biruMuda,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: TemaAplikasi.biruTua),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pilih APD yang ingin diajukan. Anda bisa memilih beberapa APD sekaligus.',
                  style: TextStyle(
                    color: TemaAplikasi.biruTua,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_itemDipilih.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: TemaAplikasi.sukses.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_itemDipilih.length} APD dipilih',
              style: const TextStyle(
                color: TemaAplikasi.sukses,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        ..._semuaApd.map((apd) {
          final id = apd['id']?.toString() ?? '';
          final dipilih = _itemDipilih.containsKey(id);
          final stok = int.tryParse('${apd['stok'] ?? 0}') ?? 0;
          final gambarUrl = buildUploadUrl(apd['gambar_apd']?.toString());

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: dipilih
                  ? const BorderSide(color: TemaAplikasi.biruTua, width: 2)
                  : BorderSide.none,
            ),
            child: InkWell(
              onTap: () => _togglePilihApd(apd),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Checkbox visual
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dipilih
                            ? TemaAplikasi.biruTua
                            : Colors.grey.shade200,
                      ),
                      alignment: Alignment.center,
                      child: dipilih
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    // Gambar APD
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 56,
                        height: 56,
                        color: Colors.grey.shade100,
                        child: gambarUrl.isEmpty
                            ? const Icon(Icons.inventory_2_outlined,
                                color: Colors.grey, size: 28)
                            : Image.network(
                                gambarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.grey,
                                  size: 28,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Info APD
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            apd['nama_apd']?.toString() ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Stok: $stok ${apd['satuan'] ?? 'pcs'}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ─── STEP 2: Isi Detail per APD ─────────────────────
  Widget _buildStep2IsiDetail() {
    final items = _itemDipilih.values.toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TemaAplikasi.emas.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.edit_note, color: TemaAplikasi.emasTua),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Isi ukuran dan alasan pengajuan untuk setiap APD yang dipilih.',
                  style: TextStyle(
                    color: TemaAplikasi.emasTua,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.namaApd,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: item.ukuranController,
                          decoration: const InputDecoration(
                            labelText: 'Ukuran',
                            hintText: 'Contoh: L, XL, 42',
                            prefixIcon: Icon(Icons.straighten_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 90,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Jumlah',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: TemaAplikasi.netral,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _JumlahButton(
                                  icon: Icons.remove,
                                  onTap: item.jumlah > 1
                                      ? () => setState(() => item.jumlah--)
                                      : null,
                                ),
                                Expanded(
                                  child: Text(
                                    '${item.jumlah}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                _JumlahButton(
                                  icon: Icons.add,
                                  onTap: item.jumlah < item.stokTersedia
                                      ? () => setState(() => item.jumlah++)
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: item.alasanController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Alasan Pengajuan',
                      hintText: 'Jelaskan alasan Anda membutuhkan APD ini',
                      prefixIcon: Icon(Icons.description_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ─── STEP 3: Tanda Tangan ─────────────────────
  Widget _buildStep3TandaTangan() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TemaAplikasi.sukses.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.draw_outlined, color: TemaAplikasi.sukses),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bubuhkan tanda tangan Anda sebagai pemohon APD.',
                  style: TextStyle(
                    color: TemaAplikasi.sukses,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Ringkasan APD yang dipilih
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ringkasan Pengajuan',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                ..._itemDipilih.values.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: TemaAplikasi.sukses, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${item.namaApd} (${item.ukuranController.text}) × ${item.jumlah}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Widget tanda tangan
        WidgetTandaTangan(
          key: _ttdKey,
          tinggi: 220,
          labelPetunjuk: 'Tanda Tangan Pemohon (Karyawan)',
        ),
      ],
    );
  }

  Widget _buildBottomButton() {
    return Container(
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
          if (_stepAktif > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _submitting ? null : _kembaliStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Kembali'),
              ),
            ),
          if (_stepAktif > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _submitting
                  ? null
                  : (_stepAktif < 2 ? _lanjutStep : _kirimPengajuan),
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(_stepAktif < 2
                      ? Icons.arrow_forward
                      : Icons.send_rounded),
              label: Text(
                _submitting
                    ? 'Mengirim...'
                    : (_stepAktif < 2 ? 'Lanjut' : 'Kirim Pengajuan'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemPengajuan {
  final String idApd;
  final String namaApd;
  final String satuan;
  final int stokTersedia;
  final TextEditingController ukuranController = TextEditingController();
  final TextEditingController alasanController = TextEditingController();
  int jumlah = 1;

  _ItemPengajuan({
    required this.idApd,
    required this.namaApd,
    required this.satuan,
    required this.stokTersedia,
  });
}

class _JumlahButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _JumlahButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: onTap != null
              ? TemaAplikasi.biruTua.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 16,
          color: onTap != null ? TemaAplikasi.biruTua : Colors.grey.shade400,
        ),
      ),
    );
  }
}
