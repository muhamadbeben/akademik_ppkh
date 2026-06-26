// File: lib/services/rapor_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import '../models/rapor_model.dart';
import '../models/santri_model.dart';
import 'rapor_pdf_service.dart';

class RaporService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> cetakRaporPdfWithLogo(
      BuildContext context, RaporModel raporData) async {
    try {
      final ByteData bytes =
          await rootBundle.load('assets/images/logo rapot.png');
      final Uint8List logoBytes = bytes.buffer.asUint8List();

      final pdfService = RaporPdfService();
      await pdfService.generateAndOpenRapor(raporData, logoBytes);
    } catch (e) {
      debugPrint("Error saat memuat logo atau mencetak PDF: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat logo atau cetak PDF: $e')),
        );
      }
    }
  }

  /// Mengambil data rapor berdasarkan Santri, Kelas, dan Tahun Ajaran
  static Future<RaporModel?> getRaporBySantri(
      String santriId, String kelas, String tahunAjaran) async {
    try {
      final snapshot = await _db
          .collection('rapor')
          .where('santriId', isEqualTo: santriId)
          .where('kelas', isEqualTo: kelas)
          .where('tahunAjaran', isEqualTo: tahunAjaran)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return RaporModel.fromMap(
            snapshot.docs.first.data(), snapshot.docs.first.id);
      }
      return null;
    } catch (e) {
      debugPrint("Error pada fungsi getRaporBySantri: $e");
      return null;
    }
  }

  /// Meramu & men-generate data rapor dari koleksi 'nilai' (FORMAT BARU GABUNGAN MAP)
  static Future<RaporModel?> generateRapor(
      SantriModel santri, String kelas, String tahunAjaran) async {
    try {
      // 1. Ambil SATU dokumen nilai gabungan milik santri
      final query = await _db
          .collection('nilai')
          .where('santriId', isEqualTo: santri.id)
          .where('kelas', isEqualTo: kelas)
          .where('tahunAjaran', isEqualTo: tahunAjaran)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return null; // Data belum diinput oleh guru di NilaiScreen
      }

      final data = query.docs.first.data();
      final Map<String, NilaiModel> mapNilaiRapot = {};
      
      // VARIABEL UNTUK MENGHITUNG BOBOT RATA-RATA
      double rataKehadiran = double.tryParse(data['nilai_kehadiran']?.toString() ?? '0') ?? 0.0;
      double rataSikap = double.tryParse(data['nilai_perilaku']?.toString() ?? '0') ?? 0.0;

      double totalUts = 0.0; int countUts = 0;
      double totalUas = 0.0; int countUas = 0;
      double totalHafalan = 0.0; int countHafalan = 0;

      // 2A. EKSTRAKSI NILAI UTS (Hanya untuk perhitungan bobot, biasanya tidak ditampilkan per mapel di rapor akhir, atau disesuaikan dengan desain PDF Anda)
      if (data.containsKey('uts') && data['uts'] is Map) {
        Map<String, dynamic> utsData = data['uts'];
        utsData.forEach((_, nilaiVal) {
          double nilaiAngka = double.tryParse(nilaiVal.toString()) ?? 0.0;
          if (nilaiAngka > 0) {
            totalUts += nilaiAngka;
            countUts++;
          }
        });
      }

      // 2B. EKSTRAKSI NILAI UAS (Ujian Akhir Semester sebagai daftar nilai utama Rapot)
      if (data.containsKey('uas') && data['uas'] is Map) {
        Map<String, dynamic> uasData = data['uas'];
        uasData.forEach((mataPelajaran, nilaiVal) {
          double nilaiAngka = double.tryParse(nilaiVal.toString()) ?? 0.0;
          if (nilaiAngka > 0) {
            mapNilaiRapot[mataPelajaran] = NilaiModel(
              id: mataPelajaran.replaceAll(' ', '_'),
              mataPelajaran: mataPelajaran,
              nilaiHarian: nilaiAngka,
              grade: _getGradeMataPelajaran(nilaiAngka),
            );
            totalUas += nilaiAngka;
            countUas++;
          }
        });
      }

      // 2C. EKSTRAKSI NILAI HAFALAN KITAB
      if (data.containsKey('hafalan_kitab') && data['hafalan_kitab'] is Map) {
        Map<String, dynamic> hafalanData = data['hafalan_kitab'];
        hafalanData.forEach((mataPelajaran, nilaiVal) {
          double nilaiAngka = double.tryParse(nilaiVal.toString()) ?? 0.0;
          if (nilaiAngka > 0) {
            mapNilaiRapot[mataPelajaran] = NilaiModel(
              id: mataPelajaran.replaceAll(' ', '_'),
              mataPelajaran: mataPelajaran,
              nilaiHarian: nilaiAngka,
              grade: _getGradeMataPelajaran(nilaiAngka),
            );
            totalHafalan += nilaiAngka;
            countHafalan++;
          }
        });
      }

      final List<NilaiModel> listDaftarNilai = mapNilaiRapot.values.toList();
      if (listDaftarNilai.isEmpty) return null;

      // 3. MENGHITUNG RATA-RATA BERBOBOT (5% Hadir, 5% Sikap, 20% UTS, 40% UAS, 30% Hafalan)
      double avgUts = countUts > 0 ? totalUts / countUts : 0.0;
      double avgUas = countUas > 0 ? totalUas / countUas : 0.0;
      double avgHafalan = countHafalan > 0 ? totalHafalan / countHafalan : 0.0;

      double rataRataBerbobot = (rataKehadiran * 0.05) + 
                                (rataSikap * 0.05) + 
                                (avgUts * 0.20) + 
                                (avgUas * 0.40) + 
                                (avgHafalan * 0.30);

      // 4. EKSTRAKSI DATA ABSENSI
      int sakit = 0;
      int izin = 0;
      int alpha = 0;
      if (data.containsKey('ketidakhadiran') && data['ketidakhadiran'] is Map) {
        Map<String, dynamic> absenData = data['ketidakhadiran'];
        sakit = int.tryParse(absenData['Sakit']?.toString() ?? '0') ?? 0;
        izin = int.tryParse(absenData['Izin']?.toString() ?? '0') ?? 0;
        alpha = int.tryParse(absenData['Tanpa Keterangan']?.toString() ?? '0') ?? 0;
      }

      // 5. EKSTRAKSI NILAI PERILAKU/ADAB
      String catatanAdabStr = 'Baik, pertahankan adab dan sopan santun kepada pengajar.';
      if (rataSikap > 0) {
        catatanAdabStr = 'Nilai Sikap / Perilaku: ${rataSikap.toStringAsFixed(0)}';
      }

      // 6. Bungkus ke dalam objek RaporModel 
      return RaporModel(
        id: 'TEMP_${santri.id}_${kelas.replaceAll(' ', '')}_${tahunAjaran.replaceAll('/', '')}',
        santriId: santri.id,
        namaSantri: santri.nama,
        nis: santri.nis,
        kelas: kelas,
        tahunAjaran: tahunAjaran,
        halaqah: '-',
        pengajar: '-',
        catatanAdab: catatanAdabStr,
        absenSakit: sakit,
        absenIzin: izin,
        absenAlpha: alpha,
        nilaiRataRata: rataRataBerbobot, // Menggunakan rata-rata berbobot
        predikat: _getPredikatRataRata(rataRataBerbobot),
        catatanWaliKelas: 'Tingkatkan terus semangat belajarmu, pertahankan prestasimu.',
        tanggalCetak: DateTime.now(),
        daftarNilai: listDaftarNilai,
      );
    } catch (e, stacktrace) {
      debugPrint("Error pada fungsi generateRapor: $e");
      debugPrint("Stacktrace: $stacktrace");
      return null;
    }
  }

  static String _getPredikatRataRata(double nilai) {
    if (nilai >= 90) return 'A - Sangat Baik';
    if (nilai >= 80) return 'B - Baik';
    if (nilai >= 70) return 'C - Cukup';
    return 'D - Kurang';
  }

  static String _getGradeMataPelajaran(double nilai) {
    if (nilai >= 90) return 'A';
    if (nilai >= 80) return 'B';
    if (nilai >= 70) return 'C';
    return 'D';
  }
}