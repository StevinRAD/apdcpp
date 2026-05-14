import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notifikasi_lokal_service.dart';

/// Service untuk mengelola notifikasi realtime menggunakan Supabase Realtime
/// Mendeteksi perubahan di database dan menampilkan notifikasi lokal
class RealtimeNotifikasiService {
  RealtimeNotifikasiService._();

  static final RealtimeNotifikasiService instance = RealtimeNotifikasiService._();
  static final SupabaseClient _supabase = Supabase.instance.client;

  RealtimeChannel? _channelKaryawan;
  RealtimeChannel? _channelAdmin;
  String? _username;
  String? _peran; // 'karyawan' atau 'admin'
  bool _isListening = false;

  /// Mulai listen notifikasi realtime untuk karyawan
  Future<void> mulaiListenKaryawan(String username) async {
    if (_isListening) return;
    _username = username;
    _peran = 'karyawan';

    try {
      // Subscribe ke perubahan pada dokumen_pengajuan_item
      _channelKaryawan = _supabase.channel('public:dokumen_pengajuan_item');

      _channelKaryawan!.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'dokumen_pengajuan_item',
        callback: (payload) async {
          await _handlePengajuanUpdate(payload);
        },
      ).subscribe();

      // Subscribe ke perubahan pada laporan_kendala
      final channelLaporan = _supabase.channel('public:laporan_kendala');

      channelLaporan.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'laporan_kendala',
        callback: (payload) async {
          await _handleLaporanKendalaUpdate(payload);
        },
      ).subscribe();

      _isListening = true;
    } catch (e) {
    }
  }

  /// Mulai listen notifikasi realtime untuk admin
  Future<void> mulaiListenAdmin(String username) async {
    if (_isListening) return;
    _username = username;
    _peran = 'admin';

    try {
      // Subscribe ke pengajuan baru
      _channelAdmin = _supabase.channel('admin:pengajuan');

      _channelAdmin!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'dokumen_pengajuan',
        callback: (payload) async {
          await _handlePengajuanBaru(payload);
        },
      ).subscribe();

      // Subscribe ke laporan kendala baru
      final channelLaporan = _supabase.channel('admin:laporan');

      channelLaporan.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'laporan_kendala',
        callback: (payload) async {
          await _handleLaporanKendalaBaru(payload);
        },
      ).subscribe();

      _isListening = true;
    } catch (e) {
    }
  }

  /// Berhenti listen notifikasi
  Future<void> stopListen() async {
    try {
      await _channelKaryawan?.unsubscribe();
      await _channelAdmin?.unsubscribe();
      _channelKaryawan = null;
      _channelAdmin = null;
      _isListening = false;
      _username = null;
      _peran = null;
    } catch (e) {
    }
  }

  /// Handle update status pengajuan untuk karyawan
  Future<void> _handlePengajuanUpdate(PostgresChangePayload payload) async {
    if (_peran != 'karyawan') return;

    final newStatus = payload.newRecord['status']?.toString().toLowerCase();
    final oldStatus = payload.oldRecord['status']?.toString().toLowerCase();

    // Hanya notifikasi jika status berubah
    if (newStatus == oldStatus) return;


    // Ambil detail pengajuan untuk notifikasi
    final idItem = payload.newRecord['id'];
    if (idItem == null) return;

    try {
      final item = await _supabase
          .from('dokumen_pengajuan_item')
          .select('id_apd, id_pengajuan')
          .eq('id', idItem)
          .maybeSingle();

      if (item == null) return;

      // Ambil nama APD
      final apd = await _supabase
          .from('apd')
          .select('nama_apd')
          .eq('id', item['id_apd'])
          .maybeSingle();

      final namaApd = apd?['nama_apd']?.toString() ?? 'APD';

      // Tentukan pesan berdasarkan status
      String judul = '';
      String pesan = '';

      switch (newStatus) {
        case 'diterima':
        case 'disetujui':
          judul = 'Pengajuan Disetujui ✅';
          pesan = 'Selamat! Pengajuan $namaApd Anda telah disetujui.';
          break;
        case 'ditolak':
          judul = 'Pengajuan Ditolak ❌';
          pesan = 'Maaf, pengajuan $namaApd Anda ditolak.';
          break;
        default:
          judul = 'Update Pengajuan';
          pesan = 'Status pengajuan $namaApd Anda telah berubah.';
      }

      await NotifikasiLokalService.tampilkanNotifikasi(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        judul: judul,
        isi: pesan,
        soundType: 'persetujuan',
      );
    } catch (e) {
    }
  }

  /// Handle update laporan kendala untuk karyawan
  Future<void> _handleLaporanKendalaUpdate(PostgresChangePayload payload) async {
    if (_peran != 'karyawan') return;

    final newStatus = payload.newRecord['status_laporan']?.toString().toLowerCase();
    final oldStatus = payload.oldRecord['status_laporan']?.toString().toLowerCase();

    if (newStatus == oldStatus) return;


    final namaApd = payload.newRecord['nama_apd']?.toString() ?? 'APD';
    final catatanAdmin = payload.newRecord['catatan_admin']?.toString();

    String judul = '';
    String pesan = '';

    switch (newStatus) {
      case 'ditindaklanjuti':
        judul = 'Laporan Sedang Diproses 🔧';
        pesan = 'Laporan kendala $namaApd sedang ditindaklanjuti.';
        break;
      case 'selesai':
        judul = 'Laporan Selesai ✅';
        pesan = 'Laporan kendala $namaApd telah selesai ditindaklanjuti.';
        if (catatanAdmin != null && catatanAdmin.isNotEmpty) {
          pesan += '\nCatatan: $catatanAdmin';
        }
        break;
      default:
        judul = 'Update Laporan';
        pesan = 'Status laporan kendala $namaApd telah berubah.';
    }

    await NotifikasiLokalService.tampilkanNotifikasi(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      judul: judul,
      isi: pesan,
      soundType: 'persetujuan',
    );
  }

  /// Handle pengajuan baru untuk admin
  Future<void> _handlePengajuanBaru(PostgresChangePayload payload) async {
    if (_peran != 'admin') return;

    final idKaryawan = payload.newRecord['id_karyawan'];
    if (idKaryawan == null) return;

    try {
      // Ambil data karyawan
      final karyawan = await _supabase
          .from('karyawan')
          .select('nama_lengkap')
          .eq('id', idKaryawan)
          .maybeSingle();

      final namaKaryawan = karyawan?['nama_lengkap']?.toString() ?? 'Karyawan';

      await NotifikasiLokalService.tampilkanNotifikasiPengajuanBaru(
        namaKaryawan: namaKaryawan,
        jenisApd: 'Pengajuan Baru',
      );
    } catch (e) {
    }
  }

  /// Handle laporan kendala baru untuk admin
  Future<void> _handleLaporanKendalaBaru(PostgresChangePayload payload) async {
    if (_peran != 'admin') return;

    final namaApd = payload.newRecord['nama_apd']?.toString() ?? 'APD';
    final idKaryawan = payload.newRecord['id_karyawan'];

    try {
      final karyawan = await _supabase
          .from('karyawan')
          .select('nama_lengkap')
          .eq('id', idKaryawan)
          .maybeSingle();

      final namaKaryawan = karyawan?['nama_lengkap']?.toString() ?? 'Karyawan';

      await NotifikasiLokalService.tampilkanNotifikasi(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        judul: 'Laporan Kendala Baru ⚠️',
        isi: '$namaKaryawan melaporkan kendala pada $namaApd',
        soundType: 'peringatan',
      );
    } catch (e) {
    }
  }

  /// Cek apakah sedang listen
  bool get isListening => _isListening;

  /// Dapatkan username saat ini
  String? get currentUsername => _username;

  /// Dapatkan peran saat ini
  String? get currentPeran => _peran;
}
