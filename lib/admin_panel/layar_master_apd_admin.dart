import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:apdcpp/konfigurasi_api.dart';
import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/services/izin_perangkat_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';

class LayarMasterApdAdmin extends StatefulWidget {
  const LayarMasterApdAdmin({super.key});

  @override
  State<LayarMasterApdAdmin> createState() => _LayarMasterApdAdminState();
}

class _LayarMasterApdAdminState extends State<LayarMasterApdAdmin> {
  final ApiApdService _api = const ApiApdService();
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<bool> _pastikanIzinPerangkat(ImageSource source) {
    if (!mounted) return Future.value(false);
    if (source == ImageSource.camera) {
      return IzinPerangkatService.pastikanAksesKamera(context);
    }
    return IzinPerangkatService.pastikanAksesGaleri(context);
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });

    final response = await _api.masterApdList();
    if (!mounted) return;

    if (_api.isSuccess(response)) {
      setState(() {
        _items = _api.extractListData(response);
        _loading = false;
      });
      return;
    }

    setState(() {
      _items = [];
      _loading = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_api.message(response))));
  }

  String _textOrEmpty(dynamic value) => value?.toString().trim() ?? '';

  int _parseInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim()) ?? fallback;
  }

  void _terapkanApdTersimpan(Map<String, dynamic> response) {
    final dataBaru = _api.extractMapData(response);
    if (dataBaru.isEmpty) {
      _loadData();
      return;
    }

    setState(() {
      final itemsBaru = List<Map<String, dynamic>>.from(_items);
      final idBaru = dataBaru['id_apd']?.toString() ?? '';
      final indexLama = itemsBaru.indexWhere(
        (item) => (item['id_apd']?.toString() ?? '') == idBaru,
      );

      if (indexLama >= 0) {
        itemsBaru[indexLama] = {...itemsBaru[indexLama], ...dataBaru};
      } else {
        itemsBaru.insert(0, dataBaru);
      }
      _items = itemsBaru;
    });
  }

  Future<void> _tambahAtauUbah({Map<String, dynamic>? item}) async {
    final namaController = TextEditingController(
      text: item?['nama_apd']?.toString() ?? '',
    );
    final stokController = TextEditingController(
      text: item?['stok']?.toString() ?? '0',
    );
    final minStokController = TextEditingController(
      text: item?['min_stok']?.toString() ?? '5',
    );
    final satuanController = TextEditingController(
      text: item?['satuan']?.toString() ?? 'pcs',
    );
    final deskripsiController = TextEditingController(
      text: item?['deskripsi']?.toString() ?? '',
    );
    bool isAktif = '${item?['is_aktif'] ?? 1}' == '1';
    File? gambarApdBaru;
    bool hapusGambar = false;

    final isEdit = item != null;
    final gambarLama = item?['gambar_apd']?.toString() ?? '';
    final gambarLamaUrl = buildUploadUrl(gambarLama);
    final formKey = GlobalKey<FormState>();
    AutovalidateMode autovalidateMode = AutovalidateMode.disabled;
    bool saving = false;
    String? dialogError;

    String? validateWajib(String? value, String label) {
      if (value == null || value.trim().isEmpty) {
        return '$label wajib diisi';
      }
      return null;
    }

    String? validateAngka(String? value, String label) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) {
        return '$label wajib diisi';
      }
      final angka = int.tryParse(text);
      if (angka == null) {
        return '$label harus berupa angka';
      }
      if (angka < 0) {
        return '$label tidak boleh negatif';
      }
      return null;
    }

    final response = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (stateCtx, setStateDialog) {
          Future<void> submitForm() async {
            if (saving) return;

            FocusScope.of(stateCtx).unfocus();
            setStateDialog(() {
              dialogError = null;
              autovalidateMode = AutovalidateMode.always;
            });

            final isValid = formKey.currentState?.validate() ?? false;
            if (!isValid) return;

            final nama = namaController.text.trim();
            final stok = stokController.text.trim();
            final minStok = minStokController.text.trim();
            final satuan = satuanController.text.trim();
            final deskripsi = deskripsiController.text.trim();

            final tidakAdaPerubahan =
                isEdit &&
                gambarApdBaru == null &&
                !hapusGambar &&
                nama == _textOrEmpty(item['nama_apd']) &&
                stok == _parseInt(item['stok']).toString() &&
                minStok ==
                    _parseInt(item['min_stok'], fallback: 5).toString() &&
                satuan == _textOrEmpty(item['satuan']) &&
                deskripsi == _textOrEmpty(item['deskripsi']) &&
                (isAktif ? '1' : '0') ==
                    (_textOrEmpty(item['is_aktif']).isEmpty
                        ? '1'
                        : _textOrEmpty(item['is_aktif']));

            if (tidakAdaPerubahan) {
              if (!dialogCtx.mounted) return;
              Navigator.pop(dialogCtx, {
                'status': 'sukses',
                'pesan': 'Data APD tidak berubah',
                'data': {...item},
              });
              return;
            }

            setStateDialog(() => saving = true);

            final response = isEdit
                ? await _api.masterApdUbah(
                    idApd: '${item['id_apd']}',
                    namaApd: nama,
                    stok: stok,
                    minStok: minStok,
                    satuan: satuan,
                    deskripsi: deskripsi,
                    isAktif: isAktif ? '1' : '0',
                    gambarApd: gambarApdBaru,
                    hapusGambar: hapusGambar,
                  )
                : await _api.masterApdTambah(
                    namaApd: nama,
                    stok: stok,
                    minStok: minStok,
                    satuan: satuan,
                    deskripsi: deskripsi,
                    gambarApd: gambarApdBaru,
                  );

            if (_api.isSuccess(response)) {
              if (!dialogCtx.mounted) return;
              Navigator.pop(dialogCtx, response);
              return;
            }

            if (!dialogCtx.mounted) return;
            setStateDialog(() {
              saving = false;
              dialogError = _api.message(response);
            });
          }

          return PopScope(
            canPop: !saving,
            child: AlertDialog(
              title: Text(isEdit ? 'Edit APD' : 'Tambah APD'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    autovalidateMode: autovalidateMode,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (dialogError != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Text(
                              dialogError!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        const Text(
                          'Informasi APD',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Lengkapi data stok dan satuan APD agar tampilan inventaris tetap rapi.',
                          style: TextStyle(
                            color: TemaAplikasi.netral,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: namaController,
                          enabled: !saving,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nama APD',
                            prefixIcon: Icon(Icons.inventory_2_outlined),
                          ),
                          validator: (value) =>
                              validateWajib(value, 'Nama APD'),
                        ),
                        const SizedBox(height: 12),
                        const SizedBox(height: 12),
                        Column(
                          children: [
                            TextFormField(
                              controller: stokController,
                              enabled: !saving,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Stok Saat Ini',
                                prefixIcon: Icon(Icons.layers_outlined),
                              ),
                              validator: (value) =>
                                  validateAngka(value, 'Stok'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: minStokController,
                              enabled: !saving,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Batas Minimum',
                                prefixIcon: Icon(Icons.warning_amber_rounded),
                              ),
                              validator: (value) =>
                                  validateAngka(value, 'Batas minimum'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: satuanController,
                          enabled: !saving,
                          decoration: const InputDecoration(
                            labelText: 'Satuan',
                            prefixIcon: Icon(Icons.straighten_outlined),
                          ),
                          validator: (value) => validateWajib(value, 'Satuan'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: deskripsiController,
                          enabled: !saving,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Deskripsi',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: TemaAplikasi.biruMuda,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: TemaAplikasi.biruTua.withValues(
                                alpha: 0.10,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Foto APD',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Upload foto agar item mudah dikenali di katalog dan stok admin.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: TemaAplikasi.netral,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: double.infinity,
                                  height: 170,
                                  color: Colors.white,
                                  child: gambarApdBaru != null
                                      ? Image.file(
                                          gambarApdBaru!,
                                          fit: BoxFit.cover,
                                        )
                                      : gambarLamaUrl.isNotEmpty && !hapusGambar
                                      ? Image.network(
                                          gambarLamaUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const Center(
                                                child: Icon(
                                                  Icons.broken_image_outlined,
                                                  size: 36,
                                                  color: TemaAplikasi.netral,
                                                ),
                                              ),
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.inventory_2_outlined,
                                            size: 42,
                                            color: TemaAplikasi.netral,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: saving
                                        ? null
                                        : () async {
                                            final source =
                                                await showModalBottomSheet<
                                                  ImageSource
                                                >(
                                                  context: stateCtx,
                                                  builder: (sheetContext) => SafeArea(
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        ListTile(
                                                          leading: const Icon(
                                                            Icons
                                                                .photo_camera_outlined,
                                                          ),
                                                          title: const Text(
                                                            'Ambil dari Kamera',
                                                          ),
                                                          onTap: () =>
                                                              Navigator.pop(
                                                                sheetContext,
                                                                ImageSource
                                                                    .camera,
                                                              ),
                                                        ),
                                                        ListTile(
                                                          leading: const Icon(
                                                            Icons
                                                                .photo_library_outlined,
                                                          ),
                                                          title: const Text(
                                                            'Pilih dari Galeri',
                                                          ),
                                                          onTap: () =>
                                                              Navigator.pop(
                                                                sheetContext,
                                                                ImageSource
                                                                    .gallery,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                            if (source == null) return;
                                            final izin =
                                                await _pastikanIzinPerangkat(
                                                  source,
                                                );
                                            if (!stateCtx.mounted || !izin) {
                                              return;
                                            }
                                            final picked = await _picker
                                                .pickImage(
                                                  source: source,
                                                  imageQuality: 72,
                                                  maxWidth: 1280,
                                                  maxHeight: 1280,
                                                );
                                            if (picked == null) {
                                              return;
                                            }
                                            setStateDialog(() {
                                              gambarApdBaru = File(picked.path);
                                              hapusGambar = false;
                                              dialogError = null;
                                            });
                                          },
                                    icon: const Icon(
                                      Icons.add_a_photo_outlined,
                                    ),
                                    label: Text(
                                      gambarApdBaru != null ||
                                              gambarLamaUrl.isNotEmpty
                                          ? 'Ganti Gambar'
                                          : 'Pilih Gambar',
                                    ),
                                  ),
                                  if (isEdit &&
                                      (gambarLamaUrl.isNotEmpty ||
                                          gambarApdBaru != null) &&
                                      !hapusGambar)
                                    TextButton.icon(
                                      onPressed: saving
                                          ? null
                                          : () {
                                              setStateDialog(() {
                                                gambarApdBaru = null;
                                                hapusGambar = true;
                                                dialogError = null;
                                              });
                                            },
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                      label: const Text(
                                        'Hapus Gambar',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5EAF2)),
                          ),
                          child: SwitchListTile(
                            value: isAktif,
                            onChanged: saving
                                ? null
                                : (value) {
                                    setStateDialog(() => isAktif = value);
                                  },
                            title: const Text('Aktifkan item APD'),
                            subtitle: const Text(
                              'Matikan jika item tidak ingin ditampilkan ke pengguna.',
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogCtx),
                  child: Text(saving ? 'Tutup' : 'Batal'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD2A92B),
                    foregroundColor: Colors.white,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan'),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Dihapus dispose() agar tidak error crash saat UI animasi close berjalan

    if (!mounted || response == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_api.message(response))));
    if (_api.isSuccess(response)) {
      _terapkanApdTersimpan(response);
    }
  }

  Future<void> _hapus(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Hapus APD'),
        content: Text('Yakin hapus ${item['nama_apd']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    final response = await _api.masterApdHapus('${item['id_apd']}');
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_api.message(response))));
    if (_api.isSuccess(response)) {
      final id = item['id_apd']?.toString() ?? '';
      setState(() {
        _items = _items
            .where((existing) => (existing['id_apd']?.toString() ?? '') != id)
            .toList();
      });
      if (_items.isEmpty) {
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalAktif = _items
        .where((item) => '${item['is_aktif'] ?? 1}' == '1')
        .length;
    final totalMenipis = _items.where((item) {
      final stok = int.tryParse('${item['stok'] ?? 0}') ?? 0;
      final minStok = int.tryParse('${item['min_stok'] ?? 0}') ?? 0;
      return stok <= minStok;
    }).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Manajemen Master APD')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: TemaAplikasi.emas,
        onPressed: () => _tambahAtauUbah(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Inventaris APD',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pantau stok, status aktif, dan ambang minimum APD dari satu tempat.',
                      style: TextStyle(color: TemaAplikasi.netral, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _summaryChip(
                          'Total item',
                          '${_items.length}',
                          TemaAplikasi.biruTua,
                        ),
                        _summaryChip(
                          'Aktif',
                          '$totalAktif',
                          TemaAplikasi.sukses,
                        ),
                        _summaryChip(
                          'Stok menipis',
                          '$totalMenipis',
                          TemaAplikasi.emas,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('Belum ada data APD.'),
                ),
              )
            else
              ..._items.map((item) {
                final stok = int.tryParse('${item['stok'] ?? 0}') ?? 0;
                final minStok = int.tryParse('${item['min_stok'] ?? 0}') ?? 0;
                final menipis = stok <= minStok;
                final gambarUrl = buildUploadUrl(
                  item['gambar_apd']?.toString(),
                );
                final aktif = '${item['is_aktif'] ?? 1}' == '1';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 62,
                            height: 62,
                            color: TemaAplikasi.biruMuda,
                            child: gambarUrl.isEmpty
                                ? const Icon(
                                    Icons.inventory_2_outlined,
                                    color: TemaAplikasi.biruTua,
                                  )
                                : Image.network(
                                    gambarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.broken_image_outlined,
                                      color: TemaAplikasi.biruTua,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['nama_apd']?.toString() ?? '-',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _summaryChip(
                                    'Stok',
                                    '$stok ${item['satuan'] ?? 'pcs'}',
                                    menipis
                                        ? TemaAplikasi.emas
                                        : TemaAplikasi.biruTua,
                                  ),
                                  _summaryChip(
                                    aktif ? 'Aktif' : 'Nonaktif',
                                    'Min $minStok',
                                    aktif
                                        ? TemaAplikasi.sukses
                                        : TemaAplikasi.netral,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              color: TemaAplikasi.emasTua,
                              onPressed: () => _tambahAtauUbah(item: item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: TemaAplikasi.bahaya,
                              onPressed: () => _hapus(item),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String title, String value, Color color) {
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
}
