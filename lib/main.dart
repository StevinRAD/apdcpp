import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apdcpp/awal/layar_memuat.dart';
import 'package:apdcpp/tema_aplikasi.dart';
import 'package:apdcpp/services/notifikasi_lokal_service.dart';

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
      title: 'CP Care',
      debugShowCheckedModeBanner: false,
      theme: TemaAplikasi.tema,
      home: const LayarMemuat(),
    );
  }
}
