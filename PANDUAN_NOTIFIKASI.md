# Panduan Notifikasi Aplikasi APD

## 📱 Fitur Notifikasi

Aplikasi APD sudah dilengkapi sistem notifikasi lengkap:

### ✅ Notifikasi Dalam Aplikasi
- Notifikasi muncul di dalam aplikasi (di menu Notifikasi)
- Update real-time saat ada perubahan data

### ✅ Notifikasi Luar Aplikasi (Push Notification)
- Notifikasi muncul di status bar HP
- Muncul meskipun aplikasi sedang tertutup
- Dengan suara notifikasi kustom
- Dengan getar (vibration)

---

## 🔔 Suara Notifikasi

### Lokasi Folder File Suara

#### Android
```
android/app/src/main/res/raw/
```

#### iOS
```
ios/Runner/
```
*(File harus ditambahkan melalui Xcode)*

---

## 📝 Format File Suara yang Diperlukan

| Nama File | Android | iOS | Kegunaan |
|-----------|---------|-----|----------|
| `notifikasi.mp3` | ✅ | ✅ | Notifikasi default |
| `pengajuan.mp3` | ✅ | ✅ | Notifikasi pengajuan baru |
| `persetujuan.mp3` | ✅ | ✅ | Notifikasi persetujuan |
| `berita.mp3` | ✅ | ✅ | Notifikasi berita/update |
| `peringatan.mp3` | ✅ | ✅ | Notifikasi peringatan |

### Spesifikasi File Suara

#### Android (.mp3)
- **Format**: MP3
- **Sample Rate**: 44.1kHz atau 48kHz
- **Bitrate**: 128kbps - 320kbps
- **Durasi**: 1-5 detik (direkomendasikan 2-3 detik)
- **Ukuran**: < 100KB per file

#### iOS (.wav atau .mp3)
- **Format**: WAV atau MP3
- **Sample Rate**: 44.1kHz
- **Bit Depth**: 16-bit (untuk WAV)
- **Durasi**: 1-5 detik

---

## 🎵 Cara Menambahkan File Suara

### untuk Android:

1. Siapkan file MP3 dengan nama sesuai tabel di atas
2. Copy file ke folder: `android/app/src/main/res/raw/`
3. Pastikan nama file hanya menggunakan huruf kecil
4. Build ulang aplikasi

```bash
# Build APK
flutter build apk

# Install ke HP
flutter install
```

### untuk iOS:

1. Buka project iOS di Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. Drag & drop file suara ke project navigator Xcode

3. Pastikan:
   - ✅ "Copy items if needed" tercentang
   - ✅ Target "Runner" dipilih
   - ✅ "Create groups" dipilih

4. Build project iOS dari Xcode

---

## 🎯 Cara Mendapatkan File Suara

### Opsi 1: Situs Download Gratis

- **Freesound.org**: https://freesound.org/
- **Zapsplat.com**: https://www.zapsplat.com/
- **Mixkit.co**: https://mixkit.co/free-sound-effects/

Cari keywords: "notification", "bell", "chime", "alert"

### Opsi 2: AI Sound Generator

- **Soundraw.io**: https://soundraw.io/
- **AIVA**: https://www.aiva.ai/

### Opsi 3: Buat Sendiri

Gunakan audio editor gratis:
- **Audacity**: https://www.audacityteam.org/
- **Ocenaudio**: https://www.ocenaudio.com/

---

## 🔧 Konfigurasi Notifikasi

### Android (API 33+)

Tambahkan permission di `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

### iOS

Permission sudah otomatis ditambahkan oleh package `flutter_local_notifications`.

---

## 📲 Cara Menggunakan Notifikasi

### Di Kode Dart:

```dart
import 'package:apdcpp/services/notifikasi_lokal_service.dart';

// Notifikasi pengajuan baru
await NotifikasiLokalService.tampilkanNotifikasiPengajuanBaru(
  namaKaryawan: 'Budi Santoso',
  jenisApd: 'Helm Safety',
);

// Notifikasi status berubah
await NotifikasiLokalService.tampilkanNotifikasiStatusPengajuan(
  status: 'Disetujui',
  keterangan: 'Silakan ambil di gudang',
);

// Notifikasi berita
await NotifikasiLokalService.tampilkanNotifikasiBerita(
  judulBerita: 'Update kebijakan penggunaan APD',
);
```

---

## ✨ Fitur Suara Notifikasi

Setiap tipe notifikasi memiliki suara berbeda:

1. **Pengajuan Baru** → Suara `pengajuan.mp3`
   - Ding-ding ringan
   - Menandakan ada pengajuan masuk

2. **Persetujuan** → Suara `persetujuan.mp3`
   - Chime menyenangkan
   - Menandakan pengajuan disetujui

3. **Berita/Update** → Suara `berita.mp3`
   - Notification sound standar
   - Menandakan ada informasi baru

4. **Peringatan** → Suara `peringatan.mp3`
   - Alert yang lebih tegas
   - Menandakan ada error/hal penting

---

## 🧪 Testing Notifikasi

Setelah menambahkan file suara:

1. **Build ulang aplikasi**:
   ```bash
   flutter clean
   flutter build apk
   ```

2. **Install ke HP**:
   ```bash
   flutter install
   ```

3. **Trigger notifikasi**:
   - Admin: Setujui/tolak pengajuan
   - Karyawan: Tunggu notifikasi status berubah

4. **Pastikan**:
   - ✅ Suara terdengar
   - ✅ Notifikasi muncul di status bar
   - ✅ HP bergetar
   - ✅ Ketik notifikasi membuka aplikasi

---

## ❓ Troubleshooting

### Suara tidak terdengar:

1. **Cek nama file**
   - Pastikan nama file sesuai (huruf kecil semua)
   - Tidak ada spasi atau karakter khusus

2. **Cek permission HP**
   - Settings → Apps → APD → Notifications
   - Pastikan "Allow notifications" aktif
   - Pastikan "Sound" aktif

3. **Cek volume HP**
   - Volume notification tidak muted
   - Silent mode tidak aktif

4. **Cek file**
   - File bisa diputar di music player
   - File tidak corrupt
   - Ukuran file tidak terlalu besar

### Notifikasi tidak muncul:

1. **Cek permission** (Android 13+)
   - Settings → Apps → APD → Notifications
   - Allow "Post notifications"

2. **Cek battery optimization**
   - Settings → Apps → APD → Battery
   - Matikan "Optimize battery usage"

3. **Restart HP**
   - Kadang perlu restart agar permission aktif

---

## 📞 Bantuan

Jika ada masalah dengan notifikasi:

1. Cek log debug saat build
2. Pastikan file suara ada di folder yang benar
3. Cek permission di setting HP
4. Coba restart HP

---

## 🎉 Contoh File Suara Rekomendasi

### notifikasi.mp3
- Suara: "Ting" pendek
- Karakter: Netral, professional
- Durasi: ~1 detik

### pengajuan.mp3
- Suara: "Ding-ding" ringan
- Karakter: Positif
- Durasi: ~1.5 detik

### persetujuan.mp3
- Suara: "Chime" menyenangkan
- Karakter: Success
- Durasi: ~2 detik

### berita.mp3
- Suara: "Notification" standar
- Karakter: Informative
- Durasi: ~1.5 detik

### peringatan.mp3
- Suara: "Alert" tegas
- Karakter: Attention
- Durasi: ~1 detik
