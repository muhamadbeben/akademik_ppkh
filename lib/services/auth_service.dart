// File: lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart'; 

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _role = '';
  String _kelas = ''; // [TAMBAHAN]: Menyimpan data kelas untuk guru

  String get role => _role;
  String get kelas => _kelas; // [TAMBAHAN]: Getter kelas
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
        final data = doc.data() as Map<String, dynamic>;
        _role = data['role'] ?? 'santri';
        _kelas = data['kelas'] ?? ''; // [TAMBAHAN]: Ambil atribut kelas jika ada
        
        notifyListeners();
        return {
          'success': true, 
          'role': _role, 
          'kelas': _kelas, // Kirimkan info kelas
          'name': data['name'] ?? data['nama']
        };
      } else {
        return {
          'success': false,
          'message': 'Data profil tidak ditemukan di database.'
        };
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Terjadi kesalahan';
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        msg = 'Email tidak ditemukan';
      }
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
    String tempAppName =
        'temp_register_${DateTime.now().millisecondsSinceEpoch}';
    FirebaseApp? tempApp;

    try {
      tempApp = await Firebase.initializeApp(
        name: tempAppName,
        options: Firebase.app().options,
      );

      FirebaseAuth tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      UserCredential res = await tempAuth.createUserWithEmailAndPassword(
          email: email.trim(), password: password.trim());

      await _firestore.collection('users').doc(res.user!.uid).set({
        'uid': res.user!.uid,
        'name': name,
        'email': email.trim(),
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await tempApp.delete();

      return {'success': true};
    } on FirebaseAuthException catch (e) {
      if (tempApp != null) await tempApp.delete();

      String msg = 'Terjadi kesalahan autentikasi';
      if (e.code == 'email-already-in-use') {
        msg = 'Email ini sudah terdaftar sebelumnya.';
      }
      if (e.code == 'weak-password') {
        msg = 'Password terlalu lemah (minimal 6 karakter).';
      }
      if (e.code == 'invalid-email') msg = 'Format email tidak valid.';

      return {'success': false, 'message': msg};
    } catch (e) {
      if (tempApp != null) await tempApp.delete();
      return {'success': false, 'message': e.toString()};
    }
  }

  // FUNGSI LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
    _role = '';
    _kelas = '';
    notifyListeners();
  }
}