import 'nilai_model.dart';

class RaporModel {
  final String id, santriId, namaSantri, nis, kelas, semester, tahunAjaran, keterangan, catatanWaliKelas;
  final List<NilaiModel> daftarNilai;
  final double rataRata;
  final int peringkat;
  final DateTime tanggalCetak;

  RaporModel({required this.id, required this.santriId, required this.namaSantri, required this.nis,
    required this.kelas, required this.semester, required this.tahunAjaran, required this.daftarNilai,
    required this.peringkat, this.keterangan = '', this.catatanWaliKelas = '', DateTime? tanggalCetak})
    : rataRata = daftarNilai.isEmpty ? 0 : daftarNilai.map((n) => n.nilaiAkhir).reduce((a, b) => a + b) / daftarNilai.length,
      tanggalCetak = tanggalCetak ?? DateTime.now();

  bool get naik => rataRata >= 70;
  String get statusKenaikan => naik ? 'Naik Kelas' : 'Tidak Naik Kelas';

  Map<String, dynamic> toMap() => {'id':id,'santriId':santriId,'namaSantri':namaSantri,'nis':nis,
    'kelas':kelas,'semester':semester,'tahunAjaran':tahunAjaran,'daftarNilai':daftarNilai.map((n)=>n.toMap()).toList(),
    'rataRata':rataRata,'peringkat':peringkat,'keterangan':keterangan,'catatanWaliKelas':catatanWaliKelas,
    'tanggalCetak':tanggalCetak.toIso8601String()};

  factory RaporModel.fromMap(Map<String, dynamic> map) => RaporModel(
    id: map['id']??'', santriId: map['santriId']??'', namaSantri: map['namaSantri']??'', nis: map['nis']??'',
    kelas: map['kelas']??'', semester: map['semester']??'', tahunAjaran: map['tahunAjaran']??'',
    daftarNilai: (map['daftarNilai'] as List<dynamic>? ?? []).map((n) => NilaiModel.fromMap(n)).toList(),
    peringkat: map['peringkat']??0, keterangan: map['keterangan']??'', catatanWaliKelas: map['catatanWaliKelas']??'',
    tanggalCetak: DateTime.parse(map['tanggalCetak']??DateTime.now().toIso8601String()));
}
