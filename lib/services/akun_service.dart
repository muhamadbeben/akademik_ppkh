// File: lib/services/akun_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:akademik_ppkh/models/akun_model.dart';

class AkunService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// =========================================================================
  /// FUNGSI PINTAR: Melacak Referensi Dokumen Pengguna secara Akurat
  /// Mencari berdasarkan UID Auth, jika gagal mencari berdasarkan Email.
  /// Parameter [role] bersifat opsional untuk mempercepat pencarian.
  /// =========================================================================
  Future<DocumentReference?> _getUserDocumentRef(User user, {String? role}) async {
    List<String> collectionsToCheck = ['walisantri', 'guru', 'admin'];

    // Jika role diketahui, fokuskan pencarian ke tabel tersebut
    if (role != null) {
      if (role.toLowerCase().contains('guru')) {
        collectionsToCheck = ['guru'];
      } else if (role.toLowerCase().contains('wali')) {
        collectionsToCheck = ['walisantri'];
      } else if (role.toLowerCase().contains('admin')) {
        collectionsToCheck = ['admin'];
      }
    }

    // TAHAP 1: Cari berdasarkan UID Auth 
    for (String col in collectionsToCheck) {
      try {
        final doc = await _firestore.collection(col).doc(user.uid).get();
        if (doc.exists) return doc.reference;
      } catch (_) {}
    }

    // TAHAP 2: Jika gagal, cari berdasarkan EMAIL (Kasus data diinput manual Admin)
    if (user.email != null) {
      for (String col in collectionsToCheck) {
        try {
          final query = await _firestore.collection(col).where('email', isEqualTo: user.email).limit(1).get();
          if (query.docs.isNotEmpty) {
            return query.docs.first.reference;
          }
        } catch (_) {}
      }
    }

    return null; // Tidak ditemukan di database
  }

  /// =========================================================================
  /// 1. MENGAMBIL DATA PROFIL USER
  /// =========================================================================
  Future<UserModel?> fetchUserProfile({String? knownRole}) async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      // Dapatkan referensi dokumen asli pengguna
      final DocumentReference? userRef = await _getUserDocumentRef(currentUser, role: knownRole);
      
      if (userRef != null) {
        final DocumentSnapshot doc = await userRef.get();
        if (doc.exists) {
          return UserModel.fromFirestore(doc);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetchUserProfile: $e');
      rethrow;
    }
  }

  /// =========================================================================
  /// 2. MEMPERBARUI/EDIT DATA PROFIL (Nama & No HP)
  /// =========================================================================
  Future<void> updateProfileData({required String namaBaru, required String noHpBaru, String? knownRole}) async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('Sesi telah berakhir, harap login ulang.');

      // Dapatkan referensi dokumen yang tepat
      final DocumentReference? userRef = await _getUserDocumentRef(currentUser, role: knownRole);
      if (userRef == null) throw Exception('Data pengguna tidak ditemukan di database.');

      final Map<String, dynamic> dataToUpdate = {
        'name': namaBaru,
        'phoneNumber': noHpBaru,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Simpan perubahan langsung ke referensi yang dilacak (merge: true agar data lain aman)
      await userRef.set(dataToUpdate, SetOptions(merge: true)); 
          
    } catch (e) {
      debugPrint('Error updateProfileData: $e');
      rethrow;
    }
  }

  /// =========================================================================
  /// 3. UPLOAD FOTO PROFIL KE FIREBASE STORAGE
  /// =========================================================================
  Future<String?> uploadProfilePicture(File imageFile, {String? knownRole}) async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User belum login');

      // Dapatkan referensi dokumen pengguna terlebih dahulu
      final DocumentReference? userRef = await _getUserDocumentRef(currentUser, role: knownRole);
      if (userRef == null) throw Exception('Data pengguna tidak ditemukan di database.');

      final Reference storageRef = _storage
          .ref()
          .child('profile_pictures')
          .child('${currentUser.uid}.jpg');

      // Mengunggah file gambar ke Storage
      final UploadTask uploadTask = storageRef.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Memperbarui field photoUrl langsung ke dokumen target
      await userRef.set({'photoUrl': downloadUrl}, SetOptions(merge: true));

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploadProfilePicture: $e');
      rethrow;
    }
  }

  /// =========================================================================
  /// 4. UPDATE PREFERENSI NOTIFIKASI
  /// =========================================================================
  Future<void> updateNotificationPreference(bool isEnabled, {String? knownRole}) async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User belum login');

      final DocumentReference? userRef = await _getUserDocumentRef(currentUser, role: knownRole);
      if (userRef == null) throw Exception('Data pengguna tidak ditemukan di database.');

      // Perbarui status notifikasi langsung ke dokumen target
      await userRef.set({'isNotificationEnabled': isEnabled}, SetOptions(merge: true));
          
    } catch (e) {
      debugPrint('Error updateNotificationPreference: $e');
      rethrow;
    }
  }
}