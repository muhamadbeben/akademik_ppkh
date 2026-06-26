import 'package:cloud_firestore/cloud_firestore.dart';

class PrediksiModel {
  final String id;
  final String santriId;
  final String namaSantri;
  final String kelas;
  final double nilaiRataRata;
  final double nilaiAgama;
  final double nilaiAkhlak;
  final double nilaiKehadiran;
  final double nilaiHafalan;
  final String hasilPrediksi;
  final double probabilitas;
  final String catatan;
  final DateTime tanggalPrediksi;

  PrediksiModel({
    required this.id,
    required this.santriId,
    required this.namaSantri,
    required this.kelas,
    required this.nilaiRataRata,
    required this.nilaiAgama,
    required this.nilaiAkhlak,
    required this.nilaiKehadiran,
    required this.nilaiHafalan,
    required this.hasilPrediksi,
    required this.probabilitas,
    required this.catatan,
    required this.tanggalPrediksi,
  });

  bool get isLulus => hasilPrediksi == 'Lulus';
  bool get isPerluPerhatian => hasilPrediksi == 'Perlu Perhatian';

  factory PrediksiModel.fromMap(Map<String, dynamic> map) {
    return PrediksiModel(
      id: map['id'] ?? '',
      santriId: map['santri_id'] ?? '',
      namaSantri: map['nama_santri'] ?? '',
      kelas: map['kelas'] ?? '',
      nilaiRataRata: (map['nilai_rata_rata'] ?? 0).toDouble(),
      nilaiAgama: (map['nilai_agama'] ?? 0).toDouble(),
      nilaiAkhlak: (map['nilai_akhlak'] ?? 0).toDouble(),
      nilaiKehadiran: (map['nilai_kehadiran'] ?? 0).toDouble(),
      nilaiHafalan: (map['nilai_hafalan'] ?? 0).toDouble(),
      hasilPrediksi: map['hasil_prediksi'] ?? '',
      probabilitas: (map['probabilitas'] ?? 0).toDouble(),
      catatan: map['catatan'] ?? '',
      tanggalPrediksi: map['tanggal_prediksi'] is Timestamp 
          ? (map['tanggal_prediksi'] as Timestamp).toDate() 
          : DateTime.tryParse(map['tanggal_prediksi']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'santri_id': santriId,
      'nama_santri': namaSantri,
      'kelas': kelas,
      'nilai_rata_rata': nilaiRataRata,
      'nilai_agama': nilaiAgama,
      'nilai_akhlak': nilaiAkhlak,
      'nilai_kehadiran': nilaiKehadiran,
      'nilai_hafalan': nilaiHafalan,
      'hasil_prediksi': hasilPrediksi,
      'probabilitas': probabilitas,
      'catatan': catatan,
      'tanggal_prediksi': tanggalPrediksi.toIso8601String(),
    };
  }
}