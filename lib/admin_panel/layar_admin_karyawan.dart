import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';
import 'package:apdcpp/konfigurasi_api.dart';

class TabAdminKaryawan extends StatefulWidget {
  final GlobalKey? tutorialAksiKey;

  const TabAdminKaryawan({super.key, this.tutorialAksiKey});

  @override
  State<TabAdminKaryawan> createState() => _TabAdminKaryawanState();
}

class _TabAdminKaryawanState extends State<TabAdminKaryawan> {
  final ApiApdService _api = const ApiApdService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z0-9]+$');

  bool _loading = true;
  bool _syncing = false;
  String _keyword = '';
  String? _deletingKaryawanId;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool preserveVisibleData = false}) async {
    final keepVisibleData = preserveVisibleData && _items.isNotEmpty;
    setState(() {
      _loading = !keepVisibleData;
      _syncing = keepVisibleData;
    });

    final response = await _api.karyawanAdminList();
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_api.message(response))));
  }

  void _resetPencarian() {
    if (_keyword.isEmpty && _searchController.text.isEmpty) {
      return;
    }

    _searchController.clear();
    _keyword = '';
  }

  void _scrollKeAtas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _terapkanKaryawanTersimpan(Map<String, dynamic> response) {
    final dataBaru = _api.extractMapData(response);
    if (dataBaru.isEmpty) {
      _loadData(preserveVisibleData: true);
      return;
    }

    setState(() {
      _resetPencarian();
      final itemsBaru = List<Map<String, dynamic>>.from(_items);
      final idBaru = dataBaru['id']?.toString() ?? '';
      final indexLama = itemsBaru.indexWhere(
        (item) => (item['id']?.toString() ?? '') == idBaru,
      );

      if (indexLama >= 0) {
        final itemLama = itemsBaru.removeAt(indexLama);
        itemsBaru.insert(0, {...itemLama, ...dataBaru});
      } else {
        itemsBaru.insert(0, dataBaru);
      }
      _items = itemsBaru;
    });
    _scrollKeAtas();
  }

  Future<void> _hapusKaryawan(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty || _deletingKaryawanId != null) return;

    final nama = item['nama_lengkap']?.toString().trim();
    final username = item['username']?.toString().trim();
    final label = (nama != null && nama.isNotEmpty) ? nama : '@$username';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Hapus Karyawan'),
        content: Text(
          'Hapus akun $label?\n\nSemua data karyawan, riwayat pengajuan, notifikasi, dan file terkait akan dihapus permanen dan tidak bisa dikembalikan lagi.',
        ),
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
            child: const Text('Hapus Permanen'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _deletingKaryawanId = id);
    final response = await _api.karyawanAdminHapus(id);
    if (!mounted) return;

    setState(() {
      _deletingKaryawanId = null;
      if (_api.isSuccess(response)) {
        _resetPencarian();
        _items = _items
            .where((existing) => (existing['id']?.toString() ?? '') != id)
            .toList();
      }
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_api.message(response))));

    if (!_api.isSuccess(response)) {
      return;
    }

    if (_items.isEmpty) {
      _loadData();
    }
  }

  String? _validateWajibIsi(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label wajib diisi';
    }
    return null;
  }

  String _textOrEmpty(dynamic value) => value?.toString().trim() ?? '';

  String _formatDateTimeForCompare(DateTime? value) {
    if (value == null) return '';
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(value);
  }

  String? _validateUsername(
    String? value, {
    required bool isEdit,
    required String currentId,
  }) {
    final username = value?.trim() ?? '';
    if (username.isEmpty) {
      return 'Username wajib diisi';
    }
    if (username.length < 2) {
      return 'Username minimal 2 karakter';
    }
    if (username.length > 50) {
      return 'Username maksimal 50 karakter';
    }
    if (!_usernamePattern.hasMatch(username)) {
      return 'Username hanya boleh huruf dan angka tanpa spasi atau simbol';
    }

    final normalizedUsername = username.toLowerCase();
    final sudahAda = _items.any((existing) {
      final existingId = existing['id']?.toString() ?? '';
      if (isEdit && existingId == currentId) {
        return false;
      }
      final existingUsername = (existing['username']?.toString() ?? '')
          .trim()
          .toLowerCase();
      return existingUsername == normalizedUsername;
    });

    if (sudahAda) {
      return 'Username sudah dipakai karyawan lain';
    }
    return null;
  }

  int _parseCooldownHari(dynamic value) {
    if (value == null) return 30;
    if (value is int) return value < 0 ? 0 : value;
    return int.tryParse(value.toString())?.clamp(0, 3650) ?? 30;
  }

  String? _validateCooldownHari(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Pending pengajuan wajib diisi';
    }

    final hari = int.tryParse(text);
    if (hari == null) {
      return 'Pending harus berupa angka';
    }
    if (hari < 0) {
      return 'Pending tidak boleh negatif';
    }
    if (hari > 3650) {
      return 'Pending maksimal 3650 hari';
    }
    return null;
  }

  String _cooldownLabel(Map<String, dynamic> item) {
    final hari = _parseCooldownHari(item['cooldown_pengajuan_hari']);
    if (hari == 0) return 'Tanpa masa tunggu';
    if (hari == 1) return 'Pending 1 hari';
    return 'Pending $hari hari';
  }

  Future<void> _bukaFormKaryawan({Map<String, dynamic>? item}) async {
    final isEdit = item != null;
    final currentId = item?['id']?.toString() ?? '';
    final initialBannedUntil = _parseDateTime(
      item?['banned_until']?.toString(),
    );
    final initialBannedUntilText = _formatDateTimeForCompare(
      initialBannedUntil,
    );
    final usernameController = TextEditingController(
      text: item?['username']?.toString() ?? '',
    );
    final namaController = TextEditingController(
      text: item?['nama_lengkap']?.toString() ?? '',
    );
    final passwordController = TextEditingController();
    final jabatanController = TextEditingController(
      text: item?['jabatan']?.toString() ?? '',
    );
    final departemenController = TextEditingController(
      text: item?['departemen']?.toString() ?? '',
    );
    final lokasiController = TextEditingController(
      text: item?['lokasi_kerja']?.toString() ?? '',
    );
    final cooldownController = TextEditingController(
      text: '${_parseCooldownHari(item?['cooldown_pengajuan_hari'])}',
    );

    String status = item?['status']?.toString() ?? 'aktif';
    DateTime? bannedUntil = initialBannedUntil;
    final formKey = GlobalKey<FormState>();
    AutovalidateMode autovalidateMode = AutovalidateMode.disabled;
    bool saving = false;
    String? dialogError;

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
            if (status == 'ban_sementara' && bannedUntil == null) return;
            if (isEdit && currentId.isEmpty) {
              setStateDialog(() {
                dialogError =
                    'Data karyawan tidak valid. Muat ulang daftar lalu coba lagi.';
              });
              return;
            }

            final username = usernameController.text.trim();
            final namaLengkap = namaController.text.trim();
            final jabatan = jabatanController.text.trim();
            final departemen = departemenController.text.trim();
            final lokasiKerja = lokasiController.text.trim();
            final cooldownPengajuanHari = cooldownController.text.trim();
            final passwordBaru = passwordController.text.trim();
            final bannedUntilText = _formatDateTimeForCompare(bannedUntil);

            final tidakAdaPerubahan =
                isEdit &&
                passwordBaru.isEmpty &&
                username == _textOrEmpty(item['username']) &&
                namaLengkap == _textOrEmpty(item['nama_lengkap']) &&
                jabatan == _textOrEmpty(item['jabatan']) &&
                departemen == _textOrEmpty(item['departemen']) &&
                lokasiKerja == _textOrEmpty(item['lokasi_kerja']) &&
                status ==
                    (_textOrEmpty(item['status']).isEmpty
                        ? 'aktif'
                        : _textOrEmpty(item['status'])) &&
                cooldownPengajuanHari ==
                    _parseCooldownHari(
                      item['cooldown_pengajuan_hari'],
                    ).toString() &&
                bannedUntilText == initialBannedUntilText;

            if (tidakAdaPerubahan) {
              if (!dialogCtx.mounted) return;
              Navigator.pop(dialogCtx, {
                'status': 'sukses',
                'pesan': 'Data karyawan tidak berubah',
                'data': {
                  'id': currentId,
                  'username': username,
                  'nama_lengkap': namaLengkap,
                  'jabatan': jabatan,
                  'departemen': departemen,
                  'lokasi_kerja': lokasiKerja,
                  'status': status,
                  'banned_until': bannedUntilText.isEmpty
                      ? null
                      : bannedUntilText,
                  'cooldown_pengajuan_hari':
                      int.tryParse(cooldownPengajuanHari) ??
                      _parseCooldownHari(item['cooldown_pengajuan_hari']),
                  'foto_profil': item['foto_profil'],
                },
              });
              return;
            }

            if (isEdit && passwordBaru.isNotEmpty) {
              final proceed = await showDialog<bool>(
                context: stateCtx,
                builder: (confirmCtx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Row(
                    children: const [
                      Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Ubah Password?',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                  content: const Text(
                    'Anda akan mereset dan menimpa password karyawan ini sepenuhnya.\n\nKaryawan tersebut akan membutuhkan password baru ini untuk bisa login kembali ke aplikasi.\n\nApakah Anda yakin ingin mengubah password?',
                    style: TextStyle(height: 1.4),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(confirmCtx, false),
                      child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(confirmCtx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Ya, Ubah Password'),
                    ),
                  ],
                ),
              );

              if (proceed != true) return;
            }

            setStateDialog(() => saving = true);

            final response = await _api.karyawanAdminSimpan(
              id: isEdit ? currentId : '',
              username: username,
              namaLengkap: namaLengkap,
              password: passwordBaru.isEmpty ? null : passwordBaru,
              jabatan: jabatan,
              departemen: departemen,
              lokasiKerja: lokasiKerja,
              status: status,
              cooldownPengajuanHari: cooldownPengajuanHari,
              bannedUntil: bannedUntilText,
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

          final showBannedUntilError =
              status == 'ban_sementara' &&
              bannedUntil == null &&
              autovalidateMode == AutovalidateMode.always;

          void resetDialogError() {
            if (dialogError == null) return;
            setStateDialog(() => dialogError = null);
          }

          return PopScope(
            canPop: !saving,
            child: AlertDialog(
              title: Text(isEdit ? 'Edit Data Karyawan' : 'Tambah Karyawan'),
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
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.30),
                              ),
                            ),
                            child: Text(
                              dialogError!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const Text(
                          'Data Akun Karyawan',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEdit
                              ? 'Perbarui informasi akun, status akses, dan pending pengajuan.'
                              : 'Buat akun karyawan baru dengan data kerja yang lengkap dan username unik.',
                          style: const TextStyle(
                            color: TemaAplikasi.netral,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Column(
                          children: [
                            TextFormField(
                              controller: usernameController,
                              enabled: !saving,
                              decoration: const InputDecoration(
                                labelText: 'Username',
                                helperText: 'Huruf dan angka tanpa spasi/simbol',
                                prefixIcon: Icon(Icons.alternate_email),
                              ),
                              validator: (value) => _validateUsername(
                                value,
                                isEdit: isEdit,
                                currentId: currentId,
                              ),
                              onChanged: (_) => resetDialogError(),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: namaController,
                              enabled: !saving,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Nama Lengkap',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) =>
                                  _validateWajibIsi(value, 'Nama lengkap'),
                              onChanged: (_) => resetDialogError(),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: passwordController,
                              enabled: !saving,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: isEdit
                                    ? 'Password Baru (opsional)'
                                    : 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                              ),
                              validator: (value) {
                                if (!isEdit &&
                                    (value == null || value.trim().isEmpty)) {
                                  return 'Password wajib diisi untuk karyawan baru';
                                }
                                return null;
                              },
                              onChanged: (_) => resetDialogError(),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: jabatanController.text.isNotEmpty
                                  ? jabatanController.text
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Jabatan',
                                prefixIcon: Icon(Icons.badge_outlined),
                                hintText: 'Pilih Jabatan',
                              ),
                              items: [
                                'Plant Head',
                                'Section Head Produksi',
                                'Supervisor Produksi',
                                'OP Pellet Mill',
                                'OP Pulvilizer',
                                'Mandor Packing',
                                'Section Head Maintenance',
                                'Staff Maintenance',
                                'Manager',
                                'Staff AFT',
                                'Staff PPIC',
                                'Staff QCP',
                                if (jabatanController.text.isNotEmpty &&
                                    ![
                                      'Plant Head',
                                      'Section Head Produksi',
                                      'Supervisor Produksi',
                                      'OP Pellet Mill',
                                      'OP Pulvilizer',
                                      'Mandor Packing',
                                      'Section Head Maintenance',
                                      'Staff Maintenance',
                                      'Manager',
                                      'Staff AFT',
                                      'Staff PPIC',
                                      'Staff QCP',
                                    ].contains(jabatanController.text))
                                  jabatanController.text,
                              ].map((e) {
                                return DropdownMenuItem(
                                  value: e,
                                  child: Text(e, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: saving
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        jabatanController.text = val;
                                        resetDialogError();
                                      }
                                    },
                              validator: (value) =>
                                  _validateWajibIsi(value, 'Jabatan'),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: departemenController.text.isNotEmpty
                                  ? departemenController.text
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Departemen',
                                prefixIcon: Icon(Icons.apartment_outlined),
                                hintText: 'Pilih Departemen',
                              ),
                              items: [
                                'PPIC',
                                'Produksi',
                                'Maintenance',
                                'AFT',
                                'QCP',
                                if (departemenController.text.isNotEmpty &&
                                    ![
                                      'PPIC',
                                      'Produksi',
                                      'Maintenance',
                                      'AFT',
                                      'QCP',
                                    ].contains(departemenController.text))
                                  departemenController.text,
                              ].map((e) {
                                return DropdownMenuItem(
                                  value: e,
                                  child: Text(e, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: saving
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        departemenController.text = val;
                                        resetDialogError();
                                      }
                                    },
                              validator: (value) =>
                                  _validateWajibIsi(value, 'Departemen'),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: lokasiController.text.isNotEmpty
                                  ? lokasiController.text
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Lokasi Kerja',
                                prefixIcon: Icon(Icons.place_outlined),
                                hintText: 'Pilih lokasi',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: 'Plan CPP Amplas',
                                  child: Text('Plan CPP Amplas'),
                                ),
                                const DropdownMenuItem(
                                  value: 'Plan CPP KIM',
                                  child: Text('Plan CPP KIM'),
                                ),
                                if (lokasiController.text.isNotEmpty &&
                                    lokasiController.text != 'Plan CPP Amplas' &&
                                    lokasiController.text != 'Plan CPP KIM')
                                  DropdownMenuItem(
                                    value: lokasiController.text,
                                    child: Text(lokasiController.text),
                                  ),
                              ],
                              onChanged: saving
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        lokasiController.text = val;
                                        resetDialogError();
                                      }
                                    },
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Lokasi kerja wajib dipilih';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: TemaAplikasi.biruMuda,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: TemaAplikasi.biruTua.withValues(alpha: 
                                0.08,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pengaturan Pending Pengajuan',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Atur pending akun ini setelah pengajuan diproses. Isi 0 jika akun boleh ajukan lagi tanpa jeda.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: TemaAplikasi.netral,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: cooldownController,
                                enabled: !saving,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Pending Pengajuan (hari)',
                                  prefixIcon: Icon(Icons.timer_outlined),
                                  suffixText: 'hari',
                                ),
                                validator: _validateCooldownHari,
                                onChanged: (_) => resetDialogError(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5EAF2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: status,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'aktif',
                                    child: Text('Aktif'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'nonaktif',
                                    child: Text('Nonaktif'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'ban_sementara',
                                    child: Text('Ban Sementara'),
                                  ),
                                ],
                                onChanged: saving
                                    ? null
                                    : (value) {
                                        if (value == null) return;
                                        setStateDialog(() {
                                          dialogError = null;
                                          status = value;
                                          if (status != 'ban_sementara') {
                                            bannedUntil = null;
                                          }
                                        });
                                      },
                                decoration: const InputDecoration(
                                  labelText: 'Status Akun',
                                  prefixIcon: Icon(Icons.shield_outlined),
                                ),
                              ),
                              if (status == 'ban_sementara') ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.18),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Akun dibatasi sementara sampai:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        bannedUntil == null
                                            ? 'Belum pilih waktu ban berakhir'
                                            : DateFormat(
                                                'dd MMM yyyy, HH:mm',
                                              ).format(bannedUntil!),
                                        style: TextStyle(
                                          color: showBannedUntilError
                                              ? Colors.red
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: saving
                                                ? null
                                                : () async {
                                                    final pickedDate =
                                                        await showDatePicker(
                                                          context: stateCtx,
                                                          initialDate:
                                                              bannedUntil ??
                                                              DateTime.now(),
                                                          firstDate:
                                                              DateTime.now(),
                                                          lastDate:
                                                              DateTime.now().add(
                                                                const Duration(
                                                                  days: 3650,
                                                                ),
                                                              ),
                                                        );
                                                    if (pickedDate == null ||
                                                        !stateCtx.mounted) {
                                                      return;
                                                    }

                                                    final pickedTime =
                                                        await showTimePicker(
                                                          context: stateCtx,
                                                          initialTime:
                                                              TimeOfDay.fromDateTime(
                                                                bannedUntil ??
                                                                    DateTime.now(),
                                                              ),
                                                        );
                                                    if (pickedTime == null ||
                                                        !stateCtx.mounted) {
                                                      return;
                                                    }

                                                    setStateDialog(() {
                                                      dialogError = null;
                                                      bannedUntil = DateTime(
                                                        pickedDate.year,
                                                        pickedDate.month,
                                                        pickedDate.day,
                                                        pickedTime.hour,
                                                        pickedTime.minute,
                                                      );
                                                    });
                                                  },
                                            icon: const Icon(
                                              Icons.event_outlined,
                                            ),
                                            label: const Text(
                                              'Pilih Tanggal & Waktu',
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed:
                                                saving || bannedUntil == null
                                                ? null
                                                : () {
                                                    setStateDialog(() {
                                                      dialogError = null;
                                                      bannedUntil = null;
                                                    });
                                                  },
                                            icon: const Icon(Icons.close),
                                            label: const Text('Reset'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (showBannedUntilError)
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: EdgeInsets.only(top: 6),
                                      child: Text(
                                        'Waktu akhir ban wajib dipilih',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
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
                      : Text(isEdit ? 'Simpan' : 'Tambah'),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Dihapus dispose() disini agar tidak menyebabkan _dependents.isEmpty crash
    // karena animasi pop out pada dialog belum selesai.
    // Local scope variable akan diurus oleh Garbage Collector.

    if (!mounted || response == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_api.message(response))));
    _terapkanKaryawanTersimpan(response);
  }

  DateTime? _parseDateTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }

  String _statusLabel(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'aktif';
    if (status == 'nonaktif') return 'Nonaktif';
    if (status == 'ban_sementara') {
      final until = _parseDateTime(item['banned_until']?.toString());
      if (until == null) return 'Ban Sementara';
      return 'Ban hingga ${DateFormat('dd/MM HH:mm').format(until)}';
    }
    return 'Aktif';
  }

  Color _statusColor(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'aktif';
    if (status == 'nonaktif') return Colors.grey;
    if (status == 'ban_sementara') return Colors.red;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where((item) {
      final keyword = _keyword.toLowerCase();
      final nama = (item['nama_lengkap']?.toString() ?? '').toLowerCase();
      final username = (item['username']?.toString() ?? '').toLowerCase();
      final jabatan = (item['jabatan']?.toString() ?? '').toLowerCase();
      return nama.contains(keyword) ||
          username.contains(keyword) ||
          jabatan.contains(keyword);
    }).toList();
    final totalAktif = _items
        .where((item) => (item['status']?.toString() ?? 'aktif') == 'aktif')
        .length;
    final totalNonaktif = _items
        .where((item) => (item['status']?.toString() ?? '') == 'nonaktif')
        .length;
    final totalBan = _items
        .where((item) => (item['status']?.toString() ?? '') == 'ban_sementara')
        .length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(),
            ),
          KeyedSubtree(
            key: widget.tutorialAksiKey,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _bukaFormKaryawan(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD2A92B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Tambah Karyawan'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _keyword = value),
                  decoration: InputDecoration(
                    hintText: 'Cari karyawan / jabatan...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _keyword.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _keyword = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.8,
            children: [
              _RingkasanKaryawanCard(
                judul: 'Total Karyawan',
                nilai: '${_items.length}',
                ikon: Icons.groups_2_outlined,
                warna: TemaAplikasi.biruTua,
              ),
              _RingkasanKaryawanCard(
                judul: 'Akun Aktif',
                nilai: '$totalAktif',
                ikon: Icons.verified_user_outlined,
                warna: TemaAplikasi.sukses,
              ),
              _RingkasanKaryawanCard(
                judul: 'Nonaktif',
                nilai: '$totalNonaktif',
                ikon: Icons.pause_circle_outline,
                warna: Colors.grey.shade700,
              ),
              _RingkasanKaryawanCard(
                judul: 'Ban Sementara',
                nilai: '$totalBan',
                ikon: Icons.shield_outlined,
                warna: TemaAplikasi.bahaya,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: Text('Data karyawan tidak ditemukan')),
            )
          else
            ...filtered.map((item) {
              final statusColor = _statusColor(item);
              final id = item['id']?.toString() ?? '';
              final isDeleting = _deletingKaryawanId == id;
              final nama = item['nama_lengkap']?.toString().trim();
              final username = item['username']?.toString().trim();
              final jabatan = item['jabatan']?.toString().trim();
              final departemen = item['departemen']?.toString().trim();
              final lokasiKerja = item['lokasi_kerja']?.toString().trim();
              final fotoProfilUrl =
                  buildUploadUrl(item['foto_profil']?.toString());

              return Card(
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: isDeleting
                      ? null
                      : () => _bukaFormKaryawan(item: item),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // FOTO PROFIL KARYAWAN
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: fotoProfilUrl.isNotEmpty
                                    ? Image.network(
                                        fotoProfilUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Icon(
                                          Icons.person,
                                          color: Colors.grey.shade400,
                                          size: 30,
                                        ),
                                      )
                                    : Icon(
                                        Icons.person,
                                        color: Colors.grey.shade400,
                                        size: 30,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (nama != null && nama.isNotEmpty)
                                        ? nama
                                        : '-',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '@${(username != null && username.isNotEmpty) ? username : '-'}',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${(jabatan != null && jabatan.isNotEmpty) ? jabatan : '-'} | ${(departemen != null && departemen.isNotEmpty) ? departemen : '-'}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: TemaAplikasi.netral,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Align(
                                alignment: Alignment.topRight,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 132,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _statusLabel(item),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Lokasi kerja: ${(lokasiKerja != null && lokasiKerja.isNotEmpty) ? lokasiKerja : '-'}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InfoKaryawanChip(
                              ikon: Icons.schedule_outlined,
                              label: _cooldownLabel(item),
                              warna: TemaAplikasi.biruTua,
                            ),
                            _InfoKaryawanChip(
                              ikon: Icons.apartment_outlined,
                              label:
                                  (departemen != null && departemen.isNotEmpty)
                                  ? departemen
                                  : 'Tanpa departemen',
                              warna: TemaAplikasi.emasTua,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            alignment: WrapAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: isDeleting
                                    ? null
                                    : () => _bukaFormKaryawan(item: item),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFD2A92B),
                                ),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const Text('Edit'),
                              ),
                              TextButton.icon(
                                onPressed: isDeleting
                                    ? null
                                    : () => _hapusKaryawan(item),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                icon: isDeleting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                      ),
                                label: const Text('Hapus'),
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
      ),
    );
  }
}

class _RingkasanKaryawanCard extends StatelessWidget {
  final String judul;
  final String nilai;
  final IconData ikon;
  final Color warna;

  const _RingkasanKaryawanCard({
    required this.judul,
    required this.nilai,
    required this.ikon,
    required this.warna,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warna.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(ikon, color: warna, size: 20),
          const SizedBox(height: 8),
          Text(
            nilai,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: warna,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            judul,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: TemaAplikasi.netral,
              fontWeight: FontWeight.w600,
              fontSize: 9.5,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoKaryawanChip extends StatelessWidget {
  final IconData ikon;
  final String label;
  final Color warna;

  const _InfoKaryawanChip({
    required this.ikon,
    required this.label,
    required this.warna,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, color: warna, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: warna,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

