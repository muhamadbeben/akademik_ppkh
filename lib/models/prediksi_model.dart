class PrediksiModel {
  final String id, santriId, namaSantri, kelas, hasilPrediksi, semester, tahunAjaran;
  final double rataRataNilai, persentaseKehadiran, confidence;
  final int jumlahMelanggar;
  final List<String> faktorPendukung, rekomendasiPerbaikan;
  final DateTime tanggalPrediksi;

  PrediksiModel({required this.id, required this.santriId, required this.namaSantri, required this.kelas,
    required this.rataRataNilai, required this.persentaseKehadiran, required this.jumlahMelanggar,
    required this.hasilPrediksi, required this.confidence, required this.faktorPendukung,
    required this.rekomendasiPerbaikan, required this.semester, required this.tahunAjaran, DateTime? tanggalPrediksi})
    : tanggalPrediksi = tanggalPrediksi ?? DateTime.now();

  bool get isLulus => hasilPrediksi == 'Lulus';

  Map<String, dynamic> toMap() => {'id':id,'santriId':santriId,'namaSantri':namaSantri,'kelas':kelas,
    'rataRataNilai':rataRataNilai,'persentaseKehadiran':persentaseKehadiran,'jumlahMelanggar':jumlahMelanggar,
    'hasilPrediksi':hasilPrediksi,'confidence':confidence,'faktorPendukung':faktorPendukung,
    'rekomendasiPerbaikan':rekomendasiPerbaikan,'semester':semester,'tahunAjaran':tahunAjaran,
    'tanggalPrediksi':tanggalPrediksi.toIso8601String()};

  factory PrediksiModel.fromMap(Map<String, dynamic> map) => PrediksiModel(
    id: map['id']??'', santriId: map['santriId']??'', namaSantri: map['namaSantri']??'', kelas: map['kelas']??'',
    rataRataNilai: (map['rataRataNilai']??0).toDouble(), persentaseKehadiran: (map['persentaseKehadiran']??0).toDouble(),
    jumlahMelanggar: map['jumlahMelanggar']??0, hasilPrediksi: map['hasilPrediksi']??'', confidence: (map['confidence']??0).toDouble(),
    faktorPendukung: List<String>.from(map['faktorPendukung']??[]), rekomendasiPerbaikan: List<String>.from(map['rekomendasiPerbaikan']??[]),
    semester: map['semester']??'', tahunAjaran: map['tahunAjaran']??'',
    tanggalPrediksi: DateTime.parse(map['tanggalPrediksi']??DateTime.now().toIso8601String()));
}
