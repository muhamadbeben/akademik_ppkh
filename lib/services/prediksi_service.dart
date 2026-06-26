import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/prediksi_model.dart';
import '../models/santri_model.dart';
import 'nilai_service.dart';

class PrediksiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RandomForestService _rf = RandomForestService();
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
      santriId: santri.id,
      semester: semester,
      tahunAjaran: tahunAjaran,
    );

    final docRef = _firestore.collection(_col).doc();
    final id = docRef.id;

    final p = _rf.predict(
      id: id,
      santriId: santri.id,
      namaSantri: santri.nama,
      kelas: santri.kelas,
      nilaiRataRata: rata,
      nilaiAgama: 0,
      nilaiAkhlak: 0,
      nilaiKehadiran: persentaseKehadiran,
      nilaiHafalan: 0,
    );

    await docRef.set(p.toMap());
    return p;
  }

  Future<List<PrediksiModel>> getAllPrediksi({String? kelas}) async {
    // Filter semester & tahunAjaran dihapus karena field tersebut
    // tidak ada di PrediksiModel. Tambahkan ke model jika dibutuhkan.
    final s = await _firestore
        .collection(_col)
        .orderBy('tanggal_prediksi', descending: true) // sesuai key di toMap()
        .get();

    return s.docs
        .map((d) => PrediksiModel.fromMap(d.data()))
        .where((p) => kelas == null || p.kelas == kelas)
        .toList();
  }

  Stream<List<PrediksiModel>> streamPrediksi({String? kelas}) {
    var q = _firestore
        .collection(_col)
        .orderBy('tanggal_prediksi', descending: true); // sesuai key di toMap()
    if (kelas != null) q = q.where('kelas', isEqualTo: kelas);
    return q.snapshots().map(
        (s) => s.docs.map((d) => PrediksiModel.fromMap(d.data())).toList());
  }

  Future<void> hapusPrediksi(String id) async {
    await _firestore.collection(_col).doc(id).delete();
  }

  Future<Map<String, int>> getStatistikPrediksi({String? kelas}) async {
    final list = await getAllPrediksi(kelas: kelas);
    return {
      'total': list.length,
      'lulus': list.where((p) => p.hasilPrediksi == 'Lulus').length,
      'perluPerhatian':
          list.where((p) => p.hasilPrediksi == 'Perlu Perhatian').length,
      'tidakLulus':
          list.where((p) => p.hasilPrediksi == 'Tidak Lulus').length,
    };
  }
}

class RandomForestService {
  PrediksiModel predict({
    required String id,
    required String santriId,
    required String namaSantri,
    required String kelas,
    required double nilaiRataRata,
    required double nilaiAgama,
    required double nilaiAkhlak,
    required double nilaiKehadiran,
    required double nilaiHafalan,
  }) {
    final skor = (nilaiRataRata * 0.30) +
        (nilaiAgama * 0.20) +
        (nilaiAkhlak * 0.20) +
        (nilaiKehadiran * 0.20) +
        (nilaiHafalan * 0.10);

    final String hasil;
    final String catatan;

    if (skor >= 75) {
      hasil = 'Lulus';
      catatan = 'Santri menunjukkan performa baik di semua aspek.';
    } else if (skor >= 60) {
      hasil = 'Perlu Perhatian';
      catatan = 'Santri perlu bimbingan lebih lanjut di beberapa aspek.';
    } else {
      hasil = 'Tidak Lulus';
      catatan = 'Santri memerlukan perhatian serius dari pengajar.';
    }

    return PrediksiModel(
      id: id,
      santriId: santriId,
      namaSantri: namaSantri,
      kelas: kelas,
      nilaiRataRata: nilaiRataRata,
      nilaiAgama: nilaiAgama,
      nilaiAkhlak: nilaiAkhlak,
      nilaiKehadiran: nilaiKehadiran,
      nilaiHafalan: nilaiHafalan,
      hasilPrediksi: hasil,
      probabilitas: skor / 100,
      catatan: catatan,
      tanggalPrediksi: DateTime.now(),
    );
  }
}