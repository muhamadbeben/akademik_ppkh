// File: lib/services/guru_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/guru_model.dart';

class KelolaGuruService {
  final CollectionReference _guruCollection = FirebaseFirestore.instance.collection('guru');

  // 1. Ambil semua data guru
  Future<List<GuruModel>> getDaftarGuru() async {
    final snapshot = await _guruCollection.get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id; 
      return GuruModel.fromMap(data); 
    }).toList();
  }

  // 2. Fungsi Tambah Guru (DIPERBAIKI: Daftar ke Auth & Database)
  Future<void> tambahGuru(Map<String, dynamic> data) async {
    // Trik "Secondary App": Membuat instance Firebase sementara agar 
    // akun Admin yang sedang dipakai tidak ter-logout saat mendaftarkan akun guru baru.
    FirebaseApp tempApp = await Firebase.initializeApp(
      name: 'TempRegisterApp',
      options: Firebase.app().options,
    );

    try {
      // Langkah 1: Buat akun login di Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(
        email: data['username'], // Pastikan field username diisi dengan format email
        password: data['password'],
      );

      // Langkah 2: Simpan data lengkap ke Firestore menggunakan UID dari Auth
      String uidBaru = userCredential.user!.uid;
      await _guruCollection.doc(uidBaru).set(data);

    } on FirebaseAuthException catch (e) {
      throw 'Gagal membuat akun login: ${e.message}';
    } finally {
      // Hapus koneksi sementara setelah proses selesai
      await tempApp.delete();
    }
  }

  // 3. Fungsi untuk Edit/Update Data Guru
  Future<void> updateGuru(String id, Map<String, dynamic> data) async {
    await _guruCollection.doc(id).update(data);
  }

  // 4. Fungsi untuk Mengubah Status Aktif/Nonaktif
  Future<void> toggleStatusAkun(String id, String status) async {
    await _guruCollection.doc(id).update({'status': status});
  }

  // 5. Fungsi untuk Reset Password (Di Firestore)
  Future<void> resetPassword(String id, String newPassword) async {
    await _guruCollection.doc(id).update({'password': newPassword});
    // Catatan: Reset password di Firebase Auth dari sisi client (admin) cukup rumit. 
    // Pendekatan ini hanya mengubah string password di database. Jika login Anda murni
    // menggunakan FirebaseAuth, user harus meresetnya via link email reset password bawaan Firebase.
  }

  // 6. Fungsi untuk Menghapus Guru
  Future<void> hapusGuru(String id) async {
    await _guruCollection.doc(id).delete();
  }
}