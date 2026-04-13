import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:apdcpp/services/apd_api_service.dart';
import 'package:apdcpp/tema_aplikasi.dart';

class TabAdminKalender extends StatefulWidget {
  final String usernameAdmin;
  final GlobalKey? tutorialKalenderKey;

  const TabAdminKalender({
    super.key,
    required this.usernameAdmin,
    this.tutorialKalenderKey,
  });

  @override
  State<TabAdminKalender> createState() => _TabAdminKalenderState();
}

class _TabAdminKalenderState extends State<TabAdminKalender>
    with SingleTickerProviderStateMixin {
  final ApiApdService _api = const ApiApdService();

  late TabController _tabController;
  bool _loadingCompany = true;
  List<Map<String, dynamic>> _companyItems = [];
  List<Map<String, dynamic>> _privateItems = [];

  String get _privateStorageKey => 'jadwal_admin_${widget.usernameAdmin}';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCompanyAgenda();
    _loadPrivateAgenda();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanyAgenda() async {
    setState(() => _loadingCompany = true);

    final response = await _api.kalenderPerusahaanAdminList(
      includeNonaktif: true,
    );
    if (!mounted) return;

    if (_api.isSuccess(response)) {
      setState(() {
        _companyItems = _api.extractListData(response);
        _loadingCompany = false;
      });
      return;
    }

    setState(() {
      _companyItems = [];
      _loadingCompany = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_api.message(response))));
  }

  Future<void> _loadPrivateAgenda() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_privateStorageKey);

    if (raw == null || raw.trim().isEmpty) {
      setState(() => _privateItems = []);
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      setState(() {
        _privateItems =
            decoded
                .whereType<Map>()
                .map((e) => e.map((key, value) => MapEntry('$key', value)))
                .toList()
              ..sort(
                (a, b) => (a['start']?.toString() ?? '').compareTo(
                  b['start']?.toString() ?? '',
                ),
              );
      });
    } catch (_) {
      setState(() => _privateItems = []);
    }
  }

  Future<void> _savePrivateAgenda() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_privateStorageKey, jsonEncode(_privateItems));
  }

  Future<void> _dialogAgendaPerusahaan({Map<String, dynamic>? item}) async {
    final isEdit = item != null;

    final judulController = TextEditingController(
      text: item?['judul']?.toString() ?? '',
    );
    final keteranganController = TextEditingController(
      text: item?['keterangan']?.toString() ?? '',
    );

    DateTime tanggal =
        _parseDate(item?['tanggal']?.toString()) ?? DateTime.now();
    TimeOfDay? jamMulai = _parseTime(item?['jam_mulai']?.toString());
    TimeOfDay? jamSelesai = _parseTime(item?['jam_selesai']?.toString());
    bool isLibur = '${item?['is_libur'] ?? 0}' == '1';
    bool isAktif = '${item?['is_aktif'] ?? 1}' == '1';
    bool kirimNotifikasi = true;

    final submit = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(isEdit ? 'Edit Agenda Perusahaan' : 'Tambah Agenda'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: judulController,
                  decoration: const InputDecoration(labelText: 'Judul Agenda'),
                ),
                TextField(
                  controller: keteranganController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Keterangan'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: tanggal,
                            firstDate: DateTime(2020, 1, 1),
                            lastDate: DateTime(2100, 12, 31),
                          );
                          if (picked != null) {
                            setStateDialog(() => tanggal = picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_month),
                        label: Text(DateFormat('dd/MM/yyyy').format(tanggal)),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime:
                                jamMulai ?? const TimeOfDay(hour: 8, minute: 0),
                          );
                          if (picked != null) {
                            setStateDialog(() => jamMulai = picked);
                          }
                        },
                        child: Text(
                          jamMulai == null
                              ? 'Jam Mulai'
                              : jamMulai!.format(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime:
                                jamSelesai ??
                                const TimeOfDay(hour: 9, minute: 0),
                          );
                          if (picked != null) {
                            setStateDialog(() => jamSelesai = picked);
                          }
                        },
                        child: Text(
                          jamSelesai == null
                              ? 'Jam Selesai'
                              : jamSelesai!.format(context),
                        ),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  value: isLibur,
                  onChanged: (value) => setStateDialog(() => isLibur = value),
                  title: const Text('Agenda Libur'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  value: isAktif,
                  onChanged: (value) => setStateDialog(() => isAktif = value),
                  title: const Text('Aktif (masuk kalender karyawan)'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  value: kirimNotifikasi,
                  onChanged: (value) =>
                      setStateDialog(() => kirimNotifikasi = value),
                  title: const Text('Kirim notifikasi karyawan'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD2A92B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (submit != true || !mounted) return;

    if (judulController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Judul agenda wajib diisi')));
      return;
    }

    final response = await _api.kalenderPerusahaanAdminSimpan(
      id: isEdit ? '${item['id']}' : null,
      tanggal: DateFormat('yyyy-MM-dd').format(tanggal),
      jamMulai: jamMulai == null ? '' : _timeOfDayTo24h(jamMulai!),
      jamSelesai: jamSelesai == null ? '' : _timeOfDayTo24h(jamSelesai!),
      judul: judulController.text.trim(),
      keterangan: keteranganController.text.trim(),
      isLibur: isLibur,
      isAktif: isAktif,
      kirimNotifikasi: kirimNotifikasi,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_api.message(response))));

    if (_api.isSuccess(response)) {
      _loadCompanyAgenda();
    }
  }

  Future<void> _hapusAgendaPerusahaan(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Agenda'),
        content: Text('Hapus agenda "${item['judul'] ?? '-'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
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
    final response = await _api.kalenderPerusahaanAdminHapus('${item['id']}');

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_api.message(response))));
    if (_api.isSuccess(response)) {
      _loadCompanyAgenda();
    }
  }

  Future<void> _dialogAgendaPribadi({Map<String, dynamic>? item}) async {
    final isEdit = item != null;
    final judulController = TextEditingController(
      text: item?['title']?.toString() ?? '',
    );
    final deskripsiController = TextEditingController(
      text: item?['description']?.toString() ?? '',
    );

    DateTime start =
        _parseDateTime(item?['start']?.toString()) ?? DateTime.now();
    DateTime end =
        _parseDateTime(item?['end']?.toString()) ??
        DateTime.now().add(const Duration(hours: 1));

    final submit = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(isEdit ? 'Edit Jadwal Pribadi' : 'Tambah Jadwal Pribadi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: judulController,
                  decoration: const InputDecoration(labelText: 'Judul'),
                ),
                TextField(
                  controller: deskripsiController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Deskripsi'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: start,
                            firstDate: DateTime(2020, 1, 1),
                            lastDate: DateTime(2100, 12, 31),
                          );
                          if (date == null || !context.mounted) return;
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(start),
                          );
                          if (time == null) return;

                          setStateDialog(() {
                            start = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                            if (!end.isAfter(start)) {
                              end = start.add(const Duration(hours: 1));
                            }
                          });
                        },
                        child: Text(DateFormat('dd/MM HH:mm').format(start)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: end,
                            firstDate: DateTime(2020, 1, 1),
                            lastDate: DateTime(2100, 12, 31),
                          );
                          if (date == null || !context.mounted) return;
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(end),
                          );
                          if (time == null) return;

                          setStateDialog(() {
                            end = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        },
                        child: Text(DateFormat('dd/MM HH:mm').format(end)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD2A92B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (submit != true || !mounted) return;

    if (judulController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Judul wajib diisi')));
      return;
    }

    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waktu selesai harus setelah waktu mulai'),
        ),
      );
      return;
    }

    final event = {
      'id': isEdit
          ? item['id']
          : 'adm_${DateTime.now().microsecondsSinceEpoch}',
      'title': judulController.text.trim(),
      'description': deskripsiController.text.trim(),
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
    };

    setState(() {
      if (isEdit) {
        final index = _privateItems.indexWhere((e) => e['id'] == item['id']);
        if (index >= 0) {
          _privateItems[index] = event;
        }
      } else {
        _privateItems.add(event);
      }
      _privateItems.sort(
        (a, b) => (a['start']?.toString() ?? '').compareTo(
          b['start']?.toString() ?? '',
        ),
      );
    });

    await _savePrivateAgenda();
  }

  Future<void> _hapusAgendaPribadi(Map<String, dynamic> item) async {
    setState(() {
      _privateItems.removeWhere((e) => e['id'] == item['id']);
    });
    await _savePrivateAgenda();
  }

  @override
  Widget build(BuildContext context) {
    final totalAgendaAktif = _companyItems
        .where((item) => '${item['is_aktif'] ?? 0}' == '1')
        .length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [TemaAplikasi.biruTua, Color(0xFF173D67)],
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kalender Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kelola agenda perusahaan dan jadwal pribadi dari satu tampilan operasional.',
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
                        _headerPill(
                          icon: Icons.apartment_outlined,
                          label: '${_companyItems.length} agenda perusahaan',
                        ),
                        _headerPill(
                          icon: Icons.event_available_outlined,
                          label: '$totalAgendaAktif agenda aktif',
                        ),
                        _headerPill(
                          icon: Icons.person_outline,
                          label: '${_privateItems.length} jadwal pribadi',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              KeyedSubtree(
                key: widget.tutorialKalenderKey,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFD9E2EE)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: TemaAplikasi.emas,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: TemaAplikasi.biruTua,
                    tabs: const [
                      Tab(text: 'Perusahaan'),
                      Tab(text: 'Jadwal Admin'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildCompanyAgenda(), _buildPrivateAgenda()],
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyAgenda() {
    return RefreshIndicator(
      onRefresh: _loadCompanyAgenda,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Agenda Perusahaan',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Agenda aktif akan terlihat juga oleh karyawan pada kalender aplikasi.',
                    style: TextStyle(color: TemaAplikasi.netral, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _dialogAgendaPerusahaan(),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Agenda Perusahaan'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingCompany)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_companyItems.isEmpty)
            _emptyStateCard('Belum ada agenda perusahaan yang tersimpan.')
          else
            ..._companyItems.map((item) {
              final tanggal = _parseDate(item['tanggal']?.toString());
              final jamMulai = item['jam_mulai']?.toString() ?? '';
              final jamSelesai = item['jam_selesai']?.toString() ?? '';
              final aktif = '${item['is_aktif'] ?? 0}' == '1';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _dialogAgendaPerusahaan(item: item),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                            _statusAgendaChip(aktif),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _metaAgendaChip(
                              icon: Icons.event_outlined,
                              label: tanggal == null
                                  ? '-'
                                  : DateFormat('dd MMM yyyy').format(tanggal),
                            ),
                            if (jamMulai.isNotEmpty)
                              _metaAgendaChip(
                                icon: Icons.schedule_outlined,
                                label: jamSelesai.isEmpty
                                    ? jamMulai
                                    : '$jamMulai - $jamSelesai',
                              ),
                          ],
                        ),
                        if ((item['keterangan']?.toString() ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              item['keterangan']?.toString() ?? '',
                              style: const TextStyle(
                                color: TemaAplikasi.netral,
                                height: 1.45,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            onPressed: () => _hapusAgendaPerusahaan(item),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: TemaAplikasi.bahaya,
                            ),
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

  Widget _buildPrivateAgenda() {
    return RefreshIndicator(
      onRefresh: _loadPrivateAgenda,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Jadwal Pribadi Admin',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Catat pengingat pribadi agar agenda internal dan agenda personal tetap terpisah rapi.',
                    style: TextStyle(color: TemaAplikasi.netral, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _dialogAgendaPribadi(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TemaAplikasi.biruTua,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Jadwal Pribadi Admin'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_privateItems.isEmpty)
            _emptyStateCard('Belum ada jadwal pribadi admin.')
          else
            ..._privateItems.map((item) {
              final start = _parseDateTime(item['start']?.toString());
              final end = _parseDateTime(item['end']?.toString());

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _dialogAgendaPribadi(item: item),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title']?.toString() ?? '-',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _metaAgendaChip(
                              icon: Icons.event_outlined,
                              label: start == null
                                  ? '-'
                                  : DateFormat('dd MMM yyyy').format(start),
                            ),
                            if (start != null)
                              _metaAgendaChip(
                                icon: Icons.schedule_outlined,
                                label: end == null
                                    ? DateFormat('HH:mm').format(start)
                                    : '${DateFormat('HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}',
                              ),
                          ],
                        ),
                        if ((item['description']?.toString() ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              item['description']?.toString() ?? '',
                              style: const TextStyle(
                                color: TemaAplikasi.netral,
                                height: 1.45,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            onPressed: () => _hapusAgendaPribadi(item),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: TemaAplikasi.bahaya,
                            ),
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

  Widget _headerPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusAgendaChip(bool aktif) {
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

  Widget _metaAgendaChip({required IconData icon, required String label}) {
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

  Widget _emptyStateCard(String message) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: Text(message)),
    );
  }

  String _timeOfDayTo24h(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }

  DateTime? _parseDateTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final chunks = value.split(':');
    if (chunks.length < 2) return null;
    final hour = int.tryParse(chunks[0]);
    final minute = int.tryParse(chunks[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }
}

