import '../models/prediksi_model.dart';

class DecisionTreeService {

  String _calcResult(double rata, double hadir, int langgar) {
    int score = 0;
    if (rata >= 75) score += 3;
    else if (rata >= 70) score += 2;
    else if (rata >= 60) score += 1;
    if (hadir >= 85) score += 3;
    else if (hadir >= 75) score += 2;
    else if (hadir >= 65) score += 1;
    if (langgar == 0) score += 2;
    else if (langgar <= 3) score += 1;
    return score >= 6 ? 'Lulus' : 'Tidak Lulus';
  }

  double _confidence(String hasil, double rata, double hadir, int langgar) {
    double s;
    if (hasil == 'Lulus') {
      s = (rata / 100) * 0.5 + (hadir / 100) * 0.3 + ((10 - langgar.clamp(0, 10)) / 10) * 0.2;
    } else {
      s = ((100 - rata) / 100) * 0.5 + ((100 - hadir) / 100) * 0.3 + (langgar.clamp(0, 10) / 10) * 0.2;
    }
    return (s * 100).clamp(50, 99);
  }

  List<String> _faktor(double rata, double hadir, int langgar) {
    final f = <String>[];
    if (rata >= 75) f.add('Nilai akademik baik (' + rata.toStringAsFixed(1) + ')');
    if (hadir >= 80) f.add('Kehadiran tinggi (' + hadir.toStringAsFixed(0) + '%)');
    if (langgar == 0) f.add('Tidak ada catatan pelanggaran');
    else if (langgar <= 2) f.add('Pelanggaran sangat minim (' + langgar.toString() + ' kali)');
    if (f.isEmpty) f.add('Memerlukan evaluasi lebih lanjut');
    return f;
  }

  List<String> _rekomendasi(double rata, double hadir, int langgar) {
    final r = <String>[];
    if (rata < 70) {
      r.add('Tingkatkan nilai akademik dengan belajar lebih giat');
      r.add('Ikuti program bimbingan belajar tambahan');
    }
    if (hadir < 80) {
      r.add('Perbaiki tingkat kehadiran minimal 80%');
      r.add('Koordinasi dengan wali santri terkait kehadiran');
    }
    if (langgar > 3) {
      r.add('Kurangi pelanggaran peraturan pesantren');
      r.add('Lakukan konseling dengan pembimbing');
    }
    if (r.isEmpty) {
      r.add('Pertahankan prestasi yang sudah baik');
      r.add('Terus tingkatkan kualitas belajar');
    }
    return r;
  }

  PrediksiModel predict({
    required String id,
    required String santriId,
    required String namaSantri,
    required String kelas,
    required double rataRataNilai,
    required double persentaseKehadiran,
    required int jumlahMelanggar,
    required String semester,
    required String tahunAjaran,
  }) {
    final hasil = _calcResult(rataRataNilai, persentaseKehadiran, jumlahMelanggar);
    return PrediksiModel(
      id: id,
      santriId: santriId,
      namaSantri: namaSantri,
      kelas: kelas,
      rataRataNilai: rataRataNilai,
      persentaseKehadiran: persentaseKehadiran,
      jumlahMelanggar: jumlahMelanggar,
      hasilPrediksi: hasil,
      confidence: _confidence(hasil, rataRataNilai, persentaseKehadiran, jumlahMelanggar),
      faktorPendukung: _faktor(rataRataNilai, persentaseKehadiran, jumlahMelanggar),
      rekomendasiPerbaikan: _rekomendasi(rataRataNilai, persentaseKehadiran, jumlahMelanggar),
      semester: semester,
      tahunAjaran: tahunAjaran,
    );
  }
}
