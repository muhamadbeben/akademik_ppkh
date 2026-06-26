// File: lib/services/laporan_pdf_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/santri_model.dart';
import '../models/prediksi_model.dart';

class LaporanPdfService {
  static pw.Widget _buildStatBlock(String label, String value, PdfColor color) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
              fontSize: 16, fontWeight: pw.FontWeight.bold, color: color),
        ),
        pw.SizedBox(height: 4),
        pw.Text(label, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
      ],
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

    // Load Logo
    Uint8List? logoBytes;
    try {
      final ByteData data = await rootBundle.load('assets/images/logo rapot.png');
      logoBytes = data.buffer.asUint8List();
    } catch (e) {
      debugPrint('Logo tidak ditemukan.');
    }

    // List untuk menampung baris yang hanya memiliki data
    List<List<String>> validTableRows = [];

    // Ambil data satu per satu dan filter yang kosong
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
          double avgHafalan = 0.0;
          double avgUts = 0.0;
          double avgUas = 0.0;

          // Ekstraksi UTS
          if (data['uts'] is Map) {
            double sum = 0; int count = 0;
            (data['uts'] as Map).forEach((_, v) { sum += double.tryParse(v.toString()) ?? 0; count++; });
            avgUts = count > 0 ? sum / count : 0.0;
          }
          // Ekstraksi UAS
          if (data['uas'] is Map) {
            double sum = 0; int count = 0;
            (data['uas'] as Map).forEach((_, v) { sum += double.tryParse(v.toString()) ?? 0; count++; });
            avgUas = count > 0 ? sum / count : 0.0;
          }
          // Ekstraksi Hafalan
          if (data['hafalan_kitab'] is Map) {
            double sum = 0; int count = 0;
            (data['hafalan_kitab'] as Map).forEach((_, v) { sum += double.tryParse(v.toString()) ?? 0; count++; });
            avgHafalan = count > 0 ? sum / count : 0.0;
          }

          // JIKA SEMUA NILAI UTAMA MASIH 0, JANGAN MASUKKAN KE LAPORAN
          if (avgHafalan > 0 || avgUts > 0 || avgUas > 0) {
            validTableRows.add([
              '${validTableRows.length + 1}',
              santri.nis,
              santri.nama,
              (data['kelas'] ?? data['semester'] ?? santri.kelas).toString(),
              tahunAjaran,
              '${kehadiran.toStringAsFixed(0)}%',
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
        pageFormat: PdfPageFormat.a4.landscape, // Pakai A4 Landscape
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Center(
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                if (logoBytes != null) pw.Image(pw.MemoryImage(logoBytes), width: 50, height: 50),
                if (logoBytes != null) pw.SizedBox(width: 15),
                pw.Column(
                  children: [
                    pw.Text('PONDOK PESANTREN KHOIRUL HUDA', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text('LAPORAN REKAPITULASI NILAI AKADEMIK & HAFALAN', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Tahun Ajaran: $tahunAjaran | Filter Kelas: $kelas', style: const pw.TextStyle(fontSize: 9)),
                  ]
                ),
              ]
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 15),
          
          pw.TableHelper.fromTextArray(
            headers: ['No', 'NIS', 'Nama Santri', 'Kelas', 'Tahun Ajaran', 'Hadir (%)', 'Nilai Hafalan', 'Nilai UTS', 'Nilai UAS'],
            data: validTableRows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
            cellStyle: const pw.TextStyle(fontSize: 8),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.3),
              1: pw.FlexColumnWidth(0.8),
              2: pw.FlexColumnWidth(1.8),
              3: pw.FlexColumnWidth(0.8),
              4: pw.FlexColumnWidth(0.9),
              5: pw.FlexColumnWidth(0.6),
              6: pw.FlexColumnWidth(0.7),
              7: pw.FlexColumnWidth(0.7),
              8: pw.FlexColumnWidth(0.7),
            },
            cellAlignments: {
              0: pw.Alignment.center,
              5: pw.Alignment.center,
              6: pw.Alignment.center,
              7: pw.Alignment.center,
              8: pw.Alignment.center,
            },
          ),
        ],
      ),
    );

    await _saveAndOpenFile(pdf, 'Rekap_Nilai_${kelas.replaceAll(' ', '_')}');
  }

  /// =========================================================================
  /// 2. LAPORAN HASIL PREDIKSI KELULUSAN KECERDASAN BUATAN (RANDOM FOREST)
  /// =========================================================================
  Future<void> generateLaporanPrediksiAI({
    required List<SantriModel> santriList, // <-- Diubah menggunakan santriList
    required String kelas,
    required String tahunAjaran,
  }) async {
    final pdf = pw.Document();

    Uint8List? logoBytes;
    try {
      final ByteData data = await rootBundle.load('assets/images/logo rapot.png');
      logoBytes = data.buffer.asUint8List();
    } catch (e) {}

    // List untuk menampung baris data yang valid dari database
    List<List<String>> validTableRows = [];

    // Mengambil data dari Firestore (Koleksi 'prediksi')
    for (var santri in santriList) {
      try {
        final prediksiQuery = await FirebaseFirestore.instance
            .collection('prediksi')
            .where('santriId', isEqualTo: santri.id)
            .get();

        if (prediksiQuery.docs.isNotEmpty) {
          // Urutkan untuk mendapatkan prediksi terbaru jika ada duplikat
          var docs = prediksiQuery.docs;
          docs.sort((a, b) {
            Timestamp? tA = a.data()['tanggalPrediksi'] as Timestamp?;
            Timestamp? tB = b.data()['tanggalPrediksi'] as Timestamp?;
            if (tA == null || tB == null) return 0;
            return tB.compareTo(tA); // Descending
          });

          final data = docs.first.data();
          String statusAI = data['hasilPrediksi']?.toString() ?? '-';

          // Filter: Jangan masukkan jika hasil prediksi tidak ada atau kosong
          if (statusAI != '-' && statusAI.isNotEmpty) {
            String avgAkademik = double.tryParse(data['nilaiRataRata']?.toString() ?? '0')?.toStringAsFixed(1) ?? '0.0';
            String avgHafalan = double.tryParse(data['nilaiHafalan']?.toString() ?? '0')?.toStringAsFixed(1) ?? '0.0';
            String kelasTercatat = data['kelas']?.toString() ?? santri.kelas;

            validTableRows.add([
              '${validTableRows.length + 1}',
              santri.nama,
              kelasTercatat,
              tahunAjaran,
              avgAkademik,
              avgHafalan,
              statusAI,
            ]);
          }
        }
      } catch (e) {
        debugPrint("Error load prediksi untuk ${santri.nama}: $e");
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Center(
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                if (logoBytes != null) pw.Image(pw.MemoryImage(logoBytes), width: 50, height: 50),
                if (logoBytes != null) pw.SizedBox(width: 15),
                pw.Column(
                  children: [
                    pw.Text('PONDOK PESANTREN KHOIRUL HUDA', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('LAPORAN PREDIKSI KELULUSAN SANTRI (AI)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Hasil Prediksi | Filter: $kelas | TA: $tahunAjaran', style: const pw.TextStyle(fontSize: 8)),
                  ]
                ),
              ]
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 15),

          pw.TableHelper.fromTextArray(
            headers: ['No', 'Nama Santri', 'Kelas', 'Tahun Ajaran', 'Nilai Akademik', 'Nilai Hafalan', 'Hasil Prediksi'],
            data: validTableRows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.purple700),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignments: {
              0: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
              6: pw.Alignment.center,
            },
          ),
        ],
      ),
    );

    await _saveAndOpenFile(pdf, 'Prediksi_AI_${kelas.replaceAll(' ', '_')}');
  }

  // FUNGSI UNTUK MENYIMPAN KE FOLDER EKSTERNAL (JIKA BISA) LALU MEMBUKA
  Future<void> _saveAndOpenFile(pw.Document pdf, String fileNameBase) async {
    try {
      Directory? dir;
      // Cobalah untuk mendapatkan direktori dokumen eksternal Android (agar tidak mudah terhapus)
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory();
      } 
      
      // Fallback jika tidak dapat akses eksternal, gunakan application documents
      dir ??= await getApplicationDocumentsDirectory();

      final file = File('${dir.path}/${fileNameBase}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      
      await file.writeAsBytes(await pdf.save());
      
      // Membuka file. Pembaca PDF sistem akan menanganinya (termasuk tombol Share/Print).
      final result = await OpenFile.open(file.path);
      
      if (result.type != ResultType.done) {
        debugPrint("Gagal membuka file PDF: ${result.message}");
      }
    } catch (e) {
      debugPrint("Gagal menyimpan PDF: $e");
    }
  }
}