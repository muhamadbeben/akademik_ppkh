import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/santri_model.dart';
import 'firestore_service.dart';

class SantriService {
  final FirestoreService _fs = FirestoreService();
  static const String _col = 'santri';

  Stream<List<SantriModel>> streamSantri({String? kelas, String? status}) {
    Query q = _fs.collection(_col).orderBy('nama');
    if (kelas != null) q = q.where('kelas', isEqualTo: kelas);
    if (status != null) q = q.where('status', isEqualTo: status);
    return q.snapshots().map((s) =>
        s.docs.map((d) => SantriModel.fromMap(d.data() as Map<String, dynamic>)).toList());
  }

  Future<List<SantriModel>> getSantri({String? kelas}) async {
    final s = await _fs.getCollection(_col, orderBy: 'nama',
        where: kelas != null ? {'kelas': kelas} : null);
    return s.docs.map((d) => SantriModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  Future<SantriModel?> getSantriById(String id) async {
    final d = await _fs.getDocument(_col, id);
    return d.exists ? SantriModel.fromMap(d.data() as Map<String, dynamic>) : null;
  }

  Future<void> tambahSantri(SantriModel s) async {
    final id = _fs.generateId(_col);
    await _fs.setDocument(_col, id, s.copyWith(id: id).toMap());
  }

  Future<void> updateSantri(SantriModel s) async => _fs.setDocument(_col, s.id, s.toMap());
  Future<void> hapusSantri(String id) async => _fs.deleteDocument(_col, id);

  Future<int> totalSantri({String status = 'aktif'}) async {
    final s = await _fs.collection(_col).where('status', isEqualTo: status).count().get();
    return s.count ?? 0;
  }

  Future<List<String>> getKelasList() async {
    final list = await getSantri();
    final kelasSet = list.map((s) => s.kelas).toSet().toList();
    kelasSet.sort();
    return kelasSet;
  }
}
