-- ============================================================================
-- MIGRATION: Menambahkan dukungan persetujuan per item pada dokumen pengajuan
-- Tanggal: 2026-04-20
-- Tujuan: Admin bisa menerima sebagian dan menolak sebagian item dalam satu dokumen
-- ============================================================================

-- Cek tipe data kolom id di tabel admin terlebih dahulu
DO $$
DECLARE
  admin_id_type TEXT;
BEGIN
  SELECT atttypid::regtype INTO admin_id_type
  FROM pg_attribute
  WHERE attrelid = 'admin'::regclass
    AND attname = 'id';

  RAISE NOTICE 'Tipe data kolom admin.id: %', admin_id_type;

  IF admin_id_type != 'uuid' THEN
    RAISE EXCEPTION 'Tipe data kolom admin.id adalah %, bukan uuid. Harap sesuaikan migration.', admin_id_type;
  END IF;
END $$;

-- ====================================================================
-- BAGIAN 1: Tambahkan kolom-kolom baru
-- ============================================================================

-- 1. Tambahkan kolom status di tabel dokumen_pengajuan_item
-- Status per item: 'menunggu', 'diterima', 'ditolak'
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

-- 2. Tambahkan kolom catatan_admin per item
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

-- 3. Tambahkan kolom tanggal_proses per item
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

-- 4. Tambahkan kolom id_admin per item (UUID, sesuai dengan tipe data admin.id)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'dokumen_pengajuan_item'
      AND column_name = 'id_admin'
  ) THEN
    ALTER TABLE dokumen_pengajuan_item
    ADD COLUMN id_admin UUID;

    -- Tambahkan foreign key constraint secara terpisah
    ALTER TABLE dokumen_pengajuan_item
    ADD CONSTRAINT dokumen_pengajuan_item_id_admin_fkey
    FOREIGN KEY (id_admin) REFERENCES admin(id) ON DELETE SET NULL;
  ELSE
    RAISE NOTICE 'Kolom id_admin sudah ada, dilewati.';
  END IF;
END $$;

-- ====================================================================
-- BAGIAN 2: Buat index untuk performa
-- ====================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE indexname = 'idx_dokumen_pengajuan_item_status'
  ) THEN
    CREATE INDEX idx_dokumen_pengajuan_item_status ON dokumen_pengajuan_item(status);
  ELSE
    RAISE NOTICE 'Index idx_dokumen_pengajuan_item_status sudah ada, dilewati.';
  END IF;
END $$;

-- ====================================================================
-- BAGIAN 3: Update data yang sudah ada
-- ====================================================================

UPDATE dokumen_pengajuan_item
SET status = 'menunggu'
WHERE status IS NULL OR status = '';

-- ====================================================================
-- BAGIAN 4: Buat fungsi helper
-- ====================================================================

-- Fungsi untuk mengecek status semua item dalam dokumen
CREATE OR REPLACE FUNCTION cek_status_dokumen_item(documen_id INTEGER)
RETURNS TABLE(
  total_items BIGINT,
  menunggu BIGINT,
  diterima BIGINT,
  ditolak BIGINT,
  semua_diproses BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) as total_items,
    COUNT(*) FILTER (WHERE status = 'menunggu') as menunggu,
    COUNT(*) FILTER (WHERE status = 'diterima') as diterima,
    COUNT(*) FILTER (WHERE status = 'ditolak') as ditolak,
    (COUNT(*) FILTER (WHERE status IN ('diterima', 'ditolak')) = COUNT(*)) as semua_diproses
  FROM dokumen_pengajuan_item
  WHERE id_pengajuan = documen_id;
END;
$$ LANGUAGE plpgsql;

-- ====================================================================
-- BAGIAN 5: Buat trigger untuk update otomatis status dokumen
-- ====================================================================

-- Drop trigger lama jika ada
DROP TRIGGER IF EXISTS trigger_update_status_dokumen_item ON dokumen_pengajuan_item;

-- Fungsi trigger
CREATE OR REPLACE FUNCTION update_status_dokumen_otomatis()
RETURNS TRIGGER AS $$
DECLARE
  status_info RECORD;
  final_status VARCHAR;
BEGIN
  -- Cek status semua item dalam dokumen ini
  SELECT * INTO status_info FROM cek_status_dokumen_item(NEW.id_pengajuan);

  -- Tentukan status dokumen berdasarkan status item
  IF status_info.semua_diproses THEN
    IF status_info.diterima > 0 AND status_info.ditolak = 0 THEN
      final_status := 'diterima';
    ELSIF status_info.ditolak > 0 AND status_info.diterima = 0 THEN
      final_status := 'ditolak';
    ELSE
      final_status := 'sebagian_diterima';
    END IF;

    -- Update status dokumen hanya jika berubah
    IF OLD.status IS DISTINCT FROM NEW.status THEN
      UPDATE dokumen_pengajuan
      SET status = final_status
      WHERE id = NEW.id_pengajuan;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Buat trigger baru
CREATE TRIGGER trigger_update_status_dokumen_item
AFTER INSERT OR UPDATE OF status ON dokumen_pengajuan_item
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION update_status_dokumen_otomatis();

-- ====================================================================
-- BAGIAN 6: Buat view untuk query yang lebih mudah
-- ====================================================================

-- Drop view lama jika ada
DROP VIEW IF EXISTS v_persetujuan_dokumen_detail CASCADE;

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

-- ====================================================================
-- BAGIAN 7: Grant permissions (sesuaikan dengan setup Supabase Anda)
-- ====================================================================

-- Untuk authenticated users
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE dokumen_pengajuan_item TO authenticated;
GRANT SELECT ON TABLE dokumen_pengajuan TO authenticated;
GRANT SELECT ON TABLE karyawan TO authenticated;
GRANT SELECT ON TABLE admin TO authenticated;
GRANT SELECT ON TABLE apd TO authenticated;
GRANT EXECUTE ON FUNCTION cek_status_dokumen_item TO authenticated;
GRANT EXECUTE ON FUNCTION update_status_dokumen_otomatis TO authenticated;
GRANT SELECT ON TABLE v_persetujuan_dokumen_detail TO authenticated;

-- Untuk service_role (untuk RPC calls)
GRANT ALL ON TABLE dokumen_pengajuan_item TO service_role;
GRANT ALL ON TABLE dokumen_pengajuan TO service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO service_role;

-- ====================================================================
-- SELESAI
-- ====================================================================

DO $$
BEGIN
  RAISE NOTICE 'Migration selesai! Berikut ringkasan:';
  RAISE NOTICE '- Kolom baru ditambahkan ke dokumen_pengajuan_item';
  RAISE NOTICE '- Fungsi cek_status_dokumen_item dibuat';
  RAISE NOTICE '- Trigger update_status_dokumen_otomatis dibuat';
  RAISE NOTICE '- View v_persetujuan_dokumen_detail dibuat';
  RAISE NOTICE '';
  RAISE NOTICE 'Anda bisa sekarang menggunakan:';
  RAISE NOTICE 'SELECT * FROM cek_status_dokumen_item(<dokumen_id>)';
  RAISE NOTICE 'SELECT * FROM v_persetujuan_dokumen_detail;';
END $$;
