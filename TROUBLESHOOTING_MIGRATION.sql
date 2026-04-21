# Troubleshooting Migration SQL

## 🔧 Error: Foreign Key Constraint (UUID vs INTEGER)

Jika error masih muncul terkait tipe data UUID vs INTEGER, ikuti langkah ini:

### Cek Tipe Data Kolom di Tabel Admin
```sql
-- Cek struktur tabel admin
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'admin'
  AND column_name = 'id';
```

### Cek Tipe Data Kolom di Tabel Dokumen Pengajuan
```sql
-- Cek struktur tabel dokumen_pengajuan
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'dokumen_pengajuan'
ORDER BY ordinal_position;
```

### Cek Tipe Data Kolom di Tabel Dokumen Pengajuan Item
```sql
-- Cek struktur tabel dokumen_pengajuan_item
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'dokumen_pengajuan_item'
ORDER BY ordinal_position;
```

---

## 🗑️ Jika Perlu Reset Migration

### Hapus Kolom yang Sudah Ditambah
```sql
-- Hapus trigger
DROP TRIGGER IF EXISTS trigger_update_status_dokumen_item ON dokumen_pengajuan_item;

-- Hapus fungsi
DROP FUNCTION IF EXISTS update_status_dokumen_otomatis CASCADE;
DROP FUNCTION IF EXISTS cek_status_dokumen_item CASCADE;

-- Hapus view
DROP VIEW IF EXISTS v_persetujuan_dokumen_detail CASCADE;

-- Hapus index
DROP INDEX IF EXISTS idx_dokumen_pengajuan_item_status;

-- Hapus kolom (urutan penting karena dependency)
ALTER TABLE dokumen_pengajuan_item DROP CONSTRAINT IF EXISTS dokumen_pengajuan_item_id_admin_fkey;
ALTER TABLE dokumen_pengajuan_item DROP COLUMN IF EXISTS id_admin;
ALTER TABLE dokumen_pengajuan_item DROP COLUMN IF EXISTS tanggal_proses;
ALTER TABLE dokumen_pengajuan_item DROP COLUMN IF EXISTS catatan_admin;
ALTER TABLE dokumen_pengajuan_item DROP COLUMN IF EXISTS status;
```

---

## ✅ Cek Setelah Migration Berhasil

### 1. Cek Kolom Baru
```sql
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'dokumen_pengajuan_item'
  AND column_name IN ('status', 'catatan_admin', 'tanggal_proses', 'id_admin')
ORDER BY column_name;
```

Expected output:
```
column_name     | data_type           | column_default
----------------|---------------------|------------------------------
status          | character varying   | 'menunggu'::character varying
catatan_admin   | text                 | (null)
tanggal_proses   | timestamp with time zone | (null)
id_admin         | uuid                 | (null)
```

### 2. Test Fungsi
```sql
SELECT * FROM cek_status_dokumen_item(1);
```

Ganti `1` dengan ID dokumen yang valid.

### 3. Cek View
```sql
SELECT * FROM v_persetujuan_dokumen_detail
LIMIT 10;
```

### 4. Cek Trigger
```sql
SELECT
  trigger_name,
  event_manipulation,
  event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'trigger_update_status_dokumen_item';
```

---

## 🔍 Debugging Pesan Error

### Error: "column ... does not exist"
**Solusi**: Kolom belum ditambah. Pastikan migration berjalan sukses.

### Error: "function ... does not exist"
**Solusi**: Fungsi belum dibuat. Cek apakah ada syntax error di CREATE FUNCTION.

### Error: "must be owner of table"
**Solusi**: Pastikan login sebagai admin/owner database.

### Error: "permission denied"
**Solusi**: Grant permissions di bagian paling bawah migration SQL.

---

## 🚀 Quick Fix (Jika Perlu Reset Ulang)

Jika semuanya bermasalah dan ingin reset:

```sql
-- WARNING: Ini akan menghapus SEMUA data terkait!
-- Jalankan hanya jika yakin!

-- 1. Hapus trigger dan fungsi
DROP TRIGGER IF EXISTS trigger_update_status_dokumen_item ON dokumen_pengajuan_item CASCADE;
DROP FUNCTION IF EXISTS update_status_dokumen_otomatis CASCADE;
DROP FUNCTION IF EXISTS cek_status_dokumen_item CASCADE;

-- 2. Hapus view
DROP VIEW IF EXISTS v_persetujuan_dokumen_detail CASCADE;

-- 3. Hapus index
DROP INDEX IF EXISTS idx_dokumen_pengajuan_item_status;

-- 4. Hapus kolom (jika sudah ada)
ALTER TABLE dokumen_pengajuan_item DROP CONSTRAINT IF EXISTS dokumen_pengajuan_item_id_admin_fkey;
ALTER TABLE dokumen_pengajuan_item DROP COLUMN IF EXISTS id_admin;
ALTER TABLE dokumen_pengajuan_item DROP COLUMN IF EXISTS tanggal_proses;
ALTER TABLE dokumen_pengajuan_item DROP COLUMN IF EXISTS catatan_admin;
ALTER TABLE dokumen_pengajuan_item DROP COLUMN IF EXISTS status;

-- 5. Sekarang jalankan migration yang diperbaiki
-- (Copy dari migration_item_approval_safe.sql)
```

---

## 📝 Checklist Verifikasi

Setelah menjalankan migration, cek item ini:

- [ ] Status "NOTICE" muncul dengan informasi yang benar
- [ ] Tidak ada error message
- [ ] Kolom `status` muncul di tabel `dokumen_pengajuan_item`
- [ ] Kolom `id_admin` bertipe UUID, bukan INTEGER
- [ ] Fungsi `cek_status_dokumen_item` bisa dipanggil
- [ ] Trigger `trigger_update_status_dokumen_item` aktif
- [ ] View `v_persetujuan_dokumen_detail` bisa diquery
- [] Index `idx_dokumen_pengajuan_item_status` ada

---

## 💡 Tips

1. **Jalankan per bagian**: Jika error masih muncul, jalankan per bagian satu per satu (bagian 1, lalu 2, dst) untuk mengetahui bagian mana yang bermasalah.

2. **Cek existing columns**: Jalankan query cek kolom terlebih dahulu sebelum migration.

3. **Backup data**: Sebelum menjalankan migration yang menghapus data, selalu backup dulu!

4. **Use safe version**: File `migration_item_approval_safe.sql` sudah dilengkapi dengan pengecekan dan error handling. Gunakan file ini sebagai pengganti `migration_item_approval.sql`.

---

**Update**: 20 April 2026
**Status**: Ready untuk Testing
