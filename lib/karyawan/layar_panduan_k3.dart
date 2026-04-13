import 'package:flutter/material.dart';

class LayarPanduanK3 extends StatelessWidget {
  const LayarPanduanK3({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panduan K3'),
        backgroundColor: const Color(0xFFD2A92B),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _PanduanCard(
            title: 'Unsafe Action',
            points: [
              'Bekerja selalu mematuhi standard kerja',
              'Gunakan Alat Pelindung Diri (APD) yang telah ditentukan',
              'Pekerjaan dilakukan oleh orang yang berwenang (terampil)',
              'Lakukan pekerjaan dengan kondisi tubuh yang tidak dipaksakan',
              'Pekerjaan yang dilakukan lebih dari 1 orang, komunikasi harus mampu dimengerti oleh tim',
              'Berjalan pada koridor yang ditetapkan dan tidak berlari di area kerja',
            ],
          ),
          SizedBox(height: 12),
          _PanduanCard(
            title: 'Unsafe Condition',
            points: [
              'Saat perbaikan mesin atau peralatan, harus dimatikan',
              'Pada kondisi abnormal, hentikan proses dan laporkan',
              'Tidak menyentuh mesin atau peralatan atau benda yang bergerak (berenergi)',
              'Tidak masuk ke area yang dilarang',
              'Selalu menjaga lingkungan yang aman dan nyaman',
              'Dalam kondisi apapun, jika merasa bahaya maka utamakan keselamatan',
            ],
          ),
        ],
      ),
    );
  }
}

class _PanduanCard extends StatelessWidget {
  final String title;
  final List<String> points;

  const _PanduanCard({required this.title, required this.points});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            ...points.map(
              (point) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(point)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
