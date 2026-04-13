import 'package:apdcpp/services/notifikasi_laporan_admin_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('NotifikasiLaporanAdminService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('menghitung laporan baru lalu nol setelah halaman dibuka', () async {
      const usernameAdmin = 'admin.apd';

      final awal = await NotifikasiLaporanAdminService.hitungLaporanBaru(
        usernameAdmin: usernameAdmin,
        waktuLaporanAktif: const [
          '2026-04-10T08:00:00',
          '2026-04-10T09:00:00',
        ],
      );
      expect(awal, 2);

      await NotifikasiLaporanAdminService.tandaiSemuaSudahDilihat(
        usernameAdmin: usernameAdmin,
      );

      final setelahDilihat =
          await NotifikasiLaporanAdminService.hitungLaporanBaru(
            usernameAdmin: usernameAdmin,
            waktuLaporanAktif: const [
              '2026-04-10T08:00:00',
              '2026-04-10T09:00:00',
            ],
          );
      expect(setelahDilihat, 0);

      final munculBaru = await NotifikasiLaporanAdminService.hitungLaporanBaru(
        usernameAdmin: usernameAdmin,
        waktuLaporanAktif: const [
          '2099-04-10T08:00:00',
        ],
      );
      expect(munculBaru, 1);
    });

    test('status dilihat dipisahkan per admin', () async {
      await NotifikasiLaporanAdminService.tandaiSemuaSudahDilihat(
        usernameAdmin: 'admin_satu',
      );

      final adminSatu = await NotifikasiLaporanAdminService.hitungLaporanBaru(
        usernameAdmin: 'admin_satu',
        waktuLaporanAktif: const ['2026-04-10T08:00:00'],
      );
      final adminDua = await NotifikasiLaporanAdminService.hitungLaporanBaru(
        usernameAdmin: 'admin_dua',
        waktuLaporanAktif: const ['2026-04-10T08:00:00'],
      );

      expect(adminSatu, 0);
      expect(adminDua, 1);
    });
  });
}
