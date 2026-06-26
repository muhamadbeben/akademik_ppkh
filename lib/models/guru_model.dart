// File: lib/models/guru_model.dart

class GuruModel {
  final String id;
  final String nama;
  final String nip;
  final String kelas; // <-- Sudah diganti dari mataPelajaran menjadi kelas
  final String username;
  final String password; 
  final String role;     
  final String status;   
  final String? imageUrl; 

  GuruModel({
    required this.id,
    required this.nama,
    required this.nip,
    required this.kelas, // <-- Disesuaikan
    required this.username,
    required this.password,
    required this.role,
    required this.status,
    this.imageUrl,
  });

  factory GuruModel.fromMap(Map<String, dynamic> map) {
    return GuruModel(
      id: map['id'] ?? '',
      nama: map['nama'] ?? '',
      nip: map['nip'] ?? '',
      kelas: map['kelas'] ?? '', // <-- Membaca field 'kelas' dari Firebase
      username: map['username'] ?? '',
      password: map['password'] ?? '', 
      role: map['role'] ?? 'Guru', 
      status: map['status'] ?? 'Aktif',
      imageUrl: map['imageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'nip': nip,
      'kelas': kelas, // <-- Menyimpan ke field 'kelas' di Firebase
      'username': username,
      'password': password,
      'role': role,
      'status': status,
      'imageUrl': imageUrl,
    };
  }
}