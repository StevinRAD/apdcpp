import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:apdcpp/konfigurasi_api.dart';
import 'package:apdcpp/tema_aplikasi.dart';

class LayarDetailBeritaKaryawan extends StatelessWidget {
  final Map<String, dynamic> berita;

  const LayarDetailBeritaKaryawan({super.key, required this.berita});

  String _formatTanggal(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return '-';
    }
    final tanggal = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (tanggal == null) {
      return raw;
    }
    return DateFormat('dd MMM yyyy, HH:mm').format(tanggal);
  }

  @override
  Widget build(BuildContext context) {
    final gambarUrl = buildUploadUrl(berita['gambar']?.toString());
    final judul = berita['judul']?.toString() ?? 'Berita';
    final kategori = berita['kategori']?.toString() ?? 'Informasi';
    final ringkasan = berita['ringkasan']?.toString() ?? '';
    final isiUtama =
        (berita['deskripsi']?.toString().trim().isNotEmpty ?? false)
        ? berita['deskripsi']?.toString() ?? ''
        : berita['isi']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Berita')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (gambarUrl.isNotEmpty)
            SizedBox(
              height: 240,
              child: Image.network(
                gambarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: Colors.grey.shade100,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    size: 36,
                    color: TemaAplikasi.netral,
                  ),
                ),
              ),
            )
          else
            Container(
              height: 220,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [TemaAplikasi.biruTua, Color(0xFF355C8A)],
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.article_outlined,
                size: 54,
                color: Colors.white,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: TemaAplikasi.biruMuda,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        kategori,
                        style: const TextStyle(
                          color: TemaAplikasi.biruTua,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _formatTanggal(berita['tanggal']?.toString()),
                        style: const TextStyle(
                          color: TemaAplikasi.netral,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  judul,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                if (ringkasan.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    ringkasan,
                    style: const TextStyle(
                      fontSize: 16,
                      color: TemaAplikasi.netral,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE7EBF2)),
                  ),
                  child: Text(
                    isiUtama.trim().isEmpty
                        ? 'Isi berita belum tersedia.'
                        : isiUtama,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: TemaAplikasi.teksUtama,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
