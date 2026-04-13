import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/services/izin_perangkat_service.dart';

class LayarEditProfilKaryawan extends StatefulWidget {
  final String namaLengkap;
  final String username;

  const LayarEditProfilKaryawan({
    super.key,
    required this.namaLengkap,
    required this.username,
  });

  @override
  State<LayarEditProfilKaryawan> createState() =>
      _LayarEditProfilKaryawanState();
}

class _LayarEditProfilKaryawanState extends State<LayarEditProfilKaryawan> {
  late TextEditingController _namaController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _passwordBaruController;
  bool _sedangLoading = false;
  bool _isPickingImage = false;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final ApiApdService _api = const ApiApdService();

  String? _extractFotoProfil(dynamic responseData) {
    if (responseData is! Map) return null;
    final topLevelFoto = responseData['foto_profil'];
    if (topLevelFoto is String && topLevelFoto.trim().isNotEmpty) {
      return topLevelFoto;
    }
    final nestedData = responseData['data'];
    if (nestedData is Map) {
      final nestedFoto = nestedData['foto_profil'];
      if (nestedFoto is String && nestedFoto.trim().isNotEmpty) {
        return nestedFoto;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.namaLengkap);
    _usernameController = TextEditingController(text: widget.username);
    _passwordController = TextEditingController();
    _passwordBaruController = TextEditingController();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordBaruController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return;

    setState(() {
      _isPickingImage = true;
    });

    try {
      final izin = await IzinPerangkatService.pastikanAksesGaleri(context);
      if (!mounted || !izin) {
        if (mounted) {
          setState(() => _isPickingImage = false);
        }
        return;
      }

      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 960,
        maxHeight: 960,
      );
      if (pickedFile != null && mounted) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memilih gambar. Coba lagi.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  Future<void> _prosesEditProfil() async {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan password untuk konfirmasi!')),
      );
      return;
    }

    setState(() {
      _sedangLoading = true;
    });

    try {
      final data = await _api.editProfilKaryawan(
        usernameLama: widget.username,
        usernameBaru: _usernameController.text.trim(),
        namaLengkap: _namaController.text.trim(),
        password: _passwordController.text,
        passwordBaru: _passwordBaruController.text.trim().isEmpty
            ? null
            : _passwordBaruController.text.trim(),
        fotoProfil: _imageFile,
      );

      if (_api.isSuccess(data)) {
        final fotoProfilBaru = _extractFotoProfil(data);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_api.message(data))));
          Navigator.pop(context, {
            'namaLengkap': _namaController.text,
            'username': _usernameController.text,
            'fotoProfil': fotoProfilBaru ?? '',
            'profilDiperbarui': true,
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_api.message(data))));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terjadi kesalahan jaringan/server')),
        );
      }
    }

    if (mounted) {
      setState(() {
        _sedangLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: const Color(0xFFD2A92B),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Edit Profil',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 24),
                ],
              ),
            ),
            const SizedBox(height: 25),
            GestureDetector(
              onTap: _isPickingImage ? null : _pickImage,
              child: Opacity(
                opacity: _isPickingImage ? 0.5 : 1.0,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _imageFile != null
                      ? FileImage(_imageFile!)
                      : null,
                  child: _imageFile == null
                      ? _isPickingImage
                            ? const SizedBox(
                                width: 50,
                                height: 50,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.grey,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                size: 40,
                                color: Colors.grey,
                              )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Ketuk untuk mengubah foto",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 25),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nama Lengkap',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _namaController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(
                        Icons.person,
                        color: Color(0xFFD2A92B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Username',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(
                        Icons.account_circle,
                        color: Color(0xFFD2A92B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Password Saat Ini',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Masukkan password untuk konfirmasi',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(
                        Icons.lock,
                        color: Color(0xFFD2A92B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Password Baru (Opsional)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordBaruController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Biarkan kosong jika tidak diubah',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Color(0xFFD2A92B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD2A92B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _sedangLoading ? null : _prosesEditProfil,
                      child: _sedangLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Simpan Perubahan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
