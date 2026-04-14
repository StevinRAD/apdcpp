-- Tambahkan kolom jumlah ke tabel pengajuan
ALTER TABLE public.pengajuan
ADD COLUMN IF NOT EXISTS jumlah integer DEFAULT 1;

-- Update semua data yang sudah ada untuk memiliki jumlah = 1
UPDATE public.pengajuan
SET jumlah = 1
WHERE jumlah IS NULL;

-- (Opsional) Jika ingin mengubah default untuk semua pengajuan baru menjadi 1
ALTER TABLE public.pengajuan
ALTER COLUMN jumlah SET DEFAULT 1;
