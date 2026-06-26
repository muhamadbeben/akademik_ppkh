// File: lib/models/santri_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class SantriModel {
  final String id;
  final String nis;
  final String nama;
  final String kelas;
  final String asrama;         
  final String kamar;          
  final String jenisKelamin;
  final String tempatLahir;
  final String tanggalLahir;
  final String alamat;
  final String tahunMasuk;     
  final String status;         // Aktif / Lulus / Keluar
  final DateTime tanggalMasuk;
  
  // Data Orang Tua / Wali
  final String namaWali;
  final String hubunganWali;   
  final String teleponWali;
  final String? pekerjaanWali; 
  final String? alamatWali;    

  // Akun Akses Wali
  final String usernameWali;   
  final String passwordWali;   

  final String foto;
  double? prediksiKelulusan;

  SantriModel({
    required this.id,
    required this.nis,
    required this.nama,
    required this.kelas,
    required this.asrama,
    required this.kamar,
    required this.jenisKelamin,
    required this.tempatLahir,
    required this.tanggalLahir,
    required this.alamat,
    required this.tahunMasuk,
    required this.status,
    required this.tanggalMasuk,
    required this.namaWali,
    required this.hubunganWali,
    required this.teleponWali,
    this.pekerjaanWali,
    this.alamatWali,
    required this.usernameWali,
    required this.passwordWali,
    this.foto = '',
    this.prediksiKelulusan,
  });

  /// Digunakan untuk membuat objek baru dengan perubahan pada field tertentu (misal: saat update UI state)
  SantriModel copyWith({
    String? id,
    String? nis,
    String? nama,
    String? kelas,
    String? asrama,
    String? kamar,
    String? jenisKelamin,
    String? tempatLahir,
    String? tanggalLahir,
    String? alamat,
    String? tahunMasuk,
    String? status,
    DateTime? tanggalMasuk,
    String? namaWali,
    String? hubunganWali,
    String? teleponWali,
    String? pekerjaanWali,
    String? alamatWali,
    String? usernameWali,
    String? passwordWali,
    String? foto,
    double? prediksiKelulusan,
  }) {
    return SantriModel(
      id: id ?? this.id,
      nis: nis ?? this.nis,
      nama: nama ?? this.nama,
      kelas: kelas ?? this.kelas,
      asrama: asrama ?? this.asrama,
      kamar: kamar ?? this.kamar,
      jenisKelamin: jenisKelamin ?? this.jenisKelamin,
      tempatLahir: tempatLahir ?? this.tempatLahir,
      tanggalLahir: tanggalLahir ?? this.tanggalLahir,
      alamat: alamat ?? this.alamat,
      tahunMasuk: tahunMasuk ?? this.tahunMasuk,
      status: status ?? this.status,
      tanggalMasuk: tanggalMasuk ?? this.tanggalMasuk,
      namaWali: namaWali ?? this.namaWali,
      hubunganWali: hubunganWali ?? this.hubunganWali,
      teleponWali: teleponWali ?? this.teleponWali,
      pekerjaanWali: pekerjaanWali ?? this.pekerjaanWali,
      alamatWali: alamatWali ?? this.alamatWali,
      usernameWali: usernameWali ?? this.usernameWali,
      passwordWali: passwordWali ?? this.passwordWali,
      foto: foto ?? this.foto,
      prediksiKelulusan: prediksiKelulusan ?? this.prediksiKelulusan,
    );
  }

  /// Menerima data dari Firestore (DocumentSnapshot.data()) dan mengubahnya menjadi Object SantriModel
  factory SantriModel.fromMap(Map<String, dynamic> map, String documentId) {
    // Fungsi pembantu parsing tanggal yang jauh lebih aman & akurat memakai keyword 'is'
    DateTime parseDate(dynamic dateData) {
      if (dateData == null) return DateTime.now();
      if (dateData is Timestamp) {
        return dateData.toDate();
      }
      if (dateData is String) {
        return DateTime.tryParse(dateData) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return SantriModel(
      id: documentId,
      nis: map['nis'] ?? '',
      nama: map['nama'] ?? '',
      kelas: map['kelas'] ?? '',
      asrama: map['asrama'] ?? '',
      kamar: map['kamar'] ?? '',
      jenisKelamin: map['jenis_kelamin'] ?? '',
      tempatLahir: map['tempat_lahir'] ?? '',
      tanggalLahir: map['tanggal_lahir'] ?? '',
      alamat: map['alamat'] ?? '',
      tahunMasuk: map['tahun_masuk'] ?? '',
      status: map['status'] ?? 'Aktif',
      tanggalMasuk: parseDate(map['tanggal_masuk']),
      namaWali: map['nama_wali'] ?? '',
      hubunganWali: map['hubungan_wali'] ?? 'Wali',
      teleponWali: map['telepon_wali'] ?? '',
      pekerjaanWali: map['pekerjaan_wali'],
      alamatWali: map['alamat_wali'],
      usernameWali: map['username_wali'] ?? '',
      passwordWali: map['password_wali'] ?? '',
      foto: map['foto'] ?? '',
      prediksiKelulusan: map['prediksi_kelulusan'] != null 
          ? (map['prediksi_kelulusan'] as num).toDouble() 
          : null,
    );
  }

  /// Mengubah Object SantriModel menjadi Map (JSON) untuk disimpan ke Firestore
  Map<String, dynamic> toMap() {
    return {
      'nis': nis,
      'nama': nama,
      'kelas': kelas,
      'asrama': asrama,
      'kamar': kamar,
      'jenis_kelamin': jenisKelamin,
      'tempat_lahir': tempatLahir,
      'tanggal_lahir': tanggalLahir,
      'alamat': alamat,
      'tahun_masuk': tahunMasuk,
      'status': status,
      'tanggal_masuk': Timestamp.fromDate(tanggalMasuk), // Disimpan sebagai tipe data Timestamp asli Firestore
      'nama_wali': namaWali,
      'hubungan_wali': hubunganWali,
      'telepon_wali': teleponWali,
      'pekerjaan_wali': pekerjaanWali,
      'alamat_wali': alamatWali,
      'username_wali': usernameWali,
      'password_wali': passwordWali,
      'foto': foto,
      'prediksi_kelulusan': prediksiKelulusan,
    };
  }
}