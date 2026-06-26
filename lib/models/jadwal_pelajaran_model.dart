// File: lib/models/jadwal_pelajaran_model.dart

class JadwalPelajaranModel {
  final String id;
  final String kelas;
  final String hari;
  final String jamMulai;
  final String jamSelesai;
  final String mataPelajaran;
  final String guru;
  final String ruangan;

  JadwalPelajaranModel({
    required this.id,
    required this.kelas,
    required this.hari,
    required this.jamMulai,
    required this.jamSelesai,
    required this.mataPelajaran,
    required this.guru,
    required this.ruangan,
  });

  /// Mengubah dokumen Map dari Firebase Firestore menjadi objek Model Dart (Aplikasi)
  factory JadwalPelajaranModel.fromMap(Map<String, dynamic> map, String docId) {
    return JadwalPelajaranModel(
      id: docId,
      kelas: map['kelas'] ?? '',
      hari: map['hari'] ?? '',
      // Menyelaraskan key Firestore 'jam_mulai' ke properti jamMulai
      jamMulai: map['jam_mulai'] ?? '',
      // Menyelaraskan key Firestore 'jam_selesai' ke properti jamSelesai
      jamSelesai: map['jam_selesai'] ?? '',
      // Menyelaraskan key Firestore 'mata_pelajaran' ke properti mataPelajaran
      mataPelajaran: map['mata_pelajaran'] ?? '',
      guru: map['guru'] ?? '',
      ruangan: map['ruangan'] ?? '',
    );
  }

  /// Mengubah objek Model Dart menjadi struktur Map sebelum diunggah ke Firebase Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kelas': kelas,
      'hari': hari,
      'jam_mulai': jamMulai,
      'jam_selesai': jamSelesai,
      'mata_pelajaran': mataPelajaran,
      'guru': guru,
      'ruangan': ruangan,
    };
  }
}

/// Daftar konstanta nama hari untuk mempermudah Dropdown & Tab Filter
const List<String> daftarHari = [
  'Senin', 
  'Selasa', 
  'Rabu', 
  'Kamis', 
  'Jumat', 
  'Sabtu'
];