import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rapor_model.dart';
import '../models/santri_model.dart';
import 'firestore_service.dart';
import 'nilai_service.dart';

class RaporService {
  final FirestoreService _fs = FirestoreService();
  final NilaiService _nilaiService = NilaiService();
  static const String _col = 'rapor';

  Future<RaporModel> generateRapor({
    required SantriModel santri,
    required String semester,
    required String tahunAjaran,
    required int peringkat,
    String catatanWaliKelas = '',
  }) async {
    final nilaiList = await _nilaiService.getNilaiBySantri(
        santriId: santri.id, semester: semester, tahunAjaran: tahunAjaran);
    final id = _fs.generateId(_col);
    final rapor = RaporModel(
      id: id, santriId: santri.id, namaSantri: santri.nama, nis: santri.nis,
      kelas: santri.kelas, semester: semester, tahunAjaran: tahunAjaran,
      daftarNilai: nilaiList, peringkat: peringkat, catatanWaliKelas: catatanWaliKelas,
    );
    await _fs.setDocument(_col, id, rapor.toMap());
    return rapor;
  }

  Future<List<RaporModel>> getRaporSantri(String santriId) async {
    final s = await _fs.collection(_col)
        .where('santriId', isEqualTo: santriId)
        .orderBy('tanggalCetak', descending: true)
        .get();
    return s.docs.map((d) => RaporModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  Stream<List<RaporModel>> streamRapor(String santriId) {
    return _fs.collection(_col).where('santriId', isEqualTo: santriId).snapshots()
        .map((s) => s.docs.map((d) => RaporModel.fromMap(d.data() as Map<String, dynamic>)).toList());
  }

  Future<void> hapusRapor(String id) async => _fs.deleteDocument(_col, id);
  Future<void> updateCatatan(String id, String catatan) async =>
      _fs.updateDocument(_col, id, {'catatanWaliKelas': catatan});
}
