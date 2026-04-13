import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apdcpp/awal/layar_memuat.dart';
import 'package:apdcpp/awal/layar_request_izin.dart';
import 'package:apdcpp/tema_aplikasi.dart';
import 'package:apdcpp/services/notifikasi_lokal_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      title: 'CP Care',
      debugShowCheckedModeBanner: false,
      theme: TemaAplikasi.tema,
      home: const LayarCekIzin(),
    );
  }
}

/// Layar untuk mengecek apakah izin sudah diberikan
/// Jika belum, tampilkan layar request izin
class LayarCekIzin extends StatefulWidget {
  const LayarCekIzin({super.key});

  @override
  State<LayarCekIzin> createState() => _LayarCekIzinState();
}

class _LayarCekIzinState extends State<LayarCekIzin> {
  bool _sedangCek = true;
  bool _perluRequestIzin = false;

  @override
  void initState() {
    super.initState();
    _cekIzinPertamaKali();
  }

  Future<void> _cekIzinPertamaKali() async {
    // Cek apakah ini pertama kali buka aplikasi
    final prefs = await SharedPreferences.getInstance();
    final sudahPernahBuka = prefs.getBool('sudah_pernah_buka') ?? false;

    if (!sudahPernahBuka) {
      // Pertama kali buka, perlu request izin
      if (mounted) {
        setState(() {
          _sedangCek = false;
          _perluRequestIzin = true;
        });
      }
    } else {
      // Sudah pernah buka, langsung ke layar memuat
      if (mounted) {
        setState(() {
          _sedangCek = false;
          _perluRequestIzin = false;
        });
      }
    }
  }

  void _onIzinSelesai() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sudah_pernah_buka', true);

    if (mounted) {
      setState(() {
        _perluRequestIzin = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sedangCek) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_perluRequestIzin) {
      return LayarRequestIzin(onSelesai: _onIzinSelesai);
    }

    return const LayarMemuat();
  }
}
