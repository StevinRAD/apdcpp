# Dokumentasi Perubahan Backend - Persetujuan APD Per Item

## 📋 Overview
Perubahan ini memungkinkan admin untuk **menerima sebagian dan menolak sebagian** item APD dalam satu dokumen pengajuan, bukan menerima/menolak semua item sekaligus.

---

## 🗄️ Langkah 1: Jalankan Migration SQL di Supabase

1. Buka **Supabase Dashboard** → **SQL Editor**
2. Buat **New Query** baru
3. Copy-paste seluruh isi file `migration_item_approval.sql`
4. Klik **Run** untuk mengeksekusi

### Apa yang dilakukan oleh migration ini?
- ✅ Menambahkan kolom `status` di tabel `dokumen_pengajuan_item`
- ✅ Menambahkan kolom `catatan_admin` per item
- ✅ Menambahkan kolom `tanggal_proses` per item
- ✅ Menambahkan kolom `id_admin` per item
- ✅ Membuat fungsi `cek_status_dokumen_item()` untuk mengecek status item
- ✅ Membuat trigger otomatis untuk update status dokumen
- ✅ Membuat view `v_persetujuan_dokumen_detail` untuk query yang lebih mudah

---

## 🔧 Langkah 2: Update Frontend (SUDAH DILAKUKAN)

File yang sudah diperbarui:
- ✅ `lib/karyawan/layar_pengajuan_dokumen_apd.dart` - Format alasan baru dengan JSON
- ✅ `lib/karyawan/layar_form_pengajuan_apd.dart` - Alasan baru dengan JSON
- ✅ `lib/services/apd_api_service.dart` - API baru untuk proses per item

---

## 📊 Struktur Database Baru

### Tabel `dokumen_pengajuan_item`
```sql
-- Kolom baru:
status              VARCHAR DEFAULT 'menunggu'  -- 'menunggu', 'diterima', 'ditolak'
catatan_admin       TEXT                          -- Penjelasan admin jika ditolak
tanggal_proses      TIMESTAMPTZ                  -- Kapan item diproses
id_admin            INTEGER REFERENCES admin(id)   -- Siapa yang memproses
```

### Status Dokumen Otomatis
Status dokumen akan otomatis diupdate oleh trigger:
- `diterima` - Semua item diterima
- `ditolak` - Semua item ditolak
- `sebagian_diterima` - Ada item yang diterima dan ada yang ditolak

---

## 🔌 API Baru yang Tersedia

### 1. Proses Satu Item
```dart
await api.prosesItemPengajuan(
  idItem: '123',           // ID item (dari tabel dokumen_pengajuan_item)
  status: 'diterima',      // 'diterima' atau 'ditolak'
  usernameAdmin: 'admin',  // Username admin yang memproses
  catatanAdmin: '...',    // Opsional (jika ditolak)
  lokasiPengambilan: '...', // Opsional (jika diterima)
);
```

### 2. Proses Batch Items
```dart
await api.prosesBatchItemPengajuan(
  idsItem: ['123', '456', '789'], // List ID item yang akan diproses
  status: 'diterima',             // 'diterima' atau 'ditolak'
  usernameAdmin: 'admin',
  catatanAdmin: '...',
  lokasiPengambilan: '...',
);
```

---

## 📝 Contoh Query untuk Debugging

### Cek status semua item dalam dokumen
```sql
SELECT 
  dpi.id,
  a.nama_apd,
  dpi.ukuran,
  dpi.jumlah,
  dpi.status,
  dpi.catatan_admin
FROM dokumen_pengajuan_item dpi
JOIN apd a ON dpi.id_apd = a.id
WHERE dpi.id_pengajuan = 'YOUR_DOKUMEN_ID'
ORDER BY dpi.id;
```

### Cek status dokumen dan ringkasan item
```sql
SELECT * FROM cek_status_dokumen_item('YOUR_DOKUMEN_ID');
```

### Lihat detail lengkap dengan view
```sql
SELECT * FROM v_persetujuan_dokumen_detail
WHERE dokumen_id = 'YOUR_DOKUMEN_ID'
ORDER BY item_id;
```

---

## ⚠️ Catatan Penting

### 1. Data Migration
Data yang sudah ada akan otomatis di-set statusnya ke `menunggu` oleh migration script.

### 2. Backward Compatibility
- Fungsi `prosesDokumenPengajuan` yang lama **MASIH BISA DIGUNAKAN** (untuk proses semua item sekaligus)
- Fungsi baru `prosesItemPengajuan` untuk proses per item

### 3. Trigger Otomatis
Trigger akan otomatis update status dokumen berdasarkan status item:
- Jika semua item `diterima` → dokumen jadi `diterima`
- Jika semua item `ditolak` → dokumen jadi `ditolak`
- Jika campuran → dokumen jadi `sebagian_diterima`

### 4. Pengurangan Stok
Stok APD **HANYA dikurangi** untuk item yang statusnya `diterima`.
Item yang `ditolak` TIDAK akan mengurangi stok.

---

## 🧪 Testing

### Test Case 1: Terima Sebagian, Tolak Sebagian
1. Karyawan ajukan 3 APD dalam satu dokumen
2. Admin buka persetujuan
3. Admin terima item 1 & 2, tolak item 3
4. **Expected**: 
   - Item 1 & 2: status `diterima`, stok berkurang
   - Item 3: status `ditolak`, stok tetap
   - Dokumen: status `sebagian_diterima`

### Test Case 2: Terima Semua
1. Karyawan ajukan 2 APD
2. Admin terima semua item
3. **Expected**: Semua item `diterima`, dokumen jadi `diterima`

### Test Case 3: Tolak Semua
1. Karyawan ajukan 2 APD
2. Admin tolak semua item
3. **Expected**: Semua item `ditolak`, dokumen jadi `ditolak`

---

## 🚀 Next Steps

### Untuk Admin (Frontend)
Perlu update UI persetujuan untuk menampilkan checkbox per item:
```dart
// Pseudocode
CheckboxList(
  items: itemDokumen,
  onChanged: (itemId, isSelected) {
    if (isSelected) {
      itemsDiterima.add(itemId);
    } else {
      itemsDiterima.remove(itemId);
    }
  },
)

// Saat submit
await api.prosesBatchItemPengajuan(
  idsItem: itemsDiterima,
  status: 'diterima',
  ...
);

await api.prosesBatchItemPengajuan(
  idsItem: itemsDitolak,
  status: 'ditolak',
  ...
);
```

### Untuk Karyawan (Notifikasi)
Karyawan akan menerima notifikasi per item, bukan per dokumen.
Informasi status dokumen akan ditampilkan secara keseluruhan.

---

## 📞 Support

Jika ada masalah saat menjalankan migration:
1. Cek apakah tabel `dokumen_pengajuan_item` sudah ada kolom `status`
2. Cek apakah trigger sudah berhasil dibuat
3. Lihat log error di Supabase Dashboard → Logs

---

## ✅ Checklist Setelah Migration

- [ ] Migration SQL berhasil dijalankan
- [ ] Kolom baru muncul di tabel `dokumen_pengajuan_item`
- [ ] Fungsi `cek_status_dokumen_item` bisa dipanggil
- [ ] Trigger `trigger_update_status_dokumen_item` aktif
- [ ] View `v_persetujuan_dokumen_detail` bisa diquery
- [ ] API `prosesItemPengajuan` bisa dipanggil dari frontend
- [ ] Test case berhasil dijalankan

---

**Dibuat**: 20 April 2026  
**Versi**: 1.0
**Status**: Ready untuk Testing
