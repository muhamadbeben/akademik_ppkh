import '../models/santri_model.dart';
import 'firestore_service.dart';

class SantriService {
  // --- READ (Real-time Stream) ---
  Stream<List<SantriModel>> streamSantri({String? kelas, String? status}) async* {
    try {
      final list = await FirestoreService.getSantriList();
      yield list.where((s) {
        final cocokKelas = kelas == null || kelas.isEmpty || s.kelas == kelas;
        final cocokStatus = status == null || status.isEmpty || s.status == status;
        return cocokKelas && cocokStatus;
      }).toList();
    } catch (e) {
      yield [];
      throw Exception('Gagal memproses stream data santri: $e');
    }
  }

  // --- READ (Once) ---
  Future<List<SantriModel>> getSantri({String? kelas}) async {
    try {
      final list = await FirestoreService.getSantriList();
      if (kelas == null || kelas.isEmpty) return list;
      return list.where((s) => s.kelas == kelas).toList();
    } catch (e) {
      throw Exception('Gagal mengambil daftar santri: $e');
    }
  }

  // --- READ (Single) ---
  Future<SantriModel?> getSantriById(String id) async {
    try {
      return await FirestoreService.getSantriById(id);
    } catch (e) {
      throw Exception('Gagal mengambil data santri berdasarkan ID: $e');
    }
  }

  // --- CREATE ---
  Future<void> tambahSantri(SantriModel santri) async {
    try {
      final berhasil = await FirestoreService.tambahSantri(santri);
      if (!berhasil) throw Exception('Gagal menyimpan data ke Firebase');
    } catch (e) {
      throw Exception('Gagal menambah santri: $e');
    }
  }

  // --- UPDATE ---
  Future<void> updateSantri(SantriModel santri) async {
    try {
      final berhasil = await FirestoreService.updateSantri(santri);
      if (!berhasil) throw Exception('Data tidak ditemukan di database atau gagal diperbarui');
    } catch (e) {
      throw Exception('Gagal memperbarui santri: $e');
    }
  }

  // --- DELETE ---
  Future<void> hapusSantri(String id) async {
    try {
      await FirestoreService.hapusSantri(id);
    } catch (e) {
      throw Exception('Gagal menghapus santri: $e');
    }
  }

  // --- AGGREGATION ---
  Future<int> totalSantri({String status = 'Aktif'}) async {
    try {
      if (status == 'Aktif') {
        return await FirestoreService.getTotalSantriAktif();
      } else {
        final list = await FirestoreService.getSantriList();
        return list.where((s) => s.status == status).length;
      }
    } catch (e) {
      throw Exception('Gagal menghitung agregasi total santri: $e');
    }
  }

  // --- UTILITY ---
  Future<List<String>> getKelasList() async {
    try {
      final list = await FirestoreService.getSantriList();
      final kelasSet = list.map((s) => s.kelas).toSet().toList();
      kelasSet.sort();
      return kelasSet;
    } catch (e) {
      return [];
    }
  }
}