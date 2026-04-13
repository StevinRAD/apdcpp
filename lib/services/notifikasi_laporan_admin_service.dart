import 'package:shared_preferences/shared_preferences.dart';

class NotifikasiLaporanAdminService {
  static String _legacyStorageKey(String usernameAdmin) {
    final normalized = usernameAdmin.trim().toLowerCase();
    return 'laporan_admin_seen_$normalized';
  }

  static String _lastOpenedKey(String usernameAdmin) {
    final normalized = usernameAdmin.trim().toLowerCase();
    return 'laporan_admin_last_opened_$normalized';
  }

  static List<DateTime> _normalizeWaktu(Iterable<String> waktuLaporan) {
    final hasil = <DateTime>[];
    for (final raw in waktuLaporan) {
      final text = raw.trim();
      if (text.isEmpty) continue;
      final parsed = DateTime.tryParse(text.replaceFirst(' ', 'T'));
      if (parsed != null) {
        hasil.add(parsed);
      }
    }
    return hasil;
  }

  static Future<void> _bersihkanPenyimpananLama(String usernameAdmin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyStorageKey(usernameAdmin));
  }

  static Future<DateTime?> _ambilWaktuTerakhirDibuka(
    String usernameAdmin,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastOpenedKey(usernameAdmin))?.trim() ?? '';
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static Future<int> hitungLaporanBaru({
    required String usernameAdmin,
    required Iterable<String> waktuLaporanAktif,
  }) async {
    await _bersihkanPenyimpananLama(usernameAdmin);
    final aktif = _normalizeWaktu(waktuLaporanAktif);
    final terakhirDibuka = await _ambilWaktuTerakhirDibuka(usernameAdmin);
    if (terakhirDibuka == null) {
      return aktif.length;
    }

    return aktif.where((waktu) => waktu.isAfter(terakhirDibuka)).length;
  }

  static Future<void> tandaiSemuaSudahDilihat({
    required String usernameAdmin,
  }) async {
    await _bersihkanPenyimpananLama(usernameAdmin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastOpenedKey(usernameAdmin),
      DateTime.now().toIso8601String(),
    );
  }
}
