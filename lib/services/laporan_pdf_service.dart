// File: lib/services/laporan_pdf_service.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart'; 
import '../models/santri_model.dart';

class LaporanPdfService {
  
  // ===========================================================================
  // WIDGET BANTUAN: KOP SURAT (HEADER) RESMI
  // ===========================================================================
  static pw.Widget _buildKopSurat(Uint8List? logoBytes) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logoBytes != null)
              pw.Container(
                width: 60,
                height: 60,
                child: pw.Image(pw.MemoryImage(logoBytes)),
              )
            else
              pw.SizedBox(width: 60), 
            
            pw.SizedBox(width: 15),
            
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'PONDOK PESANTREN KHOIRUL HUDA',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF1B5E20), 
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Sistem Informasi Akademik & Prediksi Kelulusan Santri',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Email: info@khoirulhuda.com | Layanan Administrasi Akademik Terpadu',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(width: 75), 
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 2, color: PdfColors.black),
        pw.Container(
          transform: Matrix4.translationValues(0, -6, 0), 
          child: pw.Divider(thickness: 1, color: PdfColors.black),
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }

  // ===========================================================================
  // WIDGET BANTUAN: KOLOM TANDA TANGAN
  // ===========================================================================
  static pw.Widget _buildSignatures(String kelas) {
    final tglSekarang = DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.now());
    
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 30),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('Mengetahui,'),
              pw.Text('Pimpinan Pesantren,'),
              pw.SizedBox(height: 60),
              pw.Text('( ________________________ )', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('Tangerang, $tglSekarang'), 
              pw.Text('Wali Pengajar $kelas,'),
              pw.SizedBox(height: 60),
              pw.Text('( ________________________ )', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  /// =========================================================================
  /// 1. LAPORAN REKAP NILAI SANTRI (A4 Landscape)
  /// =========================================================================
  Future<void> generateLaporanRekapNilai({
    required List<SantriModel> santriList,
    required String kelas,
    required String tahunAjaran,
  }) async {
    final pdf = pw.Document();

    Uint8List? logoBytes;
    try {
      final ByteData data = await rootBundle.load('assets/images/logo_rapot.png');
      logoBytes = data.buffer.asUint8List();
    } catch (e) {
      debugPrint('Logo tidak ditemukan.');
    }

    List<List<String>> validTableRows = [];

    for (var santri in santriList) {
      try {
        final nilaiQuery = await FirebaseFirestore.instance
            .collection('nilai')
            .where('santriId', isEqualTo: santri.id)
            .where('tahunAjaran', isEqualTo: tahunAjaran)
            .get();

        if (nilaiQuery.docs.isNotEmpty) {
          final data = nilaiQuery.docs.first.data();
          
          double kehadiran = double.tryParse(data['nilai_kehadiran']?.toString() ?? '0') ?? 0.0;
          double perilaku = double.tryParse(data['nilai_perilaku']?.toString() ?? '0') ?? 0.0;
          double avgUts = double.tryParse(data['rata_rata_uts']?.toString() ?? '0') ?? 0.0;
          double avgUas = double.tryParse(data['rata_rata_uas']?.toString() ?? '0') ?? 0.0;
          double avgHafalan = double.tryParse(data['rata_rata_hafalan']?.toString() ?? '0') ?? 0.0;

          if (avgHafalan > 0 || avgUts > 0 || avgUas > 0) {
            validTableRows.add([
              '${validTableRows.length + 1}',
              santri.nis,
              santri.nama,
              (data['kelas'] ?? santri.kelas).toString(),
              '${kehadiran.toStringAsFixed(0)}%',
              perilaku.toStringAsFixed(1),
              avgHafalan.toStringAsFixed(1),
              avgUts.toStringAsFixed(1),
              avgUas.toStringAsFixed(1),
            ]);
          }
        }
      } catch (e) {
        debugPrint("Error memproses data santri ${santri.nama}: $e");
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape, 
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildKopSurat(logoBytes),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Dicetak pada: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('Halaman ${context.pageNumber} dari ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
        ),
        build: (ctx) => [
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text('LAPORAN REKAPITULASI NILAI AKADEMIK & HAFALAN', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Tahun Ajaran: $tahunAjaran  |  Filter Kelas: $kelas', style: pw.TextStyle(fontSize: 10)),
              ]
            ),
          ),
          pw.SizedBox(height: 20),
          
          pw.TableHelper.fromTextArray(
            headers: ['No', 'NIS', 'Nama Santri', 'Kelas', 'Kehadiran', 'Perilaku', 'Nilai Hafalan', 'Rata-rata UTS', 'Rata-rata UAS'],
            data: validTableRows,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            cellStyle: const pw.TextStyle(fontSize: 8),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.3),
              1: pw.FlexColumnWidth(0.8),
              2: pw.FlexColumnWidth(1.8),
              3: pw.FlexColumnWidth(0.7),
              4: pw.FlexColumnWidth(0.7),
              5: pw.FlexColumnWidth(0.7),
              6: pw.FlexColumnWidth(0.8),
              7: pw.FlexColumnWidth(0.9),
              8: pw.FlexColumnWidth(0.9),
            },
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
              6: pw.Alignment.center,
              7: pw.Alignment.center,
              8: pw.Alignment.center,
            },
          ),
          
          _buildSignatures(kelas),
        ],
      ),
    );

    await _saveAndOpenFile(pdf, 'Rekap_Nilai_${kelas.replaceAll(' ', '_')}');
  }

  /// =========================================================================
  /// 2. LAPORAN HASIL PREDIKSI KELULUSAN AI (RANDOM FOREST)
  /// =========================================================================
  Future<void> generateLaporanPrediksiAI({
    required List<SantriModel> santriList, 
    required String kelas,
    required String tahunAjaran,
  }) async {
    final pdf = pw.Document();

    Uint8List? logoBytes;
    try {
      final ByteData data = await rootBundle.load('assets/images/logo_rapot.png');
      logoBytes = data.buffer.asUint8List();
    } catch (e) {
      debugPrint('Logo tidak ditemukan.');
    }

    List<List<String>> validTableRows = [];
    int totalNaikKelas = 0;
    int totalTinggalKelas = 0;
    int totalBelumDianalisis = 0;

    for (var santri in santriList) {
      try {
        // [PERBAIKAN UTAMA]: Menggunakan query berdasarkan santriId dan tahunAjaran agar aman
        // meskipun filter kelas diatur ke "Semua Kelas" atau nama kelas bervariasi.
        final nilaiQuery = await FirebaseFirestore.instance
            .collection('nilai')
            .where('santriId', isEqualTo: santri.id)
            .where('tahunAjaran', isEqualTo: tahunAjaran)
            .get();

        if (nilaiQuery.docs.isNotEmpty) {
          final data = nilaiQuery.docs.first.data();
          
          String statusAI = data['status_prediksi_ai']?.toString() ?? '';
          String avgAkademik = double.tryParse(data['rata_rata_uas']?.toString() ?? '0')?.toStringAsFixed(1) ?? '0.0';
          String avgHafalan = double.tryParse(data['rata_rata_hafalan']?.toString() ?? '0')?.toStringAsFixed(1) ?? '0.0';
          
          if (statusAI.isEmpty) {
            statusAI = 'BELUM DIANALISIS';
            totalBelumDianalisis++;
          } else {
            if (statusAI.toLowerCase().contains('tinggal') || statusAI.toLowerCase().contains('tidak')) {
              totalTinggalKelas++;
            } else {
              totalNaikKelas++;
            }
          }

          validTableRows.add([
            '${validTableRows.length + 1}',
            santri.nis,
            santri.nama,
            avgAkademik,
            avgHafalan,
            statusAI,
          ]);
        }
      } catch (e) {
        debugPrint("Error load prediksi untuk ${santri.nama}: $e");
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4, 
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildKopSurat(logoBytes),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Dicetak pada: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('Halaman ${context.pageNumber} dari ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
        ),
        build: (ctx) => [
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text('LAPORAN HASIL ANALISIS KELULUSAN SANTRI (AI)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Algoritma: Random Forest Model', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                pw.SizedBox(height: 2),
                pw.Text('Tahun Ajaran: $tahunAjaran  |  Filter Kelas: $kelas', style: pw.TextStyle(fontSize: 10)),
              ]
            ),
          ),
          pw.SizedBox(height: 20),

          // BLOK STATISTIK / RINGKASAN AI
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: PdfColors.grey300)
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text('Total Santri', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.Text('${validTableRows.length}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ]
                ),
                pw.Column(
                  children: [
                    pw.Text('Naik / Lulus', style: pw.TextStyle(fontSize: 9, color: PdfColors.green700)),
                    pw.Text('$totalNaikKelas', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                  ]
                ),
                pw.Column(
                  children: [
                    pw.Text('Tinggal Kelas', style: pw.TextStyle(fontSize: 9, color: PdfColors.red700)),
                    pw.Text('$totalTinggalKelas', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                  ]
                ),
                pw.Column(
                  children: [
                    pw.Text('Belum Diproses', style: pw.TextStyle(fontSize: 9, color: PdfColors.orange700)),
                    pw.Text('$totalBelumDianalisis', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.orange700)),
                  ]
                ),
              ]
            )
          ),
          pw.SizedBox(height: 15),

          pw.TableHelper.fromTextArray(
            headers: ['No', 'NIS', 'Nama Santri', 'Rata-rata Akademik', 'Rata-rata Hafalan', 'Keputusan Algoritma AI'],
            data: validTableRows,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.purple700),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            cellStyle: const pw.TextStyle(fontSize: 9),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.3),
              1: pw.FlexColumnWidth(0.8),
              2: pw.FlexColumnWidth(1.8),
              3: pw.FlexColumnWidth(0.8),
              4: pw.FlexColumnWidth(0.8),
              5: pw.FlexColumnWidth(1.4),
            },
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
            },
          ),

          _buildSignatures(kelas),
        ],
      ),
    );

    await _saveAndOpenFile(pdf, 'Prediksi_AI_${kelas.replaceAll(' ', '_')}');
  }

  // ===========================================================================
  // FUNGSI PENYIMPANAN DAN BUKA FILE PDF (CROSS-PLATFORM)
  // ===========================================================================
  Future<void> _saveAndOpenFile(pw.Document pdf, String fileNameBase) async {
    try {
      final String fileName = '${fileNameBase}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final Uint8List bytes = await pdf.save();

      await Printing.sharePdf(
        bytes: bytes,
        filename: fileName,
      );
      
    } catch (e) {
      debugPrint("Gagal menyimpan atau membuka PDF: $e");
    }
  }
}