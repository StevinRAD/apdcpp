import 'dart:convert';

import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:apdcpp/services/apd_api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LayarKalenderKaryawan extends StatefulWidget {
  final String username;

  const LayarKalenderKaryawan({super.key, required this.username});

  @override
  State<LayarKalenderKaryawan> createState() => _LayarKalenderKaryawanState();
}

class _LayarKalenderKaryawanState extends State<LayarKalenderKaryawan> {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  final DateFormat _displayDateFormat = DateFormat('dd MMM yyyy');
  final DateFormat _displayTimeFormat = DateFormat('HH:mm');
  final ApiApdService _api = const ApiApdService();

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _sedangLoad = true;

  final Map<DateTime, List<_KalenderEvent>> _eventByDate = {};
  List<_KalenderEvent> _selectedEvents = [];
  RealtimeChannel? _realtimeChannel;

  DateTime _tanggalOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String get _storageKey => 'jadwal_pribadi_${widget.username}';

  @override
  void initState() {
    super.initState();
    _loadSemuaEvent();
    _mulaiRealtimeKalender();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _mulaiRealtimeKalender() {
    _realtimeChannel = _api.supabase
        .channel('public:kalender_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'kalender_perusahaan',
          callback: (payload) {
            _loadSemuaEvent();
          },
        )
        .subscribe();
  }

  Future<void> _loadSemuaEvent() async {
    setState(() {
      _sedangLoad = true;
    });

    await Future.wait([_loadJadwalPribadi(), _loadAgendaPerusahaan()]);

    _updateSelectedEvents();
    if (!mounted) return;
    setState(() {
      _sedangLoad = false;
    });
  }

  Future<void> _loadJadwalPribadi() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.trim().isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      _removeAllBySource(_EventSource.pribadi);
      for (final item in decoded) {
        if (item is! Map) continue;
        final event = _KalenderEvent.fromJson(item.cast<String, dynamic>());
        if (event == null) continue;
        _addEvent(event);
      }
    } catch (_) {}
  }

  Future<void> _saveJadwalPribadi() async {
    final pribadi = _eventByDate.values
        .expand((list) => list)
        .where((e) => e.source == _EventSource.pribadi)
        .map((e) => e.toJson())
        .toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(pribadi));
  }

  Future<void> _loadAgendaPerusahaan() async {
    try {
      final respon = await _api.kalenderPerusahaanKaryawanList();
      if (!_api.isSuccess(respon)) return;
      final listData = _api.extractListData(respon);
      if (listData.isEmpty) return;

      _removeAllBySource(_EventSource.perusahaan);
      for (final item in listData) {
        final map = item;
        final dateText =
            _readString(map['tanggal']) ??
            _readString(map['tgl']) ??
            _readString(map['date']);
        if (dateText == null) continue;

        final parsedDate = DateTime.tryParse(dateText);
        if (parsedDate == null) continue;

        final startTimeText =
            _readString(map['jam_mulai']) ?? _readString(map['start_time']);
        final endTimeText =
            _readString(map['jam_selesai']) ?? _readString(map['end_time']);

        final startHour = _jamKeJam(startTimeText, defaultHour: 8);
        final startMinute = _jamKeMenit(startTimeText, defaultMinute: 0);
        final endHour = _jamKeJam(
          endTimeText,
          defaultHour: startHour >= 23 ? 23 : startHour + 1,
        );
        final endMinute = _jamKeMenit(endTimeText, defaultMinute: startMinute);

        final title =
            _readString(map['judul']) ??
            _readString(map['title']) ??
            _readString(map['nama_agenda']) ??
            'Agenda Perusahaan';
        final description =
            _readString(map['keterangan']) ??
            _readString(map['deskripsi']) ??
            _readString(map['description']) ??
            '';

        final startDateTime = DateTime(
          parsedDate.year,
          parsedDate.month,
          parsedDate.day,
          startHour,
          startMinute,
        );
        var endDateTime = DateTime(
          parsedDate.year,
          parsedDate.month,
          parsedDate.day,
          endHour,
          endMinute,
        );
        if (!endDateTime.isAfter(startDateTime)) {
          endDateTime = startDateTime.add(const Duration(hours: 1));
        }

        _addEvent(
          _KalenderEvent(
            id:
                _readString(map['id']) ??
                'cmp_${parsedDate.microsecondsSinceEpoch}_$title',
            title: title,
            description: description,
            start: startDateTime,
            end: endDateTime,
            source: _EventSource.perusahaan,
            isPublishedToDeviceCalendar: true,
          ),
        );
      }
    } catch (_) {}
  }

  int _jamKeJam(String? timeText, {required int defaultHour}) {
    if (timeText == null || timeText.trim().isEmpty) return defaultHour;
    final chunks = timeText.split(':');
    if (chunks.isEmpty) return defaultHour;
    final value = int.tryParse(chunks.first) ?? defaultHour;
    if (value < 0 || value > 23) return defaultHour;
    return value;
  }

  int _jamKeMenit(String? timeText, {required int defaultMinute}) {
    if (timeText == null || timeText.trim().isEmpty) return defaultMinute;
    final chunks = timeText.split(':');
    if (chunks.length < 2) return defaultMinute;
    final value = int.tryParse(chunks[1]) ?? defaultMinute;
    if (value < 0 || value > 59) return defaultMinute;
    return value;
  }

  void _removeAllBySource(_EventSource source) {
    final keys = _eventByDate.keys.toList();
    for (final day in keys) {
      final filtered = _eventByDate[day]!
          .where((e) => e.source != source)
          .toList();
      if (filtered.isEmpty) {
        _eventByDate.remove(day);
      } else {
        _eventByDate[day] = filtered;
      }
    }
  }

  void _addEvent(_KalenderEvent event) {
    final day = _tanggalOnly(event.start);
    final existing = _eventByDate[day] ?? [];
    existing.removeWhere((e) => e.id == event.id && e.source == event.source);
    existing.add(event);
    existing.sort((a, b) => a.start.compareTo(b.start));
    _eventByDate[day] = existing;
  }

  String? _readString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  void _updateSelectedEvents() {
    final day = _tanggalOnly(_selectedDay);
    _selectedEvents = List<_KalenderEvent>.from(_eventByDate[day] ?? []);
    _selectedEvents.sort((a, b) => a.start.compareTo(b.start));
  }

  Future<void> _bukaHalamanTambahJadwal() async {
    final result = await Navigator.push<_TambahJadwalResult>(
      context,
      MaterialPageRoute(
        builder: (_) => _LayarTambahJadwalPribadi(initialDate: _selectedDay),
      ),
    );

    if (result == null) return;

    final event = _KalenderEvent(
      id: 'prb_${DateTime.now().microsecondsSinceEpoch}',
      title: result.judul,
      description: result.deskripsi,
      start: result.start,
      end: result.end,
      source: _EventSource.pribadi,
      reminderMinutes: result.reminderMenit,
    );

    setState(() {
      _addEvent(event);
      _selectedDay = _tanggalOnly(result.start);
      _focusedDay = _selectedDay;
      _updateSelectedEvents();
    });
    await _saveJadwalPribadi();
  }

  Future<void> _publishKeKalenderHp(_KalenderEvent event) async {
    try {
      final permission = await _deviceCalendarPlugin.hasPermissions();
      var isGranted = permission.isSuccess && (permission.data == true);
      if (!isGranted) {
        final req = await _deviceCalendarPlugin.requestPermissions();
        isGranted = req.isSuccess && (req.data == true);
        if (!isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Izin kalender ditolak. Aktifkan izin di pengaturan HP.',
              ),
            ),
          );
          return;
        }
      }

      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      final calendars = calendarsResult.data ?? [];
      if (calendars.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kalender HP tidak ditemukan.')),
        );
        return;
      }

      Calendar? targetCalendar;
      for (final cal in calendars) {
        if (cal.isReadOnly == false) {
          targetCalendar = cal;
          break;
        }
      }
      targetCalendar ??= calendars.first;
      final pickedCalendar = targetCalendar;
      if (pickedCalendar == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kalender tujuan tidak ditemukan.')),
        );
        return;
      }

      final calendarId = pickedCalendar.id;
      if (calendarId == null || calendarId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kalender tujuan tidak valid.')),
        );
        return;
      }

      final startTz = TZDateTime.from(event.start, local);
      final endTz = TZDateTime.from(event.end, local);

      final devEvent = Event(
        calendarId,
        eventId: event.deviceEventId,
        title: event.title,
        description: event.description,
        start: startTz,
        end: endTz,
        reminders: [Reminder(minutes: event.reminderMinutes)],
      );

      final result = await _deviceCalendarPlugin.createOrUpdateEvent(devEvent);
      if (result == null || result.isSuccess != true || result.data == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal publish ke kalender HP.')),
        );
        return;
      }

      setState(() {
        event.isPublishedToDeviceCalendar = true;
        event.deviceEventId = result.data!;
        _updateSelectedEvents();
      });
      await _saveJadwalPribadi();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jadwal berhasil dipublish ke kalender HP.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi kendala saat akses kalender HP.'),
        ),
      );
    }
  }

  Future<void> _hapusJadwalPribadi(_KalenderEvent event) async {
    final day = _tanggalOnly(event.start);
    setState(() {
      final list = _eventByDate[day] ?? [];
      list.removeWhere(
        (e) => e.id == event.id && e.source == _EventSource.pribadi,
      );
      if (list.isEmpty) {
        _eventByDate.remove(day);
      } else {
        _eventByDate[day] = list;
      }
      _updateSelectedEvents();
    });
    await _saveJadwalPribadi();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Kalender Karyawan'),
        backgroundColor: const Color(0xFFD2A92B),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFD2A92B),
        onPressed: _bukaHalamanTambahJadwal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _sedangLoad
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSemuaEvent,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: TableCalendar<_KalenderEvent>(
                        availableCalendarFormats: const {
                          CalendarFormat.month: 'Bulan',
                          CalendarFormat.twoWeeks: '2 Minggu',
                          CalendarFormat.week: 'Minggu',
                        },
                        firstDay: DateTime(2020, 1, 1),
                        lastDay: DateTime(2100, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) =>
                            isSameDay(day, _selectedDay),
                        eventLoader: (day) =>
                            _eventByDate[_tanggalOnly(day)] ?? const [],
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = _tanggalOnly(selectedDay);
                            _focusedDay = focusedDay;
                            _updateSelectedEvents();
                          });
                        },
                        calendarStyle: CalendarStyle(
                          markerDecoration: const BoxDecoration(
                            color: Color(0xFFD2A92B),
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: const Color(0xFFD2A92B).withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                          todayDecoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Agenda ${_displayDateFormat.format(_selectedDay)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedEvents.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Belum ada agenda di tanggal ini.'),
                      ),
                    ),
                  ..._selectedEvents.map((event) {
                    final isPribadi = event.source == _EventSource.pribadi;
                    final titleColor = isPribadi
                        ? const Color(0xFF1A73E8)
                        : const Color(0xFFB3261E);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    event.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: titleColor,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: titleColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isPribadi ? 'Pribadi' : 'Perusahaan',
                                    style: TextStyle(
                                      color: titleColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_displayTimeFormat.format(event.start)} - ${_displayTimeFormat.format(event.end)}',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            if (event.description.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(event.description),
                            ],
                            if (isPribadi) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          event.isPublishedToDeviceCalendar
                                          ? null
                                          : () => _publishKeKalenderHp(event),
                                      icon: Icon(
                                        event.isPublishedToDeviceCalendar
                                            ? Icons.check_circle
                                            : Icons.publish,
                                      ),
                                      label: Text(
                                        event.isPublishedToDeviceCalendar
                                            ? 'Sudah publish ke kalender HP'
                                            : 'Publish ke kalender HP',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () => _hapusJadwalPribadi(event),
                                    icon: const Icon(Icons.delete_outline),
                                    color: Colors.red,
                                  ),
                                ],
                              ),
                            ],
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

class _TambahJadwalResult {
  final String judul;
  final String deskripsi;
  final DateTime start;
  final DateTime end;
  final int reminderMenit;

  _TambahJadwalResult({
    required this.judul,
    required this.deskripsi,
    required this.start,
    required this.end,
    required this.reminderMenit,
  });
}

class _LayarTambahJadwalPribadi extends StatefulWidget {
  final DateTime initialDate;

  const _LayarTambahJadwalPribadi({required this.initialDate});

  @override
  State<_LayarTambahJadwalPribadi> createState() =>
      _LayarTambahJadwalPribadiState();
}

class _LayarTambahJadwalPribadiState extends State<_LayarTambahJadwalPribadi> {
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();

  late DateTime _tanggal;
  TimeOfDay _mulai = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _selesai = const TimeOfDay(hour: 9, minute: 0);
  int _reminderMenit = 10;

  final DateFormat _displayDateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _tanggal = widget.initialDate;
  }

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _tanggal = picked);
    }
  }

  Future<void> _pilihMulai() async {
    final picked = await showTimePicker(context: context, initialTime: _mulai);
    if (picked != null) {
      setState(() => _mulai = picked);
    }
  }

  Future<void> _pilihSelesai() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selesai,
    );
    if (picked != null) {
      setState(() => _selesai = picked);
    }
  }

  void _simpan() {
    final judul = _judulController.text.trim();
    if (judul.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Judul jadwal wajib diisi')));
      return;
    }

    final start = DateTime(
      _tanggal.year,
      _tanggal.month,
      _tanggal.day,
      _mulai.hour,
      _mulai.minute,
    );
    final end = DateTime(
      _tanggal.year,
      _tanggal.month,
      _tanggal.day,
      _selesai.hour,
      _selesai.minute,
    );

    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waktu selesai harus lebih besar dari waktu mulai'),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      _TambahJadwalResult(
        judul: judul,
        deskripsi: _deskripsiController.text.trim(),
        start: start,
        end: end,
        reminderMenit: _reminderMenit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Jadwal Pribadi'),
        backgroundColor: const Color(0xFFD2A92B),
        foregroundColor: Colors.white,
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _judulController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Judul Jadwal',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _deskripsiController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pilihTanggal,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_displayDateFormat.format(_tanggal)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pilihMulai,
                    icon: const Icon(Icons.access_time),
                    label: Text('Mulai ${_mulai.format(context)}'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pilihSelesai,
                    icon: const Icon(Icons.access_time_filled),
                    label: Text('Selesai ${_selesai.format(context)}'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _reminderMenit,
                items: const [
                  DropdownMenuItem(
                    value: 5,
                    child: Text('Reminder 5 menit sebelum'),
                  ),
                  DropdownMenuItem(
                    value: 10,
                    child: Text('Reminder 10 menit sebelum'),
                  ),
                  DropdownMenuItem(
                    value: 30,
                    child: Text('Reminder 30 menit sebelum'),
                  ),
                  DropdownMenuItem(
                    value: 60,
                    child: Text('Reminder 60 menit sebelum'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _reminderMenit = value);
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Notifikasi',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _simpan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD2A92B),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Simpan Jadwal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _EventSource { pribadi, perusahaan }

class _KalenderEvent {
  final String id;
  final String title;
  final String description;
  final DateTime start;
  final DateTime end;
  final _EventSource source;
  int reminderMinutes;
  bool isPublishedToDeviceCalendar;
  String? deviceEventId;

  _KalenderEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.start,
    required this.end,
    required this.source,
    this.reminderMinutes = 10,
    this.isPublishedToDeviceCalendar = false,
    this.deviceEventId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'source': source.name,
      'reminder_minutes': reminderMinutes,
      'is_published_to_device_calendar': isPublishedToDeviceCalendar,
      'device_event_id': deviceEventId,
    };
  }

  static _KalenderEvent? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final title = json['title']?.toString();
    final startText = json['start']?.toString();
    final endText = json['end']?.toString();
    final sourceText = json['source']?.toString();
    if (id == null ||
        title == null ||
        startText == null ||
        endText == null ||
        sourceText == null) {
      return null;
    }

    final start = DateTime.tryParse(startText);
    final end = DateTime.tryParse(endText);
    if (start == null || end == null) return null;

    final source = sourceText == _EventSource.perusahaan.name
        ? _EventSource.perusahaan
        : _EventSource.pribadi;

    return _KalenderEvent(
      id: id,
      title: title,
      description: json['description']?.toString() ?? '',
      start: start,
      end: end,
      source: source,
      reminderMinutes:
          int.tryParse(json['reminder_minutes']?.toString() ?? '') ?? 10,
      isPublishedToDeviceCalendar:
          json['is_published_to_device_calendar'] == true,
      deviceEventId: json['device_event_id']?.toString(),
    );
  }
}

