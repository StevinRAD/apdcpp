// Script sederhana untuk test koneksi database dan cek data
import 'dart:io';

void main() async {
  print('=== TEST KONEKSI DATABASE ===');
  print('1. Memastikan file konfigurasi ada...');

  final configFiles = [
    'lib/konfigurasi_api.dart',
    'lib/services/apd_api_service.dart',
  ];

  for (final file in configFiles) {
    final exists = await File(file).exists();
    print('${exists ? "✓" : "✗"} $file');
  }

  print('\n2. Untuk testing lapor kendala, jalankan aplikasi dan:');
  print('   - Login sebagai karyawan');
  print('   - Buka menu "Lapor Kendala"');
  print('   - Cek console output untuk debugging');
  print('\n3. Debug yang akan muncul:');
  print('   - DEBUG: Karyawan ID: [id]');
  print('   - DEBUG: Jumlah dokumen: [jumlah]');
  print('   - DEBUG: Items valid: [jumlah]');
  print('   - DEBUG: Total allItems: [total]');
  print('   - DEBUG: Final mapped rows: [jumlah]');

  print('\n4. Untuk melihat data langsung di Supabase:');
  print('   Jalankan query ini di Supabase SQL Editor:');
  print('''
-- Cek item yang bisa dilaporkan (status diterima/disetujui)
SELECT
  dpi.id,
  dpi.status,
  dp.tanggal_pengajuan,
  a.nama_apd,
  k.username,
  k.nama_lengkap
FROM dokumen_pengajuan_item dpi
JOIN dokumen_pengajuan dp ON dpi.id_pengajuan = dp.id
JOIN karyawan k ON dp.id_karyawan = k.id
JOIN apd a ON dpi.id_apd = a.id
WHERE k.username = 'stevinrad'  -- Ganti dengan username karyawan
  AND (dpi.status ILIKE '%diterima%' OR dpi.status ILIKE '%disetujui%')
ORDER BY dp.tanggal_pengajuan DESC;
''');

  print('\n5. Jalankan aplikasi dengan:');
  print('   flutter run');
  print('   Lalu login sebagai karyawan dan buka menu Lapor Kendala');
}
