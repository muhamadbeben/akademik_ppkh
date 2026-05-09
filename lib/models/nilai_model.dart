class NilaiModel {
  final String id, santriId, mataPelajaran, semester, tahunAjaran, kelas;
  final double nilaiHarian, nilaiUTS, nilaiUAS, nilaiAkhir;
  final DateTime createdAt;

  NilaiModel({required this.id, required this.santriId, required this.mataPelajaran,
    required this.nilaiHarian, required this.nilaiUTS, required this.nilaiUAS,
    required this.semester, required this.tahunAjaran, required this.kelas, DateTime? createdAt})
    : nilaiAkhir = (nilaiHarian * 0.3) + (nilaiUTS * 0.3) + (nilaiUAS * 0.4),
      createdAt = createdAt ?? DateTime.now();

  String get grade { if (nilaiAkhir >= 90) return 'A'; if (nilaiAkhir >= 80) return 'B'; if (nilaiAkhir >= 70) return 'C'; if (nilaiAkhir >= 60) return 'D'; return 'E'; }
  bool get lulus => nilaiAkhir >= 70;

  Map<String, dynamic> toMap() => {'id':id,'santriId':santriId,'mataPelajaran':mataPelajaran,
    'nilaiHarian':nilaiHarian,'nilaiUTS':nilaiUTS,'nilaiUAS':nilaiUAS,'nilaiAkhir':nilaiAkhir,
    'semester':semester,'tahunAjaran':tahunAjaran,'kelas':kelas,'createdAt':createdAt.toIso8601String()};

  factory NilaiModel.fromMap(Map<String, dynamic> map) => NilaiModel(
    id: map['id']??'', santriId: map['santriId']??'', mataPelajaran: map['mataPelajaran']??'',
    nilaiHarian: (map['nilaiHarian']??0).toDouble(), nilaiUTS: (map['nilaiUTS']??0).toDouble(),
    nilaiUAS: (map['nilaiUAS']??0).toDouble(), semester: map['semester']??'',
    tahunAjaran: map['tahunAjaran']??'', kelas: map['kelas']??'',
    createdAt: DateTime.parse(map['createdAt']??DateTime.now().toIso8601String()));
}
