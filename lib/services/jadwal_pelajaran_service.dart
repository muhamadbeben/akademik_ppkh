import '../models/jadwal_pelajaran_model.dart';
import 'firestore_service.dart';

class JadwalPelajaranService {
  final FirestoreService _fs = FirestoreService();
  static const String _col = 'jadwal_pelajaran';
  static const List<String> hariList = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];

  Stream<List<JadwalPelajaranModel>> streamJadwal(String kelas) {
    return _fs.collection(_col).where('kelas', isEqualTo: kelas).snapshots().map((s) =>
        s.docs.map((d) => JadwalPelajaranModel.fromMap(d.data() as Map<String, dynamic>)).toList());
  }

  Future<List<JadwalPelajaranModel>> getJadwalByKelas(String kelas) async {
    final s = await _fs.collection(_col).where('kelas', isEqualTo: kelas).get();
    return s.docs.map((d) => JadwalPelajaranModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  Future<void> tambahJadwal(JadwalPelajaranModel j) async {
    final id = _fs.generateId(_col);
    await _fs.setDocument(_col, id, j.copyWith(id: id).toMap());
  }

  Future<void> updateJadwal(JadwalPelajaranModel j) async => _fs.setDocument(_col, j.id, j.toMap());
  Future<void> hapusJadwal(String id) async => _fs.deleteDocument(_col, id);
}
