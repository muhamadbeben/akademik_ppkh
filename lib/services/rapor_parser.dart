import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rapor_model.dart';
import '../models/santri_model.dart';
import '../utils/rapor_utils.dart';

class RaporDataParser {
  static RaporModel parseRaporDoc(Map<String, dynamic> d, String docId) {
    final List<NilaiModel> daftarNilai = [];

    if (d['daftarNilai'] is List) {
      for (final item in d['daftarNilai'] as List) {
        if (item is Map) {
          final n = _toDouble(item['nilaiHarian']);
          daftarNilai.add(NilaiModel(
            mataPelajaran: item['mataPelajaran']?.toString() ?? '',
            nilaiHarian: n,
            grade: item['grade']?.toString() ?? _gradeFromNilai(n),
          ));
        }
      }
    }

    if (daftarNilai.isEmpty) {
      if (d['uas'] is Map) {
        (d['uas'] as Map).forEach((mapel, val) {
          final n = _toDouble(val);
          if (n > 0) {
            daftarNilai.add(NilaiModel(
              mataPelajaran: mapel.toString(),
              nilaiHarian: n,
              grade: _gradeFromNilai(n),
            ));
          }
        });
      }

      if (d['hafalan_kitab'] is Map) {
        (d['hafalan_kitab'] as Map).forEach((mapel, val) {
          if (mapel.toString().toLowerCase().contains('lisan')) {
            final n = _toDouble(val);
            if (n > 0) {
              daftarNilai.add(NilaiModel(
                mataPelajaran: mapel.toString(),
                nilaiHarian: n,
                grade: _gradeFromNilai(n),
              ));
            }
          }
        });
      }
    }

    final nilaiAkhir = _toDouble(d['nilai_akhir']) > 0
        ? _toDouble(d['nilai_akhir'])
        : (_toDouble(d['nilaiRataRata']) > 0
            ? _toDouble(d['nilaiRataRata'])
            : _hitungRataBerbobot(d));
    final perilaku = _toDouble(d['nilaiSikap']) > 0
        ? _toDouble(d['nilaiSikap'])
        : _toDouble(d['nilai_perilaku']);
    final kehadiran = _toDouble(d['nilaiKehadiran']) > 0
        ? _toDouble(d['nilaiKehadiran'])
        : _toDouble(d['nilai_kehadiran']);

    final absen = d['ketidakhadiran'] is Map
        ? d['ketidakhadiran'] as Map<dynamic, dynamic>
        : <dynamic, dynamic>{};

    return RaporModel(
      id: docId,
      santriId: d['santriId']?.toString() ?? '',
      namaSantri: d['namaSantri']?.toString() ?? '',
      nis: d['nis']?.toString() ?? '-',
      kelas: d['kelas']?.toString() ?? '',
      tahunAjaran: d['tahunAjaran']?.toString() ?? '',
      halaqah: d['halaqah']?.toString() ?? '-',
      pengajar: d['pengajar']?.toString() ?? '-',
      catatanAdab: d['catatanAdab']?.toString() ?? '',
      absenSakit: _toInt(absen['Sakit']),
      absenIzin: _toInt(absen['Izin']),
      absenAlpha: _toInt(absen['Tanpa Keterangan']),
      nilaiRataRata: nilaiAkhir,
      predikat: d['predikat']?.toString() ?? RaporUtils.getPredikat(nilaiAkhir),
      catatanWaliKelas: d['catatanWaliKelas']?.toString() ?? '',
      tanggalCetak: d['tanggalCetak'] is Timestamp
          ? (d['tanggalCetak'] as Timestamp).toDate()
          : DateTime.now(),
      daftarNilai: daftarNilai,
      nilaiSikap: perilaku,
      predikatSikap:
          d['predikatSikap']?.toString() ?? _gradeFromNilai(perilaku),
      nilaiKehadiran: kehadiran,
      predikatKehadiran:
          d['predikatKehadiran']?.toString() ?? _gradeFromNilai(kehadiran),
    );
  }

  static RaporModel? buildRaporFromNilaiData(
    SantriModel santri,
    String kelas,
    String tahun,
    Map<String, dynamic> d,
  ) {
    final kelasNorm = kelas.replaceAll(' ', '');
    final List<NilaiModel> daftarNilai = [];

    void tambah(String prefix, dynamic m) {
      if (m is! Map) return;
      m.forEach((k, v) {
        final n = _toDouble(v);
        if (n > 0) {
          daftarNilai.add(NilaiModel(
            mataPelajaran: prefix.isEmpty ? k.toString() : '$prefix: $k',
            nilaiHarian: n,
            grade: _gradeFromNilai(n),
          ));
        }
      });
    }

    tambah('', d['uas']);

    if (d['hafalan_kitab'] is Map) {
      (d['hafalan_kitab'] as Map).forEach((k, v) {
        if (k.toString().toLowerCase().contains('lisan')) {
          final n = _toDouble(v);
          if (n > 0) {
            daftarNilai.add(NilaiModel(
              mataPelajaran: k.toString(),
              nilaiHarian: n,
              grade: _gradeFromNilai(n),
            ));
          }
        }
      });
    }

    if (daftarNilai.isEmpty) return null;

    final nilaiAkhir = _toDouble(d['nilai_akhir']) > 0
        ? _toDouble(d['nilai_akhir'])
        : _hitungRataBerbobot(d);
    final absen = d['ketidakhadiran'] is Map ? d['ketidakhadiran'] as Map : {};
    final perilaku = _toDouble(d['nilai_perilaku']);
    final kehadiran = _toDouble(d['nilai_kehadiran']);

    return RaporModel(
      id: 'GEN_${santri.id}_$kelasNorm',
      santriId: santri.id,
      namaSantri: santri.nama,
      nis: santri.nis ?? '-',
      kelas: kelas,
      tahunAjaran: tahun,
      nilaiRataRata: nilaiAkhir,
      predikat: RaporUtils.getPredikat(nilaiAkhir),
      catatanWaliKelas: '',
      tanggalCetak: DateTime.now(),
      daftarNilai: daftarNilai,
      absenSakit: _toInt(absen['Sakit']),
      absenIzin: _toInt(absen['Izin']),
      absenAlpha: _toInt(absen['Tanpa Keterangan']),
      catatanAdab: perilaku > 0 ? 'Tercatat' : 'Baik',
      nilaiSikap: perilaku,
      predikatSikap: _gradeFromNilai(perilaku),
      nilaiKehadiran: kehadiran,
      predikatKehadiran: _gradeFromNilai(kehadiran),
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _hitungRataBerbobot(Map<String, dynamic> d) {
    double kh = _toDouble(d['nilai_kehadiran']);
    double pr = _toDouble(d['nilai_perilaku']);
    double uts = _avgMap(d['uts']);
    double uas = _avgMap(d['uas']);
    double haf = _avgMap(d['hafalan_kitab']);
    return (kh * 0.05) +
        (pr * 0.05) +
        (uts * 0.20) +
        (uas * 0.40) +
        (haf * 0.30);
  }

  static double _avgMap(dynamic m) {
    if (m is! Map) return 0;
    double s = 0;
    int c = 0;
    m.forEach((_, v) {
      s += _toDouble(v);
      c++;
    });
    return c > 0 ? s / c : 0;
  }

  static String _gradeFromNilai(double n) {
    if (n >= 90) return 'A';
    if (n >= 80) return 'B';
    if (n >= 70) return 'C';
    if (n >= 60) return 'D';
    return 'E';
  }
}
