# Panduan Migrasi Aplikasi APD Prima ke Supabase

Berikut adalah langkah-langkah lengkap beserta dengan *SQL Schema* yang diperlukan untuk memigrasi sistem backend (*XAMPP/PHP* & *MySQL*) dari aplikasi "APD Prima" Anda menjadi berbasis **Supabase** secara keseluruhan.

## Langkah 1: Persiapan Database (SQL Editor Supabase)

1. Buka [Dashboard Supabase](https://app.supabase.com/) dan buat proyek baru (atau buka proyek yang sudah ada).
2. Masuk ke menu **SQL Editor** di panel sebelah kiri.
3. Klik **New Query**, kemudian *copy* dan *paste* kode SQL di bawah ini.
4. Klik **Run** atau tekan `Ctrl + Enter` (Windows) / `Cmd + Enter` (Mac) untuk membuat seluruh tabel yang dibutuhkan.

```sql
-- 1. TABEL KARYAWAN
CREATE TABLE karyawan (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  username TEXT UNIQUE NOT NULL,
  password TEXT NOT NULL,
  nama_lengkap TEXT NOT NULL,
  jabatan TEXT,
  departemen TEXT,
  lokasi_kerja TEXT,
  status TEXT DEFAULT 'aktif', -- 'aktif', 'nonaktif', dll
  cooldown_pengajuan_hari INT DEFAULT 0,
  banned_until TIMESTAMPTZ,
  foto_profil TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. TABEL ADMIN
CREATE TABLE admin (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  username TEXT UNIQUE NOT NULL,
  password TEXT NOT NULL,
  nama_lengkap TEXT NOT NULL,
  peran_admin TEXT DEFAULT 'admin_biasa', -- 'superadmin', 'admin_biasa'
  foto_profil TEXT,
  pertanyaan_1 TEXT,
  jawaban_1 TEXT,
  pertanyaan_2 TEXT,
  jawaban_2 TEXT,
  pertanyaan_3 TEXT,
  jawaban_3 TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. TABEL MASTER APD
CREATE TABLE apd (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nama_apd TEXT NOT NULL,
  stok INT DEFAULT 0,
  min_stok INT DEFAULT 0,
  satuan TEXT,
  deskripsi TEXT,
  is_aktif BOOLEAN DEFAULT true,
  gambar_apd TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. TABEL PENGAJUAN
CREATE TABLE pengajuan (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  id_karyawan UUID REFERENCES karyawan(id) ON DELETE CASCADE,
  id_apd UUID REFERENCES apd(id) ON DELETE CASCADE,
  ukuran TEXT,
  alasan_pengajuan TEXT,
  bukti_foto TEXT,
  status_pengajuan TEXT DEFAULT 'menunggu', -- 'menunggu', 'diproses', 'selesai', 'ditolak'
  id_admin UUID REFERENCES admin(id) ON DELETE SET NULL,
  catatan_admin TEXT,
  lokasi_pengambilan TEXT,
  tanggal_pengajuan TIMESTAMPTZ DEFAULT NOW(),
  tanggal_proses TIMESTAMPTZ
);

-- 5. TABEL NOTIFIKASI KARYAWAN
CREATE TABLE notifikasi_karyawan (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  id_karyawan UUID REFERENCES karyawan(id) ON DELETE CASCADE,
  isi TEXT NOT NULL,
  is_dibaca BOOLEAN DEFAULT false,
  tanggal TIMESTAMPTZ DEFAULT NOW()
);

-- 6. TABEL KALENDER PERUSAHAAN
CREATE TABLE kalender_perusahaan (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tanggal DATE NOT NULL,
  jam_mulai TIME,
  jam_selesai TIME,
  judul TEXT NOT NULL,
  keterangan TEXT,
  is_libur BOOLEAN DEFAULT false,
  is_aktif BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. TABEL BERITA
CREATE TABLE berita (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  judul TEXT NOT NULL,
  ringkasan TEXT,
  isi TEXT,
  kategori TEXT,
  is_aktif BOOLEAN DEFAULT true,
  id_admin UUID REFERENCES admin(id) ON DELETE SET NULL,
  gambar_berita TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. TABEL BANTUAN LOGIN
CREATE TABLE bantuan_login (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  username TEXT NOT NULL,
  nama_lengkap TEXT NOT NULL,
  password_diingat TEXT,
  alasan_kendala TEXT,
  status TEXT DEFAULT 'menunggu', -- 'menunggu', 'diproses', 'selesai'
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. INSERT DEFAULT SUPERADMIN (Password: admin123)
-- Pastikan password hashing diterapkan nantinya pada Flutter, atau gunakan plaintext secara default sama seperti aplikasi saat ini jika Anda belum melakukan hashing
INSERT INTO admin (username, password, nama_lengkap, peran_admin) 
VALUES ('admin', 'admin123', 'Administrator Utama', 'superadmin');

-- 10. INSERT CONTOH KARYAWAN (Password: user123)
INSERT INTO karyawan (username, password, nama_lengkap, jabatan, departemen)
VALUES ('user01', 'user123', 'Karyawan Contoh', 'Staff', 'IT');
```

## Langkah 2: Persiapan Storage Supabase (Untuk Foto/File)

Aplikasi API sebelumnya menggunakan penyimpanan foto di path PHP `uploads/`. Sekarang, kita menggunakan **Supabase Storage**.
1. Di Dashboard Supabase, pergi ke menu **Storage**.
2. Klik **New Bucket**, lalu beri nama `uploads` dan centang opsi **Public**.
3. Di dalam *bucket* `uploads`, Anda dapat menggunakan struktur folder (misalnya `apd/`, `pengajuan/`, `profil/`, `berita/`) yang mana nantinya akan diakses melalui URL: `https://[PROJECT_REF].supabase.co/storage/v1/object/public/uploads/...`.

## Langkah 3: Menjalin Hubungan (Supabase & Flutter)

### 3.1. Salin Library & Asset dari _Old Project_
Untuk "meniru" UI/UX 100% dari aplikasi XAMPP, Anda hanya perlu menyalin folder di bawah ini (yang memuat semua *screens* atau *design* yang sudah jadi) ke folder Anda yang baru (`apdcpp`):
- `C:\Users\ell\Documents\KP Aplikasi APD 2026\apdcentralproteinprima\lib` ke `C:\Users\ell\Documents\KP Aplikasi APD 2026\apdcpp\lib`
- `C:\Users\ell\Documents\KP Aplikasi APD 2026\apdcentralproteinprima\assets` ke `C:\Users\ell\Documents\KP Aplikasi APD 2026\apdcpp\assets`
Serta jangan lupa menambahkan `assets/` ke dalam `pubspec.yaml` (jika menggunakan font dan gambar).

### 3.2. Install Supabase SDK
Buka terminal dan arahkan pada `apdcpp` lalu install SDK:
```bash
flutter pub add supabase_flutter
```

### 3.3. Inisialisasi Supabase di Aplikasi
Pada aplikasi di `lib/main.dart`, inisialisasikan kunci koneksinya:
```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apdcpp/awal/layar_memuat.dart'; // import app anda
import 'package:apdcpp/tema_aplikasi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Masukkan Supabase Project URL dan Anon Key
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  runApp(const AplikasiAPD());
}

class AplikasiAPD extends StatelessWidget {
  const AplikasiAPD({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi APD Prima',
      debugShowCheckedModeBanner: false,
      theme: TemaAplikasi.tema,
      home: const LayarMemuat(),
    );
  }
}
```

### 3.4. Refactor `api_apd_service.dart` Kepada SDK Supabase
Inti dari memutus koneksi `XAMPP PHP` adalah mengubah fungsi `http.post` dalam `ApiApdService` menjadi memanggil Object `.rpc` atau `.select()` dari Supabase.
Misal, di backend sebelumnya untuk mengambil list APD:
```dart
  Future<Map<String, dynamic>> daftarApd() {
    return get(endpoint: 'get_daftar_apd.php');
  }
```

Ubah seluruh service Anda dengan Supabase SDK langsung seperti ini:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiApdService {
  const ApiApdService();
  // Tidak ada URL Api Http lagi.
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> daftarApd() async {
     try {
       final response = await _supabase
           .from('apd')
           .select()
           .eq('is_aktif', true)
           .order('nama_apd', ascending: true);
           
       return {
          'status': 'sukses',
          'data': response
       };
    } catch (e) {
       return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }
  
  Future<Map<String, dynamic>> loginKaryawan({
    required String username,
    required String password,
  }) async {
    try {
      // Menggunakan query database biasa seperti MySQL
      final response = await _supabase
          .from('karyawan')
          .select()
          .eq('username', username)
          .eq('password', password)
          .maybeSingle();

      if (response != null) {
        if (response['status'] == 'nonaktif') {
           return {'status': 'gagal', 'pesan': 'Akun karyawan nonaktif.'};
        }
        return {
          'status': 'sukses',
          'pesan': 'Login Berhasil',
          'data': response // Langsung set di UI Sesi Service
        };
      } else {
        return {'status': 'gagal', 'pesan': 'Username atau password salah.'};
      }
    } catch (e) {
      return {'status': 'gagal', 'pesan': 'Error: $e'};
    }
  }

  // .... Dan ubah metode lainnya dari API XAMPP ke _supabase API
}
```

## Tindakan Selanjutnya
1. Lakukan *copy paste* struktur folder (`lib` dan `assets`) dari proyek lama ke proyek `apdcpp` Anda yang baru.
2. Silakan jalankan `SQL Editor Script` di dashboard Supabase Anda.
3. Konfirmasi apakah saya harus langsung mulai memodifikasi `apdcpp/lib` (memasukkan SDK, Supabase setup, dan *full refactor* API servicenya) dengan tool yang saya miliki. Saya bisa mereplikasi keseluruhan XAMPP API ini menjadi Supabase call secara instan untuk Anda!
