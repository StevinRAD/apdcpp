import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service untuk mengelola izin perangkat
/// Request semua izin yang diperlukan saat pertama kali aplikasi dibuka
class IzinPerangkatService {
  IzinPerangkatService._();

  static const String _keyIzinDiberikan = 'izin_semua_diberikan';
  static const String _keyVersiIzin = 'izin_versi';
  static const int _versiIzinSekarang = 1; // Increment jika ada izin baru

  /// Cek apakah semua izin sudah pernah diberikan
  static Future<bool> cekIzinSudahDiberikan() async {
    final prefs = await SharedPreferences.getInstance();
    final versiDisimpan = prefs.getInt(_keyVersiIzin) ?? 0;
    final izinDiberikan = prefs.getBool(_keyIzinDiberikan) ?? false;

    // Jika versi berubah, request ulang izin
    if (versiDisimpan < _versiIzinSekarang) {
      return false;
    }

    return izinDiberikan;
  }

  /// Tandai bahwa semua izin sudah diberikan
  static Future<void> tandaiIzinDiberikan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIzinDiberikan, true);
    await prefs.setInt(_keyVersiIzin, _versiIzinSekarang);
  }

  /// Request semua izin yang diperlukan sekaligus
  /// Dipanggil saat pertama kali buka aplikasi
  static Future<Map<String, bool>> requestSemuaIzin(
    BuildContext context,
  ) async {
    // Cek apakah izin sudah diberikan sebelumnya
    final sudahDiberikan = await cekIzinSudahDiberikan();
    if (sudahDiberikan) {
      return {'notifikasi': true, 'kamera': true, 'galeri': true};
    }

    final hasil = <String, bool>{};

    // Request izin notifikasi
    // ignore: use_build_context_synchronously
    hasil['notifikasi'] = await _requestIzinNotifikasi(context);
    if (!context.mounted) return hasil;

    // Request izin kamera
    hasil['kamera'] = await _requestIzin(
      context,
      Permission.camera,
      'Izin Kamera Diperlukan',
      'Aplikasi butuh akses kamera untuk mengambil foto profil atau bukti APD.',
    );
    if (!context.mounted) return hasil;

    // Request izin galeri/foto
    hasil['galeri'] = await _requestIzinGaleri(context);
    if (!context.mounted) return hasil;

    // Cek apakah semua izin diberikan
    final semuaDiberikan = hasil.values.every((e) => e);

    if (semuaDiberikan) {
      await tandaiIzinDiberikan();
    }

    return hasil;
  }

  /// Request izin notifikasi
  static Future<bool> _requestIzinNotifikasi(BuildContext context) async {
    if (kIsWeb) return true;
    // Untuk Android 13+ perlu request izin notifikasi
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 33) {
        // Android 13+ memerlukan izin notifikasi
        final status = await Permission.notification.request();
        return status.isGranted;
      }
    }
    // iOS dan Android versi lama tidak perlu izin notifikasi
    return true;
  }

  /// Request izin galeri/foto
  static Future<bool> _requestIzinGaleri(BuildContext context) async {
    if (kIsWeb) return true;
    PermissionStatus status;

    if (Platform.isIOS) {
      status = await Permission.photos.request();
    } else {
      // Android
      status = await Permission.photos.request();
      if (!(status.isGranted || status.isLimited)) {
        status = await Permission.storage.request();
      }
    }

    if (!context.mounted) return false;

    // ignore: use_build_context_synchronously
    return _tanganiStatusIzin(
      context: context,
      status: status,
      judul: 'Izin Galeri Diperlukan',
      pesan:
          'Aplikasi butuh akses galeri agar kamu bisa memilih foto profil dan lampiran.',
    );
  }

  /// Request izin tunggal dengan dialog
  static Future<bool> _requestIzin(
    BuildContext context,
    Permission permission,
    String judul,
    String pesan,
  ) async {
    if (kIsWeb) return true;
    final status = await permission.request();

    if (!context.mounted) return false;

    // ignore: use_build_context_synchronously
    return _tanganiStatusIzin(
      context: context,
      status: status,
      judul: judul,
      pesan: pesan,
    );
  }

  /// Tangani status izin dan tampilkan dialog jika perlu
  static bool _tanganiStatusIzin({
    required BuildContext context,
    required PermissionStatus status,
    required String judul,
    required String pesan,
  }) {
    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (status.isPermanentlyDenied || status.isRestricted) {
      // Jangan tampilkan dialog untuk batch permission request
      // Hanya tampilkan saat request individual
      return false;
    }

    return false;
  }

  /// Request izin kamera saja (untuk use case spesifik)
  static Future<bool> pastikanAksesKamera(BuildContext context) async {
    final status = await Permission.camera.status;

    if (status.isGranted) {
      return true;
    }

    if (!context.mounted) return false;

    final statusBaru = await Permission.camera.request();

    if (!context.mounted) return false;

    // ignore: use_build_context_synchronously
    return _tanganiStatusIzin(
      context: context,
      status: statusBaru,
      judul: 'Izin Kamera Diperlukan',
      pesan:
          'Aplikasi butuh akses kamera untuk mengambil foto profil atau bukti APD.',
    );
  }

  /// Request izin galeri saja (untuk use case spesifik)
  static Future<bool> pastikanAksesGaleri(BuildContext context) async {
    if (kIsWeb) return true;
    if (!context.mounted) return false;

    PermissionStatus status;

    if (Platform.isIOS) {
      status = await Permission.photos.request();
    } else {
      status = await Permission.photos.request();
      if (!(status.isGranted || status.isLimited)) {
        status = await Permission.storage.request();
      }
    }

    if (!context.mounted) return false;

    final hasil = _tanganiStatusIzin(
      context: context,
      status: status,
      judul: 'Izin Galeri Diperlukan',
      pesan:
          'Aplikasi butuh akses galeri agar kamu bisa memilih foto profil dan lampiran.',
    );

    if (!hasil) {
      _tampilkanDialogPengaturan(
        context: context,
        judul: 'Izin Galeri Diperlukan',
        pesan:
            'Aplikasi butuh akses galeri agar kamu bisa memilih foto profil dan lampiran.',
      );
    }

    return hasil;
  }

  /// Tampilkan dialog untuk membuka pengaturan
  static Future<void> _tampilkanDialogPengaturan({
    required BuildContext context,
    required String judul,
    required String pesan,
  }) async {
    if (!context.mounted) return;

    final bukaPengaturan = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(judul),
        content: Text(
          '$pesan\n\nIzin sedang ditolak. Buka pengaturan aplikasi untuk mengaktifkan izin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Nanti'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );

    if (bukaPengaturan == true) {
      await openAppSettings();
    }
  }

  /// Cek status izin tertentu
  static Future<bool> cekIzin(Permission permission) async {
    final status = await permission.status;
    return status.isGranted || status.isLimited;
  }

  /// Buka pengaturan aplikasi
  static Future<void> bukaPengaturan() async {
    await openAppSettings();
  }
}
