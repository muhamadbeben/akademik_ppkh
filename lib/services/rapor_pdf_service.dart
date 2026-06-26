// File: lib/services/rapor_pdf_service.dart

import 'dart:io';
import 'dart:typed_data'; 
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart'; 
import 'package:printing/printing.dart'; // IMPORT PACKAGE PRINTING
import '../models/rapor_model.dart';

class RaporPdfService {
  // Fungsi logika Predikat (A-E)
  Map<String, String> _getPredikatInfo(double n) {
    if (n >= 90) return {'grade': 'A', 'ket': 'Sangat Baik'};
    if (n >= 80) return {'grade': 'B', 'ket': 'Baik'};
    if (n >= 70) return {'grade': 'C', 'ket': 'Cukup'};
    if (n >= 60) return {'grade': 'D', 'ket': 'Kurang'};
    return {'grade': 'E', 'ket': 'Sangat Kurang'};
  }

  // Logika Kenaikan Kelas (Aman dari List Kosong)
  String _cekStatusKenaikan(List<dynamic> daftarNilai) {
    if (daftarNilai.isEmpty) return 'BELUM TERSEDIA (NILAI KOSONG)';

    int jumlahBawahKKM = 0;
    for (var n in daftarNilai) {
      if (n.nilaiHarian < 70) jumlahBawahKKM++;
    }
    return jumlahBawahKKM > 2 ? 'TIDAK NAIK KELAS' : 'NAIK KELAS';
  }

  // Membersihkan karakter tidak terdukung di PDF
  String _sanitizeText(String text) {
    return text
        .replaceAll(RegExp(r'[‘’`´]'), "'") 
        .replaceAll(RegExp(r'[—–]'), "-")   
        .replaceAll('  ', ' ');            
  }

  // =========================================================================
  // FUNGSI BARU: Memformat Nama Kelas (Menghapus pengulangan kata "Kelas")
  // =========================================================================
  String _formatNamaKelas(String kelasAsli) {
    String teksFormat = kelasAsli.toLowerCase().trim();
    
    // Jika kelas SP, ubah menjadi Santri Pemula (SP)
    if (teksFormat == 'kelas sp' || teksFormat == 'sp') {
      return 'Santri Pemula (SP)';
    }
    
    // Untuk kelas angka, hapus kata "Kelas" sehingga sisa angkanya saja (1, 2, 3, 4)
    return kelasAsli.replaceAll(RegExp(r'(?i)kelas\s*'), '').trim();
  }

  // Men-generate dan membuka file PDF Rapor
  Future<void> generateAndOpenRapor(RaporModel rapor, Uint8List? logoBytes) async {
    final pdf = pw.Document();

    // Status kenaikan
    String statusKenaikan = _cekStatusKenaikan(rapor.daftarNilai);

    // Menyiapkan data tabel secara dinamis
    List<List<String>> tableData = [];

    if (rapor.daftarNilai.isEmpty) {
      tableData.add([
        '-',
        'Belum ada data nilai / Nilai belum di-input guru',
        '-',
        '-',
        '-'
      ]);
      tableData.add(['', 'RATA-RATA NILAI', '-', '', '']);
    } else {
      tableData.addAll(rapor.daftarNilai.map((n) {
        final info = _getPredikatInfo(n.nilaiHarian);
        return [
          (rapor.daftarNilai.indexOf(n) + 1).toString(),
          _sanitizeText(n.mataPelajaran), 
          n.nilaiHarian.toStringAsFixed(0),
          info['grade']!,
          info['ket']!
        ];
      }).toList());

      tableData.add([
        '',
        'RATA-RATA NILAI',
        rapor.nilaiRataRata.toStringAsFixed(1),
        '',
        ''
      ]);
    }

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
                      pw.Text(
                        'PONDOK PESANTREN KHOIRUL HUDA',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'YAYASAN PENDIDIKAN ISLAM NURUL IMAN',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Kp. Baru Desa Pangarengan, Kecamatan Rajeg, Kabupaten Tangerang',
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
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
                      // PERBAIKAN: Memanggil _formatNamaKelas untuk merapikan teksnya
                      _infoText('Kelas', _formatNamaKelas(rapor.kelas)),
                      _infoText('Tahun Pelajaran', rapor.tahunAjaran),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 15),

              // --- TABEL NILAI UTAMA ---
              pw.Text('A. Nilai Akademik', 
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
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
                data: tableData,
              ),

              pw.SizedBox(height: 15),

              // --- TABEL SIKAP & KEHADIRAN ---
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('B. Nilai Perilaku / Adab', 
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.SizedBox(height: 5),
                        pw.TableHelper.fromTextArray(
                          border: pw.TableBorder.all(),
                          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                          cellStyle: const pw.TextStyle(fontSize: 9),
                          headers: ['Aspek Penilaian', 'Catatan / Keterangan'],
                          columnWidths: {
                            0: const pw.FixedColumnWidth(90),
                            1: const pw.FlexColumnWidth(),
                          },
                          data: [
                            ['Adab & Perilaku', _sanitizeText(rapor.catatanAdab)],
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 15),
                  pw.Expanded(
                    flex: 4,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('C. Ketidakhadiran', 
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.SizedBox(height: 5),
                        pw.TableHelper.fromTextArray(
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
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // --- STATUS KENAIKAN ---
              pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  width: double.infinity,
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
                  child: pw.Center(
                      child: pw.Text('STATUS KENAIKAN KELAS: $statusKenaikan',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)))),

              pw.SizedBox(height: 35),

              // --- TANDA TANGAN ---
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

    // ==========================================
    // MENGUBAH PDF MENJADI BYTES & SIMPAN KE LOKAL
    // ==========================================
    final pdfBytes = await pdf.save();
    final fileName = "Rapor_${rapor.namaSantri.replaceAll(' ', '_')}.pdf";

    // Menyimpan file secara background ke direktori lokal
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/$fileName");
    await file.writeAsBytes(pdfBytes);

    // ==========================================
    // MEMUNCULKAN DIALOG "SIMPAN SEBAGAI PDF" (NATIVE PRINT)
    // ==========================================
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: fileName,
    );

    // CATATAN: 
    // Fitur 'OpenFile' dan 'Share' tetap dinonaktifkan (di-comment) 
    // karena `Printing.layoutPdf` di atas sudah otomatis memunculkan tampilan Simpan/Print.
    // await OpenFile.open(file.path);
    // await Share.shareXFiles([XFile(file.path)], text: 'Berikut adalah e-Rapor...');
  }

  // Helper Widgets
  pw.Widget _infoText(String label, String val) => pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(0, 2, 0, 2),
        child: pw.Text('$label : $val', style: const pw.TextStyle(fontSize: 10)),
      );

  pw.Widget _ttdBox(String title) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Text(title,
            style: const pw.TextStyle(fontSize: 10),
            textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 50),
        pw.Text('....................', style: const pw.TextStyle(fontSize: 10)),
      ]);
}