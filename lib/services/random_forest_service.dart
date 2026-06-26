// File: lib/services/random_forest_service.dart

import 'dart:math';

class RandomForestService {
  // Jumlah pohon keputusan dalam hutan (n_estimators)
  static const int N_ESTIMATORS = 50;

  /// Prediksi menggunakan Random Forest dengan teknik Bagging (Voting)
  static Map<String, dynamic> predict({
    required double nilaiRataRata,
    required double nilaiAgama,
    required double nilaiAkhlak,
    required double persentaseKehadiran,
    required double nilaiHafalan,
  }) {
    int voteLulus = 0;
    int votePerhatian = 0;
    int voteTidakLulus = 0;

    // Menjalankan Voting dari N pohon keputusan (Ensemble)
    for (int i = 0; i < N_ESTIMATORS; i++) {
      String hasilPohon = _getDecisionTreePrediction(
        nilaiRataRata: nilaiRataRata,
        nilaiAgama: nilaiAgama,
        nilaiAkhlak: nilaiAkhlak,
        persentaseKehadiran: persentaseKehadiran,
        nilaiHafalan: nilaiHafalan,
        seed: i, // Randomness unik untuk tiap pohon
      );

      if (hasilPohon == 'Lulus') voteLulus++;
      else if (hasilPohon == 'Perlu Perhatian') votePerhatian++;
      else voteTidakLulus++;
    }

    // Menentukan pemenang berdasarkan suara terbanyak (Majority Voting)
    int maxVote = max(voteLulus, max(votePerhatian, voteTidakLulus));
    double prob = maxVote / N_ESTIMATORS;

    String hasilAkhir = '';
    String rekomendasi = '';

    if (maxVote == voteLulus) {
      hasilAkhir = 'Lulus';
      rekomendasi = "Santri sangat kompeten. Pertahankan prestasi dan kedisiplinan.";
    } else if (maxVote == votePerhatian) {
      hasilAkhir = 'Perlu Perhatian';
      rekomendasi = "Perlu bimbingan intensif pada aspek akademik dan hafalan.";
    } else {
      hasilAkhir = 'Tidak Lulus';
      rekomendasi = "Diperlukan tindakan remedial segera oleh wali santri.";
    }

    return {
      'hasil': hasilAkhir,
      'probabilitas': prob,
      'rekomendasi': rekomendasi,
    };
  }

  /// Satu pohon keputusan dengan variasi acak (Stochastic)
  static String _getDecisionTreePrediction({
    required double nilaiRataRata,
    required double nilaiAgama,
    required double nilaiAkhlak,
    required double persentaseKehadiran,
    required double nilaiHafalan,
    required int seed,
  }) {
    // Menambahkan sedikit noise (randomness) pada ambang batas untuk simulasi Random Forest
    Random rnd = Random(seed);
    double noise = (rnd.nextDouble() * 5) - 2.5; // Rentang -2.5 sampai +2.5

    if (persentaseKehadiran < (75.0 + noise)) return 'Tidak Lulus';
    if (nilaiRataRata >= (78.0 + noise) && nilaiHafalan >= (75.0 + noise)) return 'Lulus';
    if (nilaiAkhlak >= (70.0 + noise)) return 'Perlu Perhatian';
    
    return 'Tidak Lulus';
  }
}