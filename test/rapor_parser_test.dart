import 'package:flutter_test/flutter_test.dart';
import 'package:akademik_ppkh/services/rapor_parser.dart';

void main() {
  test(
      'parseRaporDoc builds academic and lisan values from uas and hafalan_kitab',
      () {
    final data = <String, dynamic>{
      'santriId': 'S1',
      'namaSantri': 'Ali',
      'nis': '001',
      'kelas': 'Kelas 1',
      'tahunAjaran': '2025/2026',
      'nilai_akhir': 85.0,
      'catatanAdab': 'Baik',
      'ketidakhadiran': {
        'Sakit': 1,
        'Izin': 2,
        'Tanpa Keterangan': 0,
      },
      'nilai_perilaku': 90.0,
      'nilai_kehadiran': 85.0,
      'uas': {
        'Matematika': 80,
        'IPA': 90,
      },
      'hafalan_kitab': {
        'Surah Al-Fatihah Lisan': 95,
        'Doa Harian': 60,
      },
    };

    final rapor = RaporDataParser.parseRaporDoc(data, 'doc-123');

    expect(
      rapor.daftarNilai.map((n) => n.mataPelajaran).toList(),
      containsAll(['Matematika', 'IPA', 'Surah Al-Fatihah Lisan']),
    );
    expect(
      rapor.daftarNilai
          .where((n) => n.mataPelajaran == 'Surah Al-Fatihah Lisan')
          .first
          .nilaiHarian,
      95,
    );
    expect(rapor.absenSakit, 1);
    expect(rapor.absenIzin, 2);
    expect(rapor.absenAlpha, 0);
  });

  test('parseRaporDoc safely converts string numeric values to doubles', () {
    final data = <String, dynamic>{
      'santriId': 'S2',
      'namaSantri': 'Budi',
      'nis': '002',
      'kelas': 'Kelas 2',
      'tahunAjaran': '2025/2026',
      'nilai_akhir': '88',
      'nilaiRataRata': '88',
      'nilai_perilaku': '85',
      'nilai_kehadiran': '90',
      'ketidakhadiran': {
        'Sakit': '1',
        'Izin': '2',
        'Tanpa Keterangan': '0',
      },
      'uas': {
        'Bahasa Arab': '82',
      },
      'hafalan_kitab': {
        'Surah Al-Fatihah Lisan': '95',
      },
      'daftarNilai': [
        {'mataPelajaran': 'Akidah', 'nilaiHarian': '78', 'grade': 'C'},
      ],
    };

    final rapor = RaporDataParser.parseRaporDoc(data, 'doc-456');

    expect(rapor.nilaiRataRata, 88.0);
    expect(rapor.nilaiSikap, 85.0);
    expect(rapor.nilaiKehadiran, 90.0);
    expect(rapor.absenSakit, 1);
    expect(rapor.daftarNilai.first.nilaiHarian, 78.0);
  });
}
