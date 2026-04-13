import 'package:shared_preferences/shared_preferences.dart';

class SesiAplikasiService {
  static const String _keyPeran = 'sesi_peran';
  static const String _keyUsername = 'sesi_username';
  static const String _keyNamaLengkap = 'sesi_nama_lengkap';
  static const String _keyFotoProfil = 'sesi_foto_profil';
  static const String _keySessionToken = 'sesi_session_token';
  static const String _keyPeranAdmin =
      'sesi_peran_admin'; // 'master' atau 'biasa' (hanya bila peran=='admin')
  static const String _keyDeviceId = 'sesi_device_id';

  static Future<void> simpanSesi({
    required String peran, // 'admin' atau 'karyawan'
    required String username,
    required String namaLengkap,
    String? fotoProfil,
    String? sessionToken, // Ditambahkan untuk cek sesi device
    String? peranAdmin, // Untuk admin master
    String? deviceId, // Device ID untuk single device login
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPeran, peran);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyNamaLengkap, namaLengkap);
    if (fotoProfil != null && fotoProfil.isNotEmpty) {
      await prefs.setString(_keyFotoProfil, fotoProfil);
    } else {
      await prefs.remove(_keyFotoProfil);
    }

    if (sessionToken != null && sessionToken.isNotEmpty) {
      await prefs.setString(_keySessionToken, sessionToken);
    } else {
      await prefs.remove(_keySessionToken);
    }

    if (peranAdmin != null && peranAdmin.isNotEmpty) {
      await prefs.setString(_keyPeranAdmin, peranAdmin);
    } else {
      await prefs.remove(_keyPeranAdmin);
    }

    // Simpan device ID untuk single device login
    if (deviceId != null && deviceId.isNotEmpty) {
      await prefs.setString(_keyDeviceId, deviceId);
    } else {
      await prefs.remove(_keyDeviceId);
    }
  }

  static Future<Map<String, dynamic>?> ambilSesi() async {
    final prefs = await SharedPreferences.getInstance();
    final peran = prefs.getString(_keyPeran);
    final username = prefs.getString(_keyUsername);
    final namaLengkap = prefs.getString(_keyNamaLengkap);
    final fotoProfil = prefs.getString(_keyFotoProfil);
    final sessionToken = prefs.getString(_keySessionToken);
    final peranAdmin = prefs.getString(_keyPeranAdmin);
    final deviceId = prefs.getString(_keyDeviceId);

    if (peran != null && username != null && namaLengkap != null) {
      return {
        'peran': peran,
        'username': username,
        'nama_lengkap': namaLengkap,
        'foto_profil': fotoProfil,
        'session_token': sessionToken,
        'peran_admin': peranAdmin,
        'device_id': deviceId,
      };
    }
    return null;
  }

  static Future<void> hapusSesi() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPeran);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyNamaLengkap);
    await prefs.remove(_keyFotoProfil);
    await prefs.remove(_keySessionToken);
    await prefs.remove(_keyPeranAdmin);
    await prefs.remove(_keyDeviceId);
  }

  /// Ambil device ID dari sesi yang tersimpan
  static Future<String?> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDeviceId);
  }

  /// Update session token saja (tanpa mengubah data lain)
  static Future<void> updateSessionToken(String sessionToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySessionToken, sessionToken);
  }
}
