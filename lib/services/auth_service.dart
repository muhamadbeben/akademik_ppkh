import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _role = '';
  String get role => _role;
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final doc = await _firestore.collection('users').doc(cred.user!.uid).get();
      if (doc.exists) _role = doc.data()?['role'] ?? 'admin';
      notifyListeners();
      return {'success': true};
    } on FirebaseAuthException catch (e) {
      String msg = 'Terjadi kesalahan';
      if (e.code == 'user-not-found') msg = 'Email tidak ditemukan';
      if (e.code == 'wrong-password') msg = 'Password salah';
      if (e.code == 'invalid-email') msg = 'Format email tidak valid';
      return {'success': false, 'message': msg};
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    _role = '';
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<Map<String, dynamic>> getUserData() async {
    try {
      final d = await _firestore.collection('users').doc(currentUser!.uid).get();
      return d.data() ?? {};
    } catch (e) {
      return {};
    }
  }
}
