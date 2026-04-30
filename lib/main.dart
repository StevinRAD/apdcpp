import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apdcpp/awal/layar_memuat.dart';
import 'package:apdcpp/awal/layar_request_izin.dart';
import 'package:apdcpp/tema_aplikasi.dart';
import 'package:apdcpp/services/notifikasi_lokal_service.dart';
import 'package:apdcpp/services/izin_perangkat_service.dart';

import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);

  // INI ADALAH KUNCI KONEKSI SUPABASE ANDA
  await Supabase.initialize(
    url: 'https://mypusncskszwypbbkzrn.supabase.co',
    anonKey: 'sb_publishable_8azFbJYSrn8eqtc7JZ6jTA_uw-GTYdK',
  );

  // Inisialisasi notifikasi lokal
  await NotifikasiLokalService.inisialisasi();

  runApp(const AplikasiAPD());
}

class AplikasiAPD extends StatelessWidget {
  const AplikasiAPD({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prima Safety Care',
      debugShowCheckedModeBanner: false,
      theme: TemaAplikasi.tema,
      home: const LayarUtama(),
    );
  }
}

/// Layar utama yang mengecek apakah perlu request izin
class LayarUtama extends StatefulWidget {
  const LayarUtama({super.key});

  @override
  State<LayarUtama> createState() => _LayarUtamaState();
}

class _LayarUtamaState extends State<LayarUtama> {
  bool _sedangCekIzin = true;
  bool _perluRequestIzin = false;

  @override
  void initState() {
    super.initState();
    _cekIzin();
  }

  Future<void> _cekIzin() async {
    // Cek apakah izin sudah pernah diberikan
    final izinSudahDiberikan = await IzinPerangkatService.cekIzinSudahDiberikan();

    setState(() {
      _sedangCekIzin = false;
      _perluRequestIzin = !izinSudahDiberikan;
    });
  }

  void _onIzinSelesai() {
    setState(() {
      _perluRequestIzin = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Sedang cek izin - tampilkan splash screen
    if (_sedangCekIzin) {
      return const LayarMemuat();
    }

    // Perlu request izin - tampilkan layar request izin
    if (_perluRequestIzin) {
      return LayarRequestIzin(onSelesai: _onIzinSelesai);
    }

    // Izin sudah diberikan - lanjut ke splash screen biasa
    return const LayarMemuat();
  }
}
