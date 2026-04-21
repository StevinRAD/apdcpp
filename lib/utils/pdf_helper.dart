import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfHelper {
  static Future<void> generateDokumenApdPdf({
    required bool isPenerimaan,
    required Map<String, dynamic> dokumen,
    required Map<String, dynamic> karyawan,
    required Map<String, dynamic> admin,
    required List<Map<String, dynamic>> items,
  }) async {
    final pdf = pw.Document();

    // Load logo dari assets
    final logoImage = await _loadLogoImage();

    String formatTanggal(String? raw) {
      if (raw == null || raw.isEmpty) return '-';
      final dt = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
      if (dt == null) return raw;
      return DateFormat('dd MMMM yyyy', 'id_ID').format(dt);
    }

    pw.Widget buildInfoRow(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 140,
              child: pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
            ),
            pw.Text(': ', style: const pw.TextStyle(fontSize: 12)),
            pw.Expanded(
              child: pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    pw.Widget buildTtdBox(String role, String nama, String? base64Ttd) {
      pw.Widget ttdImage = pw.Center(
        child: pw.Text('(kosong)', style: pw.TextStyle(color: PdfColors.grey, fontSize: 10, fontStyle: pw.FontStyle.italic)),
      );

      if (base64Ttd != null && base64Ttd.isNotEmpty) {
        try {
          final bytes = base64Decode(base64Ttd);
          ttdImage = pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain);
        } catch (_) {}
      }

      return pw.Column(
        children: [
          pw.Text(role, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 8),
          pw.Container(
            height: 70,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: ttdImage,
          ),
          pw.SizedBox(height: 4),
          pw.Container(width: double.infinity, height: 1, color: PdfColors.grey400),
          pw.SizedBox(height: 2),
          pw.Text(nama, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.center, maxLines: 2),
        ],
      );
    }

    final title = isPenerimaan ? 'PENERIMAAN PENGAJUAN APD' : 'FORMULIR PERMINTAAN APD';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header dengan Logo - SELALU tampilkan logo
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColors.blue800, width: 1.5),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Logo - SELALU tampilkan (asli atau placeholder)
                  pw.Container(
                    width: 55,
                    height: 55,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.blue800, width: 1.5),
                    ),
                    child: logoImage != null
                        ? pw.Image(logoImage, fit: pw.BoxFit.contain)
                        : pw.Center(
                            child: pw.Text(
                              'CPP',
                              style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue800,
                              ),
                            ),
                          ),
                  ),
                  pw.SizedBox(width: 14),
                  // Company Info
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PT. CENTRAL PROTEINA PRIMA, Tbk', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.blue900)),
                        pw.SizedBox(height: 3),
                        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.blue700, letterSpacing: 1.5)),
                        pw.SizedBox(height: 6),
                        pw.Container(
                          height: 2,
                          decoration: pw.BoxDecoration(
                            gradient: pw.LinearGradient(
                              colors: [PdfColors.blue800, PdfColors.blue400, PdfColors.blue800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Badge Status untuk Dokumen Penerimaan
            if (isPenerimaan)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green100,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.green700, width: 1.5),
                ),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 26,
                      height: 26,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.green700,
                        shape: pw.BoxShape.circle,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          '✓',
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('DOKUMEN PENERIMAAN RESMI', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                          pw.Text('Diproses pada ${formatTanggal(dokumen['tanggal_proses']?.toString())}', style: pw.TextStyle(fontSize: 10, color: PdfColors.green800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (isPenerimaan) pw.SizedBox(height: 12),

            // Karyawan Info dengan Box
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(isPenerimaan ? 'DATA PENERIMA' : 'DATA PEMOHON', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900, letterSpacing: 1)),
                  pw.SizedBox(height: 10),
                  buildInfoRow('Nama Lengkap', karyawan['nama_lengkap'] ?? '-'),
                  buildInfoRow('Jabatan', karyawan['jabatan'] ?? '-'),
                  buildInfoRow('Departemen', karyawan['departemen'] ?? '-'),
                  buildInfoRow('Lokasi Kerja', karyawan['lokasi_kerja'] ?? '-'),
                  buildInfoRow('Tgl Pengajuan', formatTanggal(dokumen['tanggal_pengajuan']?.toString())),
                  if (isPenerimaan)
                    buildInfoRow('Tgl Diterima', formatTanggal(dokumen['tanggal_proses']?.toString())),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Items Table dengan Desain Bagus
            pw.Container(
              width: double.infinity,
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColors.grey500, width: 1.5),
              ),
              child: pw.Column(
                children: [
                  // Table Header
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blue800,
                      borderRadius: pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(8),
                        topRight: pw.Radius.circular(8),
                      ),
                    ),
                    child: pw.Row(
                      children: [
                        if (isPenerimaan)
                          pw.Container(
                            width: 8,
                            height: 8,
                            decoration: const pw.BoxDecoration(
                              color: PdfColors.white,
                              shape: pw.BoxShape.circle,
                            ),
                          ),
                        if (isPenerimaan) pw.SizedBox(width: 8),
                        pw.Text(isPenerimaan ? 'DAFTAR APD YANG DITERIMA' : 'DAFTAR APD YANG DIMINTA', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 1)),
                      ],
                    ),
                  ),
                  // Table Content
                  pw.Table(
                    border: pw.TableBorder.symmetric(
                      inside: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                      outside: pw.BorderSide.none,
                    ),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(35),
                      1: const pw.FlexColumnWidth(3),
                      2: const pw.FixedColumnWidth(60),
                      3: const pw.FixedColumnWidth(45),
                    },
                    children: [
                      // Header Row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('No', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blue900))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Nama APD', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blue900))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Ukuran', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blue900))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Jumlah', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blue900), textAlign: pw.TextAlign.center)),
                        ],
                      ),
                      // Data Rows
                      ...List.generate(items.length, (i) {
                        final item = items[i];
                        final isEven = i % 2 == 0;
                        return pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: isEven ? PdfColors.white : PdfColors.grey100,
                          ),
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${i + 1}', style: const pw.TextStyle(fontSize: 10))),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(item['nama_apd']?.toString() ?? '-', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                                  if ((item['alasan']?.toString() ?? '').isNotEmpty && !isPenerimaan)
                                    pw.Text('Alasan: ${item['alasan']}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                                ],
                              ),
                            ),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(item['ukuran']?.toString() ?? '-', style: const pw.TextStyle(fontSize: 10))),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Center(
                                child: pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: pw.BoxDecoration(
                                    color: isPenerimaan ? PdfColors.green200 : PdfColors.blue200,
                                    borderRadius: pw.BorderRadius.circular(4),
                                    border: pw.Border.all(color: isPenerimaan ? PdfColors.green700 : PdfColors.blue700, width: 0.5),
                                  ),
                                  child: pw.Text('${item['jumlah'] ?? 1}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: isPenerimaan ? PdfColors.green900 : PdfColors.blue900)),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 12),

            if (isPenerimaan) ...[
              // Pernyataan Komitmen - Compact
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(10),
                  border: pw.Border.all(color: PdfColors.blue400, width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 24,
                          height: 24,
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.blue800,
                            shape: pw.BoxShape.circle,
                          ),
                          child: pw.Center(
                            child: pw.Text('!', style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Text('PERNYATAAN KOMITMEN', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900, letterSpacing: 1)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Dengan ini saya menyatakan telah menerima APD sesuai daftar di atas dan '
                      'berkomitmen menggunakan APD tersebut sesuai ketentuan keselamatan kerja '
                      'di lingkungan PT. Central Proteina Prima, Tbk.',
                      style: const pw.TextStyle(fontSize: 10, height: 1.5),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
            ],

            // Signatures - Compact
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: pw.Column(
                children: [
                  pw.Center(
                    child: pw.Text('TANDA TANGAN', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900, letterSpacing: 1)),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: buildTtdBox(
                          isPenerimaan ? 'Diterima oleh' : 'Pemohon',
                          karyawan['nama_lengkap'] ?? '-',
                          dokumen['tanda_tangan_karyawan']?.toString(),
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: buildTtdBox(
                          isPenerimaan ? 'Diserahkan oleh' : 'Safety / Admin',
                          admin['nama_lengkap'] ?? '...................',
                          dokumen['tanda_tangan_admin']?.toString(),
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: buildTtdBox(
                          isPenerimaan ? 'Diketahui oleh' : 'Atasan',
                          '...................',
                          null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if ((dokumen['catatan_admin']?.toString() ?? '').isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber100,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.amber700, width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Catatan Admin:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.amber900)),
                    pw.SizedBox(height: 3),
                    pw.Text(dokumen['catatan_admin']?.toString() ?? '', style: const pw.TextStyle(fontSize: 10, height: 1.4)),
                  ],
                ),
              ),
            ],

            // Footer
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Text('Dokumen ini diterbitkan secara otomatis oleh Sistem Pengajuan APD', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ),
          ]);
        },
      )
    );

    final pdfBytes = await pdf.save();

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: isPenerimaan ? 'dokumen_penerimaan_${dokumen['id']}.pdf' : 'pengajuan_apd_${dokumen['id']}.pdf',
    );
  }

  /// Load logo image dari assets untuk PDF
  static Future<pw.MemoryImage?> _loadLogoImage() async {
    try {
      final ByteData data = await rootBundle.load('assets/images/logo.png');
      final bytes = data.buffer.asUint8List();
      return pw.MemoryImage(bytes);
    } catch (e) {
      return null;
    }
  }
}
