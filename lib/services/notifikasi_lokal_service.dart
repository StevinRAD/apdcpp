import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Service untuk mengelola notifikasi lokal di aplikasi
/// Menampilkan popup notifikasi di layar HP seperti aplikasi native
class NotifikasiLokalService {
  NotifikasiLokalService._();

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Inisialisasi notifikasi lokal
  /// Harus dipanggil saat aplikasi pertama kali dimuat
  static Future<void> inisialisasi() async {
    if (_initialized) return;

    // Initialize timezone
    tz_data.initializeTimeZones();

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        if (kDebugMode) {
          print('Notifikasi diklik: ${response.payload}');
        }
      },
    );

    _initialized = true;
  }

  /// Request izin notifikasi (khusus iOS)
  static Future<bool> requestIzinNotifikasi() async {
    if (kIsWeb) return true;
    if (Platform.isIOS) {
      final bool? result = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    }
    // Android tidak perlu request izin untuk notifikasi lokal
    return true;
  }

  /// Cek apakah izin notifikasi diberikan
  static Future<bool> cekIzinNotifikasi() async {
    if (kIsWeb) return true;
    if (Platform.isAndroid) {
      // Android 13+ perlu cek izin
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final bool? granted = await androidPlugin.areNotificationsEnabled();
        return granted ?? true;
      }
      return true;
    }
    return true;
  }

  /// Tampilkan notifikasi segera
  static Future<void> tampilkanNotifikasi({
    required int id,
    required String judul,
    required String isi,
    String? payload,
  }) async {
    if (!_initialized) {
      await inisialisasi();
    }

    final androidDetails = AndroidNotificationDetails(
      'apd_notifikasi_channel',
      'Notifikasi APD',
      channelDescription: 'Channel untuk notifikasi aplikasi APD',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      styleInformation: const BigTextStyleInformation(''),
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id,
      judul,
      isi,
      notificationDetails,
      payload: payload,
    );
  }

  /// Tampilkan notifikasi untuk update data
  static Future<void> tampilkanNotifikasiUpdate({
    required String jenisUpdate,
    String? detail,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch % 100000;
    await tampilkanNotifikasi(
      id: id,
      judul: 'Update $jenisUpdate',
      isi: detail ?? 'Ada perubahan data $jenisUpdate. Cek sekarang!',
      payload: 'update_$jenisUpdate',
    );
  }

  /// Tampilkan notifikasi untuk pengajuan baru
  static Future<void> tampilkanNotifikasiPengajuanBaru({
    required String namaKaryawan,
    required String jenisApd,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch % 100000;
    await tampilkanNotifikasi(
      id: id,
      judul: 'Pengajuan Baru',
      isi: '$namaKaryawan mengajukan $jenisApd',
      payload: 'pengajuan_baru',
    );
  }

  /// Tampilkan notifikasi untuk status pengajuan berubah
  static Future<void> tampilkanNotifikasiStatusPengajuan({
    required String status,
    String? keterangan,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch % 100000;
    await tampilkanNotifikasi(
      id: id,
      judul: 'Status Pengajuan: $status',
      isi: keterangan ?? 'Status pengajuan APD Anda telah berubah',
      payload: 'status_pengajuan',
    );
  }

  /// Tampilkan notifikasi untuk pesan/news baru
  static Future<void> tampilkanNotifikasiBerita({
    required String judulBerita,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch % 100000;
    await tampilkanNotifikasi(
      id: id,
      judul: 'Berita Terbaru',
      isi: judulBerita,
      payload: 'berita_baru',
    );
  }

  /// Jadwalkan notifikasi untuk waktu tertentu
  static Future<void> jadwalkanNotifikasi({
    required int id,
    required String judul,
    required String isi,
    required DateTime waktuJadwal,
    String? payload,
  }) async {
    if (!_initialized) {
      await inisialisasi();
    }

    final androidDetails = const AndroidNotificationDetails(
      'apd_notifikasi_channel',
      'Notifikasi APD',
      channelDescription: 'Channel untuk notifikasi aplikasi APD',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      judul,
      isi,
      tz.TZDateTime.from(waktuJadwal, tz.local),
      notificationDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Batalkan notifikasi yang terjadwal
  static Future<void> batalkanNotifikasi(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Batalkan semua notifikasi
  static Future<void> batalkanSemuaNotifikasi() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Dapatkan daftar notifikasi yang aktif (pending/scheduled)
  Future<List<PendingNotificationRequest>> getAktifNotifikasi() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }
}

/// Data model untuk notifikasi
class NotifikasiData {
  final int id;
  final String judul;
  final String isi;
  final DateTime waktu;
  final String? payload;
  final bool sudahDibaca;

  NotifikasiData({
    required this.id,
    required this.judul,
    required this.isi,
    required this.waktu,
    this.payload,
    this.sudahDibaca = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'judul': judul,
      'isi': isi,
      'waktu': waktu.toIso8601String(),
      'payload': payload,
      'sudah_dibaca': sudahDibaca,
    };
  }

  factory NotifikasiData.fromJson(Map<String, dynamic> json) {
    return NotifikasiData(
      id: json['id'] as int,
      judul: json['judul'] as String,
      isi: json['isi'] as String,
      waktu: DateTime.parse(json['waktu'] as String),
      payload: json['payload'] as String?,
      sudahDibaca: json['sudah_dibaca'] as bool? ?? false,
    );
  }
}
