// File: lib/models/nilai_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class NilaiModel {
  final String id;
  final String santriId;
  final String kelas;
  final String mataPelajaran;
  final String semester;
  final String tahunAjaran;
  final double nilaiHarian;
  final double nilaiAkhir;
  final DateTime createdAt;

  NilaiModel({
    required this.id,
    String? santriId, // Menggunakan opsional posisional/bernama agar fleksibel
    String?
        idSantri, // JALUR AMAN: Menampung jika ada kode lama/typo memanggil 'idSantri'
    required this.kelas,
    required this.mataPelajaran,
    required this.semester,
    required this.tahunAjaran,
    required this.nilaiHarian,
    required this.createdAt,
  })  : santriId = idSantri ?? santriId ?? '',
        nilaiAkhir = nilaiHarian;

  /// Factory untuk mengubah data dari Firestore Map menjadi Objek NilaiModel
  factory NilaiModel.fromMap(Map<String, dynamic> map, String documentId) {
    // Fungsi pembantu aman untuk mengubah dynamic number ke double
    double toDoubleSafe(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    // Fungsi pembantu aman untuk membaca DateTime / Timestamp
    DateTime toDateTimeSafe(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return NilaiModel(
      id: documentId,
      santriId: map['id_santri'] ?? map['santriId'] ?? map['idSantri'] ?? '',
      kelas: map['kelas'] ?? '',
      mataPelajaran: map['mata_pelajaran'] ?? map['mataPelajaran'] ?? '',
      semester: map['semester'] ?? '',
      tahunAjaran: map['tahun_ajaran'] ?? map['tahunAjaran'] ?? '',
      nilaiHarian: toDoubleSafe(map['nilai_harian'] ?? map['nilaiHarian']),
      createdAt: toDateTimeSafe(map['createdAt']),
    );
  }

  /// Mengubah objek NilaiModel menjadi Map sebelum disimpan ke Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id, // Menyimpan ID dokumen di dalam map data agar sinkron
      'id_santri': santriId,
      'santriId':
          santriId, // Menyediakan camelCase juga untuk mencegah eror filter di Firestore
      'kelas': kelas,
      'mata_pelajaran': mataPelajaran,
      'mataPelajaran': mataPelajaran,
      'semester': semester,
      'tahun_ajaran': tahunAjaran,
      'tahunAjaran': tahunAjaran,
      'nilai_harian': nilaiHarian,
      'nilai_akhir': nilaiAkhir,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
