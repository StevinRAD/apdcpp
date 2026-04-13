import 'package:shared_preferences/shared_preferences.dart';

class TutorialAplikasiService {
  static const String _adminKey = 'tutorial_dashboard_admin_seen';
  static const String _karyawanKey = 'tutorial_dashboard_karyawan_seen';

  static Future<bool> perluTampilkanTutorialAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_adminKey) ?? false);
  }

  static Future<bool> perluTampilkanTutorialKaryawan() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_karyawanKey) ?? false);
  }

  static Future<void> tandaiTutorialAdminSudahDilihat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adminKey, true);
  }

  static Future<void> tandaiTutorialKaryawanSudahDilihat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_karyawanKey, true);
  }
}
