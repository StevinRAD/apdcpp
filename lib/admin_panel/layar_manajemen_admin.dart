import 'package:flutter/material.dart';
import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';

class LayarManajemenAdmin extends StatefulWidget {
  const LayarManajemenAdmin({super.key});

  @override
  State<LayarManajemenAdmin> createState() => _LayarManajemenAdminState();
}

class _LayarManajemenAdminState extends State<LayarManajemenAdmin> {
  final ApiApdService _api = const ApiApdService();
  bool _loading = true;
  List<dynamic> _listAdmin = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final response = await _api.ambilAdminBiasa();
      if (!mounted) return;

      if (_api.isSuccess(response)) {
        setState(() {
          _listAdmin = _api.extractListData(response);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_api.message(response))));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan koneksi')));
    }
  }

  void _tambahAdminBaru() {
    String usernameBaru = '';
    String passwordBaru = '';
    String namaLengkapBaru = '';
    bool sedangSimpan = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text('Tambah Admin Baru'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'Username'),
                    onChanged: (val) => usernameBaru = val,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Password'),
                    onChanged: (val) => passwordBaru = val,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                    ),
                    onChanged: (val) => namaLengkapBaru = val,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: sedangSimpan ? null : () => Navigator.pop(context),
                child: const Text(
                  'Batal',
                  style: TextStyle(color: TemaAplikasi.netral),
                ),
              ),
              ElevatedButton(
                onPressed: sedangSimpan
                    ? null
                    : () async {
                        if (usernameBaru.isEmpty ||
                            passwordBaru.isEmpty ||
                            namaLengkapBaru.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Semua field harus diisi'),
                            ),
                          );
                          return;
                        }
                        setModalState(() => sedangSimpan = true);
                        final res = await _api.tambahAdmin(
                          username: usernameBaru,
                          password: passwordBaru,
                          namaLengkap: namaLengkapBaru,
                          peranAdmin: 'biasa',
                        );
                        if (!context.mounted) return;
                        setModalState(() => sedangSimpan = false);
                        if (_api.isSuccess(res)) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Admin baru berhasil ditambahkan'),
                            ),
                          );
                          _loadData(); // reload
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(_api.message(res))),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: TemaAplikasi.emas,
                  foregroundColor: Colors.white,
                ),
                child: sedangSimpan
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _kelolaStatus(Map<String, dynamic> admin) {
    bool isAktif = admin['status'] == 'aktif';
    String statusTujuan = isAktif ? 'nonaktif' : 'aktif';
    String labelTujuan = isAktif ? 'Nonaktifkan' : 'Aktifkan';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$labelTujuan Admin?'),
        content: Text(
          'Apakah Anda yakin ingin me-${statusTujuan.toLowerCase()} akun ${admin['nama_lengkap']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Batal',
              style: TextStyle(color: TemaAplikasi.netral),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _loading = true);
              final res = await _api.kelolaAdmin(
                id: admin['id'].toString(),
                action: 'nonaktif',
                statusBaru: statusTujuan,
              );
              if (!mounted) return;
              if (_api.isSuccess(res)) {
                _loadData();
              } else {
                setState(() => _loading = false);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(_api.message(res))));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isAktif
                  ? TemaAplikasi.bahaya
                  : Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text(labelTujuan),
          ),
        ],
      ),
    );
  }

  void _hapusAdmin(Map<String, dynamic> admin) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Hapus Permanen?',
          style: TextStyle(color: TemaAplikasi.bahaya),
        ),
        content: Text(
          'Anda akan menghapus admin "${admin['nama_lengkap']}". Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Batal',
              style: TextStyle(color: TemaAplikasi.netral),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _loading = true);
              final res = await _api.kelolaAdmin(
                id: admin['id'].toString(),
                action: 'hapus',
              );
              if (!mounted) return;
              if (_api.isSuccess(res)) {
                _loadData();
              } else {
                setState(() => _loading = false);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(_api.message(res))));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TemaAplikasi.bahaya,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Admin'),
        backgroundColor: TemaAplikasi.emas,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambahAdminBaru,
        backgroundColor: TemaAplikasi.emas,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _listAdmin.isEmpty
          ? const Center(child: Text('Belum ada admin lain'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _listAdmin.length,
              itemBuilder: (context, index) {
                final admin = _listAdmin[index];
                final isAktif = admin['status'] == 'aktif';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: TemaAplikasi.biruMuda,
                              child: Text(
                                admin['nama_lengkap']
                                    .toString()
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: TemaAplikasi.biruTua,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    admin['nama_lengkap'].toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '@${admin['username']}',
                                    style: const TextStyle(
                                      color: TemaAplikasi.netral,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (isAktif
                                            ? Colors.green.shade600
                                            : TemaAplikasi.bahaya)
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isAktif ? 'Aktif' : 'Nonaktif',
                                style: TextStyle(
                                  color: isAktif
                                      ? Colors.green.shade600
                                      : TemaAplikasi.bahaya,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _kelolaStatus(admin),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isAktif
                                    ? TemaAplikasi.bahaya
                                    : Colors.green.shade600,
                                side: BorderSide(
                                  color: isAktif
                                      ? TemaAplikasi.bahaya
                                      : Colors.green.shade600,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                              ),
                              icon: Icon(
                                isAktif
                                    ? Icons.block
                                    : Icons.check_circle_outline,
                                size: 18,
                              ),
                              label: Text(isAktif ? 'Nonaktifkan' : 'Aktifkan'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _hapusAdmin(admin),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: TemaAplikasi.bahaya,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                              ),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Hapus'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

