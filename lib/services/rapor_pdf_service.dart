import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../models/rapor_model.dart';

class RaporPdfService {
  Future<void> generateAndOpenRapor(RaporModel rapor) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        pw.Center(
          child: pw.Column(children: [
            pw.Text('RAPOR SANTRI',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('PESANTREN MODERN AL-HIKMAH',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text('Tahun Ajaran ' + rapor.tahunAjaran + ' - Semester ' + rapor.semester),
            pw.Divider(thickness: 2),
          ]),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Data Santri', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('Nama     : ' + rapor.namaSantri),
            pw.Text('NIS      : ' + rapor.nis),
            pw.Text('Kelas    : ' + rapor.kelas),
            pw.Text('Semester : ' + rapor.semester),
            pw.Text('Peringkat: ' + rapor.peringkat.toString()),
          ]),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(1.5),
            2: pw.FlexColumnWidth(1.5),
            3: pw.FlexColumnWidth(1.5),
            4: pw.FlexColumnWidth(1.5),
            5: pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.green100),
              children: ['Mata Pelajaran', 'Harian', 'UTS', 'UAS', 'Akhir', 'Grade']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(h,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ))
                  .toList(),
            ),
            ...rapor.daftarNilai.map((n) => pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(n.mataPelajaran)),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(n.nilaiHarian.toStringAsFixed(1), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(n.nilaiUTS.toStringAsFixed(1), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(n.nilaiUAS.toStringAsFixed(1), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(n.nilaiAkhir.toStringAsFixed(1), textAlign: pw.TextAlign.center)),
              pw.Padding(padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(n.grade, textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            ])),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Rata-rata  : ' + rapor.rataRata.toStringAsFixed(2)),
            pw.Text('Status     : ' + rapor.statusKenaikan,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold,
                    color: rapor.naik ? PdfColors.green700 : PdfColors.red700)),
            if (rapor.catatanWaliKelas.isNotEmpty)
              pw.Text('Catatan    : ' + rapor.catatanWaliKelas),
          ]),
        ),
        pw.SizedBox(height: 32),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [_ttd('Orang Tua/Wali'), _ttd('Wali Kelas'), _ttd('Kepala Pesantren')],
        ),
      ],
    ));

    final dir = await getApplicationDocumentsDirectory();
    final file = File(dir.path + '/rapor_' + rapor.nis + '_' + rapor.semester + '.pdf');
    await file.writeAsBytes(await pdf.save());
    await OpenFile.open(file.path);
  }

  pw.Widget _ttd(String label) {
    return pw.Column(children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
      pw.SizedBox(height: 50),
      pw.Text('(________________________)', style: const pw.TextStyle(fontSize: 10)),
    ]);
  }
}
