-- ============================================================================
-- MIGRATION: Menambahkan dukungan persetujuan per item pada dokumen pengajuan
-- Tanggal: 2026-04-20
-- Tujuan: Admin bisa menerima sebagian dan menolak sebagian item dalam satu dokumen
-- ============================================================================

-- 1. Tambahkan kolom status di tabel dokumen_pengajuan_item
-- Status per item: 'menunggu', 'diterima', 'ditolak'
ALTER TABLE dokumen_pengajuan_item
ADD COLUMN status VARCHAR DEFAULT 'menunggu' NOT NULL;

-- 2. Tambahkan kolom catatan_admin per item (opsional, untuk penjelasan penolakan)
ALTER TABLE dokumen_pengajuan_item
ADD COLUMN catatan_admin TEXT;

-- 3. Tambahkan kolom tanggal_proses per item
ALTER TABLE dokumen_pengajuan_item
ADD COLUMN tanggal_proses TIMESTAMPTZ;

-- 4. Tambahkan kolom id_admin per item (untuk tracking siapa yang memproses)
-- Menggunakan UUID karena kolom id di tabel admin adalah UUID
ALTER TABLE dokumen_pengajuan_item
ADD COLUMN id_admin UUID REFERENCES admin(id);

-- 5. Buat index untuk status agar query lebih cepat
CREATE INDEX idx_dokumen_pengajuan_item_status ON dokumen_pengajuan_item(status);

-- 6. Update data yang sudah ada (set status ke 'menunggu' untuk semua item yang sudah ada)
UPDATE dokumen_pengajuan_item
SET status = 'menunggu'
WHERE status IS NULL OR status = '';

-- 7. Buat fungsi untuk mengecek apakah semua item dalam dokumen sudah diproses
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

-- 8. Buat trigger untuk otomatis update status dokumen berdasarkan status item
CREATE OR REPLACE FUNCTION update_status_dokumen_otomatis()
RETURNS TRIGGER AS $$
DECLARE
  status_info RECORD;
BEGIN
  -- Cek status semua item dalam dokumen ini
  SELECT * INTO status_info FROM cek_status_dokumen_item(NEW.id_pengajuan);

  -- Update status dokumen berdasarkan status item
  IF status_info.semua_diproses THEN
    IF status_info.diterima > 0 AND status_info.ditolak = 0 THEN
      -- Semua item diterima
      UPDATE dokumen_pengajuan
      SET status = 'diterima'
      WHERE id = NEW.id_pengajuan;
    ELSIF status_info.ditolak > 0 AND status_info.diterima = 0 THEN
      -- Semua item ditolak
      UPDATE dokumen_pengajuan
      SET status = 'ditolak'
      WHERE id = NEW.id_pengajuan;
    ELSE
      -- Sebagian diterima, sebagian ditolak
      UPDATE dokumen_pengajuan
      SET status = 'sebagian_diterima'
      WHERE id = NEW.id_pengajuan;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 9. Drop trigger lama jika ada, lalu buat trigger baru
DROP TRIGGER IF EXISTS trigger_update_status_dokumen_item ON dokumen_pengajuan_item;

CREATE TRIGGER trigger_update_status_dokumen_item
AFTER INSERT OR UPDATE OF status ON dokumen_pengajuan_item
FOR EACH ROW
EXECUTE FUNCTION update_status_dokumen_otomatis();

-- 10. Buat view untuk mempermudah query persetujuan dengan detail item
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
  ad.nama_lengkap as nama_admin_proses
FROM dokumen_pengajuan dp
JOIN karyawan k ON dp.id_karyawan = k.id
LEFT JOIN admin ad ON dp.id_admin = ad.id
JOIN dokumen_pengajuan_item dpi ON dp.id = dpi.id_pengajuan
LEFT JOIN apd a ON dpi.id_apd = a.id
ORDER BY dp.tanggal_pengajuan DESC, dpi.id;

-- 11. Grant permissions (sesuaikan dengan auth config Supabase Anda)
-- GRANT USAGE ON SCHEMA public TO authenticated;
-- GRANT SELECT, INSERT, UPDATE ON TABLE dokumen_pengajuan_item TO authenticated;
-- GRANT EXECUTE ON FUNCTION cek_status_dokumen_item TO authenticated;
-- GRANT EXECUTE ON FUNCTION update_status_dokumen_otomatis TO authenticated;
