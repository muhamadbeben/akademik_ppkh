// jadwal_pelajaran_service.dart

import '../models/jadwal_pelajaran_model.dart';
import 'firestore_service.dart';

class JadwalPelajaranService {
  static Future<Map<String, List<JadwalPelajaranModel>>> getJadwalGroupedByHari(String kelas) async {
    List<JadwalPelajaranModel> semua = await FirestoreService.getJadwalByKelas(kelas);
    Map<String, List<JadwalPelajaranModel>> grouped = {};

    for (String hari in daftarHari) {
      grouped[hari] = semua.where((j) => j.hari == hari).toList()
        ..sort((a, b) => a.jamMulai.compareTo(b.jamMulai));
    }

    return grouped;
  }

  static Future<List<String>> getDaftarKelas() async {
    return ['Kelas SP', 'Kelas 1', 'Kelas 2', 'Kelas 3', 'Kelas 4'];
  }

  static String getHariIni() {
    List<String> days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Ahad'];
    return days[DateTime.now().weekday - 1];
  }

  static Future<List<JadwalPelajaranModel>> getJadwalHariIni(String kelas) async {
    String hari = getHariIni();
    return FirestoreService.getJadwalByHari(kelas, hari);
  }
}
