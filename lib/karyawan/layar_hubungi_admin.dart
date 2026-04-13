import 'package:flutter/material.dart';

import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';

class LayarHubungiAdmin extends StatefulWidget {
  final String usernameAwal;

  const LayarHubungiAdmin({super.key, this.usernameAwal = ''});

  @override
  State<LayarHubungiAdmin> createState() => _LayarHubungiAdminState();
}

class _LayarHubungiAdminState extends State<LayarHubungiAdmin> {
  final ApiApdService _api = const ApiApdService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _usernameController;
  final _namaController = TextEditingController();
  final _passwordController = TextEditingController();
  final _alasanController = TextEditingController();

  bool _sedangLoading = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.usernameAwal);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _namaController.dispose();
    _passwordController.dispose();
    _alasanController.dispose();
    super.dispose();
  }

  Future<void> _kirimPesan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sedangLoading = true);

    final response = await _api.kirimBantuanLogin(
      username: _usernameController.text.trim(),
      namaLengkap: _namaController.text.trim(),
      passwordDiingat: _passwordController.text.trim(),
      alasanKendala: _alasanController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _sedangLoading = false);

    if (_api.isSuccess(response)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_api.message(response)),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_api.message(response)),
          backgroundColor: TemaAplikasi.bahaya,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Hubungi Admin'),
        backgroundColor: Colors.white,
        foregroundColor: TemaAplikasi.biruTua,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TemaAplikasi.emas.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: TemaAplikasi.emas.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_person, color: TemaAplikasi.emasTua),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Akun Anda dikunci karena terlalu banyak percobaan masuk yang salah. Silakan isi form di bawah ini agar Admin dapat membantu mereset atau mengaktifkan kembali akun Anda.',
                        style: TextStyle(
                          height: 1.4,
                          color: TemaAplikasi.teksUtama,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Data Akun',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: TemaAplikasi.biruTua,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'Username yang terkunci',
                  prefixIcon: const Icon(Icons.person_off_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: Colors.grey.withValues(alpha: 0.15),
                ),
                style: const TextStyle(color: TemaAplikasi.netral),
                validator: (val) => val == null || val.isEmpty
                    ? 'Username tidak boleh kosong'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _namaController,
                decoration: InputDecoration(
                  labelText: 'Nama Lengkap',
                  hintText: 'Masukkan nama lengkap Anda',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (val) => val == null || val.isEmpty
                    ? 'Nama lengkap tidak boleh kosong'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password yang Diingat',
                  hintText: 'Ketik sandi terakhir yang Anda ingat',
                  prefixIcon: const Icon(Icons.key_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (val) => val == null || val.isEmpty
                    ? 'Password tidak boleh kosong'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _alasanController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Keterangan/Alasan',
                  hintText:
                      'Jelaskan bahwa akun Anda dinonaktifkan karena lupa sandi...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (val) => val == null || val.isEmpty
                    ? 'Keterangan tidak boleh kosong'
                    : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sedangLoading ? null : _kirimPesan,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _sedangLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Kirim Pesan ke Admin',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

