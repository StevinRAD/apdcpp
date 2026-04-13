import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:apdcpp/konfigurasi_api.dart';
import 'package:apdcpp/karyawan/layar_form_pengajuan_apd.dart';
import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';

class LayarKatalogApdKaryawan extends StatefulWidget {
  final String username;
  final bool modePengajuan;

  const LayarKatalogApdKaryawan({
    super.key,
    required this.username,
    this.modePengajuan = false,
  });

  @override
  State<LayarKatalogApdKaryawan> createState() =>
      _LayarKatalogApdKaryawanState();
}

class _LayarKatalogApdKaryawanState extends State<LayarKatalogApdKaryawan> {
  final ApiApdService _api = const ApiApdService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  String _searchKeyword = '';
  Map<String, dynamic> _aturanPengajuan = const {};

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.modePengajuan) {
      _loadAturanPengajuan();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAturanPengajuan() async {
    final response = await _api.dashboardKaryawan(widget.username);
    if (!_api.isSuccess(response) || !mounted) return;

    final data = _api.extractMapData(response);
    final aturanRaw = data['aturan_pengajuan'];
    setState(() {
      _aturanPengajuan = aturanRaw is Map
          ? aturanRaw.map((key, value) => MapEntry('$key', value))
          : const {};
    });
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final response = await _api.daftarApd();
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

  int _cooldownHari() {
    final raw = _aturanPengajuan['cooldown_pengajuan_hari'];
    if (raw is int) return raw;
    return int.tryParse('${raw ?? 30}') ?? 30;
  }

  String _tanggalBolehAjukan() {
    final raw = _aturanPengajuan['tanggal_boleh_ajukan']?.toString() ?? '';
    if (raw.isEmpty) return '-';
    final tanggal = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (tanggal == null) return raw;
    return DateFormat('dd MMM yyyy, HH:mm').format(tanggal);
  }

  Color _warnaAturan() {
    final status = _aturanPengajuan['status']?.toString() ?? '';
    if (status == 'menunggu_proses') return Colors.blue;
    if (status == 'cooldown') return TemaAplikasi.emasTua;
    if (status == 'akun_nonaktif' || status == 'ban_sementara') {
      return TemaAplikasi.bahaya;
    }
    return TemaAplikasi.sukses;
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _items.where((item) {
      final nama = (item['nama_apd']?.toString() ?? '').toLowerCase();
      return nama.contains(_searchKeyword.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.modePengajuan ? 'Buat Pengajuan APD' : 'Katalog APD',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.modePengajuan)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _warnaAturan().withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _warnaAturan().withValues(alpha: 0.16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (_aturanPengajuan['bisa_ajukan'] == true)
                              ? 'Akun bisa mengajukan APD'
                              : 'Akun sedang dibatasi pengajuan',
                          style: TextStyle(
                            color: _warnaAturan(),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _aturanPengajuan['pesan']?.toString() ??
                              'Aturan pengajuan akun akan muncul di sini.',
                          style: const TextStyle(height: 1.45),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _KatalogChip(
                              warna: TemaAplikasi.biruTua,
                              label: _cooldownHari() == 0
                                  ? 'Tanpa masa tunggu'
                                  : 'Pending ${_cooldownHari()} hari',
                            ),
                            if ((_aturanPengajuan['tanggal_boleh_ajukan']
                                        ?.toString() ??
                                    '')
                                .isNotEmpty)
                              _KatalogChip(
                                warna: TemaAplikasi.emasTua,
                                label: 'Ajukan lagi ${_tanggalBolehAjukan()}',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (widget.modePengajuan) const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchKeyword = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Cari APD...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchKeyword.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchKeyword = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filteredItems.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(child: Text('Data APD tidak ditemukan')),
              )
            else
              ...filteredItems.map((item) {
                final stok = int.tryParse('${item['stok'] ?? 0}') ?? 0;
                final minStok = int.tryParse('${item['min_stok'] ?? 0}') ?? 0;
                final status = stok <= 0
                    ? 'Kosong'
                    : (stok <= minStok ? 'Menipis' : 'Tersedia');
                final statusColor = stok <= 0
                    ? TemaAplikasi.bahaya
                    : (stok <= minStok
                          ? TemaAplikasi.emasTua
                          : TemaAplikasi.sukses);
                final gambarUrl = buildUploadUrl(
                  item['gambar_apd']?.toString(),
                );

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 88,
                            height: 88,
                            color: Colors.grey.shade100,
                            child: gambarUrl.isEmpty
                                ? const Icon(
                                    Icons.inventory_2_outlined,
                                    color: Colors.grey,
                                    size: 36,
                                  )
                                : Image.network(
                                    gambarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.grey,
                                      size: 36,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['nama_apd']?.toString() ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _KatalogChip(
                                    warna: statusColor,
                                    label: status,
                                  ),
                                  _KatalogChip(
                                    warna: TemaAplikasi.biruTua,
                                    label:
                                        'Stok: $stok ${item['satuan'] ?? 'pcs'}',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item['deskripsi']?.toString() ?? '-',
                                style: const TextStyle(
                                  color: TemaAplikasi.teksUtama,
                                  height: 1.4,
                                ),
                              ),
                              if (widget.modePengajuan) ...[
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    onPressed:
                                        (stok <= 0 ||
                                            (_aturanPengajuan.containsKey(
                                                  'bisa_ajukan',
                                                ) &&
                                                _aturanPengajuan['bisa_ajukan'] ==
                                                    false))
                                        ? null
                                        : () async {
                                            final result =
                                                await Navigator.push<bool>(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        LayarFormPengajuanApd(
                                                          username:
                                                              widget.username,
                                                          apd: item,
                                                        ),
                                                  ),
                                                );
                                            if (result == true) {
                                              await _loadData();
                                              await _loadAturanPengajuan();
                                            }
                                          },
                                    child: const Text('Ajukan'),
                                  ),
                                ),
                              ],
                            ],
                          ),
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
}

class _KatalogChip extends StatelessWidget {
  final Color warna;
  final String label;

  const _KatalogChip({required this.warna, required this.label});

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

