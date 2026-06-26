// File: lib/services/laporan_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/santri_model.dart';

class LaporanFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Menyimpan riwayat aktivitas cetak laporan langsung ke Firebase Firestore
  Future<void> simpanLogAktivitasLaporan({
    required String jenisLaporan,
    required String formatFile,
    required String tahunAjaran,
    required String kelas,
    required String filterSantri,
    required List<SantriModel> daftarSantriTercakup,
  }) async {
    try {
      final String logId = 'REP_${DateTime.now().millisecondsSinceEpoch}';
      
      await _firestore.collection('rekap_laporan').doc(logId).set({
        'id': logId,
        'jenisLaporan': jenisLaporan,
        'formatFile': formatFile,
        'tahunAjaran': tahunAjaran,
        'kelas': kelas, // Sinkronisasi menggunakan field kelas sebagai identitas utama
        'filterSantri': filterSantri,
        'jumlahSantriTercakup': daftarSantriTercakup.length,
        'tanggalDibuat': FieldValue.serverTimestamp(),
        'daftarSantriMencakup': daftarSantriTercakup.map((s) => {
          'id': s.id,
          'nama': s.nama,
          'nis': s.nis,
          'kelas': s.kelas,
        }).toList(),
      }, SetOptions(merge: true));

      debugPrint("Berhasil menyimpan log aktivitas laporan ke database.");
    } catch (e) {
      debugPrint("Gagal menyimpan log laporan ke Firebase: $e");
      throw Exception("Gagal sinkronisasi log ke Firebase: $e");
    }
  }
}