-- ============================================================================
-- MIGRATION: Menambahkan dukungan persetujuan per item (VERSI TANPA TRIGGER)
-- Tanggal: 2026-04-20
-- Tujuan: Admin bisa menerima sebagian dan menolak sebagian item dalam satu dokumen
--
-- CATATAN: Versi ini TANPA trigger otomatis untuk update status dokumen.
-- Status dokumen akan diupdate secara manual dari API.
-- ============================================================================

-- ==========================================
-- BAGIAN 1: Drop Trigger Lama yang Conflict
-- ==========================================

-- Drop trigger yang mungkin ada di dokumen_pengajuan_item
DROP TRIGGER IF EXISTS trigger_update_status_dokumen_item ON dokumen_pengajuan_item CASCADE;

-- Drop trigger lain yang mungkin conflict
DROP TRIGGER IF EXISTS on_dokumen_pengajuan_item_insert ON dokumen_pengajuan_item CASCADE;
DROP TRIGGER IF EXISTS on_dokumen_pengajuan_item_update ON dokumen_pengajuan_item CASCADE;

-- Drop fungsi lama jika ada
DROP FUNCTION IF EXISTS update_status_dokumen_otomatis CASCADE;
DROP FUNCTION IF EXISTS cek_status_dokumen_item CASCADE;

-- Drop view lama jika ada
DROP VIEW IF EXISTS v_persetujuan_dokumen_detail CASCADE;

-- ==========================================
-- BAGIAN 2: Tambahkan Kolom Baru
-- ==========================================

DO $$
BEGIN
  -- Cek apakah kolom sudah ada
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'dokumen_pengajuan_item'
      AND column_name = 'status'
  ) THEN
    ALTER TABLE dokumen_pengajuan_item
    ADD COLUMN status VARCHAR DEFAULT 'menunggu' NOT NULL;
  ELSE
    RAISE NOTICE 'Kolom status sudah ada, dilewati.';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'dokumen_pengajuan_item'
      AND column_name = 'catatan_admin'
  ) THEN
    ALTER TABLE dokumen_pengajuan_item
    ADD COLUMN catatan_admin TEXT;
  ELSE
    RAISE NOTICE 'Kolom catatan_admin sudah ada, dilewati.';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'dokumen_pengajuan_item'
      AND column_name = 'tanggal_proses'
  ) THEN
    ALTER TABLE dokumen_pengajuan_item
    ADD COLUMN tanggal_proses TIMESTAMPTZ;
  ELSE
    RAISE NOTICE 'Kolom tanggal_proses sudah ada, dilewati.';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'dokumen_pengajuan_item'
      AND column_name = 'id_admin'
  ) THEN
    ALTER TABLE dokumen_pengajuan_item
    ADD COLUMN id_admin UUID;

    -- Tambahkan foreign key constraint
    ALTER TABLE dokumen_pengajuan_item
    ADD CONSTRAINT dokumen_pengajuan_item_id_admin_fkey
    FOREIGN KEY (id_admin) REFERENCES admin(id) ON DELETE SET NULL;
  ELSE
    RAISE NOTICE 'Kolom id_admin sudah ada, dilewati.';
  END IF;
END $$;

-- ==========================================
-- BAGIAN 3: Update Data yang Sudah Ada
-- ==========================================

UPDATE dokumen_pengajuan_item
SET status = 'menunggu'
WHERE status IS NULL OR status = '';

-- ==========================================
-- BAGIAN 4: Buat Index
-- ==========================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE indexname = 'idx_dokumen_pengajuan_item_status'
  ) THEN
    CREATE INDEX idx_dokumen_pengajuan_item_status
    ON dokumen_pengajuan_item(status);
  ELSE
    RAISE NOTICE 'Index idx_dokumen_pengajuan_item_status sudah ada, dilewati.';
  END IF;
END $$;

-- ==========================================
-- BAGIAN 5: Buat View (untuk query yang lebih mudah)
-- ==========================================

CREATE OR REPLACE VIEW v_persetujuan_dokumen_detail AS
SELECT
  dp.id as dokumen_id,
  dp.tanggal_pengajuan,
  dp.status as status_dokumen,
  dp.catatan_admin as catatan_dokumen,
  dp.lokasi_pengambilan,
  k.nama_lengkap as nama_karyawan,
  k.username as username_karyawan,
  k.jabatan,
  k.departemen,
  dpi.id as item_id,
  dpi.id_apd,
  a.nama_apd,
  dpi.ukuran,
  dpi.jumlah,
  dpi.alasan,
  dpi.status as status_item,
  dpi.catatan_admin as catatan_item,
  dpi.tanggal_proses as tanggal_proses_item,
  dpi.id_admin,
  ad.nama_lengkap as nama_admin_proses,
  ad.username as username_admin_proses
FROM dokumen_pengajuan dp
JOIN karyawan k ON dp.id_karyawan = k.id
LEFT JOIN admin ad ON dp.id_admin = ad.id
JOIN dokumen_pengajuan_item dpi ON dp.id = dpi.id_pengajuan
LEFT JOIN apd a ON dpi.id_apd = a.id
ORDER BY dp.tanggal_pengajuan DESC, dpi.id;

-- ==========================================
-- BAGIAN 6: Grant Permissions
-- ==========================================

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE dokumen_pengajuan_item TO authenticated;
GRANT SELECT ON TABLE dokumen_pengajuan TO authenticated;
GRANT SELECT ON TABLE karyawan TO authenticated;
GRANT SELECT ON TABLE admin TO authenticated;
GRANT SELECT ON TABLE apd TO authenticated;
GRANT SELECT ON TABLE v_persetujuan_dokumen_detail TO authenticated;

-- ==========================================
-- SELESAI
-- ==========================================

DO $$
BEGIN
  RAISE NOTICE 'Migration selesai! Berikut ringkasan:';
  RAISE NOTICE '  - Kolom baru ditambahkan ke dokumen_pengajuan_item';
  RAISE NOTICE '  - View v_persetujuan_dokumen_detail dibuat';
  RAISE NOTICE '';
  RAISE NOTICE '  Catatan: Status dokumen akan diupdate secara manual dari API';
  RAISE NOTICE '  (bukan oleh trigger seperti versi sebelumnya)';
  RAISE NOTICE '';
  RAISE NOTICE 'Anda bisa sekarang menggunakan:';
  RAISE NOTICE '  SELECT * FROM v_persetujuan_dokumen_detail;';
END $$;
