import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Service untuk mengelola single device session
/// Memastikan hanya 1 device yang bisa aktif untuk 1 akun
class SingleDeviceSessionService {
  SingleDeviceSessionService._();

  static const String _keyDeviceId = 'single_device_id';
  static const String _keyLastCheck = 'single_device_last_check';
  static const String _keySessionValid = 'single_device_session_valid';

  static String? _cachedDeviceId;

  /// Mendapatkan device ID yang unik untuk perangkat ini
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      _cachedDeviceId = androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      // Untuk iOS, gunakan identifierForVendor
      _cachedDeviceId = iosInfo.identifierForVendor ?? 'ios_${iosInfo.systemVersion}';
    } else {
      // Fallback untuk platform lain
      final prefs = await SharedPreferences.getInstance();
      _cachedDeviceId = prefs.getString(_keyDeviceId) ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_keyDeviceId, _cachedDeviceId!);
    }

    return _cachedDeviceId!;
  }

  /// Simpan device ID saat login berhasil
  static Future<void> simpanDeviceIdSesi(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeviceId, deviceId);
    await prefs.setString(_keyLastCheck, DateTime.now().toIso8601String());
    await prefs.setBool(_keySessionValid, true);
    _cachedDeviceId = deviceId;
  }

  /// Cek apakah session masih valid untuk device ini
  static Future<bool> cekSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionValid = prefs.getBool(_keySessionValid) ?? false;
    return sessionValid;
  }

  /// Tandai session tidak valid (untuk logout otomatis)
  static Future<void> tandaiSessionTidakValid() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySessionValid, false);
  }

  /// Bersihkan data single device session
  static Future<void> bersihkanSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySessionValid);
    // Jangan hapus device ID karena itu identitas device
  }

  /// Mendapatkan waktu cek terakhir
  static Future<DateTime?> getLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckStr = prefs.getString(_keyLastCheck);
    if (lastCheckStr != null) {
      return DateTime.parse(lastCheckStr);
    }
    return null;
  }

  /// Update waktu cek terakhir
  static Future<void> updateLastCheck() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastCheck, DateTime.now().toIso8601String());
  }
}

/// Widget untuk memantau dan menangani single device session
/// Diletakkan di atas dashboard karyawan/admin
class SingleDeviceMonitor extends StatefulWidget {
  final Widget child;
  final String username;
  final String peran;
  final VoidCallback onSessionInvalid;

  const SingleDeviceMonitor({
    super.key,
    required this.child,
    required this.username,
    required this.peran,
    required this.onSessionInvalid,
  });

  @override
  State<SingleDeviceMonitor> createState() => _SingleDeviceMonitorState();
}

class _SingleDeviceMonitorState extends State<SingleDeviceMonitor> {
  Timer? _checkTimer;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _mulaiMonitoring();
  }

  void _mulaiMonitoring() {
    // Cek pertama kali
    _cekSessionDevice();

    // Cek setiap 30 detik
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _cekSessionDevice();
    });
  }

  Future<void> _cekSessionDevice() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final sessionValid = await SingleDeviceSessionService.cekSessionValid();

      if (!sessionValid) {
        // Session tidak valid, logout otomatis
        if (mounted) {
          _tampilkanDialogSessionHabis();
        }
      }
    } catch (e) {
      // Ignore error untuk cek session
    } finally {
      _isChecking = false;
    }
  }

  void _tampilkanDialogSessionHabis() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.phonelink_erase,
          size: 48,
          color: Colors.red.shade700,
        ),
        title: const Text('Session Berakhir'),
        content: const Text(
          'Akun Anda telah login di perangkat lain. '
          'Untuk keamanan, Anda telah keluar otomatis dari perangkat ini.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              widget.onSessionInvalid();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
