// File: lib/services/guru_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/guru_model.dart';

class KelolaGuruService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- MENGAMBIL DAFTAR GURU ---
  // --- MENGAMBIL DAFTAR GURU ---
  Future<List<GuruModel>> getDaftarGuru() async {
    try {
      final snapshot = await _db
          .collection('guru')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return GuruModel(
          id: doc.id,
          nama: data['nama'] ?? '',
          nip: data['nip'] ?? '',
          kelas: data['kelas'] ?? '',
          username: data['username'] ?? '',

          // [TAMBAHKAN 2 BARIS INI] untuk memenuhi syarat 'required' di GuruModel
          password: data['password'] ?? '',
          role: data['role'] ?? 'Guru',
          // -----------------------------------------------------------

          status: data['status'] ?? 'Aktif',
          imageUrl: data['imageUrl'],
        );
      }).toList();
    } catch (e) {
      throw Exception('Gagal mengambil data guru: $e');
    }
  }

  // --- MENAMBAH GURU BARU ---
  Future<void> tambahGuru(Map<String, dynamic> data) async {
    // Membuat instance Firebase sementara agar Admin yang sedang login TIDAK ter-logout
    // saat mendaftarkan akun baru untuk Guru.
    FirebaseApp tempApp = await Firebase.initializeApp(
      name: 'temp_register_${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );

    try {
      // 1. Daftarkan Email & Password Guru ke Firebase Auth
      UserCredential userCred = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(
              email: data['username'], password: data['password']);

      String uid = userCred.user!.uid;

      // 2. SIMPAN KE KOLEKSI 'users' (SANGAT PENTING UNTUK LOGIN & HAK AKSES)
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'nama': data['nama'],
        'email': data['username'],
        'role': data['role'], // role: 'guru'
        'kelas': data[
            'kelas'], // KELAS DISIMPAN DI SINI AGAR GURU TERKUNCI DI KELASNYA
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Simpan ke koleksi 'guru' untuk ditampilkan di tabel Kelola Guru
      await _db.collection('guru').doc(uid).set({
        'id': uid,
        'nama': data['nama'],
        'nip': data['nip'],
        'kelas': data['kelas'],
        'username': data['username'],
        'status': data['status'],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Gagal mendaftarkan guru: $e');
    } finally {
      // Hapus instance sementara
      await tempApp.delete();
    }
  }

  // --- UPDATE DATA GURU ---
  Future<void> updateGuru(String id, Map<String, dynamic> data) async {
    try {
      // Update di tabel guru
      await _db.collection('guru').doc(id).update({
        'nama': data['nama'],
        'nip': data['nip'],
        'kelas': data['kelas'],
        'username': data['username'],
      });

      // Update juga di tabel users agar otentikasi loginnya ikut berubah (jika kelasnya dipindah)
      await _db.collection('users').doc(id).update({
        'nama': data['nama'],
        'kelas': data['kelas'],
      });
    } catch (e) {
      throw Exception('Gagal mengupdate data guru: $e');
    }
  }

  // --- RESET PASSWORD GURU ---
  Future<void> resetPassword(String id, String newPassword) async {
    try {
      // Untuk mereset password secara langsung tanpa email link,
      // ini membutuhkan penanganan khusus melalui backend atau Cloud Functions.
      // Namun, jika kamu menggunakan metode sederhana, kita bisa lempar notifikasi.
      throw Exception(
          'Untuk mereset password, mohon gunakan fitur Lupa Password di halaman login, atau atur via Firebase Console.');
    } catch (e) {
      throw Exception('Gagal reset password: $e');
    }
  }

  // --- UBAH STATUS AKUN (AKTIF/NONAKTIF) ---
  Future<void> toggleStatusAkun(String id, String statusBaru) async {
    try {
      await _db.collection('guru').doc(id).update({'status': statusBaru});
    } catch (e) {
      throw Exception('Gagal mengubah status: $e');
    }
  }

  // --- HAPUS GURU ---
  Future<void> hapusGuru(String id) async {
    try {
      // Hapus dari tabel guru
      await _db.collection('guru').doc(id).delete();

      // Hapus dari tabel users agar tidak bisa login lagi
      await _db.collection('users').doc(id).delete();

      // Catatan: Menghapus dari Firebase Auth (Email/Password) secara langsung
      // dari sisi client Flutter (Admin) membutuhkan Cloud Functions.
      // Dengan menghapus dari koleksi 'users', role-nya akan hilang dan aplikasi akan menolaknya masuk.
    } catch (e) {
      throw Exception('Gagal menghapus guru: $e');
    }
  }
}
