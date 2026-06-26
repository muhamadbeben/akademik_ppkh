// File: lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart'; // Ditambahkan untuk mendukung FirebaseApp sekunder

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _role = '';
  String get role => _role;
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // FUNGSI LOGIN
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password.trim());

      final doc =
          await _firestore.collection('users').doc(cred.user!.uid).get();

      if (doc.exists) {
        _role = doc.data()?['role'] ?? 'santri';
        notifyListeners();
        return {'success': true, 'role': _role, 'name': doc.data()?['name']};
      } else {
        return {
          'success': false,
          'message': 'Data profil tidak ditemukan di database.'
        };
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Terjadi kesalahan';
      if (e.code == 'user-not-found' || e.code == 'invalid-credential')
        msg = 'Email tidak ditemukan';
      if (e.code == 'wrong-password') msg = 'Password salah';
      if (e.code == 'invalid-email') msg = 'Format email tidak valid';
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // FUNGSI REGISTER (Digunakan Admin untuk mendaftarkan akun Wali Santri baru)
  Future<Map<String, dynamic>> register(
      String name, String email, String password, String role) async {
    // Membuat nama unik untuk temporary app berdasarkan timestamp agar tidak bentrok
    String tempAppName =
        'temp_register_${DateTime.now().millisecondsSinceEpoch}';
    FirebaseApp? tempApp;

    try {
      // 1. Inisialisasi instance Firebase baru khusus untuk proses registrasi ini
      tempApp = await Firebase.initializeApp(
        name: tempAppName,
        options: Firebase.app().options,
      );

      // Gunakan FirebaseAuth dari tempApp, bukan dari instance utama (_auth)
      // Ini mencegah Admin otomatis ter-logout dari aplikasi setelah register berhasil
      FirebaseAuth tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      // 2. Daftarkan kredensial akun baru ke Firebase Authentication
      UserCredential res = await tempAuth.createUserWithEmailAndPassword(
          email: email.trim(), password: password.trim());

      // 3. Simpan data profil ke Cloud Firestore memakai UID hasil pendaftaran Auth
      // (Menggunakan _firestore utama karena tidak mempengaruhi state login)
      await _firestore.collection('users').doc(res.user!.uid).set({
        'uid': res.user!.uid,
        'name': name,
        'email': email.trim(),
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. Hapus temporary app dari memori setelah selesai digunakan
      await tempApp.delete();

      return {'success': true};
    } on FirebaseAuthException catch (e) {
      // Pastikan menghapus tempApp jika terjadi error di tengah proses pendaftaran
      if (tempApp != null) await tempApp.delete();

      String msg = 'Terjadi kesalahan autentikasi';
      if (e.code == 'email-already-in-use')
        msg = 'Email ini sudah terdaftar sebelumnya.';
      if (e.code == 'weak-password')
        msg = 'Password terlalu lemah (minimal 6 karakter).';
      if (e.code == 'invalid-email') msg = 'Format email tidak valid.';

      return {'success': false, 'message': msg};
    } catch (e) {
      // Menangkap error umum lainnya (misal: masalah koneksi Firestore)
      if (tempApp != null) await tempApp.delete();
      return {'success': false, 'message': e.toString()};
    }
  }

  // FUNGSI LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
    _role = '';
    notifyListeners();
  }
}
