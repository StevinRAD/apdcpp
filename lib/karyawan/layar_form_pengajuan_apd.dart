import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/services/izin_perangkat_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';

class LayarFormPengajuanApd extends StatefulWidget {
  final String username;
  final Map<String, dynamic> apd;

  const LayarFormPengajuanApd({
    super.key,
    required this.username,
    required this.apd,
  });

  @override
  State<LayarFormPengajuanApd> createState() => _LayarFormPengajuanApdState();
}

class _LayarFormPengajuanApdState extends State<LayarFormPengajuanApd> {
  final ApiApdService _api = const ApiApdService();
  final ImagePicker _picker = ImagePicker();

  String _alasan = 'Karyawan Baru';
  String _ukuran = '';
  bool _sedangSimpan = false;
  bool _memuatAturan = true;
  File? _buktiFoto;
  Map<String, dynamic> _aturanPengajuan = const {};

  List<String> get _opsiUkuran {
    final nama = (widget.apd['nama_apd']?.toString() ?? '').toLowerCase();
    if (nama.contains('sepatu') || nama.contains('boots')) {
      return const ['38', '39', '40', '41', '42', '43', '44'];
    }
    return const ['S', 'M', 'L', 'XL'];
  }

  @override
  void initState() {
    super.initState();
    _ukuran = _opsiUkuran.first;
    _loadAturanPengajuan();
  }

  Future<void> _loadAturanPengajuan() async {
    final response = await _api.dashboardKaryawan(widget.username);
    if (!mounted) return;

    final data = _api.extractMapData(response);
    final aturanRaw = data['aturan_pengajuan'];
    setState(() {
      _aturanPengajuan = aturanRaw is Map
          ? aturanRaw.map((key, value) => MapEntry('$key', value))
          : const {};
      _memuatAturan = false;
    });
  }

  Future<void> _pilihSumberFoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Ambil dari Kamera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Pilih dari Galeri'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;
    await _ambilFoto(source);
  }

  Future<bool> _pastikanIzinPerangkat(ImageSource source) {
    if (!mounted) return Future.value(false);
    if (source == ImageSource.camera) {
      return IzinPerangkatService.pastikanAksesKamera(context);
    }
    return IzinPerangkatService.pastikanAksesGaleri(context);
  }

  Future<void> _ambilFoto(ImageSource source) async {
    try {
      final izin = await _pastikanIzinPerangkat(source);
      if (!mounted || !izin) return;

      final result = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (result == null) return;
      setState(() {
        _buktiFoto = File(result.path);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal mengambil foto')));
    }
  }

  Future<void> _kirimPengajuan() async {
    if (!_memuatAturan &&
        _aturanPengajuan.containsKey('bisa_ajukan') &&
        !_bisaAjukan()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _aturanPengajuan['pesan']?.toString() ??
                'Akun belum bisa mengajukan APD saat ini.',
          ),
        ),
      );
      return;
    }

    if (_alasan == 'Rusak' && _buktiFoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload foto wajib jika alasan Rusak')),
      );
      return;
    }

    setState(() {
      _sedangSimpan = true;
    });

    final response = await _api.simpanPengajuan(
      username: widget.username,
      idApd: '${widget.apd['id_apd'] ?? widget.apd['id'] ?? ''}',
      ukuran: _ukuran,
      alasan: _alasan,
      buktiFoto: _buktiFoto,
    );

    if (!mounted) return;
    setState(() {
      _sedangSimpan = false;
    });

    final data = _api.extractMapData(response);
    final aturanRaw = data['aturan_pengajuan'];
    if (aturanRaw is Map) {
      setState(() {
        _aturanPengajuan = aturanRaw.map(
          (key, value) => MapEntry('$key', value),
        );
      });
    }

    if (_api.isSuccess(response)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_api.message(response))));
      Navigator.pop(context, true);
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_api.message(response))));
  }

  int _cooldownHari() {
    final raw = _aturanPengajuan['cooldown_pengajuan_hari'];
    if (raw is int) return raw;
    return int.tryParse('${raw ?? 30}') ?? 30;
  }

  bool _bisaAjukan() => _aturanPengajuan['bisa_ajukan'] == true;

  Color _warnaAturan() {
    final status = _aturanPengajuan['status']?.toString() ?? '';
    if (status == 'menunggu_proses') return Colors.blue;
    if (status == 'cooldown') return TemaAplikasi.emasTua;
    return TemaAplikasi.sukses;
  }

  String _tanggalBolehAjukan() {
    final raw = _aturanPengajuan['tanggal_boleh_ajukan']?.toString() ?? '';
    if (raw.isEmpty) return '-';
    final tanggal = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (tanggal == null) return raw;
    return DateFormat('dd MMM yyyy, HH:mm').format(tanggal);
  }

  @override
  Widget build(BuildContext context) {
    final namaApd = widget.apd['nama_apd']?.toString() ?? '-';
    final stok = int.tryParse('${widget.apd['stok'] ?? 0}') ?? 0;
    final warnaAturan = _warnaAturan();

    return Scaffold(
      appBar: AppBar(title: const Text('Form Pengajuan APD')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ringkasan APD',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: TemaAplikasi.emas.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: TemaAplikasi.emasTua,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                namaApd,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Stok tersedia: $stok ${widget.apd['satuan'] ?? 'pcs'}',
                                style: const TextStyle(
                                  color: TemaAplikasi.netral,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.apd['deskripsi']?.toString() ?? '-',
                      style: const TextStyle(height: 1.45),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aturan Pengajuan Akun',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_memuatAturan)
                      const LinearProgressIndicator()
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: warnaAturan.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: warnaAturan.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _bisaAjukan()
                                      ? Icons.verified_outlined
                                      : Icons.timelapse_outlined,
                                  color: warnaAturan,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _bisaAjukan()
                                        ? 'Akun bisa mengajukan sekarang'
                                        : 'Pengajuan akun sedang dibatasi',
                                    style: TextStyle(
                                      color: warnaAturan,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _aturanPengajuan['pesan']?.toString() ??
                                  'Aturan akun belum tersedia.',
                              style: const TextStyle(height: 1.45),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _InfoChipForm(
                                  warna: TemaAplikasi.biruTua,
                                  label: _cooldownHari() == 0
                                      ? 'Tanpa Pending'
                                      : 'Pending ${_cooldownHari()} hari',
                                ),
                                if ((_aturanPengajuan['tanggal_boleh_ajukan']
                                            ?.toString() ??
                                        '')
                                    .isNotEmpty)
                                  _InfoChipForm(
                                    warna: TemaAplikasi.emasTua,
                                    label:
                                        'Ajukan lagi ${_tanggalBolehAjukan()}',
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detail Pengajuan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _ukuran,
                      decoration: const InputDecoration(labelText: 'Ukuran'),
                      items: _opsiUkuran
                          .map(
                            (e) => DropdownMenuItem<String>(
                              value: e,
                              child: Text(e),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _ukuran = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: TemaAplikasi.emas.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Jumlah pengajuan otomatis 1 item. Pengajuan berikutnya mengikuti status pengajuan terakhir dan pengaturan masa tunggu dari admin.',
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _alasan,
                      decoration: const InputDecoration(
                        labelText: 'Alasan Pengajuan',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Karyawan Baru',
                          child: Text('Baru / Karyawan Baru'),
                        ),
                        DropdownMenuItem(value: 'Rusak', child: Text('Rusak')),
                        DropdownMenuItem(
                          value: 'Hilang',
                          child: Text('Hilang'),
                        ),
                        DropdownMenuItem(
                          value: 'Lainnya',
                          child: Text('Lainnya'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _alasan = value;
                        });
                      },
                    ),
                    if (_alasan == 'Rusak') ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Bukti Foto Kerusakan',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pilihSumberFoto,
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: _buktiFoto == null
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo_outlined,
                                      color: TemaAplikasi.netral,
                                      size: 32,
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'Tap untuk pilih kamera atau galeri',
                                      style: TextStyle(
                                        color: TemaAplikasi.netral,
                                      ),
                                    ),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(17),
                                  child: Image.file(
                                    _buktiFoto!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _pilihSumberFoto,
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Ambil Ulang / Ganti Foto'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sedangSimpan ? null : _kirimPengajuan,
                child: _sedangSimpan
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Ajukan Sekarang'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChipForm extends StatelessWidget {
  final Color warna;
  final String label;

  const _InfoChipForm({required this.warna, required this.label});

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
