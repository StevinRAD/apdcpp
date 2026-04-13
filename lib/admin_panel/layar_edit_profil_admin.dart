import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:apdcpp/konfigurasi_api.dart';
import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/services/izin_perangkat_service.dart';

class LayarEditProfilAdmin extends StatefulWidget {
  final String username;
  final String namaLengkap;
  final String? fotoProfil;

  const LayarEditProfilAdmin({
    super.key,
    required this.username,
    required this.namaLengkap,
    this.fotoProfil,
  });

  @override
  State<LayarEditProfilAdmin> createState() => _LayarEditProfilAdminState();
}

class _LayarEditProfilAdminState extends State<LayarEditProfilAdmin> {
  final ApiApdService _api = const ApiApdService();
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _usernameController;
  late TextEditingController _namaController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordBaruController = TextEditingController();

  bool _loading = false;
  bool _pickingImage = false;

  String _usernameAwal = '';
  String _fotoProfilServer = '';
  File? _fotoBaru;

  bool _aktifkanPertanyaan = false;
  String? _p1;
  String? _p2;
  String? _p3;
  final TextEditingController _j1Controller = TextEditingController();
  final TextEditingController _j2Controller = TextEditingController();
  final TextEditingController _j3Controller = TextEditingController();

  final List<String> _daftarPertanyaan = [
    'Apa nama hewan peliharaan pertama Anda?',
    'Di kota manakah Anda dilahirkan?',
    'Siapa nama teman masa kecil Anda?',
    'Apa makanan kesukaan Anda?',
    'Siapa pahlawan idola Anda?',
  ];

  @override
  void initState() {
    super.initState();
    _usernameAwal = widget.username;
    _usernameController = TextEditingController(text: widget.username);
    _namaController = TextEditingController(text: widget.namaLengkap);
    _fotoProfilServer = widget.fotoProfil ?? '';
    _loadProfil();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _namaController.dispose();
    _passwordController.dispose();
    _passwordBaruController.dispose();
    _j1Controller.dispose();
    _j2Controller.dispose();
    _j3Controller.dispose();
    super.dispose();
  }

  Future<void> _loadProfil() async {
    final response = await _api.profilAdmin(_usernameAwal);
    if (!_api.isSuccess(response) || !mounted) return;

    final data = _api.extractMapData(response);
    setState(() {
      _usernameAwal = data['username']?.toString() ?? _usernameAwal;
      _usernameController.text = _usernameAwal;
      _namaController.text =
          data['nama_lengkap']?.toString() ?? _namaController.text;
      _fotoProfilServer = data['foto_profil']?.toString() ?? _fotoProfilServer;

      final p1 = data['pertanyaan_1']?.toString() ?? '';
      final j1 = data['jawaban_1']?.toString() ?? '';
      if (p1.isNotEmpty && j1.isNotEmpty) {
        _aktifkanPertanyaan = true;
        _p1 = _daftarPertanyaan.contains(p1) ? p1 : null;
        _p2 = _daftarPertanyaan.contains(data['pertanyaan_2']?.toString())
            ? data['pertanyaan_2'].toString()
            : null;
        _p3 = _daftarPertanyaan.contains(data['pertanyaan_3']?.toString())
            ? data['pertanyaan_3'].toString()
            : null;
        _j1Controller.text = j1;
        _j2Controller.text = data['jawaban_2']?.toString() ?? '';
        _j3Controller.text = data['jawaban_3']?.toString() ?? '';
      }
    });
  }

  Future<void> _pickImage() async {
    if (_pickingImage) return;

    setState(() => _pickingImage = true);
    try {
      final izin = await IzinPerangkatService.pastikanAksesGaleri(context);
      if (!mounted || !izin) {
        if (mounted) {
          setState(() => _pickingImage = false);
        }
        return;
      }

      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 960,
        maxHeight: 960,
      );
      if (!mounted) return;
      if (picked == null) {
        setState(() => _pickingImage = false);
        return;
      }

      setState(() {
        _fotoBaru = File(picked.path);
        _pickingImage = false;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _pickingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka galeri: ${e.message ?? e.code}')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _pickingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memilih foto profil')),
      );
    }
  }

  Future<void> _simpanProfil() async {
    if (_usernameController.text.trim().isEmpty ||
        _namaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username dan nama wajib diisi')),
      );
      return;
    }

    if (_passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password saat ini wajib diisi')),
      );
      return;
    }

    if (_aktifkanPertanyaan) {
      if (_p1 == null || _p2 == null || _p3 == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih ketiga pertanyaan keamanan')),
        );
        return;
      }
      if (_j1Controller.text.trim().isEmpty ||
          _j2Controller.text.trim().isEmpty ||
          _j3Controller.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Semua jawaban keamanan wajib diisi')),
        );
        return;
      }
    }

    setState(() => _loading = true);

    final response = await _api.editProfilAdmin(
      usernameLama: _usernameAwal,
      usernameBaru: _usernameController.text.trim(),
      namaLengkap: _namaController.text.trim(),
      password: _passwordController.text.trim(),
      passwordBaru: _passwordBaruController.text.trim(),
      fotoProfil: _fotoBaru,
      pertanyaan1: _aktifkanPertanyaan ? _p1 : null,
      jawaban1: _aktifkanPertanyaan ? _j1Controller.text.trim() : null,
      pertanyaan2: _aktifkanPertanyaan ? _p2 : null,
      jawaban2: _aktifkanPertanyaan ? _j2Controller.text.trim() : null,
      pertanyaan3: _aktifkanPertanyaan ? _p3 : null,
      jawaban3: _aktifkanPertanyaan ? _j3Controller.text.trim() : null,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_api.message(response))));

    if (_api.isSuccess(response)) {
      final data = _api.extractMapData(response);
      Navigator.pop(context, {
        'username':
            data['username']?.toString() ?? _usernameController.text.trim(),
        'nama_lengkap':
            data['nama_lengkap']?.toString() ?? _namaController.text.trim(),
        'foto_profil': data['foto_profil']?.toString() ?? _fotoProfilServer,
      });
    }
  }

  Future<void> _generateKodeNumerik() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username wajib diisi untuk membuat kode'),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    final response = await _api.generateKodePemulihanAdmin(username);
    if (!mounted) return;
    setState(() => _loading = false);

    if (_api.isSuccess(response)) {
      final code = _api.extractMapData(response)['kode_numerik'];
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Kode Numerik Keamanan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Simpan kode di bawah ini baik-baik. Kode ini akan digunakan jika Anda lupa sandi admin:',
                style: TextStyle(height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      code.toString(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.blueGrey),
                      tooltip: 'Salin Kode',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code.toString()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Kode berhasil disalin'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
              },
              child: const Text('Saya Sudah Menyimpannya'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_api.message(response))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fotoUrl = buildUploadUrl(_fotoProfilServer);
    final ImageProvider<Object>? imageProvider = _fotoBaru != null
        ? FileImage(_fotoBaru!)
        : (fotoUrl.isEmpty ? null : NetworkImage(fotoUrl));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profil Admin'),
        backgroundColor: const Color(0xFFD2A92B),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickingImage ? null : _pickImage,
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: const Color(0xFFD2A92B),
                      backgroundImage: imageProvider,
                      child: (_fotoBaru == null && fotoUrl.isEmpty)
                          ? const Icon(
                              Icons.person,
                              size: 45,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _pickingImage
                        ? 'Membuka galeri...'
                        : 'Tap foto untuk ganti foto profil',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _namaController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Admin',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password Saat Ini',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passwordBaruController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password Baru (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Catatan: Kode Numerik WAJIB dibuat dan disimpan agar Anda dapat mereset sandi jika lupa.',
                          style: TextStyle(
                            color: Colors.brown,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _generateKodeNumerik,
                            icon: const Icon(Icons.pin_outlined),
                            label: const Text('Buat Kode Numerik Pemulihan'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    title: const Text(
                      'Aktifkan Pertanyaan Keamanan',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Opsi pemulihan sandi via pertanyaan'),
                    value: _aktifkanPertanyaan,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() {
                        _aktifkanPertanyaan = val;
                      });
                    },
                  ),
                  if (_aktifkanPertanyaan) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _p1,
                      isExpanded: true,
                      hint: const Text('Pilih Pertanyaan 1'),
                      items: _daftarPertanyaan
                          .map(
                            (x) => DropdownMenuItem(value: x, child: Text(x)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _p1 = val),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _j1Controller,
                      decoration: const InputDecoration(
                        labelText: 'Jawaban Pertanyaan 1',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _p2,
                      isExpanded: true,
                      hint: const Text('Pilih Pertanyaan 2'),
                      items: _daftarPertanyaan
                          .map(
                            (x) => DropdownMenuItem(value: x, child: Text(x)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _p2 = val),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _j2Controller,
                      decoration: const InputDecoration(
                        labelText: 'Jawaban Pertanyaan 2',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _p3,
                      isExpanded: true,
                      hint: const Text('Pilih Pertanyaan 3'),
                      items: _daftarPertanyaan
                          .map(
                            (x) => DropdownMenuItem(value: x, child: Text(x)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _p3 = val),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _j3Controller,
                      decoration: const InputDecoration(
                        labelText: 'Jawaban Pertanyaan 3',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _simpanProfil,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD2A92B),
                        foregroundColor: Colors.white,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Simpan Perubahan'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
