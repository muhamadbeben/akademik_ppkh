// File: lib/services/laporan_pdf_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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
              pw.SizedBox(width: 60), // Spacer jika logo tidak ada
            
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
                      color: const PdfColor.fromInt(0xFF1B5E20), // Hijau Gelap
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
            
            pw.SizedBox(width: 75), // Penyeimbang logo di kanan
          ],
        ),
        pw.SizedBox(height: 10),
        // Garis Ganda Kop Surat
        pw.Divider(thickness: 2, color: PdfColors.black),
        pw.Container(
          transform: Matrix4.translationValues(0, -6, 0), // Angkat garis kedua ke atas
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
              pw.Text('Tangerang, $tglSekarang'), // Ubah kota sesuai lokasi pesantren
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
      // [PERBAIKAN]: Menggunakan nama file dengan underscore sesuai di pubspec.yaml
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
          double avgHafalan = 0.0;
          double avgUts = 0.0;
          double avgUas = 0.0;

          if (data['uts'] is Map) {
            double sum = 0; int count = 0;
            (data['uts'] as Map).forEach((_, v) { sum += double.tryParse(v.toString()) ?? 0; count++; });
            avgUts = count > 0 ? sum / count : 0.0;
          }
          if (data['uas'] is Map) {
            double sum = 0; int count = 0;
            (data['uas'] as Map).forEach((_, v) { sum += double.tryParse(v.toString()) ?? 0; count++; });
            avgUas = count > 0 ? sum / count : 0.0;
          }
          if (data['hafalan_kitab'] is Map) {
            double sum = 0; int count = 0;
            (data['hafalan_kitab'] as Map).forEach((_, v) { sum += double.tryParse(v.toString()) ?? 0; count++; });
            avgHafalan = count > 0 ? sum / count : 0.0;
          }

          if (avgHafalan > 0 || avgUts > 0 || avgUas > 0) {
            validTableRows.add([
              '${validTableRows.length + 1}',
              santri.nis,
              santri.nama,
              (data['kelas'] ?? data['semester'] ?? santri.kelas).toString(),
              '${kehadiran.toStringAsFixed(0)}%',
              perilaku.toStringAsFixed(1),
              avgHafalan.toStringAsFixed(1),
              avgUts.toStringAsFixed(1),
              avgUas.toStringAsFixed(1),
            ]);
          }
        }
      } catch (e) {
        debugPrint("Error filter santri ${santri.nama}: $e");
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape, 
        margin: const pw.EdgeInsets.all(32),
        // HEADER SETIAP HALAMAN
        header: (context) => _buildKopSurat(logoBytes),
        // FOOTER SETIAP HALAMAN
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
          // JUDUL LAPORAN
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
          
          // TABEL DATA
          pw.TableHelper.fromTextArray(
            headers: ['No', 'NIS', 'Nama Santri', 'Kelas', 'Kehadiran', 'Perilaku', 'Nilai Hafalan', 'Rata-rata UTS', 'Rata-rata UAS'],
            data: validTableRows,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100), // Efek Zebra
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
          
          // TANDA TANGAN
          _buildSignatures(kelas),
        ],
      ),
    );

    await _saveAndOpenFile(pdf, 'Rekap_Nilai_${kelas.replaceAll(' ', '_')}');
  }

  /// =========================================================================
  /// 2. LAPORAN HASIL PREDIKSI KELULUSAN KECERDASAN BUATAN (RANDOM FOREST)
  /// =========================================================================
  Future<void> generateLaporanPrediksiAI({
    required List<SantriModel> santriList, 
    required String kelas,
    required String tahunAjaran,
  }) async {
    final pdf = pw.Document();

    Uint8List? logoBytes;
    try {
      // [PERBAIKAN]: Menggunakan nama file dengan underscore sesuai di pubspec.yaml
      final ByteData data = await rootBundle.load('assets/images/logo_rapot.png');
      logoBytes = data.buffer.asUint8List();
    } catch (e) {}

    List<List<String>> validTableRows = [];
    int totalNaikKelas = 0;
    int totalTinggalKelas = 0;

    for (var santri in santriList) {
      try {
        final prediksiQuery = await FirebaseFirestore.instance
            .collection('prediksi')
            .where('santriId', isEqualTo: santri.id)
            .get();

        if (prediksiQuery.docs.isNotEmpty) {
          var docs = prediksiQuery.docs;
          docs.sort((a, b) {
            Timestamp? tA = a.data()['tanggalPrediksi'] as Timestamp?;
            Timestamp? tB = b.data()['tanggalPrediksi'] as Timestamp?;
            if (tA == null || tB == null) return 0;
            return tB.compareTo(tA);
          });

          final data = docs.first.data();
          String statusAI = data['hasilPrediksi']?.toString() ?? '-';

          if (statusAI != '-' && statusAI.isNotEmpty) {
            String avgAkademik = double.tryParse(data['nilaiRataRata']?.toString() ?? '0')?.toStringAsFixed(1) ?? '0.0';
            String avgHafalan = double.tryParse(data['nilaiHafalan']?.toString() ?? '0')?.toStringAsFixed(1) ?? '0.0';
            
            validTableRows.add([
              '${validTableRows.length + 1}',
              santri.nis,
              santri.nama,
              avgAkademik,
              avgHafalan,
              statusAI,
            ]);

            // Menghitung statistik ringkasan AI
            if (statusAI.toLowerCase().contains('tinggal') || statusAI.toLowerCase().contains('tidak')) {
              totalTinggalKelas++;
            } else {
              totalNaikKelas++;
            }
          }
        }
      } catch (e) {
        debugPrint("Error load prediksi untuk ${santri.nama}: $e");
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4, // A4 Portrait lebih cocok untuk tabel ini
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
                    pw.Text('Total Dievaluasi', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.Text('${validTableRows.length} Santri', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ]
                ),
                pw.Column(
                  children: [
                    pw.Text('Potensi Naik / Lulus', style: pw.TextStyle(fontSize: 9, color: PdfColors.green700)),
                    pw.Text('$totalNaikKelas Santri', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                  ]
                ),
                pw.Column(
                  children: [
                    pw.Text('Potensi Tinggal Kelas', style: pw.TextStyle(fontSize: 9, color: PdfColors.red700)),
                    pw.Text('$totalTinggalKelas Santri', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                  ]
                ),
              ]
            )
          ),
          pw.SizedBox(height: 15),

          pw.TableHelper.fromTextArray(
            headers: ['No', 'NIS', 'Nama Santri', 'Akademik', 'Hafalan', 'Hasil Keputusan AI'],
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
              2: pw.FlexColumnWidth(2.0),
              3: pw.FlexColumnWidth(0.8),
              4: pw.FlexColumnWidth(0.8),
              5: pw.FlexColumnWidth(1.2),
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

  // FUNGSI UNTUK MENYIMPAN KE FOLDER EKSTERNAL (JIKA BISA) LALU MEMBUKA
  Future<void> _saveAndOpenFile(pw.Document pdf, String fileNameBase) async {
    try {
      Directory? dir;
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory();
      } 
      dir ??= await getApplicationDocumentsDirectory();

      final file = File('${dir.path}/${fileNameBase}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      
      await file.writeAsBytes(await pdf.save());
      
      final result = await OpenFile.open(file.path);
      
      if (result.type != ResultType.done) {
        debugPrint("Gagal membuka file PDF: ${result.message}");
      }
    } catch (e) {
      debugPrint("Gagal menyimpan PDF: $e");
    }
  }
}