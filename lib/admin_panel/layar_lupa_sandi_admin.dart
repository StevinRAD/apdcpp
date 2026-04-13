import 'package:flutter/material.dart';
import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';

class LayarLupaSandiAdmin extends StatefulWidget {
  final String username;

  const LayarLupaSandiAdmin({super.key, required this.username});

  @override
  State<LayarLupaSandiAdmin> createState() => _LayarLupaSandiAdminState();
}

class _LayarLupaSandiAdminState extends State<LayarLupaSandiAdmin> {
  final ApiApdService _api = const ApiApdService();
  bool _loading = false;
  int _step =
      0; // 0: loading metode, 1: pilih metode, 2: input kode, 3: input pertanyaan, 4: ganti password

  bool _punyaKode = false;
  bool _punyaPertanyaan = false;

  String _p1 = '';
  String _p2 = '';
  String _p3 = '';

  final TextEditingController _kodeController = TextEditingController();
  final TextEditingController _j1Controller = TextEditingController();
  final TextEditingController _j2Controller = TextEditingController();
  final TextEditingController _j3Controller = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController =
      TextEditingController();

  bool _sembunyikanSandi1 = true;
  bool _sembunyikanSandi2 = true;

  @override
  void initState() {
    super.initState();
    if (widget.username.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Username kosong. Silakan kembali dan isi username terlebih dahulu.',
            ),
          ),
        );
      });
    } else {
      _cekMetode();
    }
  }

  Future<void> _cekMetode() async {
    setState(() => _loading = true);
    final response = await _api.lupaSandiAdminCekMetode(widget.username);
    if (!mounted) return;
    setState(() => _loading = false);

    if (_api.isSuccess(response)) {
      final data = _api.extractMapData(response);
      _punyaKode = data['punya_kode'] == true;
      _punyaPertanyaan = data['punya_pertanyaan'] == true;
      _p1 = data['pertanyaan_1']?.toString() ?? '';
      _p2 = data['pertanyaan_2']?.toString() ?? '';
      _p3 = data['pertanyaan_3']?.toString() ?? '';

      if (!_punyaKode && !_punyaPertanyaan) {
        _tampilkanPesanError(
          'Akun ini belum mengatur metode pemulihan profil. Hubungi Super Admin.',
        );
      } else {
        setState(() => _step = 1);
      }
    } else {
      _tampilkanPesanError(_api.message(response));
    }
  }

  Future<void> _verifikasiKode() async {
    final kode = _kodeController.text.trim();
    if (kode.isEmpty) {
      _tampilkanPesanError('Masukkan kode numerik');
      return;
    }
    setState(() => _loading = true);
    final response = await _api.lupaSandiAdminVerifikasiKode(
      widget.username,
      kode,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (_api.isSuccess(response)) {
      setState(() => _step = 4);
    } else {
      _tampilkanPesanError(_api.message(response));
    }
  }

  Future<void> _verifikasiPertanyaan() async {
    final j1 = _j1Controller.text.trim();
    final j2 = _j2Controller.text.trim();
    final j3 = _j3Controller.text.trim();
    if (j1.isEmpty || j2.isEmpty || j3.isEmpty) {
      _tampilkanPesanError('Semua jawaban wajib diisi');
      return;
    }
    setState(() => _loading = true);
    final response = await _api.lupaSandiAdminVerifikasiPertanyaan(
      widget.username,
      j1,
      j2,
      j3,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (_api.isSuccess(response)) {
      setState(() => _step = 4);
    } else {
      _tampilkanPesanError(_api.message(response));
    }
  }

  Future<void> _gantiPassword() async {
    final pass = _passwordController.text.trim();
    final pass2 = _passwordConfirmController.text.trim();

    if (pass.isEmpty || pass2.isEmpty) {
      _tampilkanPesanError('Password tidak boleh kosong');
      return;
    }
    if (pass != pass2) {
      _tampilkanPesanError('Konfirmasi password tidak cocok');
      return;
    }

    setState(() => _loading = true);
    final response = await _api.lupaSandiAdminGantiPassword(
      widget.username,
      pass,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (_api.isSuccess(response)) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Berhasil'),
          content: const Text(
            'Password berhasil diubah. Silakan login menggunakan password baru Anda.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(
                  context,
                  true,
                ); // Kembali ke halaman login admin dengan result true
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      _tampilkanPesanError(_api.message(response));
    }
  }

  void _tampilkanPesanError(String pesan) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lupa Sandi Admin')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: TextEditingController(text: widget.username),
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  filled: true,
                  prefixIcon: Icon(Icons.person_off_outlined),
                ),
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              if (_loading && _step == 0)
                const Center(child: CircularProgressIndicator()),
              if (_step == 0 && !_loading)
                const Text(
                  'Mengecek metode pemulihan...',
                  style: TextStyle(color: Colors.grey),
                ),
              if (_step == 1) ..._buildPilihMetode(),
              if (_step == 2) ..._buildInputKode(),
              if (_step == 3) ..._buildInputPertanyaan(),
              if (_step == 4) ..._buildGantiPassword(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPilihMetode() {
    return [
      const Text(
        'Pilih Metode Pemulihan',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'Pilih salah satu metode yang telah Anda atur sebelumnya.',
        style: TextStyle(color: Colors.grey),
      ),
      const SizedBox(height: 24),
      if (_punyaKode)
        ElevatedButton.icon(
          onPressed: () => setState(() => _step = 2),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
          icon: const Icon(Icons.pin_outlined),
          label: const Text('Gunakan Kode Numerik'),
        ),
      if (_punyaKode && _punyaPertanyaan) const SizedBox(height: 12),
      if (_punyaPertanyaan)
        ElevatedButton.icon(
          onPressed: () => setState(() => _step = 3),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            backgroundColor: TemaAplikasi.biruTua,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.question_answer_outlined),
          label: const Text('Jawab Pertanyaan Keamanan'),
        ),
    ];
  }

  List<Widget> _buildInputKode() {
    return [
      const Text(
        'Masukkan Kode Numerik',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'Masukkan kode numerik yang Anda simpan sebelumnya.',
        style: TextStyle(color: Colors.grey),
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _kodeController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Kode Numerik',
          prefixIcon: Icon(Icons.password),
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loading ? null : _verifikasiKode,
          child: _loading
              ? const CircularProgressIndicator()
              : const Text('Verifikasi'),
        ),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => setState(() => _step = 1),
        child: const Text('Kembali ke pilihan metode'),
      ),
    ];
  }

  List<Widget> _buildInputPertanyaan() {
    return [
      const Text(
        'Jawab Pertanyaan Keamanan',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
      Text(_p1, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      TextField(
        controller: _j1Controller,
        decoration: const InputDecoration(
          labelText: 'Jawaban 1',
          isDense: true,
        ),
      ),
      const SizedBox(height: 16),
      Text(_p2, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      TextField(
        controller: _j2Controller,
        decoration: const InputDecoration(
          labelText: 'Jawaban 2',
          isDense: true,
        ),
      ),
      const SizedBox(height: 16),
      Text(_p3, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      TextField(
        controller: _j3Controller,
        decoration: const InputDecoration(
          labelText: 'Jawaban 3',
          isDense: true,
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loading ? null : _verifikasiPertanyaan,
          child: _loading
              ? const CircularProgressIndicator()
              : const Text('Verifikasi Jawaban'),
        ),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => setState(() => _step = 1),
        child: const Text('Kembali ke pilihan metode'),
      ),
    ];
  }

  List<Widget> _buildGantiPassword() {
    return [
      const Text(
        'Masukkan Password Baru',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'Verifikasi berhasil. Silakan buat password baru Anda.',
        style: TextStyle(color: Colors.green),
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _passwordController,
        obscureText: _sembunyikanSandi1,
        decoration: InputDecoration(
          labelText: 'Password Baru',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(
              _sembunyikanSandi1 ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () =>
                setState(() => _sembunyikanSandi1 = !_sembunyikanSandi1),
          ),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _passwordConfirmController,
        obscureText: _sembunyikanSandi2,
        decoration: InputDecoration(
          labelText: 'Ulangi Password Baru',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(
              _sembunyikanSandi2 ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () =>
                setState(() => _sembunyikanSandi2 = !_sembunyikanSandi2),
          ),
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loading ? null : _gantiPassword,
          child: _loading
              ? const CircularProgressIndicator()
              : const Text('Simpan Password Baru'),
        ),
      ),
    ];
  }
}
