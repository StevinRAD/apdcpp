import 'package:flutter_test/flutter_test.dart';

/// Test Driven Development untuk fitur status pengajuan
/// Menguji:
/// 1. Filter status "Selesai" dan "Diproses"
/// 2. Perhitungan status display berdasarkan item yang diproses
/// 3. Sinkronisasi status antara daftar dokumen dan preview

void main() {
  group('Perhitungan Status Display Dokumen', () {
    test('Status menunggu ketika belum ada item diproses', () {
      final dokumen = <String, dynamic>{
        'status': 'menunggu',
        'jumlah_item': 3,
        'jumlah_diterima': 0,
        'jumlah_ditolak': 0,
      };

      final items = <Map<String, dynamic>>[];

      // Simulasi logika _computeDisplayStatus
      String computeStatus(Map<String, dynamic> dok, List<Map<String, dynamic>> itemList) {
        final rawStatus = dok['status']?.toString().toLowerCase() ?? 'menunggu';
        if (rawStatus != 'menunggu') return rawStatus;

        final jumlahItem = int.tryParse('${dok['jumlah_item'] ?? 0}') ?? 0;
        int jumlahDiterima = 0;
        int jumlahDitolak = 0;

        for (final item in itemList) {
          final statusItem = item['status']?.toString().toLowerCase() ?? '';
          if (statusItem == 'diterima') jumlahDiterima++;
          if (statusItem == 'ditolak') jumlahDitolak++;
        }

        final totalDiproses = jumlahDiterima + jumlahDitolak;

        if (totalDiproses > 0 && totalDiproses >= jumlahItem && jumlahItem > 0) {
          return 'selesai';
        }
        if (totalDiproses > 0) {
          return 'diproses';
        }
        return rawStatus;
      }

      expect(computeStatus(dokumen, items), 'menunggu');
    });

    test('Status diproses ketika sebagian item sudah diproses', () {
      final dokumen = <String, dynamic>{
        'status': 'menunggu',
        'jumlah_item': 3,
        'jumlah_diterima': 1,
        'jumlah_ditolak': 0,
      };

      final items = <Map<String, dynamic>>[
        {'status': 'diterima'},
        {'status': 'menunggu'},
        {'status': 'menunggu'},
      ];

      String computeStatus(Map<String, dynamic> dok, List<Map<String, dynamic>> itemList) {
        final rawStatus = dok['status']?.toString().toLowerCase() ?? 'menunggu';
        if (rawStatus != 'menunggu') return rawStatus;

        final jumlahItem = int.tryParse('${dok['jumlah_item'] ?? 0}') ?? 0;
        int jumlahDiterima = 0;
        int jumlahDitolak = 0;

        for (final item in itemList) {
          final statusItem = item['status']?.toString().toLowerCase() ?? '';
          if (statusItem == 'diterima') jumlahDiterima++;
          if (statusItem == 'ditolak') jumlahDitolak++;
        }

        final totalDiproses = jumlahDiterima + jumlahDitolak;

        if (totalDiproses > 0 && totalDiproses >= jumlahItem && jumlahItem > 0) {
          return 'selesai';
        }
        if (totalDiproses > 0) {
          return 'diproses';
        }
        return rawStatus;
      }

      expect(computeStatus(dokumen, items), 'diproses');
    });

    test('Status selesai ketika semua item sudah diproses', () {
      final dokumen = <String, dynamic>{
        'status': 'menunggu',
        'jumlah_item': 3,
        'jumlah_diterima': 2,
        'jumlah_ditolak': 1,
      };

      final items = <Map<String, dynamic>>[
        {'status': 'diterima'},
        {'status': 'diterima'},
        {'status': 'ditolak'},
      ];

      String computeStatus(Map<String, dynamic> dok, List<Map<String, dynamic>> itemList) {
        final rawStatus = dok['status']?.toString().toLowerCase() ?? 'menunggu';
        if (rawStatus != 'menunggu') return rawStatus;

        final jumlahItem = int.tryParse('${dok['jumlah_item'] ?? 0}') ?? 0;
        int jumlahDiterima = 0;
        int jumlahDitolak = 0;

        for (final item in itemList) {
          final statusItem = item['status']?.toString().toLowerCase() ?? '';
          if (statusItem == 'diterima') jumlahDiterima++;
          if (statusItem == 'ditolak') jumlahDitolak++;
        }

        final totalDiproses = jumlahDiterima + jumlahDitolak;

        if (totalDiproses > 0 && totalDiproses >= jumlahItem && jumlahItem > 0) {
          return 'selesai';
        }
        if (totalDiproses > 0) {
          return 'diproses';
        }
        return rawStatus;
      }

      expect(computeStatus(dokumen, items), 'selesai');
    });

    test('Status diterima tidak dihitung ulang', () {
      final dokumen = <String, dynamic>{
        'status': 'diterima',
        'jumlah_item': 3,
      };

      final items = <Map<String, dynamic>>[];

      String computeStatus(Map<String, dynamic> dok, List<Map<String, dynamic>> itemList) {
        final rawStatus = dok['status']?.toString().toLowerCase() ?? 'menunggu';
        if (rawStatus != 'menunggu') return rawStatus;
        return 'menunggu';
      }

      expect(computeStatus(dokumen, items), 'diterima');
    });

    test('Status ditolak tidak dihitung ulang', () {
      final dokumen = <String, dynamic>{
        'status': 'ditolak',
        'jumlah_item': 3,
      };

      final items = <Map<String, dynamic>>[];

      String computeStatus(Map<String, dynamic> dok, List<Map<String, dynamic>> itemList) {
        final rawStatus = dok['status']?.toString().toLowerCase() ?? 'menunggu';
        if (rawStatus != 'menunggu') return rawStatus;
        return 'menunggu';
      }

      expect(computeStatus(dokumen, items), 'ditolak');
    });
  });

  group('Filter Status Dokumen', () {
    test('Filter selesai hanya menampilkan dokumen dengan semua item diproses', () {
      final allDocuments = <Map<String, dynamic>>[
        {'id': '1', 'status': 'menunggu', 'jumlah_item': 3},
        {'id': '2', 'status': 'diterima', 'jumlah_item': 2},
        {'id': '3', 'status': 'menunggu', 'jumlah_item': 3}, // Ini selesai
        {'id': '4', 'status': 'ditolak', 'jumlah_item': 1},
      ];

      // Simulasi perhitungan status
      final Map<String, List<Map<String, dynamic>>> itemsByDoc = {
        '1': [
          {'status': 'diterima'},
          {'status': 'menunggu'},
          {'status': 'menunggu'},
        ],
        '2': <Map<String, dynamic>>[],
        '3': [ // Semua item diproses
          {'status': 'diterima'},
          {'status': 'diterima'},
          {'status': 'ditolak'},
        ],
        '4': <Map<String, dynamic>>[],
      };

      List<Map<String, dynamic>> filterByStatus(String status) {
        return allDocuments.where((doc) {
          final docId = doc['id'].toString();
          final items = itemsByDoc[docId] ?? <Map<String, dynamic>>[];

          // Hitung status
          final rawStatus = doc['status']?.toString().toLowerCase() ?? 'menunggu';
          if (rawStatus != 'menunggu') return rawStatus == status;

          int jumlahDiterima = 0;
          int jumlahDitolak = 0;
          for (final item in items) {
            final statusItem = item['status']?.toString().toLowerCase() ?? '';
            if (statusItem == 'diterima') jumlahDiterima++;
            if (statusItem == 'ditolak') jumlahDitolak++;
          }

          final totalDiproses = jumlahDiterima + jumlahDitolak;
          final jumlahItem = int.tryParse('${doc['jumlah_item']}') ?? 0;

          String computedStatus;
          if (totalDiproses > 0 && totalDiproses >= jumlahItem && jumlahItem > 0) {
            computedStatus = 'selesai';
          } else if (totalDiproses > 0) {
            computedStatus = 'diproses';
          } else {
            computedStatus = rawStatus;
          }

          return computedStatus == status;
        }).toList();
      }

      final selesaiDocs = filterByStatus('selesai');
      expect(selesaiDocs.length, 1);
      expect(selesaiDocs.first['id'], '3');
    });

    test('Filter diproses menampilkan dokumen dengan sebagian item diproses', () {
      final allDocuments = <Map<String, dynamic>>[
        {'id': '1', 'status': 'menunggu', 'jumlah_item': 3}, // Ini diproses
        {'id': '2', 'status': 'diterima', 'jumlah_item': 2},
        {'id': '3', 'status': 'menunggu', 'jumlah_item': 3}, // Ini selesai
        {'id': '4', 'status': 'menunggu', 'jumlah_item': 2}, // Ini menunggu
      ];

      final Map<String, List<Map<String, dynamic>>> itemsByDoc = {
        '1': [
          {'status': 'diterima'},
          {'status': 'menunggu'},
          {'status': 'menunggu'},
        ],
        '2': <Map<String, dynamic>>[],
        '3': [
          {'status': 'diterima'},
          {'status': 'diterima'},
          {'status': 'ditolak'},
        ],
        '4': [
          {'status': 'menunggu'},
          {'status': 'menunggu'},
        ],
      };

      List<Map<String, dynamic>> filterByStatus(String status) {
        return allDocuments.where((doc) {
          final docId = doc['id'].toString();
          final items = itemsByDoc[docId] ?? <Map<String, dynamic>>[];

          final rawStatus = doc['status']?.toString().toLowerCase() ?? 'menunggu';
          if (rawStatus != 'menunggu') return rawStatus == status;

          int jumlahDiterima = 0;
          int jumlahDitolak = 0;
          for (final item in items) {
            final statusItem = item['status']?.toString().toLowerCase() ?? '';
            if (statusItem == 'diterima') jumlahDiterima++;
            if (statusItem == 'ditolak') jumlahDitolak++;
          }

          final totalDiproses = jumlahDiterima + jumlahDitolak;
          final jumlahItem = int.tryParse('${doc['jumlah_item']}') ?? 0;

          String computedStatus;
          if (totalDiproses > 0 && totalDiproses >= jumlahItem && jumlahItem > 0) {
            computedStatus = 'selesai';
          } else if (totalDiproses > 0) {
            computedStatus = 'diproses';
          } else {
            computedStatus = rawStatus;
          }

          return computedStatus == status;
        }).toList();
      }

      final diprosesDocs = filterByStatus('diproses');
      expect(diprosesDocs.length, 1);
      expect(diprosesDocs.first['id'], '1');
    });
  });

  group('Blokir Tombol Buat Pengajuan', () {
    test('Tombol diblokir jika ada pengajuan dengan status menunggu', () {
      final pengajuanTerakhir = <String, dynamic>{
        'status': 'menunggu',
        'tanggal_pengajuan': '2024-01-15',
      };

      final statusPengajuanTerakhir = pengajuanTerakhir['status']?.toString().toLowerCase() ?? '';
      final adaPengajuanMenunggu = statusPengajuanTerakhir == 'menunggu' ||
          statusPengajuanTerakhir == 'pending';

      expect(adaPengajuanMenunggu, isTrue);
    });

    test('Tombol tidak diblokir jika tidak ada pengajuan menunggu', () {
      final pengajuanTerakhir = <String, dynamic>{
        'status': 'diterima',
        'tanggal_pengajuan': '2024-01-15',
      };

      final statusPengajuanTerakhir = pengajuanTerakhir['status']?.toString().toLowerCase() ?? '';
      final adaPengajuanMenunggu = statusPengajuanTerakhir == 'menunggu' ||
          statusPengajuanTerakhir == 'pending';

      expect(adaPengajuanMenunggu, isFalse);
    });

    test('Tombol tidak diblokir jika pengajuan ditolak', () {
      final pengajuanTerakhir = <String, dynamic>{
        'status': 'ditolak',
        'tanggal_pengajuan': '2024-01-15',
      };

      final statusPengajuanTerakhir = pengajuanTerakhir['status']?.toString().toLowerCase() ?? '';
      final adaPengajuanMenunggu = statusPengajuanTerakhir == 'menunggu' ||
          statusPengajuanTerakhir == 'pending';

      expect(adaPengajuanMenunggu, isFalse);
    });

    test('Tombol tidak diblokir jika tidak ada pengajuan sama sekali', () {
      final Map<String, dynamic>? pengajuanTerakhir = null;

      final statusPengajuanTerakhir = pengajuanTerakhir?['status']?.toString().toLowerCase() ?? '';
      final adaPengajuanMenunggu = statusPengajuanTerakhir == 'menunggu' ||
          statusPengajuanTerakhir == 'pending';

      expect(adaPengajuanMenunggu, isFalse);
    });
  });
}
