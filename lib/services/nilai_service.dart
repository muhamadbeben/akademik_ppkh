import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/nilai_model.dart';
import 'firestore_service.dart';

class NilaiService {
  final FirestoreService _fs = FirestoreService();
  static const String _col = 'nilai';

  Stream<List<NilaiModel>> streamNilai({required String santriId, String? semester, String? tahunAjaran}) {
    Query q = _fs.collection(_col).where('santriId', isEqualTo: santriId);
    if (semester != null) q = q.where('semester', isEqualTo: semester);
    if (tahunAjaran != null) q = q.where('tahunAjaran', isEqualTo: tahunAjaran);
    return q.snapshots().map((s) =>
        s.docs.map((d) => NilaiModel.fromMap(d.data() as Map<String, dynamic>)).toList());
  }

  Future<List<NilaiModel>> getNilaiBySantri({required String santriId, String? semester, String? tahunAjaran}) async {
    Query q = _fs.collection(_col).where('santriId', isEqualTo: santriId);
    if (semester != null) q = q.where('semester', isEqualTo: semester);
    if (tahunAjaran != null) q = q.where('tahunAjaran', isEqualTo: tahunAjaran);
    final s = await q.get();
    return s.docs.map((d) => NilaiModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  Future<void> tambahNilai(NilaiModel n) async {
    final id = _fs.generateId(_col);
    final m = n.toMap();
    m['id'] = id;
    await _fs.setDocument(_col, id, m);
  }

  Future<void> updateNilai(NilaiModel n) async => _fs.setDocument(_col, n.id, n.toMap());
  Future<void> hapusNilai(String id) async => _fs.deleteDocument(_col, id);

  Future<double> getRataRataSantri({required String santriId, String? semester, String? tahunAjaran}) async {
    final list = await getNilaiBySantri(santriId: santriId, semester: semester, tahunAjaran: tahunAjaran);
    if (list.isEmpty) return 0;
    return list.map((n) => n.nilaiAkhir).reduce((a, b) => a + b) / list.length;
  }
}
