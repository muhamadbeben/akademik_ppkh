// File: lib/services/decision_tree_service.dart

import 'dart:math';

class DecisionTreeService {
  
  /// Prediksi menggunakan prinsip Random Forest (Ensemble Voting)
  static PrediksiResult prediksiKelulusan({
    required double nilaiRataRata,
    required double nilaiAgama,
    required double nilaiAkhlak,
    required double persentaseKehadiran,
    required double nilaiHafalan,
    required int jumlahPelanggaranDisiplin,
  }) {
    // Kita buat 5 pohon keputusan (Forest) dengan bobot/ambang batas sedikit berbeda
    // agar mensimulasikan keberagaman (diversity) dalam Random Forest
    List<String> votes = [];
    
    votes.add(_pohonKeputusan(nilaiRataRata, nilaiAgama, nilaiAkhlak, persentaseKehadiran, nilaiHafalan, jumlahPelanggaranDisiplin, 0));
    votes.add(_pohonKeputusan(nilaiRataRata, nilaiAgama, nilaiAkhlak, persentaseKehadiran, nilaiHafalan, jumlahPelanggaranDisiplin, 1));
    votes.add(_pohonKeputusan(nilaiRataRata, nilaiAgama, nilaiAkhlak, persentaseKehadiran, nilaiHafalan, jumlahPelanggaranDisiplin, 2));
    votes.add(_pohonKeputusan(nilaiRataRata, nilaiAgama, nilaiAkhlak, persentaseKehadiran, nilaiHafalan, jumlahPelanggaranDisiplin, 3));
    votes.add(_pohonKeputusan(nilaiRataRata, nilaiAgama, nilaiAkhlak, persentaseKehadiran, nilaiHafalan, jumlahPelanggaranDisiplin, 4));

    // Hitung hasil voting terbanyak
    Map<String, int> counts = {};
    for (var v in votes) counts[v] = (counts[v] ?? 0) + 1;
    
    String hasilAkhir = counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    double probabilitas = (counts[hasilAkhir]! / votes.length);

    // Memberikan rekomendasi berdasarkan hasil voting
    String rekomendasi = _generateRekomendasi(hasilAkhir, nilaiRataRata);

    return PrediksiResult(
      hasil: hasilAkhir,
      probabilitas: probabilitas,
      alasan: 'Analisis berbasis $votes pohon keputusan (Random Forest).',
      rekomendasi: rekomendasi,
      fiturPenting: ['Nilai Rata: $nilaiRataRata', 'Kehadiran: $persentaseKehadiran%'],
    );
  }

  /// Simulasi pohon keputusan yang sedikit berbeda tiap iterasinya (Randomness)
  static String _pohonKeputusan(double nr, double na, double nk, double kh, double hf, int dp, int seed) {
    // Variasi ambang batas untuk simulasi Random Forest
    double bias = seed * 2.0; 
    
    if (kh < (70.0 - bias)) return 'Tidak Lulus';
    if (nr >= (75.0 - bias) && hf >= (70.0 - bias)) return 'Lulus';
    if (nr >= 60.0 && nk >= 60.0) return 'Perlu Perhatian';
    return 'Tidak Lulus';
  }

  static String _generateRekomendasi(String hasil, double nilai) {
    if (hasil == 'Lulus') return "Pertahankan performa akademik dan kedisiplinan.";
    if (hasil == 'Perlu Perhatian') return "Perlu bimbingan tambahan pada mata pelajaran utama.";
    return "Diperlukan tindakan remedial segera oleh wali santri.";
  }
}

class PrediksiResult {
  final String hasil;
  final double probabilitas;
  final String alasan;
  final String rekomendasi;
  final List<String> fiturPenting;

  PrediksiResult({
    required this.hasil,
    required this.probabilitas,
    required this.alasan,
    required this.rekomendasi,
    required this.fiturPenting,
  });
}