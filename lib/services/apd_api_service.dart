import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class ApiApdService {
  const ApiApdService();
  static final Map<String, int> _gagalLoginAdmin = <String, int>{};
  static final Map<String, int> _gagalLoginKaryawan = <String, int>{};
  static final Map<String, String> _kodePemulihanAdminSementara =
      <String, String>{};

  SupabaseClient get _supabase => Supabase.instance.client;
  SupabaseClient get supabase => _supabase;

  bool isSuccess(Map<String, dynamic> response) =>
      (response['status']?.toString().toLowerCase() ?? '') == 'sukses';

  String message(Map<String, dynamic> response) {
    final raw = response['pesan']?.toString().trim() ?? '';
    if (raw.isNotEmpty) {
      return raw;
    }
    return isSuccess(response)
        ? 'Berhasil memproses permintaan'
        : 'Terjadi kesalahan server';
  }

  List<Map<String, dynamic>> extractListData(Map<String, dynamic> response) {
    if (response['data'] is List) {
      final list = response['data'] as List;
      return list
          .whereType<Map>()
          .map((e) => e.map((key, value) => MapEntry('$key', value)))
          .toList();
    }
    return [];
  }

  Map<String, dynamic> extractMapData(Map<String, dynamic> response) {
    if (response['data'] is Map) {
      return Map<String, dynamic>.from(response['data']);
    }
    return {};
  }

  String _readText(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  /// Generate random session token untuk single device login
  String _generateSessionToken() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  bool _isTrue(dynamic value) {
    if (value is bool) return value;
    final text = _readText(value).toLowerCase();
    return text == '1' || text == 'true' || text == 'yes';
  }

  String _flag(dynamic value) => _isTrue(value) ? '1' : '0';

  List<Map<String, dynamic>> _asMapList(dynamic source) {
    if (source is! List) return const [];
    return source
        .whereType<Map>()
        .map((e) => e.map((key, value) => MapEntry('$key', value)))
        .toList();
  }

  String _normalizeStatus(String? raw) => raw?.trim().toLowerCase() ?? '';

  DateTime? _parseDate(dynamic raw) {
    final text = _readText(raw);
    if (text.isEmpty) return null;
    return DateTime.tryParse(text.replaceFirst(' ', 'T'));
  }

  bool _inDateRange(DateTime? value, DateTime? start, DateTime? end) {
    if (start == null && end == null) return true;
    if (value == null) return false;
    final current = DateTime(value.year, value.month, value.day);
    if (start != null) {
      final s = DateTime(start.year, start.month, start.day);
      if (current.isBefore(s)) return false;
    }
    if (end != null) {
      final e = DateTime(end.year, end.month, end.day);
      if (current.isAfter(e)) return false;
    }
    return true;
  }

  String _displayStatusPengajuan(dynamic raw) {
    switch (_normalizeStatus(raw?.toString())) {
      case 'menunggu':
        return 'Menunggu';
      case 'sedang_diproses':
        return 'Sedang Diproses';
      case 'diproses':
      case 'disetujui':
      case 'diterima': // Tambahkan untuk dukungan dokumen_pengajuan
        return 'Disetujui';
      case 'sebagian_diterima':
        return 'Sebagian Diterima';
      case 'ditolak':
        return 'Ditolak';
      case 'selesai':
        return 'Selesai';
      default:
        return _readText(raw, fallback: '-');
    }
  }

  String _toDbStatusPengajuan(String rawStatus) {
    switch (_normalizeStatus(rawStatus)) {
      case 'menunggu':
        return 'menunggu';
      case 'disetujui':
      case 'diproses':
      case 'diterima':
        return 'diproses';
      case 'ditolak':
        return 'ditolak';
      case 'selesai':
        return 'selesai';
      default:
        return _normalizeStatus(rawStatus);
    }
  }

  String _displayStatusLaporan(dynamic raw) {
    switch (_normalizeStatus(raw?.toString())) {
      case 'menunggu':
        return 'Menunggu';
      case 'ditindaklanjuti':
        return 'Ditindaklanjuti';
      case 'selesai':
        return 'Selesai';
      default:
        return _readText(raw, fallback: '-');
    }
  }

  String _toDbStatusLaporan(String rawStatus) {
    switch (_normalizeStatus(rawStatus)) {
      case 'menunggu':
        return 'menunggu';
      case 'ditindaklanjuti':
        return 'ditindaklanjuti';
      case 'selesai':
        return 'selesai';
      default:
        return _normalizeStatus(rawStatus);
    }
  }

  bool _isMissingTableError(PostgrestException error, String tableName) {
    final msg = error.message.toLowerCase();
    return msg.contains('does not exist') &&
        msg.contains(tableName.toLowerCase());
  }

  bool _matchFilterPengajuan(dynamic rawStatus, String? filter) {
    if (filter == null || filter.trim().isEmpty) return true;
    return _normalizeStatus(rawStatus?.toString()) ==
            _normalizeStatus(filter) ||
        _normalizeStatus(_displayStatusPengajuan(rawStatus)) ==
            _normalizeStatus(filter);
  }

  bool _matchFilterLaporan(dynamic rawStatus, String? filter) {
    if (filter == null || filter.trim().isEmpty) return true;
    return _normalizeStatus(rawStatus?.toString()) ==
            _normalizeStatus(filter) ||
        _normalizeStatus(_displayStatusLaporan(rawStatus)) ==
            _normalizeStatus(filter);
  }

  bool _isStatusDisetujuiPengajuan(dynamic rawStatus) {
    final normalized = _normalizeStatus(rawStatus?.toString());
    return normalized == 'diproses' ||
        normalized == 'disetujui' ||
        normalized == 'diterima' ||
        normalized == 'selesai';
  }

  String _monthShortLabel(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    if (month < 1 || month > 12) return '-';
    return months[month - 1];
  }

  String _weekdayShortLabel(int weekday) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    if (weekday < 1 || weekday > 7) return '-';
    return days[weekday - 1];
  }

  String _pad2(int value) => value.toString().padLeft(2, '0');

  DateTime _startOfWeekMonday(DateTime value) {
    final local = DateTime(value.year, value.month, value.day);
    final diff = local.weekday - DateTime.monday;
    return local.subtract(Duration(days: diff < 0 ? 6 : diff));
  }

  DateTime _toDateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  List<String> _extractPendingLaporanIds(Iterable<Map<String, dynamic>> rows) {
    final ids = <String>{};
    for (final row in rows) {
      if (_normalizeStatus(row['status_laporan']?.toString()) != 'menunggu') {
        continue;
      }

      final id = _readText(row['id']).isNotEmpty
          ? _readText(row['id'])
          : _readText(row['id_laporan']);
      if (id.isNotEmpty) {
        ids.add(id);
      }
    }
    return ids.toList()..sort();
  }

  List<String> _extractPendingLaporanTimestamps(
    Iterable<Map<String, dynamic>> rows,
  ) {
    final timestamps = <String>[];
    for (final row in rows) {
      if (_normalizeStatus(row['status_laporan']?.toString()) != 'menunggu') {
        continue;
      }

      final waktu = _readText(
        row['tanggal_laporan'],
        fallback: _readText(row['created_at']),
      );
      if (waktu.isNotEmpty) {
        timestamps.add(waktu);
      }
    }
    timestamps.sort();
    return timestamps;
  }

  String _guessContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }

  Map<String, dynamic> _decodeIsiNotifikasi(dynamic isiRaw) {
    final isi = _readText(isiRaw);
    if (isi.isEmpty) return const {};

    try {
      final decoded = jsonDecode(isi);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } catch (_) {
      // Fallback ke teks biasa.
    }

    return {'pesan': isi};
  }

  Future<void> _kirimNotifikasiKaryawan({
    required String idKaryawan,
    required String judul,
    required String pesan,
    String tipeNotifikasi = 'umum',
    String? lokasiPengambilan,
    Map<String, dynamic>? payload,
  }) async {
    try {
      if (idKaryawan.trim().isEmpty) return;
      final isiMap = <String, dynamic>{
        'judul': judul,
        'pesan': pesan,
        'tipe_notifikasi': tipeNotifikasi,
        'lokasi_pengambilan': _readText(lokasiPengambilan),
        'payload': payload,
      }..removeWhere((key, value) => value == null);
      final isi = jsonEncode(isiMap);
      await _supabase.from('notifikasi_karyawan').insert({
        'id_karyawan': idKaryawan,
        'isi': isi,
        'is_dibaca': false,
        'tanggal': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Notifikasi gagal dikirim: $e');
    }
  }

  Future<void> _kirimNotifikasiMassal({
    required String judul,
    required String pesan,
    String tipeNotifikasi = 'info',
    String? lokasiPengambilan,
    Map<String, dynamic>? payload,
    bool hanyaAkunAktif = true,
  }) async {
    try {
      final karyawanRows = await _supabase.from('karyawan').select('id,status');
      final targets = _asMapList(karyawanRows).where((row) {
        if (!hanyaAkunAktif) return true;
        final status = _normalizeStatus(row['status']?.toString());
        return status.isEmpty || status == 'aktif';
      }).toList();
      if (targets.isEmpty) return;

      final now = DateTime.now().toIso8601String();
      final isiMap = <String, dynamic>{
        'judul': judul,
        'pesan': pesan,
        'tipe_notifikasi': tipeNotifikasi,
        'lokasi_pengambilan': _readText(lokasiPengambilan),
        'payload': payload,
      }..removeWhere((key, value) => value == null);
      final isi = jsonEncode(isiMap);

      final insertRows = targets
          .map(
            (karyawan) => <String, dynamic>{
              'id_karyawan': _readText(karyawan['id']),
              'isi': isi,
              'is_dibaca': false,
              'tanggal': now,
            },
          )
          .where((row) => _readText(row['id_karyawan']).isNotEmpty)
          .toList();
      if (insertRows.isEmpty) return;
      await _supabase.from('notifikasi_karyawan').insert(insertRows);
    } catch (e) {
      debugPrint('Notifikasi massal gagal dikirim: $e');
    }
  }

  Future<String?> _uploadFile(File file, String pathFolder) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';
      final storagePath = '$pathFolder/$fileName';
      final contentType = _guessContentType(p.extension(file.path));
      await _supabase.storage
          .from('uploads')
          .upload(
            storagePath,
            file,
            fileOptions: FileOptions(upsert: false, contentType: contentType),
          );
      return storagePath; // return merely the storage path
    } on StorageException catch (e) {
      debugPrint(
        'Upload storage error [bucket=uploads path=$pathFolder file=${p.basename(file.path)}]: ${e.message}',
      );
      return null;
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  Future<void> _hapusFileStorage(String? path) async {
    if (path == null || path.trim().isEmpty) return;
    try {
      final cleanPath = path.trim();
      await _supabase.storage.from('uploads').remove([cleanPath]);
      debugPrint('Berhasil menghapus file dari storage: $cleanPath');
    } catch (e) {
      debugPrint('Gagal menghapus file dari storage: $e');
    }
  }

  Future<Map<String, Map<String, dynamic>>> _loadMapByIds({
    required String table,
    required Set<String> ids,
    required String selectColumns,
  }) async {
    if (ids.isEmpty) return const {};
    final rows = await _supabase
        .from(table)
        .select(selectColumns)
        .inFilter('id', ids.toList());
    final mapped = <String, Map<String, dynamic>>{};
    for (final row in _asMapList(rows)) {
      final id = _readText(row['id']);
      if (id.isEmpty) continue;
      mapped[id] = row;
    }
    return mapped;
  }

  Future<bool> cekKoneksiServer({Duration? timeout}) async {
    try {
      await _supabase
          .from('apd')
          .select('id')
          .limit(1)
          .timeout(timeout ?? const Duration(seconds: 10));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> loginKaryawan({
    required String username,
    required String password,
    String? deviceId,
    String? deviceName,
  }) async {
    try {
      final user = username.trim();
      final pass = password.trim();
      if (user.isEmpty || pass.isEmpty) {
        return {'status': 'gagal', 'pesan': 'Username atau password salah'};
      }

      debugPrint('Supabase: Mencari user $user di tabel karyawan...');
      final res = await _supabase
          .from('karyawan')
          .select()
          .eq('username', user)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));
      debugPrint('Supabase: Cek user selesai.');

      if (res == null) {
        return {'status': 'gagal', 'pesan': 'Username atau password salah'};
      }

      final statusAkun = _normalizeStatus(res['status']?.toString());
      if (statusAkun == 'nonaktif') {
        try {
          final pendingBanding = await _supabase
              .from('bantuan_login')
              .select('id')
              .eq('username', user)
              .eq('status', 'menunggu')
              .maybeSingle()
              .timeout(const Duration(seconds: 10));
          if (pendingBanding != null) {
            return {
              'status': 'gagal',
              'pesan':
                  'TUNGGU_BANDING|Permintaan bantuan login Anda sedang ditinjau admin.',
            };
          }
        } catch (_) {
          // Abaikan dan lanjutkan pesan umum nonaktif.
        }
        return {
          'status': 'gagal',
          'pesan':
              'Akun dinonaktifkan. Hubungi admin melalui fitur banding login.',
        };
      }

      if (statusAkun == 'ban_sementara') {
        final bannedUntil = _parseDate(res['banned_until']);
        if (bannedUntil != null && DateTime.now().isBefore(bannedUntil)) {
          return {
            'status': 'gagal',
            'pesan':
                'Akun dibatasi sementara hingga ${bannedUntil.toLocal().toString().replaceFirst('T', ' ').substring(0, 16)}',
          };
        }
      }

      final passwordDb = _readText(res['password']);
      if (passwordDb != pass) {
        final key = user.toLowerCase();
        final percobaan = (_gagalLoginKaryawan[key] ?? 0) + 1;
        _gagalLoginKaryawan[key] = percobaan;

        if (percobaan >= 3) {
          _gagalLoginKaryawan.remove(key);
          await _supabase
              .from('karyawan')
              .update({'status': 'nonaktif'})
              .eq('id', res['id'])
              .timeout(const Duration(seconds: 10));

          // Auto-insert removed to prevent blank tickets interfering with actual employee submissions.

          return {
            'status': 'gagal',
            'pesan':
                'Akun dinonaktifkan karena 3 kali gagal login. Silakan hubungi admin.',
          };
        }

        final sisa = 3 - percobaan;
        return {
          'status': 'gagal',
          'pesan':
              'Username atau password salah. Sisa percobaan: $sisa kali lagi.',
        };
      }

      _gagalLoginKaryawan.remove(user.toLowerCase());

      // Generate session token unik
      final sessionToken = _generateSessionToken();

      // Update device_id, device_name, last_active, dan session_token
      final updateData = <String, dynamic>{
        'last_active': DateTime.now().toIso8601String(),
        'session_token': sessionToken,
      };

      // Tambahkan device info jika deviceId tersedia
      if (deviceId != null && deviceId.isNotEmpty) {
        updateData['device_id'] = deviceId;
        if (deviceName != null && deviceName.isNotEmpty) {
          updateData['device_name'] = deviceName;
        }
      }

      debugPrint('Supabase: Mencoba update status login ke DB...');
      try {
        await _supabase
            .from('karyawan')
            .update(updateData)
            .eq('id', res['id'])
            .timeout(const Duration(seconds: 10));
        debugPrint('Supabase: Update status login sukses.');
      } catch (e) {
        debugPrint('Supabase Error: Gagal update status login (abaikan): $e');
        // Tetap lanjut meskipun update status gagal, agar user tetap bisa masuk
      }

      // Ambil data karyawan yang sudah diupdate
      Map<String, dynamic>? updatedRes;
      try {
        updatedRes = await _supabase
            .from('karyawan')
            .select()
            .eq('id', res['id'])
            .maybeSingle()
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('Peringatan: Gagal mengambil data terbaru karyawan: $e');
      }

      return {'status': 'sukses', 'pesan': 'Berhasil login', 'data': updatedRes ?? res};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Terjadi kesalahan: $e'};
    }
  }

  Future<Map<String, dynamic>> loginAdmin({
    required String username,
    required String password,
    String? deviceId,
    String? deviceName,
  }) async {
    try {
      final user = username.trim();
      final pass = password.trim();
      if (user.isEmpty || pass.isEmpty) {
        return {'status': 'gagal', 'pesan': 'Username atau password salah'};
      }

      debugPrint('Supabase: Mencari user $user di tabel admin...');
      final res = await _supabase
          .from('admin')
          .select()
          .eq('username', user)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));
      debugPrint('Supabase: Cek admin selesai.');

      if (res == null) {
        return {'status': 'gagal', 'pesan': 'Username atau password salah'};
      }

      if (_readText(res['password']) != pass) {
        final key = user.toLowerCase();
        var percobaan = (_gagalLoginAdmin[key] ?? 0) + 1;
        _gagalLoginAdmin[key] = percobaan;

        try {
          final counterRow = await _supabase
              .from('bantuan_login')
              .select('id,password_diingat')
              .eq('username', user)
              .eq('status', 'admin_gagal_login')
              .maybeSingle()
              .timeout(const Duration(seconds: 10));
          final counterDb =
              int.tryParse(_readText(counterRow?['password_diingat'])) ?? 0;
          percobaan = math.max(percobaan, counterDb + 1);
          _gagalLoginAdmin[key] = percobaan;

          if (counterRow == null) {
            await _supabase.from('bantuan_login').insert({
              'username': user,
              'nama_lengkap': _readText(res['nama_lengkap'], fallback: user),
              'password_diingat': '$percobaan',
              'alasan_kendala': 'counter_admin_login',
              'status': 'admin_gagal_login',
            });
          } else {
            await _supabase
                .from('bantuan_login')
                .update({'password_diingat': '$percobaan'})
                .eq('id', counterRow['id']);
          }
        } catch (_) {
          // Fallback ke counter memori jika tabel bantuan_login tidak tersedia.
        }

        if (percobaan >= 3) {
          return {
            'status': 'terkunci',
            'pesan':
                'Akun admin terkunci sementara setelah 3 kali gagal login. Gunakan menu lupa sandi.',
          };
        }

        final sisa = 3 - percobaan;
        return {
          'status': 'gagal',
          'pesan':
              'Username atau password salah. Sisa percobaan: $sisa kali lagi.',
        };
      }

      _gagalLoginAdmin.remove(user.toLowerCase());
      try {
        await _supabase
            .from('bantuan_login')
            .delete()
            .eq('username', user)
            .eq('status', 'admin_gagal_login');
      } catch (_) {
        // Abaikan.
      }

      // Generate session token unik
      final sessionToken = _generateSessionToken();

      // Update device_id, device_name, last_active, dan session_token
      final updateData = <String, dynamic>{
        'last_active': DateTime.now().toIso8601String(),
        'session_token': sessionToken,
      };

      // Tambahkan device info jika deviceId tersedia
      if (deviceId != null && deviceId.isNotEmpty) {
        updateData['device_id'] = deviceId;
        if (deviceName != null && deviceName.isNotEmpty) {
          updateData['device_name'] = deviceName;
        }
      }

      debugPrint('Supabase: Mencoba update status login admin ke DB...');
      try {
        await _supabase
            .from('admin')
            .update(updateData)
            .eq('id', res['id'])
            .timeout(const Duration(seconds: 10));
        debugPrint('Supabase: Update status login admin sukses.');
      } catch (e) {
        debugPrint('Supabase Error: Gagal update status login admin (abaikan): $e');
        // Tetap lanjut meskipun update status gagal
      }

      // Ambil data admin yang sudah diupdate
      Map<String, dynamic>? updatedRes;
      try {
        updatedRes = await _supabase
            .from('admin')
            .select()
            .eq('id', res['id'])
            .maybeSingle()
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('Peringatan: Gagal mengambil data terbaru admin: $e');
      }

      return {'status': 'sukses', 'pesan': 'Berhasil login', 'data': updatedRes ?? res};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Terjadi kesalahan: $e'};
    }
  }

  Future<Map<String, dynamic>> profilKaryawan(String username) async {
    try {
      final res = await _supabase
          .from('karyawan')
          .select()
          .eq('username', username)
          .maybeSingle();
      if (res == null) {
        return {'status': 'gagal', 'pesan': 'Karyawan tidak ditemukan'};
      }
      return {'status': 'sukses', 'data': res};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> profilAdmin(String username) async {
    try {
      final res = await _supabase
          .from('admin')
          .select()
          .eq('username', username)
          .maybeSingle();
      if (res == null) {
        return {'status': 'gagal', 'pesan': 'Admin tidak ditemukan'};
      }
      return {'status': 'sukses', 'data': res};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> editProfilKaryawan({
    required String usernameLama,
    required String usernameBaru,
    required String namaLengkap,
    required String password,
    String? passwordBaru,
    File? fotoProfil,
  }) async {
    try {
      final current = await _supabase
          .from('karyawan')
          .select('*')
          .eq('username', usernameLama)
          .maybeSingle();
      if (current == null) {
        return {'status': 'gagal', 'pesan': 'Data karyawan tidak ditemukan'};
      }

      if (_readText(current['password']) != password) {
        return {'status': 'gagal', 'pesan': 'Password konfirmasi tidak sesuai'};
      }

      final normalizedUsernameBaru = usernameBaru.trim();
      if (normalizedUsernameBaru != usernameLama) {
        final duplicate = await _supabase
            .from('karyawan')
            .select('id')
            .eq('username', normalizedUsernameBaru)
            .maybeSingle();
        if (duplicate != null) {
          return {
            'status': 'gagal',
            'pesan': 'Username sudah digunakan, silakan pilih yang lain',
          };
        }
      }

      String? fotoPath;
      if (fotoProfil != null) {
        fotoPath = await _uploadFile(fotoProfil, 'profil');
        if (fotoPath == null) {
          return {'status': 'gagal', 'pesan': 'Gagal mengunggah foto profil'};
        }
      }

      final Map<String, dynamic> updateData = {
        'username': normalizedUsernameBaru,
        'nama_lengkap': namaLengkap.trim(),
        'password': _readText(passwordBaru).isEmpty ? password : passwordBaru,
      };
      if (fotoPath != null) {
        updateData['foto_profil'] = fotoPath;
        if (_readText(current['foto_profil']).isNotEmpty) {
          await _hapusFileStorage(_readText(current['foto_profil']));
        }
      }

      await _supabase
          .from('karyawan')
          .update(updateData)
          .eq('id', current['id']);

      final updated = await _supabase
          .from('karyawan')
          .select('*')
          .eq('id', current['id'])
          .maybeSingle();

      return {
        'status': 'sukses',
        'pesan': 'Profil berhasil diperbarui',
        'foto_profil': updated?['foto_profil'] ?? fotoPath ?? '',
        'data': updated ?? updateData,
      };
    } on PostgrestException catch (e) {
      return {
        'status': 'gagal',
        'pesan': 'Gagal memperbarui profil: ${e.message}',
      };
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal memperbarui profil: $e'};
    }
  }

  Future<Map<String, dynamic>> daftarApd() async {
    try {
      final res = await _supabase
          .from('apd')
          .select()
          .eq('is_aktif', true)
          .order('nama_apd', ascending: true);
      final mapped = _asMapList(res)
          .map(
            (row) => <String, dynamic>{
              ...row,
              'id_apd': _readText(row['id']),
              'is_aktif': _flag(row['is_aktif']),
            },
          )
          .toList();
      return {'status': 'sukses', 'data': mapped};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> simpanPengajuan({
    required String username,
    required String idApd,
    required String ukuran,
    required String alasan,
    File? buktiFoto,
  }) async {
    try {
      final idApdFinal = idApd.trim();
      if (idApdFinal.isEmpty || idApdFinal.toLowerCase() == 'null') {
        return {'status': 'gagal', 'pesan': 'ID APD tidak valid'};
      }

      final apd = await _supabase
          .from('apd')
          .select('id,stok,is_aktif,nama_apd')
          .eq('id', idApdFinal)
          .maybeSingle();
      if (apd == null) {
        return {'status': 'gagal', 'pesan': 'APD tidak ditemukan'};
      }
      if (!_isTrue(apd['is_aktif'])) {
        return {'status': 'gagal', 'pesan': 'APD sedang dinonaktifkan admin'};
      }
      final stok = int.tryParse('${apd['stok'] ?? 0}') ?? 0;
      if (stok <= 0) {
        return {'status': 'gagal', 'pesan': 'Stok APD sedang kosong'};
      }

      String? buktiPath;
      if (buktiFoto != null) {
        buktiPath = await _uploadFile(buktiFoto, 'pengajuan');
        if (buktiPath == null) {
          return {'status': 'gagal', 'pesan': 'Gagal mengupload bukti foto'};
        }
      }

      final karyawan = await _supabase
          .from('karyawan')
          .select('id, cooldown_pengajuan_hari')
          .eq('username', username)
          .maybeSingle();
      if (karyawan == null) {
        return {'status': 'gagal', 'pesan': 'Karyawan tidak valid'};
      }

      final dashboard = await dashboardKaryawan(username);
      if (isSuccess(dashboard)) {
        final dataDashboard = extractMapData(dashboard);
        final aturan = dataDashboard['aturan_pengajuan'];
        if (aturan is Map &&
            aturan['bisa_ajukan'] == false &&
            _readText(aturan['status']) != 'boleh_ajukan') {
          return {
            'status': 'gagal',
            'pesan': _readText(
              aturan['pesan'],
              fallback: 'Pengajuan belum bisa dilakukan saat ini.',
            ),
            'data': {
              'aturan_pengajuan': aturan.map(
                (key, value) => MapEntry('$key', value),
              ),
            },
          };
        }
      }

      await _supabase.from('pengajuan').insert({
        'id_karyawan': karyawan['id'],
        'id_apd': idApdFinal,
        'ukuran': ukuran,
        'alasan_pengajuan': alasan,
        'bukti_foto': buktiPath,
        'status_pengajuan': 'menunggu',
        'jumlah': 1,
      });

      final dashboardTerbaru = await dashboardKaryawan(username);
      final dataTerbaru = extractMapData(dashboardTerbaru);
      final aturanTerbaru = dataTerbaru['aturan_pengajuan'];
      return {
        'status': 'sukses',
        'pesan': 'Pengajuan berhasil dikirim',
        'data': {
          if (aturanTerbaru is Map)
            'aturan_pengajuan': aturanTerbaru.map(
              (key, value) => MapEntry('$key', value),
            ),
        },
      };
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Terjadi kesalahan: $e'};
    }
  }

  Future<Map<String, dynamic>> riwayatPengajuanKaryawan(String username) async {
    try {
      final user = username.trim();
      if (user.isEmpty) return {'status': 'sukses', 'data': []};

      var karyawan = await _supabase
          .from('karyawan')
          .select('id')
          .eq('username', user)
          .maybeSingle();
      karyawan ??= await _supabase
          .from('karyawan')
          .select('id')
          .ilike('username', user)
          .maybeSingle();
      if (karyawan == null) return {'status': 'sukses', 'data': []};

      final idKaryawan = _readText(karyawan['id']);

      // Ambil data dari sistem lama (tabel pengajuan)
      final resLama = await _supabase
          .from('pengajuan')
          .select()
          .eq('id_karyawan', idKaryawan)
          .order('tanggal_pengajuan', ascending: false);

      final rowsLama = _asMapList(resLama);
      final apdIds = rowsLama
          .map((row) => _readText(row['id_apd']))
          .where((id) => id.isNotEmpty)
          .toSet();
      final adminIds = rowsLama
          .map((row) => _readText(row['id_admin']))
          .where((id) => id.isNotEmpty)
          .toSet();

      final apdMap = await _loadMapByIds(
        table: 'apd',
        ids: apdIds,
        selectColumns: 'id,nama_apd,satuan',
      );
      final adminMap = await _loadMapByIds(
        table: 'admin',
        ids: adminIds,
        selectColumns: 'id,nama_lengkap',
      );

      // Ambil data dari sistem baru (tabel dokumen_pengajuan)
      final resBaru = await _supabase
          .from('dokumen_pengajuan')
          .select('*, karyawan(username,nama_lengkap,jabatan,departemen,lokasi_kerja)')
          .eq('id_karyawan', idKaryawan)
          .order('tanggal_pengajuan', ascending: false);

      final rowsBaru = _asMapList(resBaru);

      // Mapping data dari sistem lama
      final mappedLama = rowsLama.map((row) {
        final apd = apdMap[_readText(row['id_apd'])];
        final admin = adminMap[_readText(row['id_admin'])];
        return <String, dynamic>{
          ...row,
          'id_pengajuan': _readText(row['id']),
          'tipe': 'single', // Penanda sistem lama
          'nama_apd': _readText(
            apd?['nama_apd'],
            fallback: _readText(row['nama_apd'], fallback: '-'),
          ),
          'nama_admin': _readText(
            admin?['nama_lengkap'],
            fallback: _readText(row['nama_admin'], fallback: '-'),
          ),
          'status_pengajuan': _displayStatusPengajuan(row['status_pengajuan']),
          'tanggal_diproses': _readText(
            row['tanggal_diproses'],
            fallback: _readText(row['tanggal_proses']),
          ),
          'jumlah_pengajuan': row['jumlah_pengajuan'] ?? row['jumlah'] ?? 1,
          'satuan': _readText(
            row['satuan'],
            fallback: _readText(apd?['satuan']),
          ),
        };
      }).toList();

      // Mapping data dari sistem baru (dokumen_pengajuan) - KELOMPOKKAN PER DOKUMEN
      final mappedBaru = <Map<String, dynamic>>[];
      for (final dokumen in rowsBaru) {
        final idDokumen = _readText(dokumen['id']);

        // Ambil item-item APD dari dokumen ini
        final itemRows = await _supabase
            .from('dokumen_pengajuan_item')
            .select('id,id_apd,ukuran,alasan,jumlah,status,catatan_admin')
            .eq('id_pengajuan', idDokumen);

        final items = _asMapList(itemRows);
        final itemApdIds = items
            .map((item) => _readText(item['id_apd']))
            .where((id) => id.isNotEmpty)
            .toSet();

        final apdMapBaru = await _loadMapByIds(
          table: 'apd',
          ids: itemApdIds,
          selectColumns: 'id,nama_apd,satuan',
        );

        // Hitung status per item
        int menungguCount = 0;
        int diterimaCount = 0;
        int ditolakCount = 0;

        for (final item in items) {
          final status = _readText(item['status'], fallback: 'menunggu').toLowerCase();
          if (status == 'menunggu') menungguCount++;
          else if (status == 'diterima') diterimaCount++;
          else if (status == 'ditolak') ditolakCount++;
        }

        // Buat SATU entry per dokumen dengan ringkasan status item
        String statusLabel = _displayStatusPengajuan(dokumen['status']);
        String statusDetail = '';

        if (menungguCount > 0 && diterimaCount == 0 && ditolakCount == 0) {
          statusDetail = 'Semua menunggu';
        } else if (menungguCount == 0 && diterimaCount > 0 && ditolakCount == 0) {
          statusDetail = 'Semua diterima';
        } else if (menungguCount == 0 && diterimaCount == 0 && ditolakCount > 0) {
          statusDetail = 'Semua ditolak';
        } else if (menungguCount == 0 && diterimaCount > 0 && ditolakCount > 0) {
          statusDetail = '$diterimaCount diterima, $ditolakCount ditolak';
        } else if (menungguCount > 0) {
          statusDetail = '$diterimaCount diterima, $ditolakCount ditolak, $menungguCount menunggu';
        }

        // Simpan items data untuk ditampilkan di detail
        final itemsData = items.map((item) {
          final apd = apdMapBaru[_readText(item['id_apd'])];
          return {
            'id': _readText(item['id']),
            'nama_apd': _readText(apd?['nama_apd'], fallback: '-'),
            'ukuran': _readText(item['ukuran']),
            'jumlah': item['jumlah'] ?? 1,
            'status': _readText(item['status'], fallback: 'menunggu'),
            'alasan': _readText(item['alasan']),
            'catatan_admin': _readText(item['catatan_admin']),
            'satuan': _readText(apd?['satuan'], fallback: 'pcs'),
          };
        }).toList();

        mappedBaru.add({
          'id_pengajuan': idDokumen,
          'tipe': 'dokumen',
          'nama_apd': '${items.length} item APD',
          'status_pengajuan': statusLabel,
          'status_detail': statusDetail,
          'tanggal_pengajuan': _readText(dokumen['tanggal_pengajuan']),
          'tanggal_diproses': _readText(dokumen['tanggal_proses']),
          'catatan_admin': _readText(dokumen['catatan_admin']),
          'jumlah_item': items.length,
          'items_data': itemsData,
          // Untuk compatibility
          'jumlah_pengajuan': items.length,
          'satuan': 'item',
        });
      }

      // Gabungkan dan sort berdasarkan tanggal pengajuan
      final allData = [...mappedLama, ...mappedBaru];
      allData.sort((a, b) {
        final tanggalA = _parseDate(a['tanggal_pengajuan']);
        final tanggalB = _parseDate(b['tanggal_pengajuan']);
        if (tanggalA == null && tanggalB == null) return 0;
        if (tanggalA == null) return 1;
        if (tanggalB == null) return -1;
        return tanggalB.compareTo(tanggalA);
      });

      return {'status': 'sukses', 'data': allData};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> semuaPengajuan({
    String? statusPengajuan,
    DateTime? start,
    DateTime? end,
    String? jabatan,
    DateTime? tanggal,
  }) async {
    try {
      // === HANYA GUNAKAN SISTEM BARU: Tabel dokumen_pengajuan ===
      // Sistem lama (pengajuan) sudah tidak dipakai lagi

      final query = _supabase
          .from('dokumen_pengajuan')
          .select(
            '*, karyawan(username,nama_lengkap,jabatan,departemen,lokasi_kerja,cooldown_pengajuan_hari,foto_profil), '
            'admin(nama_lengkap)',
          );

      final res = await query.order('tanggal_pengajuan', ascending: false);
      final rows = _asMapList(res);
      final mappedData = <Map<String, dynamic>>[];

      for (final dokumen in rows) {
        // Filter status
        if (!_matchFilterPengajuan(dokumen['status'], statusPengajuan)) {
          continue;
        }

        final karyawan = dokumen['karyawan'] is Map
            ? Map<String, dynamic>.from(dokumen['karyawan'] as Map)
            : const <String, dynamic>{};
        final admin = dokumen['admin'] is Map
            ? Map<String, dynamic>.from(dokumen['admin'] as Map)
            : const <String, dynamic>{};

        if (_readText(jabatan).isNotEmpty &&
            _normalizeStatus(_readText(karyawan['jabatan'])) !=
                _normalizeStatus(_readText(jabatan))) {
          continue;
        }

        final tanggalPengajuan = _parseDate(dokumen['tanggal_pengajuan']);
        if (tanggal != null &&
            !_inDateRange(tanggalPengajuan, tanggal, tanggal)) {
          continue;
        }
        if (!_inDateRange(tanggalPengajuan, start, end)) {
          continue;
        }

        // Ambil item-item APD dari dokumen ini
        final idDokumen = _readText(dokumen['id']);
        final itemRows = await _supabase
            .from('dokumen_pengajuan_item')
            .select('id,id_apd,ukuran,alasan,jumlah,status,catatan_admin,tanggal_proses')
            .eq('id_pengajuan', idDokumen);

        final items = _asMapList(itemRows);

        // Hitung item yang menunggu
        final menungguCount = items.where((item) {
          final status = _readText(item['status'], fallback: 'menunggu').toLowerCase();
          return status == 'menunggu';
        }).length;

        // Skip jika filter Menunggu dan tidak ada item yang menunggu
        if (statusPengajuan == 'Menunggu' && menungguCount == 0) {
          continue;
        }

        // Untuk DOKUMEN, buat SATU entry yang berisi info summary
        mappedData.add({
          'id_pengajuan': idDokumen, // ID dokumen
          'tipe': 'dokumen', // Penanda sistem baru
          'status_pengajuan': _displayStatusPengajuan(dokumen['status']),
          'tanggal_pengajuan': _readText(dokumen['tanggal_pengajuan']),
          'tanggal_diproses': _readText(dokumen['tanggal_proses']),
          'username_karyawan': _readText(karyawan['username']),
          'nama_lengkap': _readText(karyawan['nama_lengkap'], fallback: '-'),
          'jabatan': _readText(karyawan['jabatan'], fallback: '-'),
          'departemen': _readText(karyawan['departemen'], fallback: '-'),
          'lokasi_kerja': _readText(karyawan['lokasi_kerja'], fallback: '-'),
          'foto_profil': _readText(karyawan['foto_profil']),
          'cooldown_pengajuan_hari': karyawan['cooldown_pengajuan_hari'] ?? 0,
          'nama_apd': '${items.length} item APD', // Tampilkan jumlah item
          'jumlah_item': items.length, // Jumlah total item
          'jumlah_item_menunggu': menungguCount, // Jumlah item yang menunggu
          'catatan_admin': _readText(dokumen['catatan_admin']),
          'nama_admin_proses': _readText(admin['nama_lengkap']),
          // Simpan data items untuk dipakai di detail sheet
          'items_data': items,
        });
      }

      // Sort data berdasarkan tanggal
      mappedData.sort((a, b) {
        final tanggalA = _parseDate(a['tanggal_pengajuan']);
        final tanggalB = _parseDate(b['tanggal_pengajuan']);
        if (tanggalA == null && tanggalB == null) return 0;
        if (tanggalA == null) return 1;
        if (tanggalB == null) return -1;
        return tanggalB.compareTo(tanggalA);
      });

      return {'status': 'sukses', 'data': mappedData};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> prosesPengajuan({
    required String idPengajuan,
    required String statusPengajuan,
    required String usernameAdmin,
    String? catatanAdmin,
    String? lokasiPengambilan,
  }) async {
    try {
      final targetId = idPengajuan.trim();
      if (targetId.isEmpty || targetId.toLowerCase() == 'null') {
        return {'status': 'gagal', 'pesan': 'ID pengajuan tidak valid'};
      }

      final admin = await _supabase
          .from('admin')
          .select('id,nama_lengkap')
          .eq('username', usernameAdmin)
          .maybeSingle();
      if (admin == null) {
        return {'status': 'gagal', 'pesan': 'Admin tidak valid'};
      }

      final existing = await _supabase
          .from('pengajuan')
          .select('id,id_apd,id_karyawan,status_pengajuan,jumlah')
          .eq('id', targetId)
          .maybeSingle();
      if (existing == null) {
        return {'status': 'gagal', 'pesan': 'Data pengajuan tidak ditemukan'};
      }

      final statusDb = _toDbStatusPengajuan(statusPengajuan);
      final statusSebelumnya = _normalizeStatus(
        existing['status_pengajuan']?.toString(),
      );
      final payload = <String, dynamic>{
        'status_pengajuan': statusDb,
        'id_admin': admin['id'],
        'tanggal_proses': DateTime.now().toIso8601String(),
      };
      if (_readText(catatanAdmin).isNotEmpty) {
        payload['catatan_admin'] = catatanAdmin;
      }
      if (_readText(lokasiPengambilan).isNotEmpty) {
        payload['lokasi_pengambilan'] = lokasiPengambilan;
      }

      // Kurangi stok hanya saat transisi dari belum-disetujui ke disetujui.
      if (!_isStatusDisetujuiPengajuan(statusSebelumnya) &&
          _isStatusDisetujuiPengajuan(statusDb)) {
        final idApd = _readText(existing['id_apd']);
        if (idApd.isNotEmpty) {
          final apd = await _supabase
              .from('apd')
              .select('id,stok,nama_apd')
              .eq('id', idApd)
              .maybeSingle();
          if (apd != null) {
            final stokSaatIni = int.tryParse('${apd['stok'] ?? 0}') ?? 0;
            // Gunakan jumlah untuk mengurangi stok sesuai jumlah yang diminta
            final jumlahDiminta = int.tryParse('${existing['jumlah'] ?? 1}') ?? 1;
            // Langsung kurangi stok tanpa validasi
            await _supabase
                .from('apd')
                .update({'stok': stokSaatIni - jumlahDiminta})
                .eq('id', idApd);
          }
        }
      }

      await _supabase.from('pengajuan').update(payload).eq('id', targetId);

      // Kirim notifikasi ke karyawan terkait status terbaru.
      final idKaryawan = _readText(existing['id_karyawan']);
      if (idKaryawan.isNotEmpty) {
        final detailPengajuan = await _supabase
            .from('pengajuan')
            .select('id_apd,lokasi_pengambilan,catatan_admin,status_pengajuan')
            .eq('id', targetId)
            .maybeSingle();
        final namaApd = await (() async {
          final idApd = _readText(
            detailPengajuan?['id_apd'],
            fallback: _readText(existing['id_apd']),
          );
          if (idApd.isEmpty) return 'APD';
          final apd = await _supabase
              .from('apd')
              .select('nama_apd')
              .eq('id', idApd)
              .maybeSingle();
          return _readText(apd?['nama_apd'], fallback: 'APD');
        })();

        String judul = 'Update Pengajuan APD';
        String pesan = 'Status pengajuan $namaApd Anda telah diperbarui.';
        if (statusDb == 'disetujui' || statusDb == 'diterima') {
          judul = 'Pengajuan APD Disetujui';
          pesan = 'Pengajuan $namaApd Anda telah disetujui admin.';
        } else if (statusDb == 'ditolak') {
          judul = 'Pengajuan APD Ditolak';
          pesan = 'Pengajuan $namaApd Anda ditolak admin.';
        } else if (statusDb == 'selesai') {
          judul = 'Pengajuan APD Diserahkan';
          pesan = 'Pengajuan $namaApd Anda telah diserahkan/selesai.';
        }

        final lokasi = _readText(detailPengajuan?['lokasi_pengambilan']);
        final catatan = _readText(detailPengajuan?['catatan_admin']);
        if (lokasi.isNotEmpty) {
          pesan = '$pesan\nLokasi pengambilan: $lokasi';
        }
        if (catatan.isNotEmpty) {
          pesan = '$pesan\nCatatan admin: $catatan';
        }

        await _kirimNotifikasiKaryawan(
          idKaryawan: idKaryawan,
          judul: judul,
          pesan: pesan,
          tipeNotifikasi: 'pengajuan',
          lokasiPengambilan: lokasi,
          payload: {
            'id_pengajuan': targetId,
            'status_pengajuan': statusDb,
            'nama_apd': namaApd,
          },
        );
      }

      return {'status': 'sukses', 'pesan': 'Berhasil memproses pengajuan'};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> masterApdList() async {
    try {
      final res = await _supabase
          .from('apd')
          .select()
          .order('nama_apd', ascending: true);
      final mapped = _asMapList(res)
          .map(
            (row) => <String, dynamic>{
              ...row,
              'id_apd': _readText(row['id']),
              'is_aktif': _flag(row['is_aktif']),
            },
          )
          .toList();
      return {'status': 'sukses', 'data': mapped};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> masterApdTambah({
    required String namaApd,
    required String stok,
    required String minStok,
    required String satuan,
    required String deskripsi,
    File? gambarApd,
  }) async {
    try {
      String? imgPath;
      if (gambarApd != null) {
        imgPath = await _uploadFile(gambarApd, 'apd');
      }

      await _supabase.from('apd').insert({
        'nama_apd': namaApd,
        'stok': int.tryParse(stok) ?? 0,
        'min_stok': int.tryParse(minStok) ?? 0,
        'satuan': satuan,
        'deskripsi': deskripsi,
        'gambar_apd': imgPath,
      });
      return {'status': 'sukses', 'pesan': 'APD berhasil ditambahkan'};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> masterApdUbah({
    required String idApd,
    required String namaApd,
    required String stok,
    required String minStok,
    required String satuan,
    required String deskripsi,
    required String isAktif,
    File? gambarApd,
    bool hapusGambar = false,
  }) async {
    try {
      final targetId = idApd.trim();
      if (targetId.isEmpty || targetId.toLowerCase() == 'null') {
        return {'status': 'gagal', 'pesan': 'ID APD tidak valid'};
      }

      final Map<String, dynamic> updateData = {
        'nama_apd': namaApd,
        'stok': int.tryParse(stok) ?? 0,
        'min_stok': int.tryParse(minStok) ?? 0,
        'satuan': satuan,
        'deskripsi': deskripsi,
        'is_aktif': isAktif == '1',
      };

      final current = await _supabase
          .from('apd')
          .select('gambar_apd')
          .eq('id', targetId)
          .maybeSingle();

      if (gambarApd != null) {
        final imgPath = await _uploadFile(gambarApd, 'apd');
        if (imgPath != null) {
          updateData['gambar_apd'] = imgPath;
          if (current != null && _readText(current['gambar_apd']).isNotEmpty) {
            await _hapusFileStorage(_readText(current['gambar_apd']));
          }
        }
      } else if (hapusGambar) {
        updateData['gambar_apd'] = null; // Remove image
        if (current != null && _readText(current['gambar_apd']).isNotEmpty) {
          await _hapusFileStorage(_readText(current['gambar_apd']));
        }
      }

      await _supabase.from('apd').update(updateData).eq('id', targetId);
      return {'status': 'sukses', 'pesan': 'APD berhasil diubah'};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> masterApdHapus(String idApd) async {
    try {
      final targetId = idApd.trim();
      if (targetId.isEmpty || targetId.toLowerCase() == 'null') {
        return {'status': 'gagal', 'pesan': 'ID APD tidak valid'};
      }
      final current = await _supabase
          .from('apd')
          .select('gambar_apd')
          .eq('id', targetId)
          .maybeSingle();

      await _supabase.from('apd').delete().eq('id', targetId);

      if (current != null && _readText(current['gambar_apd']).isNotEmpty) {
        await _hapusFileStorage(_readText(current['gambar_apd']));
      }
      return {'status': 'sukses', 'pesan': 'APD berhasil dihapus'};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> notifikasiKaryawan(String username) async {
    try {
      final k = await _supabase
          .from('karyawan')
          .select('id')
          .eq('username', username)
          .maybeSingle();
      if (k == null) return {'status': 'sukses', 'data': []};

      final res = await _supabase
          .from('notifikasi_karyawan')
          .select()
          .eq('id_karyawan', k['id'])
          .order('tanggal', ascending: false);

      final mapped = _asMapList(res).map((row) {
        final parsedIsi = _decodeIsiNotifikasi(row['isi']);
        final judul = _readText(parsedIsi['judul'], fallback: 'Notifikasi');
        final pesan = _readText(
          parsedIsi['pesan'],
          fallback: _readText(row['isi']),
        );
        return <String, dynamic>{
          ...row,
          'id_notifikasi': _readText(row['id']),
          'judul': judul,
          'pesan': pesan,
          'tipe_notifikasi': _readText(
            parsedIsi['tipe_notifikasi'],
            fallback: 'umum',
          ),
          'lokasi_pengambilan': _readText(parsedIsi['lokasi_pengambilan']),
          'status_baca': _isTrue(row['is_dibaca']) ? 1 : 0,
          'created_at': _readText(
            row['tanggal'],
            fallback: _readText(row['created_at']),
          ),
        };
      }).toList();
      return {'status': 'sukses', 'data': mapped};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> tandaiNotifikasiDibaca({
    required String idNotifikasi,
    required String username,
  }) async {
    try {
      final targetId = idNotifikasi.trim();
      if (targetId.isEmpty || targetId.toLowerCase() == 'null') {
        return {'status': 'gagal', 'pesan': 'ID notifikasi tidak valid'};
      }
      final karyawan = await _supabase
          .from('karyawan')
          .select('id')
          .eq('username', username)
          .maybeSingle();
      if (karyawan == null) {
        return {'status': 'gagal', 'pesan': 'Data karyawan tidak ditemukan'};
      }
      await _supabase
          .from('notifikasi_karyawan')
          .update({'is_dibaca': true})
          .eq('id', targetId)
          .eq('id_karyawan', karyawan['id']);
      return {'status': 'sukses', 'pesan': 'Berhasil'};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> hapusNotifikasi({
    required String idNotifikasi,
    required String username,
  }) async {
    try {
      final targetId = idNotifikasi.trim();
      if (targetId.isEmpty || targetId.toLowerCase() == 'null') {
        return {'status': 'gagal', 'pesan': 'ID notifikasi tidak valid'};
      }
      final karyawan = await _supabase
          .from('karyawan')
          .select('id')
          .eq('username', username)
          .maybeSingle();
      if (karyawan == null) {
        return {'status': 'gagal', 'pesan': 'Data karyawan tidak ditemukan'};
      }
      await _supabase
          .from('notifikasi_karyawan')
          .delete()
          .eq('id', targetId)
          .eq('id_karyawan', karyawan['id']);
      return {'status': 'sukses', 'pesan': 'Notifikasi berhasil dihapus'};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> hapusSemuaNotifikasi(String username) async {
    try {
      final karyawan = await _supabase
          .from('karyawan')
          .select('id')
          .eq('username', username)
          .maybeSingle();
      if (karyawan == null) {
        return {'status': 'gagal', 'pesan': 'Data karyawan tidak ditemukan'};
      }
      await _supabase
          .from('notifikasi_karyawan')
          .delete()
          .eq('id_karyawan', karyawan['id']);
      return {'status': 'sukses', 'pesan': 'Semua notifikasi berhasil dihapus'};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> laporanPengajuan({
    DateTime? start,
    DateTime? end,
    String? statusPengajuan,
  }) async {
    return semuaPengajuan(
      start: start,
      end: end,
      statusPengajuan: statusPengajuan,
    );
  }

  Future<Map<String, dynamic>> karyawanAdminList() async {
    try {
      final res = await _supabase
          .from('karyawan')
          .select()
          .order('nama_lengkap', ascending: true);
      return {'status': 'sukses', 'data': res};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> opsiJabatanKaryawan() async {
    try {
      final res = await _supabase.from('karyawan').select('jabatan');
      final jabs =
          _asMapList(res)
              .map((e) => _readText(e['jabatan']))
              .where((jabatan) => jabatan.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      final mapped = jabs.map((jabatan) => {'jabatan': jabatan}).toList();
      return {'status': 'sukses', 'data': mapped};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> karyawanAdminSimpan({
    required String id,
    required String username,
    required String namaLengkap,
    required String jabatan,
    required String departemen,
    required String lokasiKerja,
    required String status,
    required String cooldownPengajuanHari,
    String? password,
    String? bannedUntil,
  }) async {
    try {
      final data = {
        'username': username,
        'nama_lengkap': namaLengkap,
        'jabatan': jabatan,
        'departemen': departemen,
        'lokasi_kerja': lokasiKerja,
        'status': status,
        'cooldown_pengajuan_hari': int.tryParse(cooldownPengajuanHari) ?? 0,
      };
      if (password != null && password.isNotEmpty) data['password'] = password;
      if (bannedUntil != null && bannedUntil.isNotEmpty) {
        data['banned_until'] = bannedUntil;
      }

      if (id.isEmpty) {
        await _supabase.from('karyawan').insert(data);
      } else {
        await _supabase.from('karyawan').update(data).eq('id', id);
      }
      return {'status': 'sukses', 'pesan': 'Data Karyawan Tersimpan'};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> karyawanAdminHapus(String id) async {
    try {
      final targetId = id.trim();
      if (targetId.isEmpty || targetId.toLowerCase() == 'null') {
        return {'status': 'gagal', 'pesan': 'ID karyawan tidak valid'};
      }
      final karyawan = await _supabase
          .from('karyawan')
          .select('id,username')
          .eq('id', targetId)
          .maybeSingle();
      if (karyawan == null) {
        return {'status': 'gagal', 'pesan': 'Karyawan tidak ditemukan'};
      }
      await _supabase
          .from('notifikasi_karyawan')
          .delete()
          .eq('id_karyawan', targetId);
      await _supabase.from('pengajuan').delete().eq('id_karyawan', targetId);
      try {
        await _supabase
            .from('laporan_kendala')
            .delete()
            .eq('id_karyawan', targetId);
      } on PostgrestException catch (e) {
        if (!_isMissingTableError(e, 'laporan_kendala')) rethrow;
      }

      final username = _readText(karyawan['username']);
      if (username.isNotEmpty) {
        await _supabase.from('bantuan_login').delete().eq('username', username);
      }

      await _supabase.from('karyawan').delete().eq('id', targetId);
      return {'status': 'sukses', 'pesan': 'Karyawan terhapus'};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> kalenderPerusahaanAdminList({
    bool includeNonaktif = true,
  }) async {
    try {
      var q = _supabase.from('kalender_perusahaan').select();
      if (!includeNonaktif) q = q.eq('is_aktif', true);

      final res = await q.order('tanggal', ascending: true);
      final mapped = _asMapList(res)
          .map(
            (row) => <String, dynamic>{
              ...row,
              'is_aktif': _flag(row['is_aktif']),
              'is_libur': _flag(row['is_libur']),
            },
          )
          .toList();
      return {'status': 'sukses', 'data': mapped};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> kalenderPerusahaanAdminSimpan({
    String? id,
    required String tanggal,
    required String judul,
    required String keterangan,
    required bool isLibur,
    required bool isAktif,
    String? jamMulai,
    String? jamSelesai,
    bool kirimNotifikasi = true,
  }) async {
    try {
      final jamMulaiValue = _readText(jamMulai);
      final jamSelesaiValue = _readText(jamSelesai);
      final data = <String, dynamic>{
        'tanggal': tanggal,
        'judul': judul,
        'keterangan': keterangan,
        'is_libur': isLibur ? 1 : 0,
        'is_aktif': isAktif ? 1 : 0,
        'jam_mulai': jamMulaiValue.isEmpty ? null : jamMulaiValue,
        'jam_selesai': jamSelesaiValue.isEmpty ? null : jamSelesaiValue,
      };

      final targetId = _readText(id);
      final isEdit = targetId.isNotEmpty && targetId.toLowerCase() != 'null';
      if (!isEdit) {
        await _supabase.from('kalender_perusahaan').insert(data);
      } else {
        await _supabase
            .from('kalender_perusahaan')
            .update(data)
            .eq('id', targetId);
      }

      if (kirimNotifikasi && isAktif) {
        final judulNotif = isEdit
            ? 'Perubahan Agenda Perusahaan'
            : 'Agenda Perusahaan Baru';
        final infoJam = [
          if (jamMulaiValue.isNotEmpty) 'mulai $jamMulaiValue',
          if (jamSelesaiValue.isNotEmpty) 'selesai $jamSelesaiValue',
        ].join(', ');
        final tanggalLabel = _readText(tanggal);
        final pesan =
            '$judul (${tanggalLabel.isEmpty ? '-' : tanggalLabel})'
            '${infoJam.isEmpty ? '' : ' - $infoJam'}'
            '${_readText(keterangan).isEmpty ? '' : '\n$keterangan'}';
        await _kirimNotifikasiMassal(
          judul: judulNotif,
          pesan: pesan,
          tipeNotifikasi: 'kalender',
          payload: {
            'judul': judul,
            'tanggal': tanggal,
            'keterangan': keterangan,
            'is_libur': isLibur,
          },
        );
      }
      return {'status': 'sukses', 'pesan': 'Kalender Tersimpan'};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> kalenderPerusahaanAdminHapus(String id) async {
    try {
      final targetId = id.trim();
      if (targetId.isEmpty || targetId.toLowerCase() == 'null') {
        return {'status': 'gagal', 'pesan': 'ID kalender tidak valid'};
      }
      await _supabase.from('kalender_perusahaan').delete().eq('id', targetId);
      return {'status': 'sukses', 'pesan': 'Kalender Terhapus'};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> kalenderPerusahaanKaryawanList() async {
    try {
      final res = await _supabase
          .from('kalender_perusahaan')
          .select()
          .eq('is_aktif', true)
          .order('tanggal', ascending: true);
      return {'status': 'sukses', 'data': _asMapList(res)};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> pengajuanKaryawanUntukLaporan(
    String username,
  ) async {
    try {
      final user = username.trim();
      if (user.isEmpty) {
        return {
          'status': 'sukses',
          'data': {'rows': <Map<String, dynamic>>[]},
        };
      }

      var karyawan = await _supabase
          .from('karyawan')
          .select('id')
          .eq('username', user)
          .maybeSingle();
      
      karyawan ??= await _supabase
          .from('karyawan')
          .select('id')
          .ilike('username', user)
          .maybeSingle();

      if (karyawan == null) {
        return {
          'status': 'sukses',
          'data': {'rows': <Map<String, dynamic>>[]},
        };
      }

      // === GUNAKAN SISTEM BARU: dokumen_pengajuan_item ===
      // Ambil semua item yang DITERIMA dari dokumen pengajuan karyawan
      final dokumenRes = await _supabase
          .from('dokumen_pengajuan')
          .select('id,tanggal_pengajuan')
          .eq('id_karyawan', karyawan['id']);

      final dokumenRows = _asMapList(dokumenRes);
      final allItems = <Map<String, dynamic>>[];

      // Ambil item dari setiap dokumen
      for (final dokumen in dokumenRows) {
        final idDokumen = _readText(dokumen['id']);
        final tglPengajuan = _readText(dokumen['tanggal_pengajuan']);
        
        final items = await _supabase
            .from('dokumen_pengajuan_item')
            .select('id,id_apd,status')
            .eq('id_pengajuan', idDokumen);

        final listItems = _asMapList(items).where((it) {
          final st = (it['status']?.toString() ?? '').toLowerCase();
          return st == 'diterima' || st == 'disetujui';
        }).map((it) {
          final mutableItem = Map<String, dynamic>.from(it);
          mutableItem['tanggal_pengajuan'] = tglPengajuan;
          return mutableItem;
        }).toList();

        allItems.addAll(listItems);
      }

      // Ambil nama APD
      final apdIds = allItems
          .map((e) => _readText(e['id_apd']))
          .where((e) => e.isNotEmpty)
          .toSet();
      final apdMap = await _loadMapByIds(
        table: 'apd',
        ids: apdIds,
        selectColumns: 'id,nama_apd',
      );

      final mapped = allItems.map((item) {
        final apd = apdMap[_readText(item['id_apd'])];
        return <String, dynamic>{
          'id_pengajuan': _readText(item['id']), // ID item
          'nama_apd': _readText(apd?['nama_apd'], fallback: '-'),
          'status_pengajuan': 'Disetujui', // Semua item di sini sudah diterima
          'tanggal_pengajuan': _readText(item['tanggal_pengajuan']),
        };
      }).toList();

      return {
        'status': 'sukses',
        'data': {'rows': mapped},
      };
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal memuat data pengajuan: $e'};
    }
  }

  Future<Map<String, dynamic>> kirimLaporanKendala({
    required String username,
    required String namaApd,
    required String keterangan,
    String? idPengajuan,
    File? fotoLaporan,
  }) async {
    try {
      final user = username.trim();
      final idPengajuanRaw = _readText(idPengajuan);
      if (idPengajuanRaw.isEmpty) {
        return {
          'status': 'gagal',
          'pesan':
              'Pilih APD dari daftar pengajuan yang sudah diterima terlebih dahulu',
        };
      }

      if (namaApd.trim().isEmpty || keterangan.trim().isEmpty) {
        return {
          'status': 'gagal',
          'pesan': 'Nama APD dan keterangan laporan wajib diisi',
        };
      }

      final karyawan = await _supabase
          .from('karyawan')
          .select('id')
          .eq('username', user)
          .maybeSingle();
      if (karyawan == null) {
        return {'status': 'gagal', 'pesan': 'Data karyawan tidak ditemukan'};
      }

      final pengajuan = await _supabase
          .from('pengajuan')
          .select('id,id_karyawan,id_apd,status_pengajuan')
          .eq('id', idPengajuanRaw)
          .maybeSingle();
      if (pengajuan == null) {
        return {'status': 'gagal', 'pesan': 'Data pengajuan tidak ditemukan'};
      }
      if (_readText(pengajuan['id_karyawan']) != _readText(karyawan['id'])) {
        return {
          'status': 'gagal',
          'pesan': 'Pengajuan yang dipilih tidak sesuai akun karyawan',
        };
      }
      if (!_isStatusDisetujuiPengajuan(pengajuan['status_pengajuan'])) {
        return {
          'status': 'gagal',
          'pesan':
              'Laporan hanya bisa dibuat dari APD yang sudah diterima/disetujui',
        };
      }

      String namaApdFinal = namaApd.trim();
      final idApd = _readText(pengajuan['id_apd']);
      if (idApd.isNotEmpty) {
        final apd = await _supabase
            .from('apd')
            .select('nama_apd')
            .eq('id', idApd)
            .maybeSingle();
        final namaDariApd = _readText(apd?['nama_apd']);
        if (namaDariApd.isNotEmpty) {
          namaApdFinal = namaDariApd;
        }
      }

      String? fotoPath;
      if (fotoLaporan != null) {
        fotoPath = await _uploadFile(fotoLaporan, 'kendala');
        if (fotoPath == null) {
          return {'status': 'gagal', 'pesan': 'Gagal mengunggah foto laporan'};
        }
      }

      final Map<String, dynamic> payload = {
        'id_karyawan': karyawan['id'],
        'nama_apd': namaApdFinal,
        'keterangan': keterangan.trim(),
        'status_laporan': _toDbStatusLaporan('menunggu'),
        'id_pengajuan': idPengajuanRaw,
        'foto_laporan': fotoPath,
      }..removeWhere((key, value) => value == null);

      try {
        await _supabase.from('laporan_kendala').insert({
          ...payload,
          'tanggal_laporan': DateTime.now().toIso8601String(),
        });
      } on PostgrestException catch (e) {
        final message = e.message.toLowerCase();
        if (_isMissingTableError(e, 'laporan_kendala')) {
          return {
            'status': 'gagal',
            'pesan':
                'Tabel laporan_kendala belum ada di Supabase. Silakan buat tabelnya terlebih dahulu.',
          };
        }
        if (message.contains('tanggal_laporan')) {
          await _supabase.from('laporan_kendala').insert(payload);
        } else if (message.contains('id_pengajuan')) {
          final payloadTanpaPengajuan = Map<String, dynamic>.from(payload)
            ..remove('id_pengajuan');
          await _supabase.from('laporan_kendala').insert(payloadTanpaPengajuan);
        } else {
          rethrow;
        }
      }

      return {
        'status': 'sukses',
        'pesan': 'Laporan kendala berhasil dikirim ke admin',
      };
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal mengirim laporan: $e'};
    }
  }

  Future<List<Map<String, dynamic>>> _queryLaporanKendalaRows() async {
    try {
      final res = await _supabase
          .from('laporan_kendala')
          .select()
          .order('tanggal_laporan', ascending: false);
      return _asMapList(res);
    } on PostgrestException catch (e) {
      if (_isMissingTableError(e, 'laporan_kendala')) {
        return const [];
      }
      if (!e.message.toLowerCase().contains('tanggal_laporan')) {
        rethrow;
      }
      try {
        final fallback = await _supabase
            .from('laporan_kendala')
            .select()
            .order('created_at', ascending: false);
        return _asMapList(fallback);
      } on PostgrestException catch (inner) {
        if (_isMissingTableError(inner, 'laporan_kendala')) {
          return const [];
        }
        rethrow;
      }
    }
  }

  Future<Map<String, dynamic>> riwayatLaporanKendalaKaryawan(
    String username,
  ) async {
    try {
      final karyawan = await _supabase
          .from('karyawan')
          .select('id')
          .eq('username', username)
          .maybeSingle();
      if (karyawan == null) {
        return {
          'status': 'sukses',
          'data': {'rows': <Map<String, dynamic>>[]},
        };
      }

      final allRows = await _queryLaporanKendalaRows();
      final filtered = allRows.where((row) {
        return _readText(row['id_karyawan']) == _readText(karyawan['id']);
      }).toList();

      final mapped = filtered.map((row) {
        return <String, dynamic>{
          'id_laporan': _readText(row['id']).isNotEmpty
              ? _readText(row['id'])
              : _readText(row['id_laporan']),
          'nama_apd': _readText(row['nama_apd'], fallback: '-'),
          'keterangan': _readText(row['keterangan']),
          'status_laporan': _displayStatusLaporan(row['status_laporan']),
          'foto_laporan': _readText(row['foto_laporan']),
          'tanggal_laporan': _readText(
            row['tanggal_laporan'],
            fallback: _readText(row['created_at']),
          ),
          'tanggal_tindak': _readText(row['tanggal_tindak']),
          'catatan_admin': _readText(row['catatan_admin']),
        };
      }).toList();

      return {
        'status': 'sukses',
        'data': {'rows': mapped},
      };
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal memuat riwayat laporan: $e'};
    }
  }

  Future<Map<String, dynamic>> tindakLanjutLaporan({
    required String idLaporan,
    required String statusLaporan,
    required String usernameAdmin,
    String? catatanAdmin,
  }) async {
    try {
      final admin = await _supabase
          .from('admin')
          .select('id')
          .eq('username', usernameAdmin)
          .maybeSingle();
      if (admin == null) {
        return {'status': 'gagal', 'pesan': 'Data admin tidak ditemukan'};
      }

      final statusDb = _toDbStatusLaporan(statusLaporan);
      final now = DateTime.now().toIso8601String();
      final Map<String, dynamic> basePayload = {
        'status_laporan': statusDb,
        'catatan_admin': _readText(catatanAdmin),
        'tanggal_tindak': now,
      };

      try {
        await _supabase
            .from('laporan_kendala')
            .update({...basePayload, 'id_admin_tindak': admin['id']})
            .eq('id', idLaporan);
      } on PostgrestException catch (e) {
        final msg = e.message.toLowerCase();
        if (_isMissingTableError(e, 'laporan_kendala')) {
          return {
            'status': 'gagal',
            'pesan':
                'Tabel laporan_kendala belum ada di Supabase. Silakan buat tabelnya terlebih dahulu.',
          };
        }
        if (msg.contains('id_admin_tindak')) {
          await _supabase
              .from('laporan_kendala')
              .update({...basePayload, 'id_admin': admin['id']})
              .eq('id', idLaporan);
        } else {
          rethrow;
        }
      }

      return {'status': 'sukses', 'pesan': 'Laporan berhasil ditindaklanjuti'};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal menindaklanjuti laporan: $e'};
    }
  }

  Future<Map<String, dynamic>> laporanGabunganAdmin({
    DateTime? start,
    DateTime? end,
    String? statusPengajuan,
    String? statusLaporan,
  }) async {
    try {
      // === GUNAKAN SISTEM BARU: dokumen_pengajuan + dokumen_pengajuan_item ===
      final dokumenRes = await _supabase
          .from('dokumen_pengajuan')
          .select('*')
          .order('tanggal_pengajuan', ascending: false);
      final dokumenRows = _asMapList(dokumenRes);

      // Ambil semua item dari semua dokumen
      final allItemRows = <Map<String, dynamic>>[];
      for (final dokumen in dokumenRows) {
        final idDokumen = _readText(dokumen['id']);
        final items = await _supabase
            .from('dokumen_pengajuan_item')
            .select('*')
            .eq('id_pengajuan', idDokumen);
        allItemRows.addAll(_asMapList(items));
      }

      // Collect IDs
      final pengajuanKaryawanIds = dokumenRows
          .map((e) => _readText(e['id_karyawan']))
          .where((e) => e.isNotEmpty)
          .toSet();
      final pengajuanApdIds = allItemRows
          .map((e) => _readText(e['id_apd']))
          .where((e) => e.isNotEmpty)
          .toSet();
      final pengajuanAdminIds = dokumenRows
          .map((e) => _readText(e['id_admin']))
          .where((e) => e.isNotEmpty)
          .toSet();

      final karyawanMapPengajuan = await _loadMapByIds(
        table: 'karyawan',
        ids: pengajuanKaryawanIds,
        selectColumns:
            'id,username,nama_lengkap,jabatan,departemen,lokasi_kerja,foto_profil',
      );
      final apdMap = await _loadMapByIds(
        table: 'apd',
        ids: pengajuanApdIds,
        selectColumns: 'id,nama_apd,stok,min_stok,satuan',
      );
      final adminMapPengajuan = await _loadMapByIds(
        table: 'admin',
        ids: pengajuanAdminIds,
        selectColumns: 'id,nama_lengkap',
      );

      final mappedPengajuan = <Map<String, dynamic>>[];

      // Loop per item, bukan per dokumen
      for (final item in allItemRows) {
        final idDokumen = _readText(item['id_pengajuan']);
        final dokumen = dokumenRows.firstWhere(
          (d) => _readText(d['id']) == idDokumen,
          orElse: () => const {},
        );

        final tanggalPengajuan = _parseDate(dokumen['tanggal_pengajuan']);
        if (!_inDateRange(tanggalPengajuan, start, end)) continue;

        // Filter berdasarkan status item, bukan status dokumen
        // Karena sistem baru memproses per item
        final statusItem = _normalizeStatus(item['status']);
        if (!_matchFilterPengajuan(statusItem, statusPengajuan)) {
          continue;
        }

        final karyawan = karyawanMapPengajuan[_readText(dokumen['id_karyawan'])];
        final apd = apdMap[_readText(item['id_apd'])];
        final admin = adminMapPengajuan[_readText(dokumen['id_admin'])];

        mappedPengajuan.add({
          'id_pengajuan': idDokumen,
          'id_item': _readText(item['id']),
          'tanggal_pengajuan': _readText(dokumen['tanggal_pengajuan']),
          'username_karyawan': _readText(
            karyawan?['username'],
            fallback: '-',
          ),
          'nama_lengkap': _readText(
            karyawan?['nama_lengkap'],
            fallback: '-',
          ),
          'jabatan': _readText(
            karyawan?['jabatan'],
            fallback: '-',
          ),
          'departemen': _readText(
            karyawan?['departemen'],
            fallback: '-',
          ),
          'lokasi_kerja': _readText(
            karyawan?['lokasi_kerja'],
            fallback: '-',
          ),
          'foto_profil': _readText(
            karyawan?['foto_profil'],
            fallback: '-',
          ),
          'nama_apd': _readText(apd?['nama_apd'], fallback: '-'),
          'ukuran': _readText(item['ukuran'], fallback: '-'),
          'jumlah_pengajuan': item['jumlah'] ?? 1,
          'alasan_pengajuan': _readText(item['alasan']),
          'status_pengajuan': _displayStatusPengajuan(item['status']),
          'status_item': _readText(item['status'], fallback: 'menunggu'),
          'catatan_admin': _readText(item['catatan_admin']),
          'tanggal_diproses': _readText(item['tanggal_proses']),
          'nama_admin_proses': _readText(
            admin?['nama_lengkap'],
            fallback: '-',
          ),
          'stok_tersedia': apd?['stok'] ?? 0,
          'min_stok': apd?['min_stok'] ?? 0,
          'satuan': _readText(apd?['satuan'], fallback: 'pcs'),
        });
      }

      final kendalaRows = await _queryLaporanKendalaRows();
      final idLaporanMenungguSemua = _extractPendingLaporanIds(kendalaRows);
      final kendalaKaryawanIds = kendalaRows
          .map((e) => _readText(e['id_karyawan']))
          .where((e) => e.isNotEmpty)
          .toSet();
      final kendalaAdminIds = kendalaRows
          .map(
            (e) => _readText(e['id_admin_tindak']).isNotEmpty
                ? _readText(e['id_admin_tindak'])
                : _readText(e['id_admin']),
          )
          .where((e) => e.isNotEmpty)
          .toSet();

      final karyawanMapKendala = await _loadMapByIds(
        table: 'karyawan',
        ids: kendalaKaryawanIds,
        selectColumns:
            'id,username,nama_lengkap,jabatan,departemen,lokasi_kerja,foto_profil',
      );
      final adminMapKendala = await _loadMapByIds(
        table: 'admin',
        ids: kendalaAdminIds,
        selectColumns: 'id,nama_lengkap',
      );

      final mappedKendala = <Map<String, dynamic>>[];
      var menunggu = 0;
      var ditindaklanjuti = 0;
      var selesai = 0;

      for (final row in kendalaRows) {
        if (!_matchFilterLaporan(row['status_laporan'], statusLaporan)) {
          continue;
        }
        final tanggalLaporan = _parseDate(
          _readText(
            row['tanggal_laporan'],
            fallback: _readText(row['created_at']),
          ),
        );
        if (!_inDateRange(tanggalLaporan, start, end)) continue;

        final normalizedStatus = _normalizeStatus(row['status_laporan']);
        if (normalizedStatus == 'menunggu') menunggu++;
        if (normalizedStatus == 'ditindaklanjuti') ditindaklanjuti++;
        if (normalizedStatus == 'selesai') selesai++;

        final karyawan = karyawanMapKendala[_readText(row['id_karyawan'])];
        final adminId = _readText(row['id_admin_tindak']).isNotEmpty
            ? _readText(row['id_admin_tindak'])
            : _readText(row['id_admin']);
        final admin = adminMapKendala[adminId];

        mappedKendala.add({
          'id_laporan': _readText(row['id']).isNotEmpty
              ? _readText(row['id'])
              : _readText(row['id_laporan']),
          'tanggal_laporan': _readText(
            row['tanggal_laporan'],
            fallback: _readText(row['created_at']),
          ),
          'username_karyawan': _readText(
            karyawan?['username'],
            fallback: _readText(row['username_karyawan'], fallback: '-'),
          ),
          'nama_lengkap': _readText(
            karyawan?['nama_lengkap'],
            fallback: _readText(row['nama_lengkap'], fallback: '-'),
          ),
          'jabatan': _readText(
            karyawan?['jabatan'],
            fallback: _readText(row['jabatan'], fallback: '-'),
          ),
          'departemen': _readText(
            karyawan?['departemen'],
            fallback: _readText(row['departemen'], fallback: '-'),
          ),
          'lokasi_kerja': _readText(
            karyawan?['lokasi_kerja'],
            fallback: _readText(row['lokasi_kerja'], fallback: '-'),
          ),
          'foto_profil_karyawan': _readText(
            karyawan?['foto_profil'],
            fallback: _readText(row['foto_profil_karyawan']),
          ),
          'nama_apd': _readText(row['nama_apd'], fallback: '-'),
          'keterangan': _readText(row['keterangan']),
          'status_laporan': _displayStatusLaporan(row['status_laporan']),
          'catatan_admin': _readText(row['catatan_admin']),
          'tanggal_tindak': _readText(row['tanggal_tindak']),
          'nama_admin_tindak': _readText(
            admin?['nama_lengkap'],
            fallback: _readText(row['nama_admin_tindak']),
          ),
          'foto_laporan': _readText(row['foto_laporan']),
        });
      }

      return {
        'status': 'sukses',
        'data': {
          'pengajuan': {'rows': mappedPengajuan},
          'kendala': {
            'rows': mappedKendala,
            'menunggu': menunggu,
            'ditindaklanjuti': ditindaklanjuti,
            'selesai': selesai,
            'id_menunggu_semua': idLaporanMenungguSemua,
          },
        },
      };
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal memuat laporan gabungan: $e'};
    }
  }

  // ==== Dashboard Karyawan ====
  Future<Map<String, dynamic>> dashboardKaryawan(String username) async {
    try {
      final profil = await _supabase
          .from('karyawan')
          .select(
            'id,username,nama_lengkap,jabatan,departemen,lokasi_kerja,'
            'cooldown_pengajuan_hari,foto_profil,status,banned_until',
          )
          .eq('username', username)
          .maybeSingle();
      if (profil == null) {
        return {'status': 'gagal', 'pesan': 'Data karyawan tidak ditemukan'};
      }

      final idKaryawan = _readText(profil['id']);
      final cooldownHari =
          int.tryParse('${profil['cooldown_pengajuan_hari'] ?? 0}') ?? 0;

      final notifikasi = await _supabase
          .from('notifikasi_karyawan')
          .select('id')
          .eq('id_karyawan', idKaryawan)
          .eq('is_dibaca', false);
      final notifBelumDibaca = _asMapList(notifikasi).length;

      // Ambil data dari sistem lama (tabel pengajuan)
      final pengajuanRows = await _supabase
          .from('pengajuan')
          .select(
            'id,id_apd,status_pengajuan,tanggal_pengajuan,tanggal_proses,'
            'ukuran,alasan_pengajuan,catatan_admin,lokasi_pengambilan',
          )
          .eq('id_karyawan', idKaryawan)
          .order('tanggal_pengajuan', ascending: false)
          .limit(1);

      // Ambil data dari sistem baru (tabel dokumen_pengajuan)
      final dokumenRows = await _supabase
          .from('dokumen_pengajuan')
          .select(
            'id,tanggal_pengajuan,status,catatan_admin,tanggal_proses',
          )
          .eq('id_karyawan', idKaryawan)
          .order('tanggal_pengajuan', ascending: false)
          .limit(1);

      Map<String, dynamic>? pengajuanTerakhir;
      final pengajuanList = _asMapList(pengajuanRows);
      final dokumenList = _asMapList(dokumenRows);

      // Tentukan mana yang lebih baru
      DateTime? tanggalPengajuanLama;
      DateTime? tanggalDokumenBaru;

      if (pengajuanList.isNotEmpty) {
        tanggalPengajuanLama = _parseDate(
          _readText(pengajuanList.first['tanggal_pengajuan']),
        );
      }
      if (dokumenList.isNotEmpty) {
        tanggalDokumenBaru = _parseDate(
          _readText(dokumenList.first['tanggal_pengajuan']),
        );
      }

      // Gunakan yang lebih baru
      bool gunakanDokumenBaru = false;
      if (tanggalDokumenBaru != null && tanggalPengajuanLama != null) {
        gunakanDokumenBaru = tanggalDokumenBaru.isAfter(tanggalPengajuanLama);
      } else if (tanggalDokumenBaru != null) {
        gunakanDokumenBaru = true;
      }

      if (dokumenList.isNotEmpty && gunakanDokumenBaru) {
        // Gunakan data dari dokumen_pengajuan (sistem baru)
        final dok = dokumenList.first;
        final idDokumen = _readText(dok['id']);

        // Ambil jumlah item
        final itemRows = await _supabase
            .from('dokumen_pengajuan_item')
            .select('id_apd')
            .eq('id_pengajuan', idDokumen);
        final jumlahItem = _asMapList(itemRows).length;

        pengajuanTerakhir = {
          'id_pengajuan': idDokumen,
          'tipe': 'dokumen', // Penanda tipe pengajuan
          'nama_apd': '$jumlahItem item APD', // Tampilkan jumlah item
          'status_pengajuan_raw': _normalizeStatus(dok['status']?.toString()),
          'status_pengajuan': _displayStatusPengajuan(dok['status']),
          'tanggal_pengajuan': _readText(dok['tanggal_pengajuan']),
          'tanggal_proses': _readText(dok['tanggal_proses']),
          'ukuran': '-',
          'alasan_pengajuan': 'Dokumen pengajuan multi-item',
          'catatan_admin': _readText(dok['catatan_admin']),
          'lokasi_pengambilan': '-',
        };
      } else if (pengajuanList.isNotEmpty) {
        // Gunakan data dari pengajuan (sistem lama)
        final row = pengajuanList.first;
        String namaApd = '-';
        final idApd = _readText(row['id_apd']);
        if (idApd.isNotEmpty) {
          final apd = await _supabase
              .from('apd')
              .select('nama_apd')
              .eq('id', idApd)
              .maybeSingle();
          namaApd = _readText(apd?['nama_apd'], fallback: '-');
        }
        pengajuanTerakhir = {
          'id_pengajuan': _readText(row['id']),
          'tipe': 'single', // Penanda tipe pengajuan
          'nama_apd': namaApd,
          'status_pengajuan_raw': _normalizeStatus(
            row['status_pengajuan']?.toString(),
          ),
          'status_pengajuan': _displayStatusPengajuan(row['status_pengajuan']),
          'tanggal_pengajuan': _readText(row['tanggal_pengajuan']),
          'tanggal_proses': _readText(row['tanggal_proses']),
          'ukuran': _readText(row['ukuran']),
          'alasan_pengajuan': _readText(row['alasan_pengajuan']),
          'catatan_admin': _readText(row['catatan_admin']),
          'lokasi_pengambilan': _readText(row['lokasi_pengambilan']),
        };
      }

      bool bisaAjukan = true;
      String statusAturan = 'boleh_ajukan';
      String pesanAturan = 'Akun bisa mengajukan APD sekarang.';
      String tanggalBolehAjukan = '';
      int sisaHariCooldown = 0;

      final statusAkun = _normalizeStatus(profil['status']?.toString());
      if (statusAkun == 'nonaktif') {
        bisaAjukan = false;
        statusAturan = 'akun_nonaktif';
        pesanAturan = 'Akun sedang nonaktif. Hubungi admin untuk aktivasi.';
      } else if (statusAkun == 'ban_sementara') {
        final bannedUntil = _parseDate(profil['banned_until']);
        if (bannedUntil != null && DateTime.now().isBefore(bannedUntil)) {
          bisaAjukan = false;
          statusAturan = 'ban_sementara';
          tanggalBolehAjukan = bannedUntil.toIso8601String();
          pesanAturan =
              'Akun sedang dibatasi sementara hingga ${bannedUntil.toLocal()}.';
        }
      }

      if (bisaAjukan && pengajuanTerakhir != null) {
        final statusRaw = _normalizeStatus(
          _readText(
            pengajuanTerakhir['status_pengajuan_raw'],
            fallback: pengajuanTerakhir['status_pengajuan']?.toString() ?? '',
          ),
        );
        if (statusRaw == 'menunggu') {
          bisaAjukan = false;
          statusAturan = 'menunggu_proses';
          pesanAturan = 'Pengajuan APD sebelumnya masih menunggu proses admin.';
        } else {
          final referensiWaktu = _parseDate(
            _readText(
              pengajuanTerakhir['tanggal_proses'],
              fallback: _readText(pengajuanTerakhir['tanggal_pengajuan']),
            ),
          );
          if (cooldownHari > 0 && referensiWaktu != null) {
            final nextAllowed = referensiWaktu.add(
              Duration(days: cooldownHari),
            );
            final nowRef = DateTime.now();
            if (nowRef.isBefore(nextAllowed)) {
              final selisihJam = nextAllowed.difference(nowRef).inHours;
              sisaHariCooldown = (selisihJam / 24).ceil();
              if (sisaHariCooldown <= 0) {
                sisaHariCooldown = 1;
              }
              bisaAjukan = false;
              statusAturan = 'cooldown';
              tanggalBolehAjukan = nextAllowed.toIso8601String();
              pesanAturan =
                  'Pengajuan sebelumnya sudah diproses. Kamu bisa mengajukan lagi dalam $sisaHariCooldown hari.';
            }
          }
        }
      } else {
        pesanAturan =
            'Belum ada riwayat pengajuan, kamu bisa mulai mengajukan.';
      }

      final beritaRows = await _supabase
          .from('berita')
          .select(
            'id,judul,ringkasan,isi,kategori,gambar_berita,created_at,is_aktif',
          )
          .eq('is_aktif', true)
          .order('created_at', ascending: false)
          .limit(10);
      final berita = _asMapList(beritaRows)
          .map(
            (row) => <String, dynamic>{
              ...row,
              'id_berita': _readText(row['id']),
              'judul': _readText(row['judul'], fallback: '-'),
              'ringkasan': _readText(row['ringkasan']),
              'isi': _readText(row['isi']),
              'deskripsi': _readText(
                row['deskripsi'],
                fallback: _readText(row['isi']),
              ),
              'kategori': _readText(row['kategori'], fallback: 'Berita'),
              'gambar': _readText(row['gambar_berita']),
              'gambar_berita': _readText(row['gambar_berita']),
              'tanggal': _readText(row['created_at']),
              'is_aktif': _flag(row['is_aktif']),
              'jenis': 'berita',
            },
          )
          .toList();

      return {
        'status': 'sukses',
        'data': {
          'profil': {
            'id': idKaryawan,
            'username': _readText(profil['username']),
            'nama_lengkap': _readText(profil['nama_lengkap']),
            'jabatan': _readText(profil['jabatan']),
            'departemen': _readText(profil['departemen']),
            'lokasi_kerja': _readText(profil['lokasi_kerja']),
            'status': _readText(profil['status'], fallback: 'aktif'),
            'foto_profil': _readText(profil['foto_profil']),
          },
          'notifikasi_belum_dibaca': notifBelumDibaca,
          'pengajuan_terakhir': pengajuanTerakhir,
          'aturan_pengajuan': {
            'bisa_ajukan': bisaAjukan,
            'status': statusAturan,
            'pesan': pesanAturan,
            'cooldown_pengajuan_hari': cooldownHari,
            'sisa_hari_cooldown': sisaHariCooldown,
            'tanggal_boleh_ajukan': tanggalBolehAjukan,
          },
          'berita': berita,
          'informasi_utama': berita,
        },
      };
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal memuat dashboard: $e'};
    }
  }

  Future<Map<String, dynamic>> dashboardAdmin(
    String username, {
    String modeGrafik = 'mingguan',
    int? tahunGrafik,
    int? bulanGrafik,
  }) async {
    try {
      final admin = await _supabase
          .from('admin')
          .select('id')
          .eq('username', username)
          .maybeSingle();
      if (admin == null) {
        return {'status': 'gagal', 'pesan': 'Akun admin tidak ditemukan'};
      }

      final now = DateTime.now();
      final modeRaw = _normalizeStatus(modeGrafik);
      final mode =
          (modeRaw == 'mingguan' ||
              modeRaw == 'bulanan' ||
              modeRaw == 'tahunan')
          ? modeRaw
          : 'mingguan';
      final tahunRef = tahunGrafik ?? now.year;
      final bulanRef =
          (bulanGrafik != null && bulanGrafik >= 1 && bulanGrafik <= 12)
          ? bulanGrafik
          : now.month;

      // SISTEM BARU: Query dokumen_pengajuan dan dokumen_pengajuan_item
      final dokumenRes = await _supabase
          .from('dokumen_pengajuan')
          .select('id,id_karyawan,status,tanggal_pengajuan,tanggal_proses')
          .order('tanggal_pengajuan', ascending: false);
      final dokumenRows = _asMapList(dokumenRes);

      // Query semua item dari dokumen
      final dokumenIds = dokumenRows
          .map((row) => _readText(row['id']))
          .where((id) => id.isNotEmpty)
          .toSet();

      final itemsRes = await _supabase
          .from('dokumen_pengajuan_item')
          .select('id,id_pengajuan,id_apd,status')
          .inFilter('id_pengajuan', dokumenIds.toList());
      final itemRows = _asMapList(itemsRes);

      // Group items by dokumen
      final itemsByDokumen = <String, List<Map<String, dynamic>>>{};
      for (final item in itemRows) {
        final idDokumen = _readText(item['id_pengajuan']);
        itemsByDokumen.putIfAbsent(idDokumen, () => []).add(item);
      }

      // Buat map dokumen by id untuk mengambil tanggal
      final dokumenMap = <String, Map<String, dynamic>>{};
      for (final d in dokumenRows) {
        final id = _readText(d['id']);
        if (id.isNotEmpty) {
          dokumenMap[id] = d;
        }
      }

      final karyawanIds = dokumenRows
          .map((row) => _readText(row['id_karyawan']))
          .where((id) => id.isNotEmpty)
          .toSet();
      final apdIds = itemRows
          .map((row) => _readText(row['id_apd']))
          .where((id) => id.isNotEmpty)
          .toSet();

      final karyawanMap = await _loadMapByIds(
        table: 'karyawan',
        ids: karyawanIds,
        selectColumns: 'id,username,nama_lengkap,jabatan',
      );
      final apdMap = await _loadMapByIds(
        table: 'apd',
        ids: apdIds,
        selectColumns: 'id,nama_apd,stok,min_stok,satuan,is_aktif',
      );

      // STATISTIK: Menghitung dokumen menunggu
      final pengajuanMenunggu = dokumenRows
          .where(
            (row) => _normalizeStatus(row['status']?.toString()) == 'menunggu',
          )
          .length;

      // STATISTIK: Menghitung item yang disetujui bulan ini
      final disetujuiBulanIni = itemRows.where((row) {
        if (!_isStatusDisetujuiPengajuan(row['status'])) return false;
        // Gunakan tanggal dari dokumen terkait
        final dokumen = dokumenRows.firstWhere(
          (d) => _readText(d['id']) == _readText(row['id_pengajuan']),
          orElse: () => {},
        );
        if (dokumen.isEmpty) return false;
        final tanggalAcuan = _parseDate(
          _readText(
            dokumen['tanggal_proses'],
            fallback: _readText(dokumen['tanggal_pengajuan']),
          ),
        );
        if (tanggalAcuan == null) return false;
        return tanggalAcuan.year == now.year && tanggalAcuan.month == now.month;
      }).length;

      final apdRes = await _supabase
          .from('apd')
          .select('id,stok,min_stok,is_aktif');
      final apdRows = _asMapList(apdRes);
      final lowStockApdIds = <String>{};
      for (final apd in apdRows) {
        if (!_isTrue(apd['is_aktif'])) continue;
        final stok = int.tryParse('${apd['stok'] ?? 0}') ?? 0;
        final minStok = int.tryParse('${apd['min_stok'] ?? 0}') ?? 0;
        if (stok <= minStok) {
          final id = _readText(apd['id']);
          if (id.isNotEmpty) lowStockApdIds.add(id);
        }
      }
      final stokMenipis = lowStockApdIds.length;

      var bandingMenunggu = 0;
      try {
        final banding = await _supabase
            .from('bantuan_login')
            .select('id')
            .eq('status', 'menunggu');
        bandingMenunggu = _asMapList(banding).length;
      } catch (_) {
        bandingMenunggu = 0;
      }

      final kendalaRows = await _queryLaporanKendalaRows();
      final laporanKendalaMenungguIds = _extractPendingLaporanIds(kendalaRows);
      final laporanKendalaMenungguTimestamps = _extractPendingLaporanTimestamps(
        kendalaRows,
      );

      // PENGAJUAN TERBARU: Menampilkan dokumen yang menunggu
      final pengajuanTerbaru = <Map<String, dynamic>>[];
      for (final dokumen in dokumenRows) {
        if (_normalizeStatus(dokumen['status']?.toString()) != 'menunggu') {
          continue;
        }
        final idDokumen = _readText(dokumen['id']);
        final karyawan = karyawanMap[_readText(dokumen['id_karyawan'])];
        final items = itemsByDokumen[idDokumen] ?? [];

        // Buat nama APD summary
        final namaApdList = <String>[];
        for (final item in items) {
          final apd = apdMap[_readText(item['id_apd'])];
          final nama = _readText(apd?['nama_apd'], fallback: '-');
          namaApdList.add(nama);
        }

        pengajuanTerbaru.add({
          'id_pengajuan': idDokumen,
          'tanggal_pengajuan': _readText(dokumen['tanggal_pengajuan']),
          'status_pengajuan': _displayStatusPengajuan(dokumen['status']),
          'username_karyawan': _readText(karyawan?['username']),
          'nama_lengkap': _readText(
            karyawan?['nama_lengkap'],
            fallback: _readText(karyawan?['username'], fallback: '-'),
          ),
          'jabatan': _readText(karyawan?['jabatan'], fallback: '-'),
          'nama_apd': namaApdList.isNotEmpty ? namaApdList.join(', ') : '-',
          'jumlah_item': items.length,
        });
        if (pengajuanTerbaru.length >= 7) break;
      }

      // GRAFIK: Menggunakan itemRows untuk data per item
      final grafik = <Map<String, dynamic>>[];
      if (mode == 'mingguan') {
        final startWeek = _startOfWeekMonday(now.toLocal());
        for (var i = 0; i < 7; i++) {
          final targetDate = startWeek.add(Duration(days: i));
          var total = 0;
          var menunggu = 0;
          var disetujui = 0;
          var lowStock = 0;
          for (final item in itemRows) {
            // Ambil tanggal dari parent dokumen
            final idDokumen = _readText(item['id_pengajuan']);
            final dokumen = dokumenMap[idDokumen];
            if (dokumen == null) continue;
            final tanggal = _parseDate(dokumen['tanggal_pengajuan'])?.toLocal();
            if (tanggal == null) continue;
            final dateOnly = _toDateOnly(tanggal);
            if (dateOnly != targetDate) continue;
            total++;
            final status = _normalizeStatus(item['status']?.toString());
            if (status == 'menunggu') menunggu++;
            if (_isStatusDisetujuiPengajuan(status)) disetujui++;
            if (lowStockApdIds.contains(_readText(item['id_apd']))) lowStock++;
          }
          grafik.add({
            'periode_key':
                '${targetDate.year}-${_pad2(targetDate.month)}-${_pad2(targetDate.day)}',
            'tanggal':
                '${targetDate.year}-${_pad2(targetDate.month)}-${_pad2(targetDate.day)}',
            'label':
                '${_weekdayShortLabel(targetDate.weekday)} ${_pad2(targetDate.day)}',
            'menunggu': menunggu,
            'disetujui': disetujui,
            'stok_menipis': lowStock,
            'total_masuk': total,
          });
        }
      } else if (mode == 'bulanan') {
        final lastDay = DateTime(tahunRef, bulanRef + 1, 0).day;
        for (var day = 1; day <= lastDay; day++) {
          final targetDate = DateTime(tahunRef, bulanRef, day);
          var total = 0;
          var menunggu = 0;
          var disetujui = 0;
          var lowStock = 0;
          for (final item in itemRows) {
            // Ambil tanggal dari parent dokumen
            final idDokumen = _readText(item['id_pengajuan']);
            final dokumen = dokumenMap[idDokumen];
            if (dokumen == null) continue;
            final tanggal = _parseDate(dokumen['tanggal_pengajuan'])?.toLocal();
            if (tanggal == null) continue;
            if (tanggal.year != tahunRef ||
                tanggal.month != bulanRef ||
                tanggal.day != day) {
              continue;
            }
            total++;
            final status = _normalizeStatus(item['status']?.toString());
            if (status == 'menunggu') menunggu++;
            if (_isStatusDisetujuiPengajuan(status)) disetujui++;
            if (lowStockApdIds.contains(_readText(item['id_apd']))) lowStock++;
          }
          grafik.add({
            'periode_key':
                '${targetDate.year}-${_pad2(targetDate.month)}-${_pad2(targetDate.day)}',
            'tanggal':
                '${targetDate.year}-${_pad2(targetDate.month)}-${_pad2(targetDate.day)}',
            'label': '$day',
            'menunggu': menunggu,
            'disetujui': disetujui,
            'stok_menipis': lowStock,
            'total_masuk': total,
          });
        }
      } else {
        for (var month = 1; month <= 12; month++) {
          var total = 0;
          var menunggu = 0;
          var disetujui = 0;
          var lowStock = 0;
          for (final item in itemRows) {
            // Ambil tanggal dari parent dokumen
            final idDokumen = _readText(item['id_pengajuan']);
            final dokumen = dokumenMap[idDokumen];
            if (dokumen == null) continue;
            final tanggal = _parseDate(dokumen['tanggal_pengajuan'])?.toLocal();
            if (tanggal == null ||
                tanggal.year != tahunRef ||
                tanggal.month != month) {
              continue;
            }
            total++;
            final status = _normalizeStatus(item['status']?.toString());
            if (status == 'menunggu') menunggu++;
            if (_isStatusDisetujuiPengajuan(status)) disetujui++;
            if (lowStockApdIds.contains(_readText(item['id_apd']))) lowStock++;
          }
          grafik.add({
            'periode_key': '$tahunRef-${_pad2(month)}',
            'label': _monthShortLabel(month),
            'bulan': '$tahunRef-${_pad2(month)}',
            'menunggu': menunggu,
            'disetujui': disetujui,
            'stok_menipis': lowStock,
            'total_masuk': total,
          });
        }
      }

      final opsiTahun = dokumenRows
          .map((d) => _parseDate(d['tanggal_pengajuan'])?.year)
          .whereType<int>()
          .toSet()
          .toList();
      opsiTahun.add(now.year);
      opsiTahun.sort((a, b) => b.compareTo(a));

      return {
        'status': 'sukses',
        'data': {
          'statistik': {
            'pengajuan_menunggu': pengajuanMenunggu,
            'total_disetujui_bulan_ini': disetujuiBulanIni,
            'stok_apd_menipis': stokMenipis,
            'banding_login_menunggu': bandingMenunggu,
            'laporan_kendala_menunggu': laporanKendalaMenungguIds.length,
          },
          'laporan_kendala_menunggu_ids': laporanKendalaMenungguIds,
          'laporan_kendala_menunggu_timestamps':
              laporanKendalaMenungguTimestamps,
          'pengajuan_terbaru': pengajuanTerbaru,
          'grafik_bulanan': grafik,
          'meta_grafik': {'mode': mode, 'tahun': tahunRef, 'bulan': bulanRef},
          'opsi_tahun': opsiTahun,
        },
      };
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal memuat dashboard admin: $e'};
    }
  }

  Future<Map<String, dynamic>> beritaAdminList({
    bool includeNonaktif = true,
  }) async {
    try {
      var q = _supabase.from('berita').select();
      if (!includeNonaktif) q = q.eq('is_aktif', true);
      final res = await q.order('created_at', ascending: false);
      final mapped = _asMapList(res)
          .map(
            (row) => <String, dynamic>{
              ...row,
              'id_berita': _readText(row['id']),
              'is_aktif': _flag(row['is_aktif']),
              'gambar': _readText(
                row['gambar'],
                fallback: _readText(row['gambar_berita']),
              ),
              'tanggal': _readText(
                row['tanggal'],
                fallback: _readText(row['created_at']),
              ),
            },
          )
          .toList();
      return {'status': 'sukses', 'data': mapped};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> beritaAdminSimpan({
    String? idBerita,
    required String judul,
    required String ringkasan,
    required String isi,
    required String kategori,
    required bool isAktif,
    required String usernameAdmin,
    bool kirimNotifikasi = false,
    bool hapusGambar = false,
    File? gambarBerita,
  }) async {
    try {
      final admin = await _supabase
          .from('admin')
          .select('id')
          .eq('username', usernameAdmin)
          .maybeSingle();
      String? img;
      if (gambarBerita != null) img = await _uploadFile(gambarBerita, 'berita');
      final data = <String, dynamic>{
        'judul': judul,
        'ringkasan': ringkasan,
        'isi': isi,
        'kategori': kategori,
        'is_aktif': isAktif ? 1 : 0,
        'id_admin': admin?['id'],
      };
      if (img != null) data['gambar_berita'] = img;
      if (hapusGambar) data['gambar_berita'] = null;

      final targetId = _readText(idBerita);
      final isEdit = targetId.isNotEmpty && targetId.toLowerCase() != 'null';
      if (!isEdit) {
        await _supabase.from('berita').insert(data);
      } else {
        final current = await _supabase
            .from('berita')
            .select('gambar_berita')
            .eq('id', targetId)
            .maybeSingle();

        await _supabase.from('berita').update(data).eq('id', targetId);

        if ((img != null || hapusGambar) &&
            current != null &&
            _readText(current['gambar_berita']).isNotEmpty) {
          await _hapusFileStorage(_readText(current['gambar_berita']));
        }
      }

      if (kirimNotifikasi && isAktif) {
        final judulNotif = isEdit ? 'Berita Diperbarui' : 'Berita Baru';
        await _kirimNotifikasiMassal(
          judul: judulNotif,
          pesan:
              '$judul\n${_readText(ringkasan, fallback: _readText(isi, fallback: 'Silakan cek detail berita terbaru.'))}',
          tipeNotifikasi: 'berita',
          payload: {
            'id_berita': targetId,
            'judul': judul,
            'kategori': kategori,
          },
        );
      }
      return {'status': 'sukses', 'pesan': 'Berita disimpan'};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> beritaAdminHapus(String idBerita) async {
    try {
      final targetId = idBerita.trim();
      if (targetId.isEmpty || targetId.toLowerCase() == 'null') {
        return {'status': 'gagal', 'pesan': 'ID berita tidak valid'};
      }
      final current = await _supabase
          .from('berita')
          .select('gambar_berita')
          .eq('id', targetId)
          .maybeSingle();

      await _supabase.from('berita').delete().eq('id', targetId);

      if (current != null && _readText(current['gambar_berita']).isNotEmpty) {
        await _hapusFileStorage(_readText(current['gambar_berita']));
      }
      return {'status': 'sukses'};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> lupaSandiAdminCekMetode(String username) async {
    try {
      final user = username.trim();
      final admin = await _supabase
          .from('admin')
          .select(
            'username,pertanyaan_1,jawaban_1,pertanyaan_2,jawaban_2,pertanyaan_3,jawaban_3',
          )
          .eq('username', user)
          .maybeSingle();
      if (admin == null) {
        return {'status': 'gagal', 'pesan': 'Admin tidak ditemukan'};
      }

      final punyaPertanyaan =
          _readText(admin['pertanyaan_1']).isNotEmpty &&
          _readText(admin['jawaban_1']).isNotEmpty &&
          _readText(admin['pertanyaan_2']).isNotEmpty &&
          _readText(admin['jawaban_2']).isNotEmpty &&
          _readText(admin['pertanyaan_3']).isNotEmpty &&
          _readText(admin['jawaban_3']).isNotEmpty;

      var punyaKode = _kodePemulihanAdminSementara.containsKey(
        user.toLowerCase(),
      );
      if (!punyaKode) {
        try {
          final kodeRow = await _supabase
              .from('bantuan_login')
              .select('password_diingat')
              .eq('username', user)
              .eq('status', 'kode_admin')
              .eq('alasan_kendala', 'kode_pemulihan_admin')
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          punyaKode = _readText(kodeRow?['password_diingat']).isNotEmpty;
        } catch (_) {
          punyaKode = false;
        }
      }

      return {
        'status': 'sukses',
        'data': {
          'punya_kode': punyaKode,
          'punya_pertanyaan': punyaPertanyaan,
          'pertanyaan_1': _readText(admin['pertanyaan_1']),
          'pertanyaan_2': _readText(admin['pertanyaan_2']),
          'pertanyaan_3': _readText(admin['pertanyaan_3']),
        },
      };
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal cek metode pemulihan: $e'};
    }
  }

  Future<Map<String, dynamic>> generateKodePemulihanAdmin(
    String username,
  ) async {
    try {
      final user = username.trim();
      if (user.isEmpty) {
        return {'status': 'gagal', 'pesan': 'Username admin tidak valid'};
      }
      final admin = await _supabase
          .from('admin')
          .select('username,nama_lengkap')
          .eq('username', user)
          .maybeSingle();
      if (admin == null) {
        return {'status': 'gagal', 'pesan': 'Admin tidak ditemukan'};
      }

      final random = math.Random.secure();
      final kode = (100000 + random.nextInt(900000)).toString();
      _kodePemulihanAdminSementara[user.toLowerCase()] = kode;

      try {
        await _supabase
            .from('bantuan_login')
            .delete()
            .eq('username', user)
            .eq('status', 'kode_admin')
            .eq('alasan_kendala', 'kode_pemulihan_admin');
        await _supabase.from('bantuan_login').insert({
          'username': user,
          'nama_lengkap': _readText(admin['nama_lengkap'], fallback: user),
          'password_diingat': kode,
          'alasan_kendala': 'kode_pemulihan_admin',
          'status': 'kode_admin',
        });
      } catch (_) {
        // Fallback ke cache memori jika tabel bantuan_login gagal.
      }

      return {
        'status': 'sukses',
        'pesan': 'Kode pemulihan berhasil dibuat',
        'data': {'kode_numerik': kode},
      };
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal membuat kode pemulihan: $e'};
    }
  }

  Future<Map<String, dynamic>> lupaSandiAdminVerifikasiKode(
    String username,
    String kode,
  ) async {
    try {
      final user = username.trim();
      final code = kode.trim();
      if (user.isEmpty || code.isEmpty) {
        return {'status': 'gagal', 'pesan': 'Username dan kode wajib diisi'};
      }

      var kodeTersimpan = _kodePemulihanAdminSementara[user.toLowerCase()];
      if (_readText(kodeTersimpan).isEmpty) {
        try {
          final kodeRow = await _supabase
              .from('bantuan_login')
              .select('password_diingat')
              .eq('username', user)
              .eq('status', 'kode_admin')
              .eq('alasan_kendala', 'kode_pemulihan_admin')
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          kodeTersimpan = _readText(kodeRow?['password_diingat']);
        } catch (_) {
          kodeTersimpan = '';
        }
      }

      if (_readText(kodeTersimpan).isEmpty) {
        return {
          'status': 'gagal',
          'pesan': 'Kode pemulihan belum dibuat. Hubungi Super Admin.',
        };
      }
      if (_readText(kodeTersimpan) != code) {
        return {'status': 'gagal', 'pesan': 'Kode pemulihan tidak sesuai'};
      }
      return {'status': 'sukses', 'pesan': 'Verifikasi kode berhasil'};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal verifikasi kode: $e'};
    }
  }

  Future<Map<String, dynamic>> lupaSandiAdminVerifikasiPertanyaan(
    String username,
    String j1,
    String j2,
    String j3,
  ) async {
    try {
      final user = username.trim();
      final admin = await _supabase
          .from('admin')
          .select('jawaban_1,jawaban_2,jawaban_3')
          .eq('username', user)
          .maybeSingle();
      if (admin == null) {
        return {'status': 'gagal', 'pesan': 'Admin tidak ditemukan'};
      }

      final jawaban1 = _readText(admin['jawaban_1']).toLowerCase();
      final jawaban2 = _readText(admin['jawaban_2']).toLowerCase();
      final jawaban3 = _readText(admin['jawaban_3']).toLowerCase();
      if (jawaban1.isEmpty || jawaban2.isEmpty || jawaban3.isEmpty) {
        return {
          'status': 'gagal',
          'pesan': 'Pertanyaan keamanan belum diatur pada akun ini',
        };
      }

      final isValid =
          jawaban1 == _readText(j1).toLowerCase() &&
          jawaban2 == _readText(j2).toLowerCase() &&
          jawaban3 == _readText(j3).toLowerCase();
      if (!isValid) {
        return {'status': 'gagal', 'pesan': 'Jawaban keamanan tidak sesuai'};
      }
      return {'status': 'sukses', 'pesan': 'Verifikasi jawaban berhasil'};
    } catch (e) {
      return {
        'status': 'gagal',
        'pesan': 'Gagal verifikasi pertanyaan keamanan: $e',
      };
    }
  }

  Future<Map<String, dynamic>> lupaSandiAdminGantiPassword(
    String username,
    String passwordBaru,
  ) async {
    try {
      final user = username.trim();
      final passBaru = passwordBaru.trim();
      if (user.isEmpty || passBaru.isEmpty) {
        return {
          'status': 'gagal',
          'pesan': 'Username dan password wajib diisi',
        };
      }
      await _supabase
          .from('admin')
          .update({'password': passBaru})
          .eq('username', user);
      _gagalLoginAdmin.remove(user.toLowerCase());
      _kodePemulihanAdminSementara.remove(user.toLowerCase());
      try {
        await _supabase
            .from('bantuan_login')
            .delete()
            .eq('username', user)
            .eq('status', 'kode_admin')
            .eq('alasan_kendala', 'kode_pemulihan_admin');
        await _supabase
            .from('bantuan_login')
            .delete()
            .eq('username', user)
            .eq('status', 'admin_gagal_login');
      } catch (_) {
        // Abaikan jika cleanup kode tidak tersedia.
      }
      return {'status': 'sukses', 'pesan': 'Password admin berhasil diubah'};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal ubah password: $e'};
    }
  }

  Future<Map<String, dynamic>> kirimBantuanLogin({
    required String username,
    required String namaLengkap,
    required String passwordDiingat,
    required String alasanKendala,
  }) async {
    try {
      final user = username.trim();
      if (user.isEmpty ||
          namaLengkap.trim().isEmpty ||
          passwordDiingat.trim().isEmpty ||
          alasanKendala.trim().isEmpty) {
        return {'status': 'gagal', 'pesan': 'Semua data bantuan wajib diisi'};
      }

      final karyawan = await _supabase
          .from('karyawan')
          .select('id,username')
          .eq('username', user)
          .maybeSingle();
      if (karyawan == null) {
        return {
          'status': 'gagal',
          'pesan': 'Username karyawan tidak ditemukan',
        };
      }

      final pending = await _supabase
          .from('bantuan_login')
          .select('id')
          .eq('username', user)
          .eq('status', 'menunggu')
          .maybeSingle();

      if (pending != null) {
        return {
          'status': 'gagal',
          'pesan': 'Anda sudah mengirimkan laporan banding. Mohon tunggu proses dari admin.',
        };
      }

      await _supabase.from('bantuan_login').insert({
        'username': user,
        'nama_lengkap': namaLengkap.trim(),
        'password_diingat': passwordDiingat.trim(),
        'alasan_kendala': alasanKendala.trim(),
        'status': 'menunggu',
      });

      return {
        'status': 'sukses',
        'pesan': 'Permintaan bantuan login berhasil dikirim ke admin',
      };
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal mengirim bantuan login: $e'};
    }
  }

  Future<Map<String, dynamic>> daftarBantuanLogin() async {
    try {
      final rows = await _supabase
          .from('bantuan_login')
          .select()
          .order('created_at', ascending: false);
      final mapped = _asMapList(rows)
          .where((row) {
            final status = _normalizeStatus(row['status']?.toString());
            return status == 'menunggu';
          })
          .map(
            (row) => <String, dynamic>{
              ...row,
              'id_bantuan': _readText(row['id']),
              'username_karyawan': _readText(row['username']),
              'nama_lengkap': _readText(row['nama_lengkap'], fallback: '-'),
              'password_diingat': _readText(row['password_diingat']),
              'alasan_kendala': _readText(row['alasan_kendala']),
              'status_baca':
                  _normalizeStatus(row['status']?.toString()) == 'menunggu'
                  ? 0
                  : 1,
              'created_at': _readText(row['created_at']),
            },
          )
          .toList();
      return {'status': 'sukses', 'data': mapped};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal memuat bantuan login: $e'};
    }
  }

  Future<Map<String, dynamic>> ubahStatusBantuanLogin({
    required String idBantuan,
    required String aksi,
  }) async {
    try {
      final targetId = idBantuan.trim();
      if (targetId.isEmpty || targetId.toLowerCase() == 'null') {
        return {'status': 'gagal', 'pesan': 'ID bantuan tidak valid'};
      }
      final row = await _supabase
          .from('bantuan_login')
          .select('id,username,status')
          .eq('id', targetId)
          .maybeSingle();
      if (row == null) {
        return {'status': 'gagal', 'pesan': 'Data bantuan tidak ditemukan'};
      }

      final tindakan = _normalizeStatus(aksi);
      if (tindakan == 'hapus') {
        await _supabase.from('bantuan_login').delete().eq('id', targetId);
        return {'status': 'sukses', 'pesan': 'Data bantuan berhasil dihapus'};
      }

      if (tindakan == 'tandai_baca') {
        await _supabase
            .from('bantuan_login')
            .delete()
            .eq('id', targetId);
        return {'status': 'sukses', 'pesan': 'Bantuan ditandai sudah dibaca dan dihapus'};
      }

      if (tindakan == 'aktifkan') {
        final usernameKaryawan = _readText(row['username']);
        String idKaryawan = '';
        if (usernameKaryawan.isNotEmpty) {
          final karyawan = await _supabase
              .from('karyawan')
              .select('id')
              .eq('username', usernameKaryawan)
              .maybeSingle();
          idKaryawan = _readText(karyawan?['id']);
          
          final bandingLengkap = await _supabase.from('bantuan_login').select('password_diingat').eq('id', targetId).maybeSingle();
          final passBaru = _readText(bandingLengkap?['password_diingat']);

          final Map<String, dynamic> updateKaryawan = {
            'status': 'aktif',
            'banned_until': null
          };

          if (passBaru.isNotEmpty) {
            updateKaryawan['password'] = passBaru;
          }

          await _supabase
              .from('karyawan')
              .update(updateKaryawan)
              .eq('username', usernameKaryawan);
        }
        await _supabase
            .from('bantuan_login')
            .delete()
            .eq('username', usernameKaryawan);
        if (idKaryawan.isNotEmpty) {
          await _kirimNotifikasiKaryawan(
            idKaryawan: idKaryawan,
            judul: 'Akun Berhasil Diaktifkan',
            pesan:
                'Akun Anda telah diaktifkan kembali oleh admin. Silakan login ulang.',
            tipeNotifikasi: 'akun',
          );
        }
        _gagalLoginKaryawan.remove(usernameKaryawan.toLowerCase());
        return {
          'status': 'sukses',
          'pesan': 'Akun karyawan berhasil diaktifkan',
        };
      }

      return {'status': 'gagal', 'pesan': 'Aksi bantuan login tidak dikenal'};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal ubah status bantuan: $e'};
    }
  }

  Future<Map<String, dynamic>> hapusDataSpesifik(String jenis) async {
    try {
      final key = _normalizeStatus(jenis);
      switch (key) {
        case 'karyawan':
          await _supabase
              .from('notifikasi_karyawan')
              .delete()
              .not('id', 'is', null);
          await _supabase.from('pengajuan').delete().not('id', 'is', null);
          try {
            await _supabase
                .from('laporan_kendala')
                .delete()
                .not('id', 'is', null);
          } on PostgrestException catch (e) {
            if (!_isMissingTableError(e, 'laporan_kendala')) rethrow;
          }
          await _supabase.from('bantuan_login').delete().not('id', 'is', null);
          await _supabase.from('karyawan').delete().not('id', 'is', null);
          return {'status': 'sukses', 'pesan': 'Semua akun karyawan dihapus'};
        case 'notifikasi':
          await _supabase
              .from('notifikasi_karyawan')
              .delete()
              .not('id', 'is', null);
          return {
            'status': 'sukses',
            'pesan': 'Semua notifikasi karyawan berhasil dihapus',
          };
        case 'pengajuan':
          await _supabase.from('pengajuan').delete().not('id', 'is', null);
          return {'status': 'sukses', 'pesan': 'Semua pengajuan APD dihapus'};
        case 'laporan_kendala':
          try {
            await _supabase
                .from('laporan_kendala')
                .delete()
                .not('id', 'is', null);
          } on PostgrestException catch (e) {
            if (_isMissingTableError(e, 'laporan_kendala')) {
              return {
                'status': 'sukses',
                'pesan': 'Tabel laporan_kendala belum tersedia',
              };
            }
            rethrow;
          }
          return {
            'status': 'sukses',
            'pesan': 'Semua laporan kendala APD berhasil dihapus',
          };
        case 'master_apd':
          await _supabase.from('apd').update({'stok': 0}).not('id', 'is', null);
          return {'status': 'sukses', 'pesan': 'Semua stok APD direset ke nol'};
        case 'kalender':
          await _supabase
              .from('kalender_perusahaan')
              .delete()
              .not('id', 'is', null);
          return {'status': 'sukses', 'pesan': 'Semua agenda kalender dihapus'};
        case 'berita':
          await _supabase.from('berita').delete().not('id', 'is', null);
          return {'status': 'sukses', 'pesan': 'Semua berita berhasil dihapus'};
        default:
          return {'status': 'gagal', 'pesan': 'Jenis data tidak dikenali'};
      }
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal menghapus data: $e'};
    }
  }

  Future<Map<String, dynamic>> resetAplikasi() async {
    try {
      await _supabase
          .from('notifikasi_karyawan')
          .delete()
          .not('id', 'is', null);
      await _supabase.from('pengajuan').delete().not('id', 'is', null);
      try {
        await _supabase.from('laporan_kendala').delete().not('id', 'is', null);
      } on PostgrestException catch (e) {
        if (!_isMissingTableError(e, 'laporan_kendala')) rethrow;
      }
      await _supabase.from('bantuan_login').delete().not('id', 'is', null);
      await _supabase
          .from('kalender_perusahaan')
          .delete()
          .not('id', 'is', null);
      await _supabase.from('berita').delete().not('id', 'is', null);
      await _supabase.from('apd').delete().not('id', 'is', null);
      await _supabase.from('karyawan').delete().not('id', 'is', null);
      return {
        'status': 'sukses',
        'pesan': 'Reset aplikasi berhasil. Data admin tetap dipertahankan.',
      };
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal reset aplikasi: $e'};
    }
  }

  Future<Map<String, dynamic>> cekSesi({
    required String peran,
    required String username,
    required String sessionToken,
  }) async {
    try {
      final role = _normalizeStatus(peran);
      if (role == 'admin') {
        final admin = await _supabase
            .from('admin')
            .select('id, session_token, device_id, status')
            .eq('username', username)
            .maybeSingle();
        if (admin == null) {
          return {'status': 'expired', 'pesan': 'Akun admin tidak ditemukan'};
        }
        // Cek session token
        final dbToken = _readText(admin['session_token']);
        if (dbToken != sessionToken) {
          return {'status': 'expired', 'pesan': 'Session tidak valid'};
        }
        // Update last_active
        await _supabase
            .from('admin')
            .update({'last_active': DateTime.now().toIso8601String()})
            .eq('id', admin['id']);
        return {'status': 'sukses'};
      }

      final karyawan = await _supabase
          .from('karyawan')
          .select('id,status,banned_until,session_token,device_id')
          .eq('username', username)
          .maybeSingle();
      if (karyawan == null) {
        return {'status': 'expired', 'pesan': 'Akun karyawan tidak ditemukan'};
      }
      // Cek session token
      final dbToken = _readText(karyawan['session_token']);
      if (dbToken != sessionToken) {
        return {'status': 'expired', 'pesan': 'Session tidak valid'};
      }
      final status = _normalizeStatus(karyawan['status']?.toString());
      if (status == 'nonaktif') {
        return {'status': 'expired', 'pesan': 'Akun karyawan nonaktif'};
      }
      if (status == 'ban_sementara') {
        final bannedUntil = _parseDate(karyawan['banned_until']);
        if (bannedUntil != null && DateTime.now().isBefore(bannedUntil)) {
          return {
            'status': 'expired',
            'pesan': 'Akun sedang dibatasi sementara',
          };
        }
      }
      // Update last_active
      await _supabase
          .from('karyawan')
          .update({'last_active': DateTime.now().toIso8601String()})
          .eq('id', karyawan['id']);
      return {'status': 'sukses'};
    } catch (e) {
      return {'status': 'error', 'pesan': 'Gagal validasi sesi: $e'};
    }
  }

  Future<Map<String, dynamic>> tambahAdmin({
    required String username,
    required String password,
    required String namaLengkap,
    required String peranAdmin,
  }) async {
    try {
      final user = username.trim();
      if (user.isEmpty ||
          password.trim().isEmpty ||
          namaLengkap.trim().isEmpty) {
        return {'status': 'gagal', 'pesan': 'Semua data admin wajib diisi'};
      }

      final duplicate = await _supabase
          .from('admin')
          .select('id')
          .eq('username', user)
          .maybeSingle();
      if (duplicate != null) {
        return {'status': 'gagal', 'pesan': 'Username admin sudah digunakan'};
      }

      await _supabase.from('admin').insert({
        'username': user,
        'password': password.trim(),
        'nama_lengkap': namaLengkap.trim(),
        'peran_admin': (() {
          final normalized = _normalizeStatus(peranAdmin);
          if (normalized == 'biasa' || normalized.isEmpty) {
            return 'admin_biasa';
          }
          return peranAdmin;
        })(),
      });
      return {'status': 'sukses', 'pesan': 'Admin baru berhasil ditambahkan'};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal menambah admin: $e'};
    }
  }

  Future<Map<String, dynamic>> ambilAdminBiasa() async {
    try {
      final rows = await _supabase
          .from('admin')
          .select('id,username,nama_lengkap,peran_admin,created_at')
          .order('nama_lengkap', ascending: true);
      final mapped = _asMapList(rows)
          .where(
            (row) =>
                _normalizeStatus(row['peran_admin']?.toString()) !=
                'super_admin',
          )
          .map((row) {
            final peran = _readText(
              row['peran_admin'],
              fallback: 'admin_biasa',
            );
            final status = _normalizeStatus(peran).contains('nonaktif')
                ? 'nonaktif'
                : 'aktif';
            return <String, dynamic>{...row, 'status': status};
          })
          .toList();
      return {'status': 'sukses', 'data': mapped};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal mengambil data admin: $e'};
    }
  }

  Future<Map<String, dynamic>> kelolaAdmin({
    required String id,
    required String action,
    String? statusBaru,
  }) async {
    try {
      final targetId = id.trim();
      if (targetId.isEmpty || targetId.toLowerCase() == 'null') {
        return {'status': 'gagal', 'pesan': 'ID admin tidak valid'};
      }

      final aksi = _normalizeStatus(action);
      if (aksi == 'hapus') {
        await _supabase.from('admin').delete().eq('id', targetId);
        return {'status': 'sukses', 'pesan': 'Admin berhasil dihapus'};
      }

      if (aksi == 'nonaktif') {
        final targetStatus = _normalizeStatus(statusBaru);
        final peranBaru = targetStatus == 'nonaktif'
            ? 'admin_nonaktif'
            : 'admin_biasa';
        await _supabase
            .from('admin')
            .update({'peran_admin': peranBaru})
            .eq('id', targetId);
        return {
          'status': 'sukses',
          'pesan': 'Status admin berhasil diperbarui',
        };
      }

      return {'status': 'gagal', 'pesan': 'Aksi kelola admin tidak dikenali'};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal kelola admin: $e'};
    }
  }

  Future<Map<String, dynamic>> editProfilAdmin({
    required String usernameLama,
    required String usernameBaru,
    required String namaLengkap,
    required String password,
    String? passwordBaru,
    File? fotoProfil,
    String? pertanyaan1,
    String? jawaban1,
    String? pertanyaan2,
    String? jawaban2,
    String? pertanyaan3,
    String? jawaban3,
  }) async {
    try {
      final current = await _supabase
          .from('admin')
          .select('*')
          .eq('username', usernameLama)
          .maybeSingle();
      if (current == null) {
        return {'status': 'gagal', 'pesan': 'Data admin tidak ditemukan'};
      }

      if (_readText(current['password']) != password.trim()) {
        return {'status': 'gagal', 'pesan': 'Password konfirmasi tidak sesuai'};
      }

      final usernameBaruTrim = usernameBaru.trim();
      if (usernameBaruTrim != usernameLama) {
        final duplicate = await _supabase
            .from('admin')
            .select('id')
            .eq('username', usernameBaruTrim)
            .maybeSingle();
        if (duplicate != null) {
          return {
            'status': 'gagal',
            'pesan': 'Username admin sudah digunakan akun lain',
          };
        }
      }

      String? fotoPath;
      if (fotoProfil != null) {
        fotoPath = await _uploadFile(fotoProfil, 'profil');
        if (fotoPath == null) {
          return {'status': 'gagal', 'pesan': 'Gagal mengunggah foto profil'};
        }
      }

      final Map<String, dynamic> updateData = {
        'username': usernameBaruTrim,
        'nama_lengkap': namaLengkap.trim(),
        'password': _readText(passwordBaru).isEmpty
            ? password.trim()
            : passwordBaru!.trim(),
      };
      if (fotoPath != null) {
        updateData['foto_profil'] = fotoPath;
        if (_readText(current['foto_profil']).isNotEmpty) {
          await _hapusFileStorage(_readText(current['foto_profil']));
        }
      }

      final p1 = _readText(pertanyaan1);
      final p2 = _readText(pertanyaan2);
      final p3 = _readText(pertanyaan3);
      final j1 = _readText(jawaban1);
      final j2 = _readText(jawaban2);
      final j3 = _readText(jawaban3);
      final aktifkanPertanyaan =
          p1.isNotEmpty ||
          p2.isNotEmpty ||
          p3.isNotEmpty ||
          j1.isNotEmpty ||
          j2.isNotEmpty ||
          j3.isNotEmpty;

      if (aktifkanPertanyaan) {
        if (p1.isEmpty ||
            p2.isEmpty ||
            p3.isEmpty ||
            j1.isEmpty ||
            j2.isEmpty ||
            j3.isEmpty) {
          return {
            'status': 'gagal',
            'pesan': 'Pertanyaan dan jawaban keamanan harus lengkap',
          };
        }
        updateData['pertanyaan_1'] = p1;
        updateData['jawaban_1'] = j1;
        updateData['pertanyaan_2'] = p2;
        updateData['jawaban_2'] = j2;
        updateData['pertanyaan_3'] = p3;
        updateData['jawaban_3'] = j3;
      } else {
        updateData['pertanyaan_1'] = null;
        updateData['jawaban_1'] = null;
        updateData['pertanyaan_2'] = null;
        updateData['jawaban_2'] = null;
        updateData['pertanyaan_3'] = null;
        updateData['jawaban_3'] = null;
      }

      await _supabase.from('admin').update(updateData).eq('id', current['id']);
      final updated = await _supabase
          .from('admin')
          .select('*')
          .eq('id', current['id'])
          .maybeSingle();

      final oldKey = usernameLama.toLowerCase();
      final newKey = usernameBaruTrim.toLowerCase();
      _gagalLoginAdmin.remove(oldKey);
      if (usernameLama.trim() != usernameBaruTrim) {
        try {
          await _supabase
              .from('bantuan_login')
              .update({
                'username': usernameBaruTrim,
                'nama_lengkap': namaLengkap.trim(),
              })
              .eq('username', usernameLama)
              .inFilter('status', ['kode_admin', 'admin_gagal_login']);
        } catch (_) {
          // Abaikan jika sinkronisasi data bantuan tidak tersedia.
        }
      }
      if (oldKey != newKey &&
          _kodePemulihanAdminSementara.containsKey(oldKey)) {
        _kodePemulihanAdminSementara[newKey] =
            _kodePemulihanAdminSementara[oldKey]!;
        _kodePemulihanAdminSementara.remove(oldKey);
      }

      return {
        'status': 'sukses',
        'pesan': 'Profil admin berhasil diperbarui',
        'data': updated ?? updateData,
      };
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal memperbarui profil admin: $e'};
    }
  }

  // ============================================================
  // DOKUMEN PENGAJUAN APD (Multi-APD + Tanda Tangan)
  // ============================================================

  /// Menyimpan dokumen pengajuan APD multi-item dengan tanda tangan karyawan.
  Future<Map<String, dynamic>> simpanDokumenPengajuan({
    required String username,
    required List<Map<String, dynamic>> items,
    required String tandaTanganKaryawan,
  }) async {
    try {
      if (items.isEmpty) {
        return {'status': 'gagal', 'pesan': 'Pilih minimal 1 APD'};
      }
      if (tandaTanganKaryawan.isEmpty) {
        return {'status': 'gagal', 'pesan': 'Tanda tangan karyawan wajib diisi'};
      }

      final karyawan = await _supabase
          .from('karyawan')
          .select('id')
          .eq('username', username)
          .maybeSingle();
      if (karyawan == null) {
        return {'status': 'gagal', 'pesan': 'Karyawan tidak valid'};
      }

      // Validasi stok semua APD
      for (final item in items) {
        final idApd = _readText(item['id_apd']);
        if (idApd.isEmpty) {
          return {'status': 'gagal', 'pesan': 'ID APD tidak valid'};
        }
        final apd = await _supabase
            .from('apd')
            .select('id,stok,is_aktif,nama_apd')
            .eq('id', idApd)
            .maybeSingle();
        if (apd == null) {
          return {'status': 'gagal', 'pesan': 'APD tidak ditemukan'};
        }
        if (!_isTrue(apd['is_aktif'])) {
          return {
            'status': 'gagal',
            'pesan': 'APD "${apd['nama_apd']}" sedang dinonaktifkan',
          };
        }
        final stok = int.tryParse('${apd['stok'] ?? 0}') ?? 0;
        final jumlah = int.tryParse('${item['jumlah'] ?? 1}') ?? 1;
        if (stok < jumlah) {
          return {
            'status': 'gagal',
            'pesan':
                'Stok APD "${apd['nama_apd']}" tidak mencukupi (tersedia: $stok)',
          };
        }
      }

      // Insert dokumen utama
      final dokumenResult = await _supabase
          .from('dokumen_pengajuan')
          .insert({
            'id_karyawan': karyawan['id'],
            'tanda_tangan_karyawan': tandaTanganKaryawan,
            'status': 'menunggu',
            'tanggal_pengajuan': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      final idDokumen = _readText(dokumenResult['id']);

      // Insert semua item APD
      for (final item in items) {
        await _supabase.from('dokumen_pengajuan_item').insert({
          'id_pengajuan': idDokumen,
          'id_apd': _readText(item['id_apd']),
          'ukuran': _readText(item['ukuran']),
          'alasan': _readText(item['alasan']),
          'jumlah': int.tryParse('${item['jumlah'] ?? 1}') ?? 1,
        });
      }

      return {
        'status': 'sukses',
        'pesan': 'Dokumen pengajuan APD berhasil dikirim',
        'data': {'id_pengajuan': idDokumen},
      };
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal menyimpan dokumen: $e'};
    }
  }

  /// Mengambil daftar semua dokumen pengajuan (untuk admin).
  Future<Map<String, dynamic>> daftarDokumenPengajuan({
    String? filterStatus,
  }) async {
    try {
      var query = _supabase
          .from('dokumen_pengajuan')
          .select('*')
          .order('tanggal_pengajuan', ascending: false);

      if (filterStatus != null && filterStatus.isNotEmpty) {
        if (filterStatus == 'selesai') {
          query = _supabase
              .from('dokumen_pengajuan')
              .select('*')
              .inFilter('status', ['selesai', 'sebagian_diterima'])
              .order('tanggal_pengajuan', ascending: false);
        } else {
          query = _supabase
              .from('dokumen_pengajuan')
              .select('*')
              .eq('status', filterStatus)
              .order('tanggal_pengajuan', ascending: false);
        }
      }

      final rows = _asMapList(await query);

      // Enrich with karyawan & item info
      final enriched = <Map<String, dynamic>>[];
      for (final row in rows) {
        final idKaryawan = _readText(row['id_karyawan']);
        final idDokumen = _readText(row['id']);

        // Ambil data karyawan
        String namaKaryawan = '-';
        String departemen = '-';
        String jabatan = '-';
        if (idKaryawan.isNotEmpty) {
          final karyawan = await _supabase
              .from('karyawan')
              .select('nama_lengkap,departemen,jabatan')
              .eq('id', idKaryawan)
              .maybeSingle();
          namaKaryawan =
              _readText(karyawan?['nama_lengkap'], fallback: '-');
          departemen = _readText(karyawan?['departemen'], fallback: '-');
          jabatan = _readText(karyawan?['jabatan'], fallback: '-');
        }

        // Ambil jumlah item
        final itemRows = _asMapList(
          await _supabase
              .from('dokumen_pengajuan_item')
              .select('id')
              .eq('id_pengajuan', idDokumen),
        );

        // Ambil nama admin (jika sudah diproses)
        String namaAdmin = '-';
        final idAdmin = _readText(row['id_admin']);
        if (idAdmin.isNotEmpty) {
          final admin = await _supabase
              .from('admin')
              .select('nama_lengkap')
              .eq('id', idAdmin)
              .maybeSingle();
          namaAdmin = _readText(admin?['nama_lengkap'], fallback: '-');
        }

        enriched.add({
          ...row.map((key, value) => MapEntry('$key', value)),
          'nama_karyawan': namaKaryawan,
          'departemen': departemen,
          'jabatan': jabatan,
          'jumlah_item': itemRows.length,
          'nama_admin': namaAdmin,
        });
      }

      return {'status': 'sukses', 'data': enriched};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal memuat dokumen: $e'};
    }
  }

  /// Mengambil detail lengkap satu dokumen pengajuan beserta item-itemnya.
  Future<Map<String, dynamic>> detailDokumenPengajuan(String idDokumen) async {
    try {
      final dokumen = await _supabase
          .from('dokumen_pengajuan')
          .select('*')
          .eq('id', idDokumen)
          .maybeSingle();
      if (dokumen == null) {
        return {'status': 'gagal', 'pesan': 'Dokumen tidak ditemukan'};
      }

      // Ambil data karyawan
      final idKaryawan = _readText(dokumen['id_karyawan']);
      Map<String, dynamic> profilKaryawan = {};
      if (idKaryawan.isNotEmpty) {
        final karyawan = await _supabase
            .from('karyawan')
            .select(
              'id,username,nama_lengkap,jabatan,departemen,lokasi_kerja',
            )
            .eq('id', idKaryawan)
            .maybeSingle();
        if (karyawan != null) {
          profilKaryawan =
              karyawan.map((key, value) => MapEntry('$key', value));
        }
      }

      // Ambil item-item APD
      final itemRows = _asMapList(
        await _supabase
            .from('dokumen_pengajuan_item')
            .select('*')
            .eq('id_pengajuan', idDokumen),
      );

      final enrichedItems = <Map<String, dynamic>>[];
      for (final item in itemRows) {
        final idApd = _readText(item['id_apd']);
        String namaApd = '-';
        String satuan = 'pcs';
        if (idApd.isNotEmpty) {
          final apd = await _supabase
              .from('apd')
              .select('nama_apd,satuan')
              .eq('id', idApd)
              .maybeSingle();
          namaApd = _readText(apd?['nama_apd'], fallback: '-');
          satuan = _readText(apd?['satuan'], fallback: 'pcs');
        }
        enrichedItems.add({
          ...item.map((key, value) => MapEntry('$key', value)),
          'nama_apd': namaApd,
          'satuan': satuan,
        });
      }

      // Ambil data admin (jika ada)
      Map<String, dynamic> profilAdmin = {};
      final idAdmin = _readText(dokumen['id_admin']);
      if (idAdmin.isNotEmpty) {
        final admin = await _supabase
            .from('admin')
            .select('id,nama_lengkap')
            .eq('id', idAdmin)
            .maybeSingle();
        if (admin != null) {
          profilAdmin = admin.map((key, value) => MapEntry('$key', value));
        }
      }

      return {
        'status': 'sukses',
        'data': {
          'dokumen':
              dokumen.map((key, value) => MapEntry('$key', value)),
          'karyawan': profilKaryawan,
          'admin': profilAdmin,
          'items': enrichedItems,
        },
      };
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal memuat detail dokumen: $e'};
    }
  }

  /// Admin memproses dokumen pengajuan (terima/tolak).
  Future<Map<String, dynamic>> prosesDokumenPengajuan({
    required String idDokumen,
    required String status,
    required String usernameAdmin,
    String? catatan,
    String? lokasiPengambilan,
  }) async {
    try {
      final admin = await _supabase
          .from('admin')
          .select('id,nama_lengkap,tanda_tangan')
          .eq('username', usernameAdmin)
          .maybeSingle();
      if (admin == null) {
        return {'status': 'gagal', 'pesan': 'Admin tidak valid'};
      }

      final dokumen = await _supabase
          .from('dokumen_pengajuan')
          .select('id,id_karyawan,status')
          .eq('id', idDokumen)
          .maybeSingle();
      if (dokumen == null) {
        return {'status': 'gagal', 'pesan': 'Dokumen tidak ditemukan'};
      }
      if (dokumen['status'] != 'menunggu') {
        return {'status': 'gagal', 'pesan': 'Dokumen sudah diproses sebelumnya'};
      }

      final payload = <String, dynamic>{
        'status': status,
        'id_admin': admin['id'],
        'tanggal_proses': DateTime.now().toIso8601String(),
      };

      // Jika diterima, tambahkan tanda tangan admin
      if (status == 'diterima') {
        final ttdAdmin = _readText(admin['tanda_tangan']);
        if (ttdAdmin.isNotEmpty) {
          payload['tanda_tangan_admin'] = ttdAdmin;
        }

        // Ambil semua item untuk mengurangi stok
        final items = _asMapList(
          await _supabase
              .from('dokumen_pengajuan_item')
              .select('id_apd,jumlah')
              .eq('id_pengajuan', idDokumen),
        );

        // Langsung kurangi stok tanpa validasi
        for (final item in items) {
          final idApd = _readText(item['id_apd']);
          final jumlah = int.tryParse('${item['jumlah'] ?? 1}') ?? 1;
          if (idApd.isNotEmpty) {
            final apd = await _supabase
                .from('apd')
                .select('id,stok')
                .eq('id', idApd)
                .maybeSingle();
            if (apd != null) {
              final stok = int.tryParse('${apd['stok'] ?? 0}') ?? 0;
              await _supabase
                  .from('apd')
                  .update({'stok': stok - jumlah})
                  .eq('id', idApd);
            }
          }
        }
      }

      if (catatan != null && catatan.isNotEmpty) {
        payload['catatan_admin'] = catatan;
      }

      if (lokasiPengambilan != null && lokasiPengambilan.isNotEmpty) {
        payload['lokasi_pengambilan'] = lokasiPengambilan;
      }

      await _supabase
          .from('dokumen_pengajuan')
          .update(payload)
          .eq('id', idDokumen);

      // Kirim notifikasi ke karyawan
      final idKaryawan = _readText(dokumen['id_karyawan']);
      if (idKaryawan.isNotEmpty) {
        final judul = status == 'diterima'
            ? 'Dokumen Pengajuan APD Diterima'
            : 'Dokumen Pengajuan APD Ditolak';
        final pesan = status == 'diterima'
            ? 'Pengajuan APD Anda telah diterima oleh admin ${admin['nama_lengkap']}. Silakan buka dokumen penerimaan.'
            : 'Pengajuan APD Anda ditolak oleh admin. ${catatan != null && catatan.isNotEmpty ? 'Catatan: $catatan' : ''}';

        await _kirimNotifikasiKaryawan(
          idKaryawan: idKaryawan,
          judul: judul,
          pesan: pesan,
          tipeNotifikasi: 'dokumen_pengajuan',
          payload: {
            'id_pengajuan': idDokumen,
            'status': status,
          },
        );
      }

      return {
        'status': 'sukses',
        'pesan': status == 'diterima'
            ? 'Dokumen pengajuan berhasil diterima'
            : 'Dokumen pengajuan berhasil ditolak',
      };
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal memproses dokumen: $e'};
    }
  }

  /// Admin memproses item APD individually (terima/tolak per item).
  /// Ini memungkinkan admin menerima sebagian dan menolak sebagian item dalam satu dokumen.
  Future<Map<String, dynamic>> prosesItemPengajuan({
    required String idItem,
    required String status, // 'diterima' atau 'ditolak'
    required String usernameAdmin,
    String? catatanAdmin,
    String? lokasiPengambilan,
  }) async {
    try {
      final admin = await _supabase
          .from('admin')
          .select('id,nama_lengkap,tanda_tangan')
          .eq('username', usernameAdmin)
          .maybeSingle();
      if (admin == null) {
        return {'status': 'gagal', 'pesan': 'Admin tidak valid'};
      }

      // Ambil data item untuk dicek
      final itemData = await _supabase
          .from('dokumen_pengajuan_item')
          .select('id,id_pengajuan,id_apd,jumlah,status')
          .eq('id', idItem)
          .maybeSingle();

      if (itemData == null) {
        return {'status': 'gagal', 'pesan': 'Item pengajuan tidak ditemukan'};
      }

      if (itemData['status'] != 'menunggu') {
        return {'status': 'gagal', 'pesan': 'Item ini sudah diproses sebelumnya'};
      }

      final idDokumen = _readText(itemData['id_pengajuan']);

      // Cek status dokumen
      final dokumenData = await _supabase
          .from('dokumen_pengajuan')
          .select('id,status,id_karyawan')
          .eq('id', idDokumen)
          .maybeSingle();

      if (dokumenData == null) {
        return {'status': 'gagal', 'pesan': 'Dokumen tidak ditemukan'};
      }

      // Siapkan payload untuk update item
      final payload = <String, dynamic>{
        'status': status == 'diterima' ? 'diterima' : 'ditolak',
        'catatan_admin': catatanAdmin?.trim() ?? '',
        'id_admin': admin['id'],
        'tanggal_proses': DateTime.now().toIso8601String(),
      };

      // Update status item
      await _supabase
          .from('dokumen_pengajuan_item')
          .update(payload)
          .eq('id', idItem);

      // Jika diterima, kurangi stok APD
      if (status == 'diterima') {
        final idApd = _readText(itemData['id_apd']);
        final jumlah = int.tryParse('${itemData['jumlah'] ?? 1}') ?? 1;

        if (idApd.isNotEmpty) {
          final apd = await _supabase
              .from('apd')
              .select('id,stok')
              .eq('id', idApd)
              .maybeSingle();

          if (apd != null) {
            final stok = int.tryParse('${apd['stok'] ?? 0}') ?? 0;
            await _supabase
                .from('apd')
                .update({'stok': stok - jumlah})
                .eq('id', idApd);
          }
        }
      }

      // Update status dokumen secara manual agar terlihat di dashboard karyawan
      // Cek semua item dalam dokumen ini
      final allItems = await _supabase
          .from('dokumen_pengajuan_item')
          .select('status')
          .eq('id_pengajuan', idDokumen);

      final items = _asMapList(allItems);
      int menungguCount = 0;
      int diterimaCount = 0;
      int ditolakCount = 0;

      for (final item in items) {
        final itemStatus = _readText(item['status'], fallback: 'menunggu').toLowerCase();
        if (itemStatus == 'menunggu') {
          menungguCount++;
        } else if (itemStatus == 'diterima') {
          diterimaCount++;
        } else if (itemStatus == 'ditolak') {
          ditolakCount++;
        }
      }

      // Tentukan status dokumen
      String finalStatus = 'menunggu';
      if (menungguCount == 0) {
        finalStatus = 'selesai';
      } else if (diterimaCount > 0 || ditolakCount > 0) {
        finalStatus = 'diproses';
      }

      // Update status dokumen
      await _supabase
          .from('dokumen_pengajuan')
          .update({'status': finalStatus})
          .eq('id', idDokumen);

      // Kirim notifikasi ke karyawan
      final idKaryawan = _readText(dokumenData['id_karyawan']);
      if (idKaryawan.isNotEmpty) {
        final judul = status == 'diterima'
            ? 'Item APD Diterima'
            : 'Item APD Ditolak';
        final pesan = status == 'diterima'
            ? 'Salah satu item pengajuan APD Anda telah diterima oleh admin ${admin['nama_lengkap']}.'
            : 'Salah satu item pengajuan APD Anda ditolak. ${catatanAdmin != null && catatanAdmin!.isNotEmpty ? 'Catatan: $catatanAdmin' : ''}';

        await _kirimNotifikasiKaryawan(
          idKaryawan: idKaryawan,
          judul: judul,
          pesan: pesan,
          tipeNotifikasi: 'dokumen_pengajuan',
          payload: {
            'id_pengajuan': idDokumen,
            'status': finalStatus,
          },
        );
      }

      return {
        'status': 'sukses',
        'pesan': 'Item pengajuan berhasil ${status == 'diterima' ? 'diterima' : 'ditolak'}',
        'data': {
          'status_dokumen': finalStatus,
        },
      };
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal memproses item: $e'};
    }
  }

  /// Proses multiple items sekaligus (untuk persetujuan batch)
  Future<Map<String, dynamic>> prosesBatchItemPengajuan({
    required List<String> idsItem, // List item yang akan diproses
    required String status, // 'diterima' atau 'ditolak'
    required String usernameAdmin,
    String? catatanAdmin,
    String? lokasiPengambilan,
  }) async {
    try {
      final admin = await _supabase
          .from('admin')
          .select('id,nama_lengkap')
          .eq('username', usernameAdmin)
          .maybeSingle();

      if (admin == null) {
        return {'status': 'gagal', 'pesan': 'Admin tidak valid'};
      }

      final results = <Map<String, dynamic>>[];

      for (final idItem in idsItem) {
        final result = await prosesItemPengajuan(
          idItem: idItem,
          status: status,
          usernameAdmin: usernameAdmin,
          catatanAdmin: catatanAdmin,
          lokasiPengambilan: lokasiPengambilan,
        );

        results.add({
          'id_item': idItem,
          'sukses': result['status'] == 'sukses',
          'pesan': result['pesan']?.toString() ?? '',
        });
      }

      final suksesCount = results.where((r) => r['sukses'] == true).length;
      final gagalCount = results.where((r) => r['sukses'] != true).length;

      return {
        'status': 'sukses',
        'pesan': '$suksesCount item berhasil diproses${gagalCount > 0 ? ', $gagalCount gagal' : ''}',
        'data': {
          'results': results,
        },
      };
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal memproses batch: $e'};
    }
  }

  /// Menyimpan tanda tangan admin ke database.
  Future<Map<String, dynamic>> simpanTandaTanganAdmin({
    required String username,
    required String tandaTanganBase64,
  }) async {
    try {
      await _supabase
          .from('admin')
          .update({'tanda_tangan': tandaTanganBase64})
          .eq('username', username);

      return {'status': 'sukses', 'pesan': 'Tanda tangan berhasil disimpan'};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal menyimpan tanda tangan: $e'};
    }
  }

  /// Mengambil tanda tangan admin dari database.
  Future<Map<String, dynamic>> ambilTandaTanganAdmin(String username) async {
    try {
      final admin = await _supabase
          .from('admin')
          .select('tanda_tangan')
          .eq('username', username)
          .maybeSingle();

      return {
        'status': 'sukses',
        'data': {
          'tanda_tangan': admin?['tanda_tangan']?.toString() ?? '',
        },
      };
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal memuat tanda tangan: $e'};
    }
  }

  /// Mengambil daftar dokumen pengajuan milik karyawan tertentu.
  Future<Map<String, dynamic>> daftarDokumenKaryawan(String username) async {
    try {
      final karyawan = await _supabase
          .from('karyawan')
          .select('id')
          .eq('username', username)
          .maybeSingle();
      if (karyawan == null) {
        return {'status': 'sukses', 'data': []};
      }

      final rows = _asMapList(
        await _supabase
            .from('dokumen_pengajuan')
            .select('*')
            .eq('id_karyawan', karyawan['id'])
            .order('tanggal_pengajuan', ascending: false),
      );

      final enriched = <Map<String, dynamic>>[];
      for (final row in rows) {
        final idDokumen = _readText(row['id']);

        // Ambil jumlah item
        final itemRows = _asMapList(
          await _supabase
              .from('dokumen_pengajuan_item')
              .select('id')
              .eq('id_pengajuan', idDokumen),
        );

        // Ambil nama admin (jika sudah diproses)
        String namaAdmin = '-';
        final idAdmin = _readText(row['id_admin']);
        if (idAdmin.isNotEmpty) {
          final admin = await _supabase
              .from('admin')
              .select('nama_lengkap')
              .eq('id', idAdmin)
              .maybeSingle();
          namaAdmin = _readText(admin?['nama_lengkap'], fallback: '-');
        }

        enriched.add({
          ...row.map((key, value) => MapEntry('$key', value)),
          'jumlah_item': itemRows.length,
          'nama_admin': namaAdmin,
        });
      }

      return {'status': 'sukses', 'data': enriched};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal memuat dokumen karyawan: $e'};
    }
  }

  Future<Map<String, dynamic>> dokumenPenerimaanKaryawan(String username) async {
    try {
      final user = username.trim();
      if (user.isEmpty) return {'status': 'sukses', 'data': []};

      var karyawan = await _supabase
          .from('karyawan')
          .select('id')
          .eq('username', user)
          .maybeSingle();
      karyawan ??= await _supabase
          .from('karyawan')
          .select('id')
          .ilike('username', user)
          .maybeSingle();
      if (karyawan == null) return {'status': 'sukses', 'data': []};

      final idKaryawan = _readText(karyawan['id']);

      final rows = _asMapList(
        await _supabase
            .from('dokumen_pengajuan')
            .select('*')
            .eq('id_karyawan', idKaryawan)
            .not('status', 'eq', 'menunggu')
            .order('tanggal_pengajuan', ascending: false),
      );

      final enriched = <Map<String, dynamic>>[];
      for (final row in rows) {
        final idDokumen = _readText(row['id']);

        // Hanya ambil item yang DITERIMA saja
        final itemRows = _asMapList(
          await _supabase
              .from('dokumen_pengajuan_item')
              .select('id')
              .eq('id_pengajuan', idDokumen)
              .eq('status', 'diterima'),
        );

        // Hanya tampilkan dokumen jika ada item yang diterima
        if (itemRows.isNotEmpty) {
          enriched.add({
            ...row.map((key, value) => MapEntry('$key', value)),
            'item_count': itemRows.length,
          });
        }
      }

      return {'status': 'sukses', 'data': enriched};
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal memuat dokumen penerimaan: $e'};
    }
  }

  Future<Map<String, dynamic>> detailDokumenPenerimaan(String idDokumen) async {
    try {
      final id = idDokumen.trim();
      if (id.isEmpty) {
        return {'status': 'gagal', 'pesan': 'ID dokumen tidak valid'};
      }

      final dokumen = await _supabase
          .from('dokumen_pengajuan')
          .select('*')
          .eq('id', id)
          .maybeSingle();

      if (dokumen == null) {
        return {'status': 'gagal', 'pesan': 'Dokumen tidak ditemukan'};
      }

      final idKaryawan = _readText(dokumen['id_karyawan']);
      final idAdmin = _readText(dokumen['id_admin']);

      final karyawan = await _supabase
          .from('karyawan')
          .select('id,username,nama_lengkap,jabatan,departemen,lokasi_kerja')
          .eq('id', idKaryawan)
          .maybeSingle();

      Map<String, dynamic>? admin;
      if (idAdmin.isNotEmpty) {
        admin = await _supabase
            .from('admin')
            .select('id,nama_lengkap')
            .eq('id', idAdmin)
            .maybeSingle();
      }

      final itemRows = _asMapList(
        await _supabase
            .from('dokumen_pengajuan_item')
            .select('id_apd,ukuran,alasan,jumlah')
            .eq('id_pengajuan', id)
            .eq('status', 'diterima'), // Hanya item yang diterima
      );

      final apdIds = itemRows
          .map((row) => _readText(row['id_apd']))
          .where((id) => id.isNotEmpty)
          .toSet();

      final apdMap = await _loadMapByIds(
        table: 'apd',
        ids: apdIds,
        selectColumns: 'id,nama_apd,satuan',
      );

      final items = itemRows.map((row) {
        final apd = apdMap[_readText(row['id_apd'])];
        return <String, dynamic>{
          'id_apd': _readText(row['id_apd']),
          'nama_apd': _readText(apd?['nama_apd'], fallback: '-'),
          'satuan': _readText(apd?['satuan'], fallback: 'pcs'),
          'ukuran': _readText(row['ukuran']),
          'alasan': _readText(row['alasan']),
          'jumlah': row['jumlah'] ?? 1,
        };
      }).toList();

      return {
        'status': 'sukses',
        'data': {
          ...dokumen.map((key, value) => MapEntry('$key', value)),
          'karyawan': karyawan ?? {},
          'admin': admin ?? {},
          'items': items,
        },
      };
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Gagal memuat detail dokumen: $e'};
    }
  }
}


