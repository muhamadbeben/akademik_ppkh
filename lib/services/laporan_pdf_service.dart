import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../models/prediksi_model.dart';
import '../models/santri_model.dart';

class LaporanPdfService {

  Future<void> generateLaporanPrediksi({
    required List<PrediksiModel> prediksiList,
    required String kelas,
    required String semester,
    required String tahunAjaran,
  }) async {
    final pdf = pw.Document();
    final lulus = prediksiList.where((p) => p.isLulus).length;
    final total = prediksiList.length;
    final pctLulus = total > 0 ? (lulus / total * 100) : 0.0;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        pw.Center(child: pw.Column(children: [
          pw.Text('PESANTREN MODERN AL-HIKMAH',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('LAPORAN PREDIKSI KELULUSAN SANTRI',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.Text('Kelas ' + kelas + ' | Semester ' + semester + ' | TA ' + tahunAjaran),
          pw.Text('Dicetak: ' + DateTime.now().toString().substring(0, 16)),
          pw.Divider(thickness: 2),
        ])),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(border: pw.Border.all(), color: PdfColors.green50),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _statBlock('Total Santri', total.toString(), PdfColors.blue),
              _statBlock('Prediksi Lulus', lulus.toString(), PdfColors.green),
              _statBlock('Tidak Lulus', (total - lulus).toString(), PdfColors.red),
              _statBlock('% Lulus', pctLulus.toStringAsFixed(1) + '%', PdfColors.orange),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: const {
            0: pw.FlexColumnWidth(0.5),
            1: pw.FlexColumnWidth(2.5),
            2: pw.FlexColumnWidth(1),
            3: pw.FlexColumnWidth(1),
            4: pw.FlexColumnWidth(1),
            5: pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.green200),
              children: ['No', 'Nama', 'Nilai', 'Hadir%', 'Langgar', 'Prediksi']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(h,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ))
                  .toList(),
            ),
            ...prediksiList.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : PdfColors.grey100),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text((i + 1).toString(), textAlign: pw.TextAlign.center)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(p.namaSantri)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(p.rataRataNilai.toStringAsFixed(1), textAlign: pw.TextAlign.center)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(p.persentaseKehadiran.toStringAsFixed(0) + '%', textAlign: pw.TextAlign.center)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(p.jumlahMelanggar.toString(), textAlign: pw.TextAlign.center)),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(p.hasilPrediksi,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: p.isLulus ? PdfColors.green700 : PdfColors.red700,
                        )),
                  ),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Divider(),
        pw.Text('Dokumen ini digenerate secara otomatis oleh Sistem Manajemen Pesantren',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
      ],
    ));

    final dir = await getApplicationDocumentsDirectory();
    final file = File(dir.path + '/laporan_prediksi_' + kelas + '_' + semester + '.pdf');
    await file.writeAsBytes(await pdf.save());
    await OpenFile.open(file.path);
  }

  Future<void> generateLaporanSantri({
    required List<SantriModel> santriList,
    required String kelas,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        pw.Center(child: pw.Column(children: [
          pw.Text('PESANTREN MODERN AL-HIKMAH',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('LAPORAN DATA SANTRI - KELAS ' + kelas,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.Text('Total: ' + santriList.length.toString() + ' santri'),
          pw.Divider(thickness: 2),
        ])),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.green200),
              children: ['No', 'NIS', 'Nama', 'Jenis Kelamin', 'Kelas', 'Status']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ))
                  .toList(),
            ),
            ...santriList.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : PdfColors.grey100),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text((i + 1).toString())),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(s.nis)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(s.nama)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(s.jenisKelamin)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(s.kelas)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(s.status)),
                ],
              );
            }),
          ],
        ),
      ],
    ));

    final dir = await getApplicationDocumentsDirectory();
    final file = File(dir.path + '/laporan_santri_' + kelas + '.pdf');
    await file.writeAsBytes(await pdf.save());
    await OpenFile.open(file.path);
  }

  pw.Widget _statBlock(String label, String value, PdfColor color) {
    return pw.Column(children: [
      pw.Text(value, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: color)),
      pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
    ]);
  }
}
