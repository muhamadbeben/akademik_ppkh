class JadwalPelajaranModel {
  final String id, mataPelajaran, kelas, hari, jamMulai, jamSelesai, ustadz, ruangan;

  JadwalPelajaranModel({required this.id, required this.mataPelajaran, required this.kelas,
    required this.hari, required this.jamMulai, required this.jamSelesai, required this.ustadz, required this.ruangan});

  String get waktu => '\$jamMulai - \$jamSelesai';

  Map<String, dynamic> toMap() => {'id':id,'mataPelajaran':mataPelajaran,'kelas':kelas,
    'hari':hari,'jamMulai':jamMulai,'jamSelesai':jamSelesai,'ustadz':ustadz,'ruangan':ruangan};

  factory JadwalPelajaranModel.fromMap(Map<String, dynamic> map) => JadwalPelajaranModel(
    id: map['id']??'', mataPelajaran: map['mataPelajaran']??'', kelas: map['kelas']??'',
    hari: map['hari']??'', jamMulai: map['jamMulai']??'', jamSelesai: map['jamSelesai']??'',
    ustadz: map['ustadz']??'', ruangan: map['ruangan']??'');

  JadwalPelajaranModel copyWith({String? id, String? mataPelajaran, String? kelas, String? hari,
    String? jamMulai, String? jamSelesai, String? ustadz, String? ruangan}) =>
    JadwalPelajaranModel(id:id??this.id, mataPelajaran:mataPelajaran??this.mataPelajaran, kelas:kelas??this.kelas,
      hari:hari??this.hari, jamMulai:jamMulai??this.jamMulai, jamSelesai:jamSelesai??this.jamSelesai,
      ustadz:ustadz??this.ustadz, ruangan:ruangan??this.ruangan);
}
