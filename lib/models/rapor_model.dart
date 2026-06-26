// File: lib/models/rapor_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class NilaiModel {
  final String? id; // Menampung ID Dokumen jika diambil dari koleksi independen
  final String mataPelajaran;
  final double nilaiHarian;
  final String grade;

  NilaiModel({
    this.id,
    required this.mataPelajaran,
    required this.nilaiHarian,
    required this.grade,
  });

  factory NilaiModel.fromMap(Map<String, dynamic> map, String documentId) {
    return NilaiModel(
      id: documentId.isNotEmpty ? documentId : (map['id'] ?? ''),
      mataPelajaran: map['mataPelajaran'] ?? '',
      nilaiHarian: (map['nilaiHarian'] ?? 0.0).toDouble(),
      grade: map['grade'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null && id!.isNotEmpty) 'id': id,
      'mataPelajaran': mataPelajaran,
      'nilaiHarian': nilaiHarian,
      'grade': grade,
    };
  }
}

class RaporModel {
  final String id;
  final String santriId;
  final String namaSantri;
  final String nis;
  final String kelas;
  final String tahunAjaran;

  // Field Tambahan Baru Akademik/Kepesantrenan
  final String halaqah;
  final String pengajar;
  final String catatanAdab;
  final int absenSakit;
  final int absenIzin;
  final int absenAlpha;

  final String predikat;
  final String catatanWaliKelas;
  final DateTime tanggalCetak;
  final List<NilaiModel> daftarNilai;
  final double nilaiRataRata;

  RaporModel({
    required this.id,
    required this.santriId,
    required this.namaSantri,
    required this.nis,
    required this.kelas,
    required this.tahunAjaran,
    this.halaqah = '-',
    this.pengajar = '-',
    this.catatanAdab = '-',
    this.absenSakit = 0,
    this.absenIzin = 0,
    this.absenAlpha = 0,
    required this.predikat,
    required this.catatanWaliKelas,
    required this.tanggalCetak,
    required this.daftarNilai,
    required this.nilaiRataRata,
  });

  factory RaporModel.fromMap(Map<String, dynamic> map, String documentId) {
    // Penanganan konversi data dinamis dari nested array Firebase secara aman
    List<NilaiModel> parsedNilai = [];
    if (map['daftarNilai'] != null) {
      final List<dynamic> listRaw = map['daftarNilai'];
      parsedNilai = listRaw.map((x) {
        if (x is Map<String, dynamic>) {
          return NilaiModel.fromMap(x, '');
        }
        return NilaiModel(mataPelajaran: '-', nilaiHarian: 0.0, grade: '-');
      }).toList();
    }

    // Penanganan konversi tipe data Waktu (Timestamp/String/DateTime)
    DateTime parsedDate = DateTime.now();
    if (map['tanggalCetak'] != null) {
      if (map['tanggalCetak'] is Timestamp) {
        parsedDate = (map['tanggalCetak'] as Timestamp).toDate();
      } else if (map['tanggalCetak'] is String) {
        parsedDate = DateTime.tryParse(map['tanggalCetak']) ?? DateTime.now();
      }
    }

    return RaporModel(
      id: documentId,
      santriId: map['santriId'] ?? '',
      namaSantri: map['namaSantri'] ?? '',
      nis: map['nis'] ?? '',
      kelas: map['kelas'] ?? '',
      tahunAjaran: map['tahunAjaran'] ?? '',
      halaqah: map['halaqah'] ?? '-',
      pengajar: map['pengajar'] ?? '-',
      catatanAdab: map['catatanAdab'] ?? '-',
      absenSakit: map['absenSakit'] ?? 0,
      absenIzin: map['absenIzin'] ?? 0,
      absenAlpha: map['absenAlpha'] ?? 0,
      predikat: map['predikat'] ?? '',
      catatanWaliKelas: map['catatanWaliKelas'] ?? '',
      tanggalCetak: parsedDate,
      nilaiRataRata: (map['nilaiRataRata'] ?? 0.0).toDouble(),
      daftarNilai: parsedNilai,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'santriId': santriId,
      'namaSantri': namaSantri,
      'nis': nis,
      'kelas': kelas,
      'tahunAjaran': tahunAjaran,
      'halaqah': halaqah,
      'pengajar': pengajar,
      'catatanAdab': catatanAdab,
      'absenSakit': absenSakit,
      'absenIzin': absenIzin,
      'absenAlpha': absenAlpha,
      'predikat': predikat,
      'catatanWaliKelas': catatanWaliKelas,
      'tanggalCetak': Timestamp.fromDate(tanggalCetak), // Disimpan sebagai format asli Firebase Timestamp
      'daftarNilai': daftarNilai.map((x) => x.toMap()).toList(),
      'nilaiRataRata': nilaiRataRata,
    };
  }
}