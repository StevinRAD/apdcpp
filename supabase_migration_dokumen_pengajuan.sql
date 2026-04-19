-- ============================================================
-- MIGRATION: Sistem Dokumen Pengajuan & Penerimaan APD
-- Jalankan SQL ini di Supabase SQL Editor
-- ============================================================

-- 1. Tabel utama dokumen pengajuan (mengelompokkan multi APD)
CREATE TABLE IF NOT EXISTS dokumen_pengajuan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  id_karyawan UUID NOT NULL REFERENCES karyawan(id) ON DELETE CASCADE,
  tanggal_pengajuan TIMESTAMPTZ NOT NULL DEFAULT now(),
  tanda_tangan_karyawan TEXT,           -- base64 PNG tanda tangan karyawan
  tanda_tangan_admin TEXT,              -- base64 PNG tanda tangan admin (diisi saat diterima)
  status TEXT NOT NULL DEFAULT 'menunggu',  -- menunggu / diterima / ditolak
  catatan_admin TEXT,
  tanggal_proses TIMESTAMPTZ,
  id_admin UUID REFERENCES admin(id) ON DELETE SET NULL,
  tanggal_penerimaan TIMESTAMPTZ,       -- waktu karyawan konfirmasi terima
  tanda_tangan_penerimaan TEXT,         -- base64 PNG TTD karyawan saat konfirmasi terima
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Perbaiki tabel item jika sudah ada dengan nama kolom salah
DO $$
BEGIN
  -- Cek apakah tabel dokumen_pengajuan_item sudah ada
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'dokumen_pengajuan_item') THEN
    -- Cek apakah kolom id_dokumen ada (nama lama yang salah)
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_name = 'dokumen_pengajuan_item' AND column_name = 'id_dokumen'
    ) THEN
      -- Rename kolom dari id_dokumen ke id_pengajuan
      ALTER TABLE dokumen_pengajuan_item RENAME COLUMN id_dokumen TO id_pengajuan;
      RAISE NOTICE 'Kolom id_dokumen berhasil diubah ke id_pengajuan';
    END IF;
  ELSE
    -- Tabel belum ada, buat tabel baru
    CREATE TABLE dokumen_pengajuan_item (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      id_pengajuan UUID NOT NULL REFERENCES dokumen_pengajuan(id) ON DELETE CASCADE,
      id_apd UUID NOT NULL REFERENCES apd(id) ON DELETE CASCADE,
      ukuran TEXT,
      alasan TEXT,
      jumlah INT NOT NULL DEFAULT 1,
      created_at TIMESTAMPTZ DEFAULT now()
    );
    RAISE NOTICE 'Tabel dokumen_pengajuan_item berhasil dibuat';
  END IF;
END $$;

-- 3. Tambah kolom tanda tangan di tabel admin (jika belum ada)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'admin' AND column_name = 'tanda_tangan'
  ) THEN
    ALTER TABLE admin ADD COLUMN tanda_tangan TEXT;
  END IF;
END $$;

-- 4. Drop index lama jika ada
DROP INDEX IF EXISTS idx_dokumen_pengajuan_item_dokumen CASCADE;

-- 5. Indexes untuk performa query
CREATE INDEX IF NOT EXISTS idx_dokumen_pengajuan_karyawan
  ON dokumen_pengajuan(id_karyawan);
CREATE INDEX IF NOT EXISTS idx_dokumen_pengajuan_status
  ON dokumen_pengajuan(status);
CREATE INDEX IF NOT EXISTS idx_dokumen_pengajuan_admin
  ON dokumen_pengajuan(id_admin);
CREATE INDEX IF NOT EXISTS idx_dokumen_pengajuan_item_pengajuan
  ON dokumen_pengajuan_item(id_pengajuan);

-- 6. RLS (Row Level Security) - aktifkan jika diperlukan
-- ALTER TABLE dokumen_pengajuan ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE dokumen_pengajuan_item ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- SELESAI: Jalankan migration ini di Supabase SQL Editor
-- ============================================================
