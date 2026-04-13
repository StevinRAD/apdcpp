import 'package:apdcpp/karyawan/dashboard_karyawan_aturan_helper.dart';
import 'package:apdcpp/tema_aplikasi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dashboard aturan pengajuan helper', () {
    test('status menunggu proses admin', () {
      final aturan = <String, dynamic>{
        'bisa_ajukan': false,
        'status': 'menunggu_proses',
        'cooldown_pengajuan_hari': 30,
      };

      expect(bisaAjukanSekarang(aturan), isFalse);
      expect(labelAturanPengajuan(aturan), 'Masih menunggu proses admin');
      expect(warnaAturanPengajuan(aturan), Colors.blue);
      expect(cooldownHariAkun(aturan), 30);
    });

    test('status cooldown menampilkan sisa hari', () {
      final aturan = <String, dynamic>{
        'bisa_ajukan': false,
        'status': 'cooldown',
        'cooldown_pengajuan_hari': 30,
        'sisa_hari_cooldown': 7,
      };

      expect(labelAturanPengajuan(aturan), 'Pending 7 hari lagi');
      expect(sisaHariCooldown(aturan), 7);
      expect(warnaAturanPengajuan(aturan), TemaAplikasi.emasTua);
    });

    test('status boleh ajukan', () {
      final aturan = <String, dynamic>{
        'bisa_ajukan': true,
        'status': 'boleh_ajukan',
        'cooldown_pengajuan_hari': 0,
      };

      expect(bisaAjukanSekarang(aturan), isTrue);
      expect(labelAturanPengajuan(aturan), 'Boleh ajukan sekarang');
      expect(warnaAturanPengajuan(aturan), TemaAplikasi.sukses);
      expect(cooldownHariAkun(aturan), 0);
    });
  });
}
