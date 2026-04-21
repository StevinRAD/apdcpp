# Contoh Implementasi UI Persetujuan Per Item

## 📋 Overview
Berikut adalah contoh implementasi UI di `layar_persetujuan_apd_admin.dart` untuk menampilkan checkbox per item, memungkinkan admin memilih item mana yang akan diterima/ditolak.

---

## 🎯 Konsep UI

### Tampilan Detail Dokumen dengan Checkbox Per Item

```dart
// Di dalam _bukaDetail() untuk dokumen (tipe == 'dokumen')
void _bukaDetailDokumen(Map<String, dynamic> dokumen) async {
  // Load items dari dokumen
  final response = await _api.detailDokumenPengajuan(dokumen['id']);
  final data = _api.extractMapData(response);
  final items = _api.extractListData(data['items']);
  
  // State untuk checkbox
  final Set<String> _itemsDiterima = {}; // ID item yang akan diterima
  final Set<String> _itemsDitolak = {}; // ID item yang akan ditolak
  final Map<String, TextEditingController> _catatanControllers = {};
  
  // Parse alasan dari JSON
  String _parseAlasan(String? alasanRaw) {
    if (alasanRaw == null || alasanRaw.isEmpty) return '-';
    
    try {
      final decoded = jsonDecode(alasanRaw);
      final jenis = decoded['jenis_alasan'] ?? alasanRaw;
      final penjelasan = decoded['penjelasan'] ?? '';
      
      if (penjelasan.isNotEmpty) {
        return '$jenis: $penjelasan';
      }
      return jenis;
    } catch (_) {
      return alasanRaw;
    }
  }
  
  // Tampilkan dialog dengan checkbox per item
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Persetujuan Per Item',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Pilih item yang ingin diterima atau ditolak',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                
                // List items dengan checkbox
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final itemId = item['id']?.toString() ?? '';
                      final isDiterima = _itemsDiterima.contains(itemId);
                      final isDitolak = _itemsDitolak.contains(itemId);
                      
                      return Card(
                        margin: EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Nama APD & Status Checkbox
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['nama_apd'] ?? '-',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            _buildInfoChip('Ukuran', item['ukuran'] ?? '-'),
                                            SizedBox(width: 8),
                                            _buildInfoChip('Jml', '${item['jumlah'] ?? 1}'),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Checkbox Terima
                                  CheckboxListTile(
                                    title: Text('Terima'),
                                    value: isDiterima,
                                    onChanged: (value) {
                                      setModalState(() {
                                        if (value == true) {
                                          _itemsDiterima.add(itemId);
                                          _itemsDitolak.remove(itemId);
                                        } else {
                                          _itemsDiterima.remove(itemId);
                                        }
                                      });
                                    },
                                    controlAffinity: ListTileControlAffinity.leading,
                                    activeColor: Colors.green,
                                    checkboxShape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  
                                  // Checkbox Tolak
                                  CheckboxListTile(
                                    title: Text('Tolak'),
                                    value: isDitolak,
                                    onChanged: (value) {
                                      setModalState(() {
                                        if (value == true) {
                                          _itemsDitolak.add(itemId);
                                          _itemsDiterima.remove(itemId);
                                        } else {
                                          _itemsDitolak.remove(itemId);
                                        }
                                      });
                                    },
                                    activeColor: Colors.red,
                                    checkboxShape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: 12),
                              
                              // Alasan (parsed)
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Alasan:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      _parseAlasan(item['alasan']?.toString()),
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Catatan admin jika ditolak
                              if (isDitolak) ...[
                                SizedBox(height: 12),
                                TextField(
                                  controller: _catatanControllers.putIfAbsent(
                                    itemId,
                                    () => TextEditingController(),
                                  ),
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    labelText: 'Catatan Penolakan *',
                                    hintText: 'Jelaskan kenapa ditolak...',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.all(12),
                                  ),
                                ),
                              ],
                              
                              // Foto bukti jika ada
                              if (_parseAlasan(item['alasan']?.toString()).contains('APD Lama Rusak')) ...[
                                SizedBox(height: 12),
                                Text(
                                  'Bukti Foto:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    _extractFotoBukti(item['alasan']?.toString()),
                                    height: 120,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 120,
                                      color: Colors.grey.shade200,
                                      alignment: Alignment.center,
                                      child: Text('Foto tidak tersedia'),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Summary & Action Buttons
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Column(
                    children: [
                      // Summary
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem('Total', '${items.length}', Colors.blue),
                          _buildSummaryItem('Diterima', '${_itemsDiterima.length}', Colors.green),
                          _buildSummaryItem('Ditolak', '${_itemsDitolak.length}', Colors.red),
                          _buildSummaryItem('Belum', '${items.length - _itemsDiterima.length - _itemsDitolak.length}', Colors.grey),
                        ],
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Catatan admin umum (optional)
                      TextField(
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Catatan Umum (Opsional)',
                          hintText: 'Catatan untuk seluruh dokumen...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.close),
                              label: Text('Batal'),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: _itemsDiterima.isEmpty && _itemsDitolak.isEmpty
                                  ? null
                                  : () => _prosesPersetujuanPerItem(
                                        dokumenId: dokumen['id'],
                                        itemsDiterima: _itemsDiterima.toList(),
                                        itemsDitolak: _itemsDitolak.toList(),
                                        catatanControllers: _catatanControllers,
                                      ),
                              icon: Icon(Icons.check_circle),
                              label: Text('Proses'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: TemaAplikasi.biruTua,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// Helper widget untuk info chip
Widget _buildInfoChip(String label, String value) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '$label: $value',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

// Helper widget untuk summary
Widget _buildSummaryItem(String label, String value, Color color) {
  return Column(
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      Text(
        label,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
    ],
  );
}

// Extract foto bukti from alasan JSON
String _extractFotoBukti(String? alasanRaw) {
  if (alasanRaw == null || alasanRaw.isEmpty) return '';
  
  try {
    final decoded = jsonDecode(alasanRaw);
    return decoded['foto_bukti']?.toString() ?? '';
  } catch (_) {
    return '';
  }
}

// Proses persetujuan per item
Future<void> _prosesPersetujuanPerItem({
  required String dokumenId,
  required List<String> itemsDiterima,
  required List<String> itemsDitolak,
  required Map<String, TextEditingController> catatanControllers,
}) async {
  // Proses item yang diterima
  for (final itemId in itemsDiterima) {
    final response = await _api.prosesItemPengajuan(
      idItem: itemId,
      status: 'diterima',
      usernameAdmin: widget.usernameAdmin,
      catatanAdmin: null, // Catatan umum di dokumen
      lokasiPengambilan: 'Gudang APD Lt. 2', // Sesuaikan dengan kebutuhan
    );
    
    if (!_api.isSuccess(response)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memproses item: ${_api.message(response)}'),
          backgroundColor: TemaAplikasi.bahaya,
        ),
      );
    }
  }
  
  // Proses item yang ditolak
  for (final itemId in itemsDitolak) {
    final catatan = catatanControllers[itemId]?.text.trim() ?? '';
    
    if (catatan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Catatan penolakan wajib diisi'),
          backgroundColor: TemaAplikasi.bahaya,
        ),
      );
      return;
    }
    
    final response = await _api.prosesItemPengajuan(
      idItem: itemId,
      status: 'ditolak',
      usernameAdmin: widget.usernameAdmin,
      catatanAdmin: catatan,
    );
    
    if (!_api.isSuccess(response)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memproses item: ${_api.message(response)}'),
          backgroundColor: TemaAplikasi.bahaya,
        ),
      );
    }
  }
  
  // Tutup dialog dan refresh data
  Navigator.pop(context);
  await _loadData();
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('${itemsDiterima.length} item diterima, ${itemsDitolak.length} item ditolak'),
      backgroundColor: TemaAplikasi.sukses,
    ),
  );
}
```

---

## 🔧 Integrasi dengan Kode yang Sudah Ada

### Di `layar_persetujuan_apd_admin.dart`

Ubah `_buildTombolAksi` untuk tipe dokumen:

```dart
Widget _buildTombolAksi(Map<String, dynamic> item) {
  final tipe = item['tipe']?.toString() ?? 'single';

  if (tipe == 'dokumen') {
    // Sistem baru: Buka dialog dengan checkbox per item
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _bukaDetailDokumen(item),
            icon: const Icon(Icons.checklist_outlined),
            label: const Text('Proses Per Item'),
            style: ElevatedButton.styleFrom(
              backgroundColor: TemaAplikasi.biruTua,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              // Opsi: Terima semua dengan satu klik
              final result = await _inputPenerimaanPengajuan();
              if (result == null) return;
              Navigator.of(context).pop();
              await _prosesStatus(
                item: item,
                status: 'Disetujui',
                catatan: result.catatan,
                lokasiPengambilan: result.lokasi,
              );
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Terima Semua'),
            style: ElevatedButton.styleFrom(
              backgroundColor: TemaAplikasi.sukses,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              // Opsi: Tolak semua
              final alasan = await _inputCatatanPenolakan();
              if (alasan == null) return;
              Navigator.of(context).pop();
              await _prosesStatus(
                item: item,
                status: 'Ditolak',
                catatan: alasan,
              );
            },
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Tolak Semua'),
            style: ElevatedButton.styleFrom(
              backgroundColor: TemaAplikasi.bahaya,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
  
  // ... (kode existing untuk tipe single)
}
```

---

## 📝 Catatan Penting

### 1. Import yang Diperlukan
```dart
import 'dart:convert';
```

### 2. State Management
Gunakan `StatefulBuilder` atau `setState` untuk memperbarui UI saat checkbox diklik.

### 3. Validasi
Pastikan semua item dipilih (diterima atau ditolak) sebelum submit.

### 4. Catatan Penolakan
Catatan WAJIB diisi untuk item yang ditolak.

### 5. Foto Bukti
Foto bukti ditampilkan jika alasan mengandung "APD Lama Rusak".

---

## ✅ Testing Checklist

- [ ] Checkbox untuk Terima berfungsi
- [ ] Checkbox untuk Tolak berfungsi
- [ ] Satu item tidak bisa dipilih Terima dan Tolak secara bersamaan
- [ ] Catatan penolakan muncul saat item ditolak
- [ ] Validasi: tidak bisa proses jika ada item belum dipilih
- [ ] Validasi: catatan wajib untuk item yang ditolak
- [ ] Foto bukti muncul untuk alasan "APD Lama Rusak"
- [ ] Summary count update secara real-time
- [ ] Notifikasi muncul setelah proses berhasil
- [ ] Data refresh setelah proses selesai

---

**Dibuat**: 20 April 2026  
**Status**: Contoh Implementasi - Siap untuk Integrasi
