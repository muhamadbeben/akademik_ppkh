// File: lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:flutter/foundation.dart';
import '../models/santri_model.dart';
import '../models/jadwal_pelajaran_model.dart';

class FirestoreService {
  // Memanggil instance database Firebase Firestore & Firebase Auth
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============ MANAJEMEN REGISTRASI AKUN ============

  /// Membuat akun Guru Baru berbasis Email & Password kustom
  static Future<void> buatAkunUser({
    required String nama,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      // 1. Daftarkan email dan password ke Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = userCredential.user!.uid;

      // 2. Simpan detail informasi pengguna ke koleksi 'users' di Firestore
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'nama': nama,
        'email': email,
        'role': role, // Menyimpan hak akses: 'guru' atau 'admin'
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error buatAkunUser (Guru/Admin): $e');
      rethrow;
    }
  }

  /// Membuat akun Wali Baru berbasis namaSantri & menangani error email yang sudah terdaftar
  static Future<void> buatAkunWaliMasingMasing({
    required String namaSantri, 
    required String email,
    required String password,
  }) async {
    try {
      // 1. Cari dokumen santri berdasarkan nama santri terlebih dahulu
      final santriQuery = await _db
          .collection('santri')
          .where('nama', isEqualTo: namaSantri)
          .limit(1)
          .get();

      if (santriQuery.docs.isEmpty) {
        throw Exception('Data Santri dengan nama "$namaSantri" tidak ditemukan! Pastikan data santri diinput terlebih dahulu.');
      }

      final docSantriId = santriQuery.docs.first.id;
      String uid = '';

      try {
        // 2. Daftarkan kredensial email & password wali ke Firebase Authentication
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        uid = userCredential.user!.uid;

        // 3. Daftarkan data Wali tersebut ke dalam koleksi 'users' utama aplikasi
        await _db.collection('users').doc(uid).set({
          'uid': uid,
          'nama': santriQuery.docs.first.data()['namaWali'] ?? 'Wali Santri',
          'email': email,
          'role': 'walisantri',
          'namaAnak': namaSantri,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseAuthException catch (authError) {
        // Tangkap jika email sudah pernah dipakai sebelumnya
        if (authError.code == 'email-already-in-use') {
          debugPrint('Email sudah terdaftar di Firebase Auth. Melanjutkan penautan langsung ke data master santri.');
        } else {
          rethrow;
        }
      }

      // 4. Update data kredensial akun di dalam dokumen data master santri terkait
      await _db.collection('santri').doc(docSantriId).update({
        'usernameWali': email,      
        'passwordWali': password,   
      });
    } catch (e) {
      debugPrint('Error buatAkunWaliMasingMasing: $e');
      rethrow;
    }
  }

  // ============ MANAJEMEN SANTRI ============

  static Future<List<SantriModel>> getSantriList() async {
    try {
      final snapshot = await _db.collection('santri').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return SantriModel.fromMap(data, doc.id); 
      }).toList();
    } catch (e) {
      debugPrint('Error getSantriList: $e'); 
      return [];
    }
  }

  static Future<SantriModel?> getSantriById(String id) async {
    try {
      final doc = await _db.collection('santri').doc(id).get();
      if (doc.exists) {
        final data = doc.data()!;
        return SantriModel.fromMap(data, doc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> tambahSantri(SantriModel santri) async {
    try {
      final docRef = _db.collection('santri').doc(); // Generate ID otomatis
      final data = santri.toMap();
      data['id'] = docRef.id; 
      
      await docRef.set(data);
      return true;
    } catch (e) {
      debugPrint('Error tambahSantri: $e');
      return false;
    }
  }

  static Future<bool> updateSantri(SantriModel santri) async {
    try {
      await _db.collection('santri').doc(santri.id).update(santri.toMap());
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> hapusSantri(String id) async {
    try {
      await _db.collection('santri').doc(id).delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<List<SantriModel>> cariSantri(String query) async {
    try {
      final allSantri = await getSantriList();
      final q = query.toLowerCase();
      
      return allSantri.where((s) =>
        s.nama.toLowerCase().contains(q) ||
        s.nis.toLowerCase().contains(q)
      ).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<int> getTotalSantriAktif() async {
    try {
      final snapshot = await _db.collection('santri')
          .where('status', isEqualTo: 'Aktif')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  static Future<int> getTotalKelas() async {
    try {
      final snapshot = await _db.collection('kelas').get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // ============ MASTER DATA KELAS (DINAMIS) ============

  /// Mengambil daftar nama kelas secara dinamis langsung dari koleksi 'kelas'
  static Future<List<String>> getKelasList() async {
    try {
      final snapshot = await _db.collection('kelas').orderBy('nama_kelas').get();
      
      // Jika dokumen di koleksi 'kelas' masih kosong, berikan fallback otomatis
      if (snapshot.docs.isEmpty) {
        return ['Kelas 7', 'Kelas 8', 'Kelas 9', 'Kelas 10', 'Kelas 11'];
      }
      
      return snapshot.docs.map((doc) => doc.data()['nama_kelas'].toString()).toList();
    } catch (e) {
      debugPrint('Error getKelasList: $e');
      return ['Kelas 7', 'Kelas 8', 'Kelas 9', 'Kelas 10', 'Kelas 11'];
    }
  }

  /// Menambah master data kelas baru
  static Future<bool> tambahKelas(String namaKelas) async {
    try {
      final docRef = _db.collection('kelas').doc(); // Auto-generate ID
      await docRef.set({
        'id': docRef.id,
        'nama_kelas': namaKelas,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error tambahKelas: $e');
      return false;
    }
  }

  // ============ JADWAL PELAJARAN ============

  static Future<List<JadwalPelajaranModel>> getJadwalByKelas(String kelas) async {
    try {
      final snapshot = await _db.collection('jadwal')
          .where('kelas', isEqualTo: kelas)
          .get();
          
      return snapshot.docs.map((doc) {
        final data = doc.data();
        // PERBAIKAN SINKRONISASI 2 ARGUMEN POSITIONAL
        return JadwalPelajaranModel.fromMap(data, doc.id);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<List<JadwalPelajaranModel>> getJadwalByHari(String kelas, String hari) async {
    try {
      final snapshot = await _db.collection('jadwal')
          .where('kelas', isEqualTo: kelas)
          .where('hari', isEqualTo: hari)
          .get();
          
      return snapshot.docs.map((doc) {
        final data = doc.data();
        // PERBAIKAN SINKRONISASI 2 ARGUMEN POSITIONAL
        return JadwalPelajaranModel.fromMap(data, doc.id);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<bool> tambahJadwal(JadwalPelajaranModel jadwal) async {
    try {
      final docRef = _db.collection('jadwal').doc();
      final data = jadwal.toMap();
      data['id'] = docRef.id;
      
      await docRef.set(data);
      return true;
    } catch (e) {
      debugPrint('Error tambahJadwal: $e');
      return false;
    }
  }

  static Future<bool> hapusJadwal(String id) async {
    try {
      await _db.collection('jadwal').doc(id).delete();
      return true;
    } catch (e) {
      return false;
    }
  }
}