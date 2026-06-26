// File: lib/screens/nilai_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/santri_model.dart';
import '../services/firestore_service.dart';

class NilaiScreen extends StatefulWidget {
  const NilaiScreen({super.key});

  @override
  State<NilaiScreen> createState() => _NilaiScreenState();
}

class _NilaiScreenState extends State<NilaiScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  List<SantriModel> _allSantriList = [];
  List<SantriModel> _filteredSantriList = [];
  List<String> _mapelAktifList = [];
  
  Map<String, dynamic>? _savedDocumentData;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _kategoriNilaiList = [
    {'id': 'Absensi & Perilaku', 'label': 'Absensi & Sikap', 'icon': Icons.assignment_ind_outlined},
    {'id': 'Hafalan Kitab', 'label': 'Hafalan', 'icon': Icons.menu_book_rounded},
    {'id': 'UTS', 'label': 'UTS', 'icon': Icons.description_outlined},
    {'id': 'UAS', 'label': 'UAS', 'icon': Icons.article_outlined},
  ];
  String _selectedKategori = 'Absensi & Perilaku'; 

  final List<String> _kelasList = [
    'Kelas sp',
    'Kelas 1',
    'Kelas 2',
    'Kelas 3',
    'Kelas 4'
  ];
  String _selectedKelas = 'Kelas sp';
  String _selectedSantriId = '';
  String _selectedTahunAjaran = '2025/2026';
  String _selectedSemester = 'Kelas sp';

  final Map<String, Map<String, Map<String, TextEditingController>>> _controllers = {};

  final List<String> _opsiTahunAjaranList = [
    '2025/2026',
    '2024/2025',
    '2023/2024'
  ];

  final List<String> _listAlasanAbsensi = [
    'Sakit',
    'Izin',
    'Tanpa Keterangan',
  ];

  final Map<String, List<String>> _masterMapelPerSemester = {
    'Kelas sp': [
      'BTQ (Tulis)',
      'Tashrif Bina shahih (Lisan)',
      'Praktek Ibadah (Lisan)',
      'Aqoidul Iman (Lisan)',
      'Tahsin Al-Quran',
      'Hafalan Kitab: Aqoidul Iman',
    ],
    'Kelas 1': [
      'Awamil (Tulis)',
      'Tajwid (Tulis)',
      'Safinah (Tulis)',
      'Jurmiyah (Tulis)',
      'Tashrif Bina Shahih (Lisan)',
      'Tahsin Al-Qur’an',
      'Qira’atul Kutub (Safinah)',
      'Hafalan Kitab: Safinah & Awamil',
    ],
    'Kelas 2': [
      'Kaelani (Tulis)',
      'Nastainu (Tulis)',
      'Imrity (Tulis)',
      'Jurmiyah (Lisan)',
      'Qowaid Fiqhiyah (Lisan)',
      'Ngelal – Ngasal (Lisan)',
      'Tahsin Al-Qur’an',
      'Qira’atul Kutub (Riyadul Badiah)',
      'Hafalan Kitab: Nadhom Imrity',
    ],
    'Kelas 3': [
      'Samar Qondi (Tulis)',
      'Jauhar Maknun (Tulis)',
      'Qowaid Fiqhiyah (Lisan)',
      'Alfiyyah (Lisan)',
      'Tahsin Al-Quran',
      'Qiro’atul Kutub (Fathul Mu’in)',
      'Hafalan Kitab: Nadhom Alfiyyah (Bab 1)',
    ],
    'Kelas 4': [
      'Samar Qondi (Tulis)',
      'Jauhar Maknun (Tulis)',
      'Qowaid Fiqhiyah (Lisan)',
      'Alfiyyah (Lisan)',
      'Tahsin Al-Quran',
      'Qiro’atul Kutub (Fathul Mu’in)',
      'Hafalan Kitab: Nadhom Alfiyyah (Khatam)',
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDataAwal();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _controllers.forEach((_, kategoriMap) {
      kategoriMap.forEach((_, mapelMap) {
        mapelMap.forEach((_, ctrl) => ctrl.dispose());
      });
    });
    super.dispose();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        backgroundColor: color, 
        duration: const Duration(seconds: 4), 
        behavior: SnackBarBehavior.floating
      ),
    );
  }

  List<String> _getSafeMasterMapel(String targetSemester) {
    String clean = targetSemester.toLowerCase().trim();
    if (clean == 'kelas sp') {
      return _masterMapelPerSemester['Kelas sp'] ?? [];
    } else if (clean == 'kelas 1') {
      return _masterMapelPerSemester['Kelas 1'] ?? [];
    } else if (clean == 'kelas 2') {
      return _masterMapelPerSemester['Kelas 2'] ?? [];
    } else if (clean == 'kelas 3') {
      return _masterMapelPerSemester['Kelas 3'] ?? [];
    } else if (clean == 'kelas 4') {
      return _masterMapelPerSemester['Kelas 4'] ?? [];
    }
    return [];
  }

  void _sinkronisasiSemesterOtomatis(String kelas) {
    String clean = kelas.toLowerCase().trim();
    if (clean == 'kelas sp') {
      _selectedSemester = 'Kelas sp';
    } else if (clean == 'kelas 1') {
      _selectedSemester = 'Kelas 1';
    } else if (clean == 'kelas 2') {
      _selectedSemester = 'Kelas 2';
    } else if (clean == 'kelas 3') {
      _selectedSemester = 'Kelas 3';
    } else if (clean == 'kelas 4') {
      _selectedSemester = 'Kelas 4';
    } else {
      _selectedSemester = kelas;
    }
  }

  Future<void> _loadDataAwal() async {
    setState(() => _isLoading = true);
    try {
      _allSantriList = await FirestoreService.getSantriList();
      _allSantriList = _allSantriList
          .where((s) => s.status.toLowerCase().contains('aktif'))
          .toList();

      _sinkronisasiSemesterOtomatis(_selectedKelas);
      await _prosesFilterKelasDanMapel();
    } catch (e) {
      _showSnackBar('Gagal memanggil data Kelola Santri: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _getMapelTersaringSesuaiKategori() {
    List<String> masterMapel = _getSafeMasterMapel(_selectedSemester);

    if (_selectedKategori == 'UTS' || _selectedKategori == 'UAS') {
      return masterMapel;
    } else if (_selectedKategori == 'Hafalan Kitab') {
      return masterMapel.where((mapel) {
        final lower = mapel.toLowerCase();
        return lower.contains('(lisan)') || lower.contains('hafalan');
      }).toList();
    } else if (_selectedKategori == 'Absensi & Perilaku') {
      return ['Nilai Kehadiran', 'Nilai Perilaku', 'Sakit', 'Izin', 'Tanpa Keterangan'];
    } else {
      return ['Global'];
    }
  }

  Future<void> _prosesFilterKelasDanMapel() async {
    try {
      _filteredSantriList = _allSantriList.where((s) {
        String dbKelas = s.kelas.toLowerCase().replaceAll('kelas', 'kelas').trim();
        String dropdownKelas = _selectedKelas.toLowerCase().trim();
        return dbKelas == dropdownKelas || s.kelas == _selectedKelas;
      }).toList();

      _filteredSantriList.sort((a, b) => a.nama.compareTo(b.nama));

      if (_filteredSantriList.isNotEmpty) {
        bool masihAda = _filteredSantriList.any((s) => s.id == _selectedSantriId);
        if (!masihAda && _selectedSantriId.isEmpty) {
          _selectedSantriId = '';
        }
        if (_selectedSantriId.isNotEmpty) {
          await _loadNilaiDariDatabase();
        }
      } else {
        _selectedSantriId = '';
        _savedDocumentData = null;
        _mapelAktifList = _getMapelTersaringSesuaiKategori();
      }
    } catch (e) {
      debugPrint("Error sinkronisasi mapel kelas: $e");
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadNilaiDariDatabase() async {
    if (_selectedSantriId.isEmpty) {
      setState(() {});
      return;
    }

    _mapelAktifList = _getMapelTersaringSesuaiKategori();

    if (!_controllers.containsKey(_selectedSantriId)) {
      _controllers[_selectedSantriId] = {};
    }

    final List<String> klsKategoriAsli = ['Nilai Kehadiran', 'Nilai Perilaku', 'Ketidakhadiran', 'Hafalan Kitab', 'UTS', 'UAS'];

    for (var katId in klsKategoriAsli) {
      if (!_controllers[_selectedSantriId]!.containsKey(katId)) {
        _controllers[_selectedSantriId]![katId] = {};
      }
      
      List<String> scopeMapel;
      List<String> currentMasterMapel = _getSafeMasterMapel(_selectedSemester);

      if (katId == 'UTS' || katId == 'UAS') {
        scopeMapel = currentMasterMapel;
      } else if (katId == 'Hafalan Kitab') {
        scopeMapel = currentMasterMapel
            .where((m) => m.toLowerCase().contains('(lisan)') || m.toLowerCase().contains('hafalan'))
            .toList();
      } else if (katId == 'Ketidakhadiran') {
        scopeMapel = _listAlasanAbsensi;
      } else {
        scopeMapel = ['Global'];
      }

      for (var mapel in scopeMapel) {
        if (!_controllers[_selectedSantriId]![katId]!.containsKey(mapel)) {
          _controllers[_selectedSantriId]![katId]![mapel] = TextEditingController(text: '')
            ..addListener(() {
              setState(() {});
            });
        }
      }
    }

    _controllers[_selectedSantriId]!.forEach((_, mapelMap) {
      mapelMap.forEach((_, ctrl) => ctrl.clear());
    });

    try {
      String docId = "${_selectedSantriId}_${_selectedTahunAjaran.replaceAll('/', '-')}_${_selectedSemester.replaceAll(' ', '')}";
      
      final docSnapshot = await FirebaseFirestore.instance
          .collection('nilai')
          .doc(docId)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        _savedDocumentData = docSnapshot.data();
        Map<String, dynamic> data = _savedDocumentData!;

        if (data.containsKey('nilai_kehadiran')) {
          _controllers[_selectedSantriId]!['Nilai Kehadiran']!['Global']!.text = 
              data['nilai_kehadiran'] == 0 ? '' : data['nilai_kehadiran'].toStringAsFixed(0);
        }
        if (data.containsKey('nilai_perilaku')) {
          _controllers[_selectedSantriId]!['Nilai Perilaku']!['Global']!.text = 
              data['nilai_perilaku'] == 0 ? '' : data['nilai_perilaku'].toStringAsFixed(0);
        }

        if (data.containsKey('ketidakhadiran') && data['ketidakhadiran'] is Map) {
          Map absenMap = data['ketidakhadiran'];
          absenMap.forEach((key, value) {
            if (_controllers[_selectedSantriId]!['Ketidakhadiran']!.containsKey(key)) {
              // Jika absensi bernilai 0 di database, maka tampilkan "-" pada textfield form
              _controllers[_selectedSantriId]!['Ketidakhadiran']![key]!.text = 
                  value == 0 ? '-' : value.toString();
            }
          });
        }

        if (data.containsKey('uts') && data['uts'] is Map) {
          Map utsMap = data['uts'];
          utsMap.forEach((mapelKey, nilaiValue) {
            if (_controllers[_selectedSantriId]!['UTS']!.containsKey(mapelKey)) {
              _controllers[_selectedSantriId]!['UTS']![mapelKey]!.text = 
                  nilaiValue == 0 ? '' : nilaiValue.toStringAsFixed(0);
            }
          });
        }

        if (data.containsKey('uas') && data['uas'] is Map) {
          Map uasMap = data['uas'];
          uasMap.forEach((mapelKey, nilaiValue) {
            if (_controllers[_selectedSantriId]!['UAS']!.containsKey(mapelKey)) {
              _controllers[_selectedSantriId]!['UAS']![mapelKey]!.text = 
                  nilaiValue == 0 ? '' : nilaiValue.toStringAsFixed(0);
            }
          });
        }

        if (data.containsKey('hafalan_kitab') && data['hafalan_kitab'] is Map) {
          Map hafalanMap = data['hafalan_kitab'];
          hafalanMap.forEach((mapelKey, nilaiValue) {
            if (_controllers[_selectedSantriId]!['Hafalan Kitab']!.containsKey(mapelKey)) {
              _controllers[_selectedSantriId]!['Hafalan Kitab']![mapelKey]!.text = 
                  nilaiValue == 0 ? '' : nilaiValue.toStringAsFixed(0);
            }
          });
        }
      } else {
        _savedDocumentData = null;
      }
    } catch (e) {
      debugPrint("Error load data nilai gabungan: $e");
    }
    if (mounted) setState(() {});
  }

  Map<String, String> _getKenaikanKelasDanSemester(String kelasSekarang) {
    String kelasClean = kelasSekarang.toLowerCase().trim();
    if (kelasClean == 'kelas sp') {
      return {'kelas': 'Kelas 1', 'semester': 'Kelas 1', 'status': 'Aktif'};
    } else if (kelasClean == 'kelas 1') {
      return {'kelas': 'Kelas 2', 'semester': 'Kelas 2', 'status': 'Aktif'};
    } else if (kelasClean == 'kelas 2') {
      return {'kelas': 'Kelas 3', 'semester': 'Kelas 3', 'status': 'Aktif'};
    } else if (kelasClean == 'kelas 3') {
      return {'kelas': 'Kelas 4', 'semester': 'Kelas 4', 'status': 'Aktif'};
    } else if (kelasClean == 'kelas 4') {
      return {'kelas': 'Lulus', 'semester': 'Lulus', 'status': 'Lulus'};
    }
    return {'kelas': kelasSekarang, 'semester': _selectedSemester, 'status': 'Aktif'};
  }

  Future<void> _hapusDataNilaiSpesifik(String targetSantriId) async {
    setState(() => _isSaving = true);
    try {
      String docId = "${targetSantriId}_${_selectedTahunAjaran.replaceAll('/', '-')}_${_selectedSemester.replaceAll(' ', '')}";
      await FirebaseFirestore.instance.collection('nilai').doc(docId).delete();

      String raporDocId = "${targetSantriId}_${_selectedKelas.replaceAll(' ', '')}_${_selectedTahunAjaran.replaceAll('/', '')}";
      await FirebaseFirestore.instance.collection('rapor').doc(raporDocId).delete();

      _showSnackBar('Data nilai berhasil dihapus!', Colors.green);
      if (_selectedSantriId == targetSantriId) {
        _selectedSantriId = '';
        _savedDocumentData = null;
      }
      await _prosesFilterKelasDanMapel();
    } catch (e) {
      _showSnackBar('Gagal menghapus data: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _hapusDataNilai() async {
    if (_selectedSantriId.isEmpty) return;
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Data Nilai'),
        content: const Text('Yakin ingin menghapus seluruh nilai santri ini? Ini juga akan menghapus data di Cetak Rapot.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true) return;
    await _hapusDataNilaiSpesifik(_selectedSantriId);
  }

  Future<void> _prosesSimpanMasalDanNaikKelas() async {
    if (_selectedSantriId.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      int jumlahMapelDiBawah70 = 0;
      bool adaFormKosong = false;
      String pesanKategoriKosong = "";

      if (_controllers[_selectedSantriId]?['Nilai Kehadiran']?['Global']?.text.trim().isEmpty ?? true) {
        adaFormKosong = true; pesanKategoriKosong = "Nilai Kehadiran";
      } else if (_controllers[_selectedSantriId]?['Nilai Perilaku']?['Global']?.text.trim().isEmpty ?? true) {
        adaFormKosong = true; pesanKategoriKosong = "Nilai Perilaku";
      } else if ((_controllers[_selectedSantriId]?['Ketidakhadiran']?['Sakit']?.text.trim().isEmpty ?? true) ||
                 (_controllers[_selectedSantriId]?['Ketidakhadiran']?['Izin']?.text.trim().isEmpty ?? true) ||
                 (_controllers[_selectedSantriId]?['Ketidakhadiran']?['Tanpa Keterangan']?.text.trim().isEmpty ?? true)) {
        adaFormKosong = true; pesanKategoriKosong = "Form Absensi";
      }

      if (!adaFormKosong) {
        for (var m in _getSafeMasterMapel(_selectedSemester)) {
          if (_controllers[_selectedSantriId]?['UTS']?[m]?.text.trim().isEmpty ?? true) {
            adaFormKosong = true; pesanKategoriKosong = "UTS ($m)"; break;
          }
        }
      }

      if (!adaFormKosong) {
        for (var m in _getSafeMasterMapel(_selectedSemester)) {
          if (_controllers[_selectedSantriId]?['UAS']?[m]?.text.trim().isEmpty ?? true) {
            adaFormKosong = true; pesanKategoriKosong = "UAS ($m)"; break;
          }
        }
      }

      if (!adaFormKosong) {
        List<String> mapelHafalan = _getSafeMasterMapel(_selectedSemester).where((m) {
          final lower = m.toLowerCase();
          return lower.contains('(lisan)') || lower.contains('hafalan');
        }).toList();
        for (var m in mapelHafalan) {
          if (_controllers[_selectedSantriId]?['Hafalan Kitab']?[m]?.text.trim().isEmpty ?? true) {
            adaFormKosong = true; pesanKategoriKosong = "Hafalan Kitab ($m)"; break;
          }
        }
      }

      if (adaFormKosong) {
        _showSnackBar('Gagal! Form wajib diisi lengkap. ($pesanKategoriKosong kosong)', Colors.red);
        setState(() => _isSaving = false);
        return;
      }

      String docId = "${_selectedSantriId}_${_selectedTahunAjaran.replaceAll('/', '-')}_${_selectedSemester.replaceAll(' ', '')}";
      DocumentReference docRef = FirebaseFirestore.instance.collection('nilai').doc(docId);
      
      int indexSantri = _allSantriList.indexWhere((s) => s.id == _selectedSantriId);
      if (indexSantri == -1) throw Exception("Santri tidak ditemukan.");
      final santriTerpilih = _allSantriList[indexSantri];

      double nilaiKehadiran = double.tryParse(_controllers[_selectedSantriId]?['Nilai Kehadiran']?['Global']?.text ?? '') ?? 0.0;
      double nilaiPerilaku = double.tryParse(_controllers[_selectedSantriId]?['Nilai Perilaku']?['Global']?.text ?? '') ?? 0.0;

      Map<String, int> ketidakhadiranMap = {};
      _controllers[_selectedSantriId]?['Ketidakhadiran']?.forEach((key, ctrl) {
        // Logika menangani input minus (-) yang menandakan 0 absen
        String valText = ctrl.text.trim();
        ketidakhadiranMap[key] = (valText == '-' || valText.isEmpty) ? 0 : (int.tryParse(valText) ?? 0);
      });

      Map<String, double> utsDataMap = {};
      _controllers[_selectedSantriId]?['UTS']?.forEach((mapel, ctrl) {
        utsDataMap[mapel] = double.tryParse(ctrl.text) ?? 0.0;
      });

      Map<String, double> uasDataMap = {};
      _controllers[_selectedSantriId]?['UAS']?.forEach((mapel, ctrl) {
        double nilai = double.tryParse(ctrl.text) ?? 0.0;
        uasDataMap[mapel] = nilai;
        if (nilai < 70.0) jumlahMapelDiBawah70++;
      });

      Map<String, double> hafalanDataMap = {};
      _controllers[_selectedSantriId]?['Hafalan Kitab']?.forEach((mapel, ctrl) {
        hafalanDataMap[mapel] = double.tryParse(ctrl.text) ?? 0.0;
      });

      final batch = FirebaseFirestore.instance.batch();

      Map<String, dynamic> payloadGabungan = {
        'id': docRef.id,
        'santriId': _selectedSantriId,
        'id_santri': _selectedSantriId,
        'namaSantri': santriTerpilih.nama,
        'kelas': _selectedKelas,
        'semester': _selectedSemester, 
        'tahunAjaran': _selectedTahunAjaran,
        'tahun_ajaran': _selectedTahunAjaran,
        'nilai_kehadiran': nilaiKehadiran,
        'nilai_perilaku': nilaiPerilaku,
        'ketidakhadiran': ketidakhadiranMap, 
        'uts': utsDataMap,            
        'uas': uasDataMap,            
        'hafalan_kitab': hafalanDataMap, 
        'updatedAt': FieldValue.serverTimestamp(),
      };

      batch.set(docRef, payloadGabungan, SetOptions(merge: true));

      String statusKenaikan = "";
      bool isNaik = true;
      final santriDocRef = FirebaseFirestore.instance.collection('santri').doc(_selectedSantriId);

      if (jumlahMapelDiBawah70 >= 3) {
        isNaik = false;
        statusKenaikan = "SANTRI TIDAK NAIK KELAS! (Ada $jumlahMapelDiBawah70 nilai UAS di bawah 70). Tetap berada di $_selectedKelas.";
      } else {
        isNaik = true;
        Map<String, String> dataBaru = _getKenaikanKelasDanSemester(_selectedKelas);
        String kelasBaru = dataBaru['kelas']!;
        String semesterBaru = dataBaru['semester']!;
        String statusBaru = dataBaru['status']!;

        batch.update(santriDocRef, {'kelas': kelasBaru, 'semester': semesterBaru, 'status': statusBaru});
        
        if (kelasBaru == 'Lulus') {
          statusKenaikan = "SANTRI TELAH LULUS! Selamat kepada ${santriTerpilih.nama}.";
        } else {
          // Kata "otomatis" dihilangkan dari notifikasi ini
          statusKenaikan = "SANTRI TELAH NAIK KELAS! Selamat, naik ke $kelasBaru.";
        }

        _allSantriList[indexSantri] = santriTerpilih.copyWith(
          kelas: kelasBaru,
          status: statusBaru,
        );
      }

      await batch.commit();

      String raporDocId = "${_selectedSantriId}_${_selectedKelas.replaceAll(' ', '')}_${_selectedTahunAjaran.replaceAll('/', '')}";
      await FirebaseFirestore.instance.collection('rapor').doc(raporDocId).delete();

      _controllers[_selectedSantriId]?.forEach((kategoriKey, mapelMap) {
        mapelMap.forEach((mapelKey, ctrl) {
          ctrl.clear();
        });
      });

      _selectedSantriId = '';
      _savedDocumentData = null;

      _showDialogNotifikasi(statusKenaikan, isNaik);
      await _prosesFilterKelasDanMapel();
    } catch (e) {
      _showSnackBar('Gagal memproses data: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showDialogNotifikasi(String pesan, bool suksesNaik) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(suksesNaik ? Icons.check_circle : Icons.warning_rounded, color: suksesNaik ? Colors.green : Colors.orange),
            const SizedBox(width: 8),
            const Text('Status Kelulusan', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(pesan, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  double _hitungRataRataBerbobotUtama() {
    if (_selectedSantriId.isEmpty) return 0.0;
    
    double kehadiran = double.tryParse(_controllers[_selectedSantriId]?['Nilai Kehadiran']?['Global']?.text ?? '') ?? 0.0;
    double perilaku = double.tryParse(_controllers[_selectedSantriId]?['Nilai Perilaku']?['Global']?.text ?? '') ?? 0.0;

    double totalUts = 0; int countUts = 0;
    _controllers[_selectedSantriId]?['UTS']?.forEach((_, ctrl) {
      double? n = double.tryParse(ctrl.text);
      if (n != null && n > 0) { totalUts += n; countUts++; }
    });
    double avgUts = countUts > 0 ? totalUts / countUts : 0.0;

    double totalUas = 0; int countUas = 0;
    _controllers[_selectedSantriId]?['UAS']?.forEach((_, ctrl) {
      double? n = double.tryParse(ctrl.text);
      if (n != null && n > 0) { totalUas += n; countUas++; }
    });
    double avgUas = countUas > 0 ? totalUas / countUas : 0.0;

    double totalHafalan = 0; int countHafalan = 0;
    _controllers[_selectedSantriId]?['Hafalan Kitab']?.forEach((_, ctrl) {
      double? n = double.tryParse(ctrl.text);
      if (n != null && n > 0) { totalHafalan += n; countHafalan++; }
    });
    double avgHafalan = countHafalan > 0 ? totalHafalan / countHafalan : 0.0;

    return (kehadiran * 0.05) + (perilaku * 0.05) + (avgUts * 0.20) + (avgUas * 0.40) + (avgHafalan * 0.30);
  }

  double _hitungRataRataBerbobotDariDoc(Map<String, dynamic> data) {
    double kehadiran = double.tryParse(data['nilai_kehadiran']?.toString() ?? '0') ?? 0.0;
    double perilaku = double.tryParse(data['nilai_perilaku']?.toString() ?? '0') ?? 0.0;

    double sumUts = 0; int cUts = 0;
    if (data['uts'] is Map) {
      (data['uts'] as Map).forEach((_, v) { sumUts += double.tryParse(v.toString()) ?? 0; cUts++; });
    }
    double avgUts = cUts > 0 ? sumUts / cUts : 0.0;

    double sumUas = 0; int cUas = 0;
    if (data['uas'] is Map) {
      (data['uas'] as Map).forEach((_, v) { sumUas += double.tryParse(v.toString()) ?? 0; cUas++; });
    }
    double avgUas = cUas > 0 ? sumUas / cUas : 0.0;

    double sumHafal = 0; int cHafal = 0;
    if (data['hafalan_kitab'] is Map) {
      (data['hafalan_kitab'] as Map).forEach((_, v) { sumHafal += double.tryParse(v.toString()) ?? 0; cHafal++; });
    }
    double avgHafalan = cHafal > 0 ? sumHafal / cHafal : 0.0;

    return (kehadiran * 0.05) + (perilaku * 0.05) + (avgUts * 0.20) + (avgUas * 0.40) + (avgHafalan * 0.30);
  }

  void _showPicker(String title, List<String> items, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, idx) {
                  final item = items[idx];
                  return ListTile(
                    title: Text(item, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    onTap: () {
                      setState(() {
                        onSelect(item);
                      });
                      _prosesFilterKelasDanMapel();
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSantriPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Text('Pilih Nama Santri', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: _filteredSantriList.isEmpty
                    ? const Center(child: Text('Tidak ada santri di kelas ini', style: TextStyle(color: Colors.grey, fontSize: 12)))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredSantriList.length,
                        itemBuilder: (context, idx) {
                          final santri = _filteredSantriList[idx];
                          return ListTile(
                            leading: const Icon(Icons.person_outline, size: 20),
                            title: Text(santri.nama, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            onTap: () {
                              setState(() => _selectedSantriId = santri.id);
                              _loadNilaiDariDatabase();
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKategoriNilaiTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _kategoriNilaiList.map((kat) {
          bool isSelected = _selectedKategori == kat['id'];
          return GestureDetector(
            onTap: () => setState(() {
              _selectedKategori = kat['id'];
              _mapelAktifList = _getMapelTersaringSesuaiKategori();
            }),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF5D38F5).withAlpha(25) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected ? const Color(0xFF5D38F5) : Colors.grey.shade300),
              ),
              child: Text(
                kat['label'],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF5D38F5) : Colors.grey.shade700,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDropdownItem({required String label, required String value, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                  const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String currentSantriName = 'Pilih Santri...';
    if (_filteredSantriList.isNotEmpty && _selectedSantriId.isNotEmpty) {
      final found = _filteredSantriList.where((s) => s.id == _selectedSantriId);
      if (found.isNotEmpty) currentSantriName = found.first.nama;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)), onPressed: () => Navigator.pop(context)),
        centerTitle: true,
        title: const Text('Kelola Nilai Santri', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF5D38F5),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF5D38F5),
          tabs: const [
            Tab(icon: Icon(Icons.edit_note, size: 20), text: 'Input Data'),
            Tab(icon: Icon(Icons.analytics_outlined, size: 20), text: 'Rekap Kelas'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF5D38F5)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFormInputTab(currentSantriName),
                _buildRekapKelasTab(),
              ],
            ),
    );
  }

  Widget _buildFormInputTab(String currentSantriName) {
    double rataRataNilai = _hitungRataRataBerbobotUtama();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildDropdownItem(
                label: 'Kelas',
                value: _selectedKelas,
                onTap: () => _showPicker('Pilih Kelas', _kelasList, (val) {
                  _selectedKelas = val;
                  _sinkronisasiSemesterOtomatis(val);
                }),
              ),
              const SizedBox(width: 8),
              _buildDropdownItem(
                label: 'Tahun Ajaran',
                value: _selectedTahunAjaran,
                onTap: () => _showPicker('Tahun Ajaran', _opsiTahunAjaranList, (val) => _selectedTahunAjaran = val),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _showSantriPicker,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 20, color: Color(0xFF3C21F7)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Fokus Santri Terpilih', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(currentSantriName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          _buildKategoriNilaiTabs(),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFF5D38F5).withAlpha(12), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('Form input: $_selectedKategori', style: const TextStyle(color: Color(0xFF5D38F5), fontSize: 12, fontWeight: FontWeight.w600))),
                if (_selectedSantriId.isNotEmpty)
                  Text('Rata-rata: ${rataRataNilai.toStringAsFixed(1)}', style: const TextStyle(color: Color(0xFF15803D), fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _selectedSantriId.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                  child: const Text('Silakan pilih nama santri di atas terlebih dahulu.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _mapelAktifList.length,
                  itemBuilder: (context, index) {
                    String itemMapel = _mapelAktifList[index];
                    String labelTeks = itemMapel;
                    String hintText = '0-100';
                    TextInputType kType = TextInputType.number;
                    TextEditingController? ctrl;

                    if (_selectedKategori == 'Absensi & Perilaku') {
                      if (itemMapel == 'Nilai Kehadiran') { 
                        labelTeks = 'Nilai Kehadiran'; 
                        ctrl = _controllers[_selectedSantriId]?['Nilai Kehadiran']?['Global']; 
                      }
                      else if (itemMapel == 'Nilai Perilaku') { 
                        labelTeks = 'Nilai Perilaku / Sikap'; 
                        ctrl = _controllers[_selectedSantriId]?['Nilai Perilaku']?['Global']; 
                      }
                      else if (itemMapel == 'Sakit') { 
                        labelTeks = 'Ketidakhadiran: Sakit'; 
                        hintText = '-'; 
                        kType = TextInputType.text; // agar bisa ngetik strip '-'
                        ctrl = _controllers[_selectedSantriId]?['Ketidakhadiran']?['Sakit']; 
                      }
                      else if (itemMapel == 'Izin') { 
                        labelTeks = 'Ketidakhadiran: Izin'; 
                        hintText = '-'; 
                        kType = TextInputType.text;
                        ctrl = _controllers[_selectedSantriId]?['Ketidakhadiran']?['Izin']; 
                      }
                      else if (itemMapel == 'Tanpa Keterangan') { 
                        labelTeks = 'Tanpa Keterangan (Alpha)'; 
                        hintText = '-'; 
                        kType = TextInputType.text;
                        ctrl = _controllers[_selectedSantriId]?['Ketidakhadiran']?['Tanpa Keterangan']; 
                      }
                    } else {
                      ctrl = _controllers[_selectedSantriId]?[_selectedKategori]?[itemMapel];
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                      child: Row(
                        children: [
                          Expanded(child: Text(labelTeks, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 65,
                            child: TextField(
                              controller: ctrl,
                              keyboardType: kType,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: hintText,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          const SizedBox(height: 24),
          
          if (_selectedSantriId.isNotEmpty)
            Row(
              children: [
                if (_savedDocumentData != null) ...[
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _hapusDataNilai,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _prosesSimpanMasalDanNaikKelas,
                    icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save, size: 18),
                    label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Semua Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5D38F5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                )
              ],
            ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildRekapKelasTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('nilai')
          .where('kelas', isEqualTo: _selectedKelas)
          .where('tahunAjaran', isEqualTo: _selectedTahunAjaran)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF5D38F5)));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('Belum ada data nilai santri yang diinputkan untuk $_selectedKelas pada TA $_selectedTahunAjaran.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length + 1,
          itemBuilder: (context, index) {
            if (index == docs.length) {
              return const SizedBox(height: 60);
            }

            final docData = docs[index].data() as Map<String, dynamic>;
            final String sId = docData['santriId'] ?? '';
            final String sNama = docData['namaSantri'] ?? 'Tanpa Nama';
            double rataBerbobot = _hitungRataRataBerbobotDariDoc(docData);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              elevation: 0,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF5D38F5).withAlpha(15),
                      child: const Icon(Icons.person, color: Color(0xFF5D38F5), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sNama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                          const SizedBox(height: 4),
                          Text('Rata-rata: ${rataBerbobot.toStringAsFixed(1)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note, color: Colors.blue, size: 22),
                      onPressed: () async {
                        setState(() => _selectedSantriId = sId);
                        await _loadNilaiDariDatabase();
                        _tabController?.animateTo(0); 
                        _showSnackBar('Data $sNama berhasil dimuat untuk diubah.', Colors.blue);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}