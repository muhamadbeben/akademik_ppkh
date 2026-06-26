// File: lib/services/wali_santri_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:akademik_ppkh/models/walisantri_model.dart';

class WaliSantriService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Ambil Data Realtime Stream untuk UI
  Stream<List<WaliSantriModel>> getWaliSantriStream() {
    return _db.collection('walisantri').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => WaliSantriModel.fromFirestore(doc))
          .toList();
    });
  }

  // 2. Tambah Data Wali Santri (WAJIB menggunakan .doc(uid).set)
  Future<void> tambahWaliSantri({
    required String uid,
    required String namaWali,
    required String noHp,
    required String santriId,
    required String hubungan,
    required String username,
    required String password,
  }) async {
    try {
      // Mengambil data nama & kelas santri untuk sinkronisasi profil wali
      String namaSantri = '-';
      String kelasSantri = '-';

      if (santriId.isNotEmpty) {
        DocumentSnapshot santriDoc =
            await _db.collection('santri').doc(santriId).get();
        if (santriDoc.exists) {
          Map<String, dynamic> dataSantri =
              santriDoc.data() as Map<String, dynamic>;
          namaSantri = dataSantri['nama'] ?? '-';
          kelasSantri = dataSantri['kelas'] ?? '-';
        }
      }

      // PERBAIKAN UTAMA: .doc(uid).set digunakan agar ID Firestore
      // sama dengan UID Firebase Auth
      await _db.collection('walisantri').doc(uid).set({
        'uid': uid,
        'namaWali': namaWali,
        'noHp': noHp,
        'hubungan': hubungan,
        'santriId': santriId,
        'namaSantri': namaSantri,
        'kelasSantri': kelasSantri,
        'username': username,
        'password':
            password, // Catatan: Sebaiknya jangan simpan password asli di database untuk keamanan
        'status': 'Aktif',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Gagal menambah data wali: $e");
      rethrow;
    }
  }

  // 3. Edit Data Wali Santri
  Future<void> editWaliSantri({
    required String id,
    required String namaWali,
    required String noHp,
    required String hubungan,
    required String username,
  }) async {
    try {
      await _db.collection('walisantri').doc(id).update({
        'namaWali': namaWali,
        'noHp': noHp,
        'hubungan': hubungan,
        'username': username,
      });
    } catch (e) {
      print("Gagal mengedit data: $e");
      rethrow;
    }
  }

  // 4. Reset Password Akun Wali di Firestore
  Future<void> resetPassword(String id, String passwordBaru) async {
    try {
      await _db.collection('walisantri').doc(id).update({
        'password': passwordBaru,
      });
    } catch (e) {
      print("Gagal mereset password: $e");
      rethrow;
    }
  }

  // 5. Aktifkan / Nonaktifkan Akun
  Future<void> toggleStatusAkun(String id, String statusBaru) async {
    try {
      await _db.collection('walisantri').doc(id).update({
        'status': statusBaru,
      });
    } catch (e) {
      print("Gagal mengubah status akun: $e");
      rethrow;
    }
  }

  // 6. Hapus Akun & Data Wali Santri
  Future<void> hapusWaliSantri(String id) async {
    try {
      await _db.collection('walisantri').doc(id).delete();
    } catch (e) {
      print("Gagal menghapus data: $e");
      rethrow;
    }
  }
}
