-- ============================================================
-- MIGRATION: Tambah lokasi_pengambilan ke dokumen_pengajuan
-- Jalankan SQL ini di Supabase SQL Editor
-- ============================================================

-- Tambah kolom lokasi_pengambilan jika belum ada
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'dokumen_pengajuan' AND column_name = 'lokasi_pengambilan'
  ) THEN
    ALTER TABLE dokumen_pengajuan ADD COLUMN lokasi_pengambilan TEXT;
    RAISE NOTICE 'Kolom lokasi_pengambilan berhasil ditambahkan ke dokumen_pengajuan';
  ELSE
    RAISE NOTICE 'Kolom lokasi_pengambilan sudah ada';
  END IF;
END $$;
