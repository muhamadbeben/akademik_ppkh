class SantriModel {
  final String id, nama, nis, jenisKelamin, tempatLahir, alamat, namaWali, noHpWali, kelas, tahunMasuk, foto, status;
  final DateTime tanggalLahir;

  SantriModel({required this.id, required this.nama, required this.nis, required this.jenisKelamin,
    required this.tempatLahir, required this.tanggalLahir, required this.alamat,
    required this.namaWali, required this.noHpWali, required this.kelas, required this.tahunMasuk,
    this.foto = '', this.status = 'aktif'});

  Map<String, dynamic> toMap() => {'id':id,'nama':nama,'nis':nis,'jenisKelamin':jenisKelamin,
    'tempatLahir':tempatLahir,'tanggalLahir':tanggalLahir.toIso8601String(),'alamat':alamat,
    'namaWali':namaWali,'noHpWali':noHpWali,'kelas':kelas,'tahunMasuk':tahunMasuk,'foto':foto,'status':status};

  factory SantriModel.fromMap(Map<String, dynamic> map) => SantriModel(
    id: map['id']??'', nama: map['nama']??'', nis: map['nis']??'', jenisKelamin: map['jenisKelamin']??'',
    tempatLahir: map['tempatLahir']??'', tanggalLahir: DateTime.parse(map['tanggalLahir']??DateTime.now().toIso8601String()),
    alamat: map['alamat']??'', namaWali: map['namaWali']??'', noHpWali: map['noHpWali']??'',
    kelas: map['kelas']??'', tahunMasuk: map['tahunMasuk']??'', foto: map['foto']??'', status: map['status']??'aktif');

  SantriModel copyWith({String? id, String? nama, String? nis, String? jenisKelamin, String? tempatLahir,
    DateTime? tanggalLahir, String? alamat, String? namaWali, String? noHpWali, String? kelas, String? tahunMasuk, String? foto, String? status}) =>
    SantriModel(id:id??this.id, nama:nama??this.nama, nis:nis??this.nis, jenisKelamin:jenisKelamin??this.jenisKelamin,
      tempatLahir:tempatLahir??this.tempatLahir, tanggalLahir:tanggalLahir??this.tanggalLahir, alamat:alamat??this.alamat,
      namaWali:namaWali??this.namaWali, noHpWali:noHpWali??this.noHpWali, kelas:kelas??this.kelas,
      tahunMasuk:tahunMasuk??this.tahunMasuk, foto:foto??this.foto, status:status??this.status);
}
