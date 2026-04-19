import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:apdcpp/tema_aplikasi.dart';

/// Widget tanda tangan digital menggunakan GestureDetector + CustomPainter.
/// Menghasilkan base64 PNG yang bisa disimpan ke database.
class WidgetTandaTangan extends StatefulWidget {
  final double tinggi;
  final Color warnaGaris;
  final double lebarGaris;
  final String? labelPetunjuk;
  final ValueChanged<String?>? onTandaTanganBerubah;

  const WidgetTandaTangan({
    super.key,
    this.tinggi = 200,
    this.warnaGaris = TemaAplikasi.biruTua,
    this.lebarGaris = 2.5,
    this.labelPetunjuk,
    this.onTandaTanganBerubah,
  });

  @override
  State<WidgetTandaTangan> createState() => WidgetTandaTanganState();
}

class WidgetTandaTanganState extends State<WidgetTandaTangan> {
  final List<List<Offset>> _goresan = [];
  List<Offset> _goresanAktif = [];
  bool _sudahDigambar = false;

  bool get sudahDigambar => _sudahDigambar;

  void bersihkan() {
    setState(() {
      _goresan.clear();
      _goresanAktif.clear();
      _sudahDigambar = false;
    });
    widget.onTandaTanganBerubah?.call(null);
  }

  /// Mengekspor tanda tangan sebagai string base64 PNG.
  Future<String?> eksporBase64() async {
    if (!_sudahDigambar || _goresan.isEmpty) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Ukuran kanvas
    final size = Size(
      context.size?.width ?? 300,
      widget.tinggi,
    );

    // Gambar background putih
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    // Gambar goresan
    final paint = Paint()
      ..color = widget.warnaGaris
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = widget.lebarGaris
      ..style = PaintingStyle.stroke;

    for (final goresan in _goresan) {
      if (goresan.length < 2) continue;
      final path = Path()..moveTo(goresan.first.dx, goresan.first.dy);
      for (int i = 1; i < goresan.length; i++) {
        path.lineTo(goresan[i].dx, goresan[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final bytes = byteData.buffer.asUint8List();
    return base64Encode(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelPetunjuk != null) ...[
          Text(
            widget.labelPetunjuk!,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: TemaAplikasi.teksUtama,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          height: widget.tinggi,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _sudahDigambar
                  ? TemaAplikasi.biruTua.withValues(alpha: 0.4)
                  : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: [
                // Area gambar
                GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _goresanAktif = [details.localPosition];
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _goresanAktif.add(details.localPosition);
                    });
                  },
                  onPanEnd: (_) {
                    setState(() {
                      if (_goresanAktif.length >= 2) {
                        _goresan.add(List.from(_goresanAktif));
                        _sudahDigambar = true;
                      }
                      _goresanAktif = [];
                    });
                    widget.onTandaTanganBerubah?.call('drawn');
                  },
                  child: CustomPaint(
                    painter: _TandaTanganPainter(
                      goresan: _goresan,
                      goresanAktif: _goresanAktif,
                      warnaGaris: widget.warnaGaris,
                      lebarGaris: widget.lebarGaris,
                    ),
                    size: Size.infinite,
                  ),
                ),

                // Placeholder text
                if (!_sudahDigambar)
                  const Center(
                    child: Text(
                      'Tanda tangan di sini',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                // Garis bawah tanda tangan
                Positioned(
                  bottom: 30,
                  left: 24,
                  right: 24,
                  child: Container(
                    height: 1,
                    color: Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _sudahDigambar ? bersihkan : null,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Hapus Tanda Tangan'),
              style: TextButton.styleFrom(
                foregroundColor: TemaAplikasi.bahaya,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TandaTanganPainter extends CustomPainter {
  final List<List<Offset>> goresan;
  final List<Offset> goresanAktif;
  final Color warnaGaris;
  final double lebarGaris;

  _TandaTanganPainter({
    required this.goresan,
    required this.goresanAktif,
    required this.warnaGaris,
    required this.lebarGaris,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = warnaGaris
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = lebarGaris
      ..style = PaintingStyle.stroke;

    // Gambar goresan yang sudah selesai
    for (final goresan in goresan) {
      if (goresan.length < 2) continue;
      final path = Path()..moveTo(goresan.first.dx, goresan.first.dy);
      for (int i = 1; i < goresan.length; i++) {
        path.lineTo(goresan[i].dx, goresan[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    // Gambar goresan aktif (sedang digambar)
    if (goresanAktif.length >= 2) {
      final path = Path()
        ..moveTo(goresanAktif.first.dx, goresanAktif.first.dy);
      for (int i = 1; i < goresanAktif.length; i++) {
        path.lineTo(goresanAktif[i].dx, goresanAktif[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TandaTanganPainter oldDelegate) => true;
}

/// Widget untuk menampilkan tanda tangan dari base64 yang tersimpan.
class TampilanTandaTangan extends StatelessWidget {
  final String? base64Ttd;
  final double tinggi;
  final String labelKosong;

  const TampilanTandaTangan({
    super.key,
    this.base64Ttd,
    this.tinggi = 120,
    this.labelKosong = 'Belum ada tanda tangan',
  });

  @override
  Widget build(BuildContext context) {
    if (base64Ttd == null || base64Ttd!.isEmpty) {
      return Container(
        height: tinggi,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        alignment: Alignment.center,
        child: Text(
          labelKosong,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    try {
      final bytes = base64Decode(base64Ttd!);
      return Container(
        height: tinggi,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        padding: const EdgeInsets.all(8),
        child: Image.memory(
          Uint8List.fromList(bytes),
          fit: BoxFit.contain,
        ),
      );
    } catch (_) {
      return Container(
        height: tinggi,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Tanda tangan tidak valid',
          style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
        ),
      );
    }
  }
}
