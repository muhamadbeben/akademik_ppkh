import '../models/prediksi_model.dart';
import '../models/santri_model.dart';
import 'firestore_service.dart';
import 'decision_tree_service.dart';
import 'nilai_service.dart';

class PrediksiService {
  final FirestoreService _fs = FirestoreService();
  final DecisionTreeService _dt = DecisionTreeService();
  final NilaiService _nilaiService = NilaiService();
  static const String _col = 'prediksi';

  Future<PrediksiModel> prediksikanSantri({
    required SantriModel santri,
    required String semester,
    required String tahunAjaran,
    required double persentaseKehadiran,
    required int jumlahMelanggar,
  }) async {
    final rata = await _nilaiService.getRataRataSantri(
        santriId: santri.id, semester: semester, tahunAjaran: tahunAjaran);
    final id = _fs.generateId(_col);
    final p = _dt.predict(
      id: id, santriId: santri.id, namaSantri: santri.nama, kelas: santri.kelas,
      rataRataNilai: rata, persentaseKehadiran: persentaseKehadiran,
      jumlahMelanggar: jumlahMelanggar, semester: semester, tahunAjaran: tahunAjaran,
    );
    await _fs.setDocument(_col, id, p.toMap());
    return p;
  }

  Future<List<PrediksiModel>> getAllPrediksi({String? kelas, String? semester, String? tahunAjaran}) async {
    final s = await _fs.getCollection(_col, orderBy: 'tanggalPrediksi', descending: true);
    return s.docs
        .map((d) => PrediksiModel.fromMap(d.data() as Map<String, dynamic>))
        .where((p) =>
            (kelas == null || p.kelas == kelas) &&
            (semester == null || p.semester == semester) &&
            (tahunAjaran == null || p.tahunAjaran == tahunAjaran))
        .toList();
  }

  Stream<List<PrediksiModel>> streamPrediksi({String? kelas}) {
    var q = _fs.collection(_col).orderBy('tanggalPrediksi', descending: true);
    if (kelas != null) q = q.where('kelas', isEqualTo: kelas);
    return q.snapshots().map((s) =>
        s.docs.map((d) => PrediksiModel.fromMap(d.data() as Map<String, dynamic>)).toList());
  }

  Future<void> hapusPrediksi(String id) async => _fs.deleteDocument(_col, id);

  Future<Map<String, int>> getStatistikPrediksi({String? kelas, String? semester}) async {
    final list = await getAllPrediksi(kelas: kelas, semester: semester);
    return {
      'total': list.length,
      'lulus': list.where((p) => p.isLulus).length,
      'tidakLulus': list.where((p) => !p.isLulus).length,
    };
  }
}
