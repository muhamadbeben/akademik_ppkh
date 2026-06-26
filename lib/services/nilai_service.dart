// File: lib/services/nilai_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/nilai_model.dart';

class NilaiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _col = 'nilai';

  /// Stream data nilai berdasarkan santri, semester, dan tahun ajaran
  Stream<List<NilaiModel>> streamNilai({
    required String santriId,
    String? semester,
    String? tahunAjaran,
  }) {
    Query q =
        _firestore.collection(_col).where('santriId', isEqualTo: santriId);

    if (semester != null && semester.isNotEmpty) {
      q = q.where('semester', isEqualTo: semester);
    }
    if (tahunAjaran != null && tahunAjaran.isNotEmpty) {
      q = q.where('tahunAjaran', isEqualTo: tahunAjaran);
    }

    return q.snapshots().map((snapshot) => snapshot.docs.map((doc) {
          return NilaiModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList());
  }

  /// Mengambil data nilai (Future) berdasarkan santri, semester, dan tahun ajaran
  Future<List<NilaiModel>> getNilaiBySantri({
    required String santriId,
    String? semester,
    String? tahunAjaran,
  }) async {
    Query q =
        _firestore.collection(_col).where('santriId', isEqualTo: santriId);

    if (semester != null && semester.isNotEmpty) {
      q = q.where('semester', isEqualTo: semester);
    }
    if (tahunAjaran != null && tahunAjaran.isNotEmpty) {
      q = q.where('tahunAjaran', isEqualTo: tahunAjaran);
    }

    final snapshot = await q.get();
    return snapshot.docs.map((doc) {
      return NilaiModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }

  /// Menambah atau memperbarui data nilai secara keseluruhan
  Future<void> tambahNilai(NilaiModel nilai) async {
    // Jika ID kosong, biarkan Firestore men-generate ID dokumen baru secara otomatis
    final docRef = (nilai.id.isEmpty || nilai.id == 'auto_generated_id')
        ? _firestore.collection(_col).doc()
        : _firestore.collection(_col).doc(nilai.id);

    // Sinkronisasikan ID dokumen baru ke dalam field data 'id' sebelum diupload
    final dataToSend = nilai.toMap();
    dataToSend['id'] = docRef.id;

    await docRef.set(dataToSend, SetOptions(merge: true));
  }

  /// Memperbarui data nilai yang sudah ada
  Future<void> updateNilai(NilaiModel nilai) async {
    if (nilai.id.isEmpty) return;
    await _firestore
        .collection(_col)
        .doc(nilai.id)
        .set(nilai.toMap(), SetOptions(merge: true));
  }

  /// Menghapus data nilai berdasarkan ID dokumen
  Future<void> hapusNilai(String id) async {
    await _firestore.collection(_col).doc(id).delete();
  }

  /// Menghitung rata-rata nilai dari seluruh mata pelajaran yang dimiliki santri
  Future<double> getRataRataSantri({
    required String santriId,
    String? semester,
    String? tahunAjaran,
  }) async {
    // Mengambil list dokumen nilai sesuai filter
    final list = await getNilaiBySantri(
        santriId: santriId, semester: semester, tahunAjaran: tahunAjaran);
    if (list.isEmpty) return 0.0;

    double totalNilai = 0.0;

    // Menjumlahkan nilaiAkhir dari setiap dokumen nilai (mata pelajaran)
    for (var nilaiModel in list) {
      totalNilai += nilaiModel.nilaiAkhir;
    }

    // Pembagian total nilai dengan jumlah total dokumen (mata pelajaran)
    return totalNilai / list.length;
  }
}
