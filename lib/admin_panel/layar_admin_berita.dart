import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import 'package:apdcpp/konfigurasi_api.dart';
import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/services/izin_perangkat_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';

class TabAdminBerita extends StatefulWidget {
  final String usernameAdmin;
  final GlobalKey? tutorialAksiKey;

  const TabAdminBerita({
    super.key,
    required this.usernameAdmin,
    this.tutorialAksiKey,
  });

  @override
  State<TabAdminBerita> createState() => _TabAdminBeritaState();
}

class _TabAdminBeritaState extends State<TabAdminBerita> {
  final ApiApdService _api = const ApiApdService();
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  int get _totalAktif =>
      _items.where((item) => '${item['is_aktif'] ?? 0}' == '1').length;

  int get _totalNonaktif => _items.length - _totalAktif;

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
    setState(() => _loading = true);

    final response = await _api.beritaAdminList(includeNonaktif: true);
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

  Future<void> _dialogBerita({Map<String, dynamic>? item}) async {
    final isEdit = item != null;
    final judulController = TextEditingController(
      text: item?['judul']?.toString() ?? '',
    );
    final ringkasanController = TextEditingController(
      text: item?['ringkasan']?.toString() ?? '',
    );
    final isiController = TextEditingController(
      text: item?['isi']?.toString() ?? '',
    );

    String kategori = item?['kategori']?.toString() ?? 'Informasi Perusahaan';
    bool isAktif = '${item?['is_aktif'] ?? 1}' == '1';
    bool kirimNotif = !isEdit;
    File? gambarBeritaBaru;
    bool hapusGambar = false;
    final gambarLamaUrl = buildUploadUrl(item?['gambar_berita']?.toString());
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

    Future<void> submitForm(StateSetter setStateDialog) async {
      if (saving) return;

      FocusManager.instance.primaryFocus?.unfocus();
      setStateDialog(() {
        dialogError = null;
        autovalidateMode = AutovalidateMode.always;
      });

      final isValid = formKey.currentState?.validate() ?? false;
      if (!isValid) return;

      setStateDialog(() => saving = true);

      final response = await _api.beritaAdminSimpan(
        idBerita: isEdit ? '${item['id_berita']}' : null,
        judul: judulController.text.trim(),
        ringkasan: ringkasanController.text.trim(),
        isi: isiController.text.trim(),
        kategori: kategori,
        isAktif: isAktif,
        usernameAdmin: widget.usernameAdmin,
        kirimNotifikasi: kirimNotif,
        hapusGambar: hapusGambar,
        gambarBerita: gambarBeritaBaru,
      );

      if (_api.isSuccess(response)) {
        if (!mounted) return;
        Navigator.pop(context, response);
        return;
      }

      if (!mounted) return;
      setStateDialog(() {
        saving = false;
        dialogError = _api.message(response);
      });
    }

    final response = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (innerContext, setStateDialog) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: Text(isEdit ? 'Edit Berita' : 'Tambah Berita'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
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
                        'Informasi Berita',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Berita aktif akan tampil di dashboard karyawan. Tambahkan foto agar berita lebih menonjol.',
                        style: TextStyle(
                          color: TemaAplikasi.netral,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: judulController,
                        enabled: !saving,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Judul Berita',
                          prefixIcon: Icon(Icons.title_outlined),
                        ),
                        validator: (value) => validateWajib(value, 'Judul'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: ringkasanController,
                        enabled: !saving,
                        minLines: 2,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Ringkasan',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.short_text_outlined),
                        ),
                        validator: (value) => validateWajib(value, 'Ringkasan'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: isiController,
                        enabled: !saving,
                        minLines: 5,
                        maxLines: 8,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Isi Berita',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.article_outlined),
                        ),
                        validator: (value) =>
                            validateWajib(value, 'Isi berita'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: kategori,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'Keamanan APD',
                            child: Text('Keamanan APD'),
                          ),
                          DropdownMenuItem(
                            value: 'Stok APD',
                            child: Text('Stok APD'),
                          ),
                          DropdownMenuItem(
                            value: 'Informasi Perusahaan',
                            child: Text('Informasi Perusahaan'),
                          ),
                          DropdownMenuItem(
                            value: 'Pengumuman',
                            child: Text('Pengumuman'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setStateDialog(() => kategori = value);
                              },
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                          prefixIcon: Icon(Icons.label_outline),
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
                            color: TemaAplikasi.biruTua.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Foto Berita',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Opsional. Jika diisi, foto akan tampil di slider berita dan halaman detail karyawan.',
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
                                height: 180,
                                color: Colors.white,
                                child: gambarBeritaBaru != null
                                    ? Image.file(
                                        gambarBeritaBaru!,
                                        fit: BoxFit.cover,
                                      )
                                    : gambarLamaUrl.isNotEmpty && !hapusGambar
                                    ? Image.network(
                                        gambarLamaUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            size: 36,
                                            color: TemaAplikasi.netral,
                                          ),
                                        ),
                                      )
                                    : const Center(
                                        child: Icon(
                                          Icons.image_outlined,
                                          size: 40,
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
                                                context: innerContext,
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
                                          if (!innerContext.mounted || !izin) {
                                            return;
                                          }
                                          final picked = await _picker
                                              .pickImage(
                                                source: source,
                                                imageQuality: 50,
                                                maxWidth: 1024,
                                                maxHeight: 1024,
                                              );
                                          if (picked == null ||
                                              !innerContext.mounted) {
                                            return;
                                          }
                                          setStateDialog(() {
                                            gambarBeritaBaru = File(
                                              picked.path,
                                            );
                                            hapusGambar = false;
                                            dialogError = null;
                                          });
                                        },
                                  icon: const Icon(Icons.add_a_photo_outlined),
                                  label: Text(
                                    gambarBeritaBaru != null ||
                                            gambarLamaUrl.isNotEmpty
                                        ? 'Ganti Foto'
                                        : 'Pilih Foto',
                                  ),
                                ),
                                if (isEdit &&
                                    (gambarLamaUrl.isNotEmpty ||
                                        gambarBeritaBaru != null) &&
                                    !hapusGambar)
                                  TextButton.icon(
                                    onPressed: saving
                                        ? null
                                        : () {
                                            setStateDialog(() {
                                              gambarBeritaBaru = null;
                                              hapusGambar = true;
                                              dialogError = null;
                                            });
                                          },
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    label: const Text(
                                      'Hapus Foto',
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
                        child: Column(
                          children: [
                            SwitchListTile(
                              value: isAktif,
                              onChanged: saving
                                  ? null
                                  : (value) =>
                                        setStateDialog(() => isAktif = value),
                              title: const Text('Aktif (tampil ke karyawan)'),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              value: kirimNotif,
                              onChanged: saving
                                  ? null
                                  : (value) => setStateDialog(
                                      () => kirimNotif = value,
                                    ),
                              title: const Text('Kirim notifikasi ke karyawan'),
                              subtitle: const Text(
                                'Aktifkan jika berita ini perlu langsung diberitahukan.',
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: Text(saving ? 'Tutup' : 'Batal'),
              ),
              ElevatedButton(
                onPressed: saving ? null : () => submitForm(setStateDialog),
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
        ),
      ),
    );

    judulController.dispose();
    ringkasanController.dispose();
    isiController.dispose();

    if (!mounted || response == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_api.message(response))));

    if (_api.isSuccess(response)) {
      _loadData();
    }
  }

  Future<void> _hapusBerita(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Berita'),
        content: Text(
          'Yakin ingin menghapus berita "${item['judul'] ?? '-'}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: TemaAplikasi.bahaya,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final response = await _api.beritaAdminHapus('${item['id_berita']}');
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_api.message(response))));
    if (_api.isSuccess(response)) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [TemaAplikasi.biruTua, Color(0xFF173D67)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pusat Informasi Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kelola pengumuman, stok informasi, dan berita yang akan tampil ke karyawan.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _beritaStatCard(
                      icon: Icons.article_outlined,
                      title: 'Total berita',
                      value: '${_items.length}',
                    ),
                    _beritaStatCard(
                      icon: Icons.visibility_outlined,
                      title: 'Aktif',
                      value: '$_totalAktif',
                    ),
                    _beritaStatCard(
                      icon: Icons.visibility_off_outlined,
                      title: 'Nonaktif',
                      value: '$_totalNonaktif',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                KeyedSubtree(
                  key: widget.tutorialAksiKey,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Tulis berita baru',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Buat pengumuman atau pembaruan penting untuk seluruh karyawan.',
                                  style: TextStyle(
                                    color: TemaAplikasi.netral,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => _dialogBerita(),
                            icon: const Icon(Icons.add),
                            label: const Text('Tambah'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(
                  'Daftar Berita',
                  'Semua berita perusahaan tersusun berdasarkan data yang tersedia saat ini.',
                ),
                const SizedBox(height: 10),
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
                      child: Text('Belum ada berita yang dibuat.'),
                    ),
                  )
                else
                  ..._items.map((item) {
                    final aktif = '${item['is_aktif'] ?? 0}' == '1';
                    final gambarUrl = buildUploadUrl(
                      item['gambar_berita']?.toString(),
                    );
                    final tanggal = DateTime.tryParse(
                      (item['tanggal_publish']?.toString() ?? '').replaceFirst(
                        ' ',
                        'T',
                      ),
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _dialogBerita(item: item),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (gambarUrl.isNotEmpty) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 170,
                                    child: Image.network(
                                      gambarUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        color: Colors.grey.shade100,
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.broken_image_outlined,
                                          color: TemaAplikasi.netral,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['judul']?.toString() ?? '-',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _statusChip(aktif),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _metaChip(
                                    icon: Icons.label_outline,
                                    label: item['kategori']?.toString() ?? '-',
                                  ),
                                  if (tanggal != null)
                                    _metaChip(
                                      icon: Icons.event_outlined,
                                      label: DateFormat(
                                        'dd MMM yyyy',
                                      ).format(tanggal),
                                    ),
                                ],
                              ),
                              if ((item['ringkasan']?.toString() ?? '')
                                  .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    item['ringkasan']?.toString() ?? '',
                                    style: const TextStyle(
                                      color: TemaAplikasi.netral,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _dialogBerita(item: item),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Edit'),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () => _hapusBerita(item),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: TemaAplikasi.bahaya,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: TemaAplikasi.netral, height: 1.4),
        ),
      ],
    );
  }

  Widget _beritaStatCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.74),
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: TemaAplikasi.biruMuda,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: TemaAplikasi.biruTua),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: TemaAplikasi.biruTua,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(bool aktif) {
    final color = aktif ? TemaAplikasi.sukses : TemaAplikasi.netral;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        aktif ? 'Aktif' : 'Nonaktif',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
