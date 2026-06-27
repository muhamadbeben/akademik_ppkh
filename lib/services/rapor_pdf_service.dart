// File: lib/services/rapor_pdf_service.dart

import 'dart:io';
import 'dart:typed_data'; 
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart'; 
import '../models/rapor_model.dart';

class RaporPdfService {
  // Fungsi pembantu untuk mendeteksi apakah mata pelajaran termasuk kategori hafalan
  bool _isKategoriHafalan(String namaMapel) {
    final nama = namaMapel.toLowerCase();
    return nama.contains('hafalan') || 
           nama.contains('tahfidz') || 
           nama.contains('tahfizh') || 
           nama.contains('ziyadah');
  }

  // Fungsi logika Predikat (A-E)
  Map<String, String> _getPredikatInfo(double n) {
    if (n >= 90) return {'grade': 'A', 'ket': 'Sangat Baik'};
    if (n >= 80) return {'grade': 'B', 'ket': 'Baik'};
    if (n >= 70) return {'grade': 'C', 'ket': 'Cukup'};
    if (n >= 60) return {'grade': 'D', 'ket': 'Kurang'};
    return {'grade': 'E', 'ket': 'Sangat Kurang'};
  }

  // Logika Kenaikan Kelas
  String _cekStatusKenaikan(List<NilaiModel> daftarNilai) {
    if (daftarNilai.isEmpty) return 'BELUM TERSEDIA (NILAI KOSONG)';
    final jumlahBawahKKM = daftarNilai.where((n) => n.nilaiHarian < 70).length;
    return jumlahBawahKKM > 2 ? 'TIDAK NAIK KELAS' : 'NAIK KELAS';
  }

  // Membersihkan karakter tidak terdukung di PDF
  String _sanitizeText(String text) {
    return text
        .replaceAll(RegExp(r'[‘’`´]'), "'") 
        .replaceAll(RegExp(r'[—–]'), "-")   
        .replaceAll('  ', ' ');            
  }

  // Memformat Nama Kelas
  String _formatNamaKelas(String kelasAsli) {
    final teksFormat = kelasAsli.toLowerCase().trim();
    if (teksFormat == 'kelas sp' || teksFormat == 'sp') {
      return 'Santri Pemula (SP)';
    }
    return kelasAsli.replaceAll(RegExp(r'kelas\s*', caseSensitive: false), '').trim();
  }

  // Men-generate dan membuka file PDF Rapor
  Future<void> generateAndOpenRapor(RaporModel rapor, Uint8List? logoBytes) async {
    final pdf = pw.Document();
    final statusKenaikan = _cekStatusKenaikan(rapor.daftarNilai);
    
    // PROSES FILTERING: Memisahkan list dari model asli berdasarkan nama mata pelajaran
    final listAkademik = rapor.daftarNilai.where((n) => !_isKategoriHafalan(n.mataPelajaran)).toList();
    final listHafalan = rapor.daftarNilai.where((n) => _isKategoriHafalan(n.mataPelajaran)).toList();

    // -------------------------------------------------------------------------
    // 1. DATA TABEL A: AKADEMIK (UMUM)
    // -------------------------------------------------------------------------
    final List<List<String>> tableAkademikData = [];
    if (listAkademik.isEmpty) {
      tableAkademikData.add(['-', 'Belum ada data nilai akademik umum', '-', '-', '-']);
      tableAkademikData.add(['', 'RATA-RATA NILAI', '-', '', '']);
    } else {
      final barisNilai = listAkademik.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final n = entry.value;
        final info = _getPredikatInfo(n.nilaiHarian);
        return [
          index.toString(),
          _sanitizeText(n.mataPelajaran), 
          n.nilaiHarian.toStringAsFixed(0),
          info['grade']!,
          info['ket']!
        ];
      }).toList();

      tableAkademikData.addAll(barisNilai);
      tableAkademikData.add(['', 'RATA-RATA NILAI', rapor.nilaiRataRata.toStringAsFixed(1), '', '']);
    }

    // -------------------------------------------------------------------------
    // 2. DATA TABEL C: HAFALAN / TAHFIDZ
    // -------------------------------------------------------------------------
    final List<List<String>> tableHafalanData = [];
    if (listHafalan.isEmpty) {
      tableHafalanData.add(['-', 'Belum ada data nilai hafalan / tahfidz', '-', '-', '-']);
    } else {
      final barisHafalan = listHafalan.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final h = entry.value;
        final info = _getPredikatInfo(h.nilaiHarian); 
        return [
          index.toString(),
          _sanitizeText(h.mataPelajaran), 
          h.nilaiHarian.toStringAsFixed(0),
          info['grade']!,
          info['ket']!
        ];
      }).toList();
      tableHafalanData.addAll(barisHafalan);
    }

    // -------------------------------------------------------------------------
    // DESAIN LAYOUT PDF A4
    // -------------------------------------------------------------------------
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- HEADER KOP ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoBytes != null)
                    pw.Container(
                      width: 55,
                      height: 55,
                      margin: const pw.EdgeInsets.only(right: 15),
                      child: pw.Image(pw.MemoryImage(logoBytes)),
                    ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text('PONDOK PESANTREN KHOIRUL HUDA', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text('YAYASAN PENDIDIKAN ISLAM NURUL IMAN', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text('Kp. Baru Desa Pangarengan, Kecamatan Rajeg, Kabupaten Tangerang', style: const pw.TextStyle(fontSize: 8.5)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5),
              pw.SizedBox(height: 10),

              // --- DATA SANTRI ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _infoText('Nama Santri', rapor.namaSantri),
                      _infoText('NIS', rapor.nis),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _infoText('Kelas', _formatNamaKelas(rapor.kelas)),
                      _infoText('Tahun Pelajaran', rapor.tahunAjaran),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 15),

              // --- BAGIAN A: NILAI AKADEMIK ---
              pw.Text('A. Nilai Akademik', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.SizedBox(height: 5),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headers: ['No', 'Mata Pelajaran', 'Nilai', 'Predikat', 'Keterangan'],
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FixedColumnWidth(40),
                  3: const pw.FixedColumnWidth(50),
                  4: const pw.FlexColumnWidth(2),
                },
                data: tableAkademikData,
              ),
              pw.SizedBox(height: 15),

              // --- BAGIAN B: NILAI PERILAKU / ADAB & KEHADIRAN (DIGABUNG BERDAMPINGAN) ---
              pw.Text('B. Nilai Perilaku / Adab & Kehadiran', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.SizedBox(height: 5),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Sub-Tabel Kotak Adab & Perilaku
                  pw.Expanded(
                    flex: 5,
                    child: pw.TableHelper.fromTextArray(
                      border: pw.TableBorder.all(),
                      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                      cellStyle: const pw.TextStyle(fontSize: 9),
                      headers: ['Aspek Penilaian', 'Catatan / Keterangan'],
                      columnWidths: {0: const pw.FixedColumnWidth(90), 1: const pw.FlexColumnWidth()},
                      data: [['Adab & Perilaku', _sanitizeText(rapor.catatanAdab)]],
                    ),
                  ),
                  pw.SizedBox(width: 15),
                  // Sub-Tabel Kotak Kehadiran (Absensi)
                  pw.Expanded(
                    flex: 4,
                    child: pw.TableHelper.fromTextArray(
                      border: pw.TableBorder.all(),
                      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                      cellStyle: const pw.TextStyle(fontSize: 9),
                      headers: ['Alasan Absensi', 'Jumlah'],
                      data: [
                        ['1. Sakit', '${rapor.absenSakit} Hari'],
                        ['2. Izin', '${rapor.absenIzin} Hari'],
                        ['3. Tanpa Keterangan', '${rapor.absenAlpha} Hari'],
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 15),

              // --- BAGIAN C: NILAI HAFALAN / TAHFIDZ (TERPISAH SEPENUHNYA) ---
              pw.Text('C. Nilai Hafalan / Tahfidz', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.SizedBox(height: 5),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headers: ['No', 'Materi / Surah / Juz', 'Nilai', 'Predikat', 'Keterangan'],
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FixedColumnWidth(40),
                  3: const pw.FixedColumnWidth(50),
                  4: const pw.FlexColumnWidth(2),
                },
                data: tableHafalanData,
              ),
              pw.SizedBox(height: 20),

              // --- STATUS KENAIKAN KELAS ---
              pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  width: double.infinity,
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
                  child: pw.Center(child: pw.Text('STATUS KENAIKAN KELAS: $statusKenaikan', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)))),
              pw.SizedBox(height: 30),

              // --- AREA TANDA TANGAN ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _ttdBox('Wali Kelas'),
                  _ttdBox('Mengetahui,\nPimpinan Pondok Pesantren'),
                ],
              ),
            ],
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();
    final fileName = "Rapor_${rapor.namaSantri.replaceAll(' ', '_')}.pdf";

    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/$fileName");
      await file.writeAsBytes(pdfBytes);
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: fileName,
    );
  }

  // Helper Widget Informasi Santri
  pw.Widget _infoText(String label, String val) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Text('$label : $val', style: const pw.TextStyle(fontSize: 10)),
      );

  // Helper Widget Kolom Tanda Tangan (Menggunakan prefix pw. secara tepat)
  pw.Widget _ttdBox(String title) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center, 
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 45), 
          pw.Text('....................', style: const pw.TextStyle(fontSize: 10)),
        ],
      );
}