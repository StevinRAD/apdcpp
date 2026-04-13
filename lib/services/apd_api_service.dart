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
      case 'diproses':
      case 'disetujui':
        return 'Disetujui';
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

      final res = await _supabase
          .from('karyawan')
          .select()
          .eq('username', user)
          .maybeSingle();

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
              .maybeSingle();
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
              .eq('id', res['id']);

          final nama = _readText(res['nama_lengkap'], fallback: user);
          try {
            await _supabase.from('bantuan_login').insert({
              'username': user,
              'nama_lengkap': nama,
              'password_diingat': '',
              'alasan_kendala':
                  'Akun dinonaktifkan otomatis setelah 3x gagal login.',
              'status': 'menunggu',
            });
          } catch (_) {
            // Abaikan jika gagal insert banding otomatis.
          }

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

      await _supabase
          .from('karyawan')
          .update(updateData)
          .eq('id', res['id']);

      // Ambil data karyawan yang sudah diupdate
      final updatedRes = await _supabase
          .from('karyawan')
          .select()
          .eq('id', res['id'])
          .maybeSingle();

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

      final res = await _supabase
          .from('admin')
          .select()
          .eq('username', user)
          .maybeSingle();

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
              .maybeSingle();
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

      await _supabase
          .from('admin')
          .update(updateData)
          .eq('id', res['id']);

      // Ambil data admin yang sudah diupdate
      final updatedRes = await _supabase
          .from('admin')
          .select()
          .eq('id', res['id'])
          .maybeSingle();

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

      final res = await _supabase
          .from('pengajuan')
          .select()
          .eq('id_karyawan', karyawan['id'])
          .order('tanggal_pengajuan', ascending: false);

      final rows = _asMapList(res);
      final apdIds = rows
          .map((row) => _readText(row['id_apd']))
          .where((id) => id.isNotEmpty)
          .toSet();
      final adminIds = rows
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

      final mapped = rows.map((row) {
        final apd = apdMap[_readText(row['id_apd'])];
        final admin = adminMap[_readText(row['id_admin'])];
        return <String, dynamic>{
          ...row,
          'id_pengajuan': _readText(row['id']),
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

      return {'status': 'sukses', 'data': mapped};
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
      final query = _supabase
          .from('pengajuan')
          .select(
            '*, apd(nama_apd,stok,min_stok), '
            'karyawan(username,nama_lengkap,jabatan,departemen,lokasi_kerja,cooldown_pengajuan_hari,foto_profil), '
            'admin(nama_lengkap)',
          );

      final res = await query.order('tanggal_pengajuan', ascending: false);
      final rows = _asMapList(res);
      final mapped = <Map<String, dynamic>>[];

      for (final row in rows) {
        if (!_matchFilterPengajuan(row['status_pengajuan'], statusPengajuan)) {
          continue;
        }

        final karyawan = row['karyawan'] is Map
            ? Map<String, dynamic>.from(row['karyawan'] as Map)
            : const <String, dynamic>{};
        final apd = row['apd'] is Map
            ? Map<String, dynamic>.from(row['apd'] as Map)
            : const <String, dynamic>{};
        final admin = row['admin'] is Map
            ? Map<String, dynamic>.from(row['admin'] as Map)
            : const <String, dynamic>{};

        if (_readText(jabatan).isNotEmpty &&
            _normalizeStatus(_readText(karyawan['jabatan'])) !=
                _normalizeStatus(_readText(jabatan))) {
          continue;
        }

        final tanggalPengajuan = _parseDate(row['tanggal_pengajuan']);
        if (tanggal != null &&
            !_inDateRange(tanggalPengajuan, tanggal, tanggal)) {
          continue;
        }
        if (!_inDateRange(tanggalPengajuan, start, end)) {
          continue;
        }

        mapped.add({
          ...row,
          'id_pengajuan': _readText(row['id']),
          'status_pengajuan': _displayStatusPengajuan(row['status_pengajuan']),
          'tanggal_diproses': _readText(
            row['tanggal_diproses'],
            fallback: _readText(row['tanggal_proses']),
          ),
          'username_karyawan': _readText(karyawan['username']),
          'nama_lengkap': _readText(karyawan['nama_lengkap'], fallback: '-'),
          'jabatan': _readText(karyawan['jabatan'], fallback: '-'),
          'departemen': _readText(karyawan['departemen'], fallback: '-'),
          'lokasi_kerja': _readText(karyawan['lokasi_kerja'], fallback: '-'),
          'foto_profil': _readText(karyawan['foto_profil']),
          'cooldown_pengajuan_hari': karyawan['cooldown_pengajuan_hari'] ?? 0,
          'nama_apd': _readText(apd['nama_apd'], fallback: '-'),
          'stok_tersedia': apd['stok'] ?? 0,
          'min_stok': apd['min_stok'] ?? 0,
          'jumlah_pengajuan': row['jumlah_pengajuan'] ?? row['jumlah'] ?? 1,
          'nama_admin_proses': _readText(admin['nama_lengkap']),
        });
      }

      return {'status': 'sukses', 'data': mapped};
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
          .select('id,id_apd,id_karyawan,status_pengajuan')
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
            if (stokSaatIni <= 0) {
              return {
                'status': 'gagal',
                'pesan': 'Stok APD sudah habis sehingga tidak bisa disetujui',
              };
            }
            await _supabase
                .from('apd')
                .update({'stok': stokSaatIni - 1})
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
        if (statusDb == 'diproses') {
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

      if (gambarApd != null) {
        final imgPath = await _uploadFile(gambarApd, 'apd');
        if (imgPath != null) updateData['gambar_apd'] = imgPath;
      } else if (hapusGambar) {
        updateData['gambar_apd'] = null; // Remove image
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
      await _supabase.from('apd').delete().eq('id', targetId);
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
        'is_libur': isLibur,
        'is_aktif': isAktif,
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

      final karyawan = await _supabase
          .from('karyawan')
          .select('id')
          .eq('username', user)
          .maybeSingle();
      if (karyawan == null) {
        return {
          'status': 'sukses',
          'data': {'rows': <Map<String, dynamic>>[]},
        };
      }

      final pengajuanRes = await _supabase
          .from('pengajuan')
          .select('id,id_apd,status_pengajuan,tanggal_pengajuan')
          .eq('id_karyawan', karyawan['id'])
          .order('tanggal_pengajuan', ascending: false);
      final rows = _asMapList(pengajuanRes)
          .where((row) => _isStatusDisetujuiPengajuan(row['status_pengajuan']))
          .toList();

      final apdIds = rows
          .map((e) => _readText(e['id_apd']))
          .where((e) => e.isNotEmpty)
          .toSet();
      final apdMap = await _loadMapByIds(
        table: 'apd',
        ids: apdIds,
        selectColumns: 'id,nama_apd',
      );

      final mapped = rows.map((row) {
        final apd = apdMap[_readText(row['id_apd'])];
        return <String, dynamic>{
          'id_pengajuan': _readText(row['id']),
          'nama_apd': _readText(row['nama_apd']).isNotEmpty
              ? _readText(row['nama_apd'])
              : _readText(apd?['nama_apd'], fallback: '-'),
          'status_pengajuan': _displayStatusPengajuan(row['status_pengajuan']),
          'tanggal_pengajuan': _readText(row['tanggal_pengajuan']),
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
      final pengajuanRes = await _supabase
          .from('pengajuan')
          .select('*')
          .order('tanggal_pengajuan', ascending: false);
      final pengajuanRows = _asMapList(pengajuanRes);

      final pengajuanKaryawanIds = pengajuanRows
          .map((e) => _readText(e['id_karyawan']))
          .where((e) => e.isNotEmpty)
          .toSet();
      final pengajuanApdIds = pengajuanRows
          .map((e) => _readText(e['id_apd']))
          .where((e) => e.isNotEmpty)
          .toSet();
      final pengajuanAdminIds = pengajuanRows
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
        selectColumns: 'id,nama_apd,stok,min_stok',
      );
      final adminMapPengajuan = await _loadMapByIds(
        table: 'admin',
        ids: pengajuanAdminIds,
        selectColumns: 'id,nama_lengkap',
      );

      final mappedPengajuan = <Map<String, dynamic>>[];
      for (final row in pengajuanRows) {
        if (!_matchFilterPengajuan(row['status_pengajuan'], statusPengajuan)) {
          continue;
        }
        final tanggalPengajuan = _parseDate(row['tanggal_pengajuan']);
        if (!_inDateRange(tanggalPengajuan, start, end)) continue;

        final karyawan = karyawanMapPengajuan[_readText(row['id_karyawan'])];
        final apd = apdMap[_readText(row['id_apd'])];
        final admin = adminMapPengajuan[_readText(row['id_admin'])];
        mappedPengajuan.add({
          'id_pengajuan': _readText(row['id']),
          'tanggal_pengajuan': _readText(row['tanggal_pengajuan']),
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
          'foto_profil': _readText(
            karyawan?['foto_profil'],
            fallback: _readText(row['foto_profil']),
          ),
          'nama_apd': _readText(row['nama_apd']).isNotEmpty
              ? _readText(row['nama_apd'])
              : _readText(apd?['nama_apd'], fallback: '-'),
          'ukuran': _readText(row['ukuran'], fallback: '-'),
          'jumlah_pengajuan': row['jumlah_pengajuan'] ?? row['jumlah'] ?? 1,
          'alasan_pengajuan': _readText(row['alasan_pengajuan']),
          'status_pengajuan': _displayStatusPengajuan(row['status_pengajuan']),
          'catatan_admin': _readText(row['catatan_admin']),
          'tanggal_diproses': _readText(
            row['tanggal_diproses'],
            fallback: _readText(row['tanggal_proses']),
          ),
          'nama_admin_proses': _readText(
            admin?['nama_lengkap'],
            fallback: _readText(row['nama_admin_proses']),
          ),
          'bukti_foto': _readText(row['bukti_foto']),
          'stok_tersedia': apd?['stok'] ?? row['stok_tersedia'] ?? 0,
          'min_stok': apd?['min_stok'] ?? row['min_stok'] ?? 0,
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

      final pengajuanRows = await _supabase
          .from('pengajuan')
          .select(
            'id,id_apd,status_pengajuan,tanggal_pengajuan,tanggal_proses,'
            'ukuran,alasan_pengajuan,catatan_admin,lokasi_pengambilan',
          )
          .eq('id_karyawan', idKaryawan)
          .order('tanggal_pengajuan', ascending: false)
          .limit(1);

      Map<String, dynamic>? pengajuanTerakhir;
      final pengajuanList = _asMapList(pengajuanRows);
      if (pengajuanList.isNotEmpty) {
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

      final pengajuanRes = await _supabase
          .from('pengajuan')
          .select(
            'id,id_karyawan,id_apd,status_pengajuan,tanggal_pengajuan,tanggal_proses',
          )
          .order('tanggal_pengajuan', ascending: false);
      final pengajuanRows = _asMapList(pengajuanRes);

      final karyawanIds = pengajuanRows
          .map((row) => _readText(row['id_karyawan']))
          .where((id) => id.isNotEmpty)
          .toSet();
      final apdIds = pengajuanRows
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
        selectColumns: 'id,nama_apd,stok,min_stok,is_aktif',
      );

      final pengajuanMenunggu = pengajuanRows
          .where(
            (row) =>
                _normalizeStatus(row['status_pengajuan']?.toString()) ==
                'menunggu',
          )
          .length;

      final disetujuiBulanIni = pengajuanRows.where((row) {
        if (!_isStatusDisetujuiPengajuan(row['status_pengajuan'])) return false;
        final tanggalAcuan = _parseDate(
          _readText(
            row['tanggal_proses'],
            fallback: _readText(row['tanggal_pengajuan']),
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

      final pengajuanTerbaru = <Map<String, dynamic>>[];
      for (final row in pengajuanRows) {
        if (_normalizeStatus(row['status_pengajuan']?.toString()) !=
            'menunggu') {
          continue;
        }
        final karyawan = karyawanMap[_readText(row['id_karyawan'])];
        final apd = apdMap[_readText(row['id_apd'])];
        pengajuanTerbaru.add({
          'id_pengajuan': _readText(row['id']),
          'tanggal_pengajuan': _readText(row['tanggal_pengajuan']),
          'status_pengajuan': _displayStatusPengajuan(row['status_pengajuan']),
          'username_karyawan': _readText(karyawan?['username']),
          'nama_lengkap': _readText(
            karyawan?['nama_lengkap'],
            fallback: _readText(karyawan?['username'], fallback: '-'),
          ),
          'jabatan': _readText(karyawan?['jabatan'], fallback: '-'),
          'nama_apd': _readText(apd?['nama_apd'], fallback: '-'),
        });
        if (pengajuanTerbaru.length >= 7) break;
      }

      final grafik = <Map<String, dynamic>>[];
      if (mode == 'mingguan') {
        final startWeek = _startOfWeekMonday(now.toLocal());
        for (var i = 0; i < 7; i++) {
          final targetDate = startWeek.add(Duration(days: i));
          var total = 0;
          var menunggu = 0;
          var disetujui = 0;
          var lowStock = 0;
          for (final row in pengajuanRows) {
            final tanggal = _parseDate(row['tanggal_pengajuan'])?.toLocal();
            if (tanggal == null) continue;
            final dateOnly = _toDateOnly(tanggal);
            if (dateOnly != targetDate) continue;
            total++;
            final status = _normalizeStatus(
              row['status_pengajuan']?.toString(),
            );
            if (status == 'menunggu') menunggu++;
            if (_isStatusDisetujuiPengajuan(status)) disetujui++;
            if (lowStockApdIds.contains(_readText(row['id_apd']))) lowStock++;
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
          for (final row in pengajuanRows) {
            final tanggal = _parseDate(row['tanggal_pengajuan'])?.toLocal();
            if (tanggal == null) continue;
            if (tanggal.year != tahunRef ||
                tanggal.month != bulanRef ||
                tanggal.day != day) {
              continue;
            }
            total++;
            final status = _normalizeStatus(
              row['status_pengajuan']?.toString(),
            );
            if (status == 'menunggu') menunggu++;
            if (_isStatusDisetujuiPengajuan(status)) disetujui++;
            if (lowStockApdIds.contains(_readText(row['id_apd']))) lowStock++;
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
          for (final row in pengajuanRows) {
            final tanggal = _parseDate(row['tanggal_pengajuan'])?.toLocal();
            if (tanggal == null ||
                tanggal.year != tahunRef ||
                tanggal.month != month) {
              continue;
            }
            total++;
            final status = _normalizeStatus(
              row['status_pengajuan']?.toString(),
            );
            if (status == 'menunggu') menunggu++;
            if (_isStatusDisetujuiPengajuan(status)) disetujui++;
            if (lowStockApdIds.contains(_readText(row['id_apd']))) lowStock++;
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

      final opsiTahun = pengajuanRows
          .map((row) => _parseDate(row['tanggal_pengajuan'])?.year)
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
        'is_aktif': isAktif,
        'id_admin': admin?['id'],
      };
      if (img != null) data['gambar_berita'] = img;
      if (hapusGambar) data['gambar_berita'] = null;

      final targetId = _readText(idBerita);
      final isEdit = targetId.isNotEmpty && targetId.toLowerCase() != 'null';
      if (!isEdit) {
        await _supabase.from('berita').insert(data);
      } else {
        await _supabase.from('berita').update(data).eq('id', targetId);
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
      await _supabase.from('berita').delete().eq('id', targetId);
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
        await _supabase
            .from('bantuan_login')
            .update({
              'nama_lengkap': namaLengkap.trim(),
              'password_diingat': passwordDiingat.trim(),
              'alasan_kendala': alasanKendala.trim(),
            })
            .eq('id', pending['id']);
        return {
          'status': 'sukses',
          'pesan':
              'Permintaan banding sudah ada, data terbaru berhasil diperbarui.',
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
            return status != 'kode_admin' && status != 'admin_gagal_login';
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
            .update({'status': 'ditinjau'})
            .eq('id', targetId);
        return {'status': 'sukses', 'pesan': 'Bantuan ditandai sudah dibaca'};
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
          await _supabase
              .from('karyawan')
              .update({'status': 'aktif', 'banned_until': null})
              .eq('username', usernameKaryawan);
        }
        await _supabase
            .from('bantuan_login')
            .update({'status': 'selesai'})
            .eq('id', targetId);
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
          return {'status': 'gagal', 'pesan': 'Akun admin tidak ditemukan'};
        }
        // Cek session token
        final dbToken = _readText(admin['session_token']);
        if (dbToken != sessionToken) {
          return {'status': 'gagal', 'pesan': 'Session tidak valid'};
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
        return {'status': 'gagal', 'pesan': 'Akun karyawan tidak ditemukan'};
      }
      // Cek session token
      final dbToken = _readText(karyawan['session_token']);
      if (dbToken != sessionToken) {
        return {'status': 'gagal', 'pesan': 'Session tidak valid'};
      }
      final status = _normalizeStatus(karyawan['status']?.toString());
      if (status == 'nonaktif') {
        return {'status': 'gagal', 'pesan': 'Akun karyawan nonaktif'};
      }
      if (status == 'ban_sementara') {
        final bannedUntil = _parseDate(karyawan['banned_until']);
        if (bannedUntil != null && DateTime.now().isBefore(bannedUntil)) {
          return {
            'status': 'gagal',
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
      return {'status': 'gagal', 'pesan': 'Gagal validasi sesi: $e'};
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
}
