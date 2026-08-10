import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/santri_model.dart';
import '../services/firestore_service.dart';

// ============================================================================
// 1. TEMA & KONSTANTA WARNA
// ============================================================================
const Color _kPrimary = Color(0xFF5D38F5);

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}

const Color _kSurface = Color(0xFFFAFAFC);
const Color _kCard = Colors.white;
const Color _kText = Color(0xFF1E293B);
const Color _kSubtext = Color(0xFF64748B);

// ============================================================================
// 2. DATA MASTER (Kelas, Mapel, Tahun Ajaran)
// ============================================================================
class SkemaData {
  static const List<String> kelasList = [
    'Kelas sp',
    'Kelas 1',
    'Kelas 2',
    'Kelas 3',
    'Kelas 4'
  ];
  static const List<String> tahunList = ['2025/2026', '2024/2025', '2023/2024'];

  static const List<Map<String, dynamic>> kategoriList = [
    {'id': 'Absensi & Perilaku', 'label': 'Absensi & Sikap'},
    {'id': 'Hafalan Kitab', 'label': 'Hafalan'},
    {'id': 'UTS', 'label': 'UTS'},
    {'id': 'UAS', 'label': 'UAS'},
  ];

  static const List<String> absenList = ['Sakit', 'Izin', 'Tanpa Keterangan'];

  static Map<String, Map<String, List<String>>> mapelPerKelas = {
    'Kelas sp': {
      'Hafalan Kitab': [
        'Tashrif Bina shahih (Lisan)',
        'Praktek Ibadah (Lisan)',
        'Aqoidul Iman (Lisan)',
        'Hafalan Kitab: Aqoidul Iman',
      ],
      'UTS': [
        'BTQ (Tulis)',
        'Tashrif Bina shahih (Lisan)',
        'Praktek Ibadah (Lisan)',
        'Aqoidul Iman (Lisan)',
        'Tahsin Al-Quran',
        'Hafalan Kitab: Aqoidul Iman',
      ],
      'UAS': [
        'BTQ (Tulis)',
        'Tashrif Bina shahih (Lisan)',
        'Praktek Ibadah (Lisan)',
        'Aqoidul Iman (Lisan)',
        'Tahsin Al-Quran',
        'Hafalan Kitab: Aqoidul Iman',
      ],
    },
    'Kelas 1': {
      'Hafalan Kitab': [
        'Tashrif Bina Shahih (Lisan)',
        'Tahsin Al-Qur\u02bcaan',
        'Hafalan Kitab: Safinah & Awamil',
      ],
      'UTS': [
        'Awamil (Tulis)',
        'Tajwid (Tulis)',
        'Safinah (Tulis)',
        'Jurmiyah (Tulis)',
        'Tashrif Bina Shahih (Lisan)',
        'Tahsin Al-Qur\u02bcaan',
        'Qira\u02bcatul Kutub (Safinah)',
        'Hafalan Kitab: Safinah & Awamil',
      ],
      'UAS': [
        'Awamil (Tulis)',
        'Tajwid (Tulis)',
        'Safinah (Tulis)',
        'Jurmiyah (Tulis)',
        'Tashrif Bina Shahih (Lisan)',
        'Tahsin Al-Qur\u02bcaan',
        'Qira\u02bcatul Kutub (Safinah)',
        'Hafalan Kitab: Safinah & Awamil',
      ],
    },
    'Kelas 2': {
      'Hafalan Kitab': [
        'Jurmiyah (Lisan)',
        'Qowaid Fiqhiyah (Lisan)',
        'Ngelal \u2013 Ngasal (Lisan)',
        'Tahsin Al-Qur\u02bcaan',
        'Hafalan Kitab: Nadhom Imrity',
      ],
      'UTS': [
        'Kaelani (Tulis)',
        'Nastainu (Tulis)',
        'Imrity (Tulis)',
        'Jurmiyah (Lisan)',
        'Qowaid Fiqhiyah (Lisan)',
        'Ngelal \u2013 Ngasal (Lisan)',
        'Tahsin Al-Qur\u02bcaan',
        'Qira\u02bcatul Kutub (Riyadul Badiah)',
        'Hafalan Kitab: Nadhom Imrity',
      ],
      'UAS': [
        'Kaelani (Tulis)',
        'Nastainu (Tulis)',
        'Imrity (Tulis)',
        'Jurmiyah (Lisan)',
        'Qowaid Fiqhiyah (Lisan)',
        'Ngelal \u2013 Ngasal (Lisan)',
        'Tahsin Al-Qur\u02bcaan',
        'Qira\u02bcatul Kutub (Riyadul Badiah)',
        'Hafalan Kitab: Nadhom Imrity',
      ],
    },
    'Kelas 3': {
      'Hafalan Kitab': [
        'Qowaid Fiqhiyah (Lisan)',
        'Alfiyyah (Lisan)',
        'Tahsin Al-Quran',
        'Hafalan Kitab: Nadhom Alfiyyah (Bab 1)',
      ],
      'UTS': [
        'Samar Qondi (Tulis)',
        'Jauhar Maknun (Tulis)',
        'Qowaid Fiqhiyah (Lisan)',
        'Alfiyyah (Lisan)',
        'Tahsin Al-Quran',
        'Qiro\u02bcatul Kutub (Fathul Mu\u02bcin)',
        'Hafalan Kitab: Nadhom Alfiyyah (Bab 1)',
      ],
      'UAS': [
        'Samar Qondi (Tulis)',
        'Jauhar Maknun (Tulis)',
        'Qowaid Fiqhiyah (Lisan)',
        'Alfiyyah (Lisan)',
        'Tahsin Al-Quran',
        'Qiro\u02bcatul Kutub (Fathul Mu\u02bcin)',
        'Hafalan Kitab: Nadhom Alfiyyah (Bab 1)',
      ],
    },
    'Kelas 4': {
      'Hafalan Kitab': [
        'Qowaid Fiqhiyah (Lisan)',
        'Alfiyyah (Lisan)',
        'Tahsin Al-Quran',
        'Hafalan Kitab: Nadhom Alfiyyah (Khatam)',
      ],
      'UTS': [
        'Samar Qondi (Tulis)',
        'Jauhar Maknun (Tulis)',
        'Qowaid Fiqhiyah (Lisan)',
        'Alfiyyah (Lisan)',
        'Tahsin Al-Quran',
        'Qiro\u02bcatul Kutub (Fathul Mu\u02bcin)',
        'Hafalan Kitab: Nadhom Alfiyyah (Khatam)',
      ],
      'UAS': [
        'Samar Qondi (Tulis)',
        'Jauhar Maknun (Tulis)',
        'Qowaid Fiqhiyah (Lisan)',
        'Alfiyyah (Lisan)',
        'Tahsin Al-Quran',
        'Qiro\u02bcatul Kutub (Fathul Mu\u02bcin)',
        'Hafalan Kitab: Nadhom Alfiyyah (Khatam)',
      ],
    },
  };

  static List<String> getMapelHafalan(String kelas) =>
      mapelPerKelas[kelas]?['Hafalan Kitab'] ?? [];
  static List<String> getMapelUTS(String kelas) =>
      mapelPerKelas[kelas]?['UTS'] ?? [];
  static List<String> getMapelUAS(String kelas) =>
      mapelPerKelas[kelas]?['UAS'] ?? [];
}

// ============================================================================
// 3. LOGIKA PENILAIAN & KENAIKAN KELAS
// ============================================================================
class SkemaPenilaian {
  static double hitungNilaiAkhir({
    required double kehadiran,
    required double perilaku,
    required double avgUts,
    required double avgUas,
    required double avgHafalan,
  }) {
    return (kehadiran * 0.05) +
        (perilaku * 0.05) +
        (avgUts * 0.20) +
        (avgUas * 0.40) +
        (avgHafalan * 0.30);
  }

  static String getPredikat(double nilai) {
    if (nilai >= 90) return 'A (Mumtaz)';
    if (nilai >= 80) return 'B (Jayyid Jiddan)';
    if (nilai >= 70) return 'C (Jayyid)';
    if (nilai >= 60) return 'D (Maqbul)';
    return 'E (Rasib)';
  }

  static Map<String, dynamic> cekKenaikanKelas({
    required String kelasSekarang,
    required double nilaiAkhir,
    required double kehadiran,
    required double perilaku,
  }) {
    List<String> alasanGagal = [];

    if (nilaiAkhir < 65)
      alasanGagal
          .add('Nilai Rata-rata Akhir (${nilaiAkhir.toStringAsFixed(1)}) < 65');
    if (kehadiran < 70) alasanGagal.add('Kehadiran ($kehadiran) < 70');
    if (perilaku < 70) alasanGagal.add('Sikap/Perilaku ($perilaku) < 70');

    bool naikKelas = alasanGagal.isEmpty;

    if (!naikKelas) {
      return {
        'kelas': kelasSekarang,
        'status': 'Aktif',
        'naik': false,
        'pesan': alasanGagal.join('\n• ')
      };
    }

    const urutanKelas = {
      'kelas sp': {'kelas': 'Kelas 1', 'status': 'Aktif'},
      'kelas 1': {'kelas': 'Kelas 2', 'status': 'Aktif'},
      'kelas 2': {'kelas': 'Kelas 3', 'status': 'Aktif'},
      'kelas 3': {'kelas': 'Kelas 4', 'status': 'Aktif'},
      'kelas 4': {'kelas': 'Lulus', 'status': 'Lulus'},
    };

    var hasil = urutanKelas[kelasSekarang.toLowerCase().trim()] ??
        {'kelas': kelasSekarang, 'status': 'Aktif'};
    return {
      'kelas': hasil['kelas'],
      'status': hasil['status'],
      'naik': true,
      'pesan': ''
    };
  }

  static double hitungRataRataMap(Map<String, double> mapValues) {
    if (mapValues.isEmpty) return 0.0;
    double sum = 0;
    mapValues.forEach((_, val) => sum += val);
    return sum / mapValues.length;
  }
}

// ============================================================================
// 4. UI UTAMA (Screen & Logika State)
// ============================================================================
class NilaiScreen extends StatefulWidget {
  const NilaiScreen({super.key});
  @override
  State<NilaiScreen> createState() => _NilaiScreenState();
}

class _NilaiScreenState extends State<NilaiScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  List<SantriModel> _allSantri = [];
  List<SantriModel> _filteredSantri = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLoadNilai = false;
  bool _isAdmin = true;

  String _kelas = 'Kelas 1';
  String _tahunAjaran = '2025/2026';
  String _santriId = '';
  String _kategori = 'Absensi & Perilaku';

  Map<String, dynamic>? _savedData;
  final Map<String, Map<String, Map<String, TextEditingController>>> _ctrl = {};

  List<String> get _mapelHafalan => SkemaData.getMapelHafalan(_kelas);
  List<String> get _mapelUTS => SkemaData.getMapelUTS(_kelas);
  List<String> get _mapelUAS => SkemaData.getMapelUAS(_kelas);

  String get _docIdNilai =>
      '${_santriId}_${_tahunAjaran.replaceAll('/', '-')}_${_kelas.replaceAll(' ', '')}';
  String get _docIdRapor =>
      '${_santriId}_${_kelas.replaceAll(' ', '')}_${_tahunAjaran.replaceAll('/', '')}';

  SantriModel? get _santriTerpilih =>
      _filteredSantri.where((s) => s.id == _santriId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _checkRoleAndLoadSantri();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _bersihkanSemuaCtrl();
    super.dispose();
  }

  Future<void> _checkRoleAndLoadSantri() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docUser = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (docUser.exists) {
          final role = (docUser.data()!['role'] ?? '').toString().toLowerCase();
          if (role == 'guru') {
            _isAdmin = false;
            _kelas = docUser.data()!['kelas'] ?? 'Kelas 1';
          }
        }
      }
      await _loadSantri();
    } catch (e) {
      _snack('Gagal verifikasi role: $e', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSantri() async {
    try {
      final list = await FirestoreService.getSantriList();
      _allSantri =
          list.where((s) => s.status.toLowerCase().contains('aktif')).toList();
      _filterSantri();
    } catch (e) {
      _snack('Gagal memuat data santri: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterSantri() {
    setState(() {
      _filteredSantri = _allSantri
          .where((s) =>
              s.kelas.toLowerCase().trim() == _kelas.toLowerCase().trim())
          .toList()
        ..sort((a, b) => a.nama.compareTo(b.nama));

      if (!_filteredSantri.any((s) => s.id == _santriId)) {
        _santriId = '';
        _savedData = null;
        _bersihkanCtrlSantriId();
      }
    });
  }

  void _siapkanCtrl(String id) {
    if (_ctrl.containsKey(id)) {
      final keysLama = _ctrl[id]?['UTS']?.keys.toSet() ?? <String>{};
      final keysBaru = _mapelUTS.toSet();
      if (keysLama.containsAll(keysBaru) && keysBaru.containsAll(keysLama)) {
        _bersihkanCtrlSantriId();
        return;
      }
    }

    _ctrl.remove(id);
    _ctrl[id] = {
      'Nilai Kehadiran': {'Global': _buatCtrl()},
      'Nilai Perilaku': {'Global': _buatCtrl()},
      'Ketidakhadiran': {for (var a in SkemaData.absenList) a: _buatCtrl()},
      'UTS': {for (var m in _mapelUTS) m: _buatCtrl()},
      'UAS': {for (var m in _mapelUAS) m: _buatCtrl()},
      'Hafalan Kitab': {for (var m in _mapelHafalan) m: _buatCtrl()},
    };
  }

  TextEditingController _buatCtrl() => TextEditingController()
    ..addListener(() {
      if (mounted) setState(() {});
    });

  void _bersihkanSemuaCtrl() {
    for (final k in _ctrl.values) {
      for (final m in k.values) {
        for (final c in m.values) {
          c.dispose();
        }
      }
    }
    _ctrl.clear();
  }

  void _bersihkanCtrlSantriId() {
    _ctrl[_santriId]?.forEach((_, m) => m.forEach((_, c) => c.clear()));
  }

  void _isiCtrl(String kat, String key, dynamic val) {
    if (val == null) return;
    final n = val is num ? val.toDouble() : double.tryParse(val.toString());
    if (n == null || n == 0) return;

    if (_ctrl[_santriId]?[kat]?[key] == null) {
      _ctrl[_santriId]?[kat]?[key] = _buatCtrl();

      if (SkemaData.mapelPerKelas[_kelas] == null) {
        SkemaData.mapelPerKelas[_kelas] = {
          'Hafalan Kitab': [],
          'UTS': [],
          'UAS': []
        };
      }
      if (!SkemaData.mapelPerKelas[_kelas]![kat]!.contains(key)) {
        SkemaData.mapelPerKelas[_kelas]![kat]!.add(key);
      }
    }

    _ctrl[_santriId]?[kat]?[key]?.text = n.toStringAsFixed(0);
  }

  Future<void> _loadNilai() async {
    if (_santriId.isEmpty) return;
    _siapkanCtrl(_santriId);
    setState(() => _isLoadNilai = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('nilai')
          .doc(_docIdNilai)
          .get();
      if (!mounted) return;

      if (snap.exists && snap.data() != null) {
        final d = snap.data()!;
        _savedData = d;
        _isiCtrl('Nilai Kehadiran', 'Global', d['nilai_kehadiran']);
        _isiCtrl('Nilai Perilaku', 'Global', d['nilai_perilaku']);

        if (d['ketidakhadiran'] is Map) {
          (d['ketidakhadiran'] as Map).forEach((k, v) {
            _ctrl[_santriId]?['Ketidakhadiran']?[k]?.text =
                (v == 0) ? '-' : v.toString();
          });
        }
        void isiMapValues(String field, String kat) {
          if (d[field] is Map) {
            (d[field] as Map).forEach((k, v) {
              final n = v is num
                  ? v.toDouble()
                  : double.tryParse(v.toString()) ?? 0.0;
              _isiCtrl(kat, k, n);
            });
          }
        }

        isiMapValues('uts', 'UTS');
        isiMapValues('uas', 'UAS');
        isiMapValues('hafalan_kitab', 'Hafalan Kitab');
      } else {
        _savedData = null;
      }
    } catch (e) {
      debugPrint('_loadNilai error: $e');
    } finally {
      if (mounted) setState(() => _isLoadNilai = false);
    }
  }

  Future<void> _simpan() async {
    if (_santriId.isEmpty) return;
    final error = _validasi();
    if (error != null) {
      _snack('⚠️ $error', Colors.orange.shade800);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final namaSantri = _santriTerpilih?.nama ??
          _savedData?['namaSantri']?.toString() ??
          'Santri';

      final kehadiran = double.tryParse(
              _ctrl[_santriId]!['Nilai Kehadiran']!['Global']!.text) ??
          0.0;
      final perilaku = double.tryParse(
              _ctrl[_santriId]!['Nilai Perilaku']!['Global']!.text) ??
          0.0;

      final Map<String, int> ketidakhadiran = {};
      _ctrl[_santriId]!['Ketidakhadiran']!.forEach((k, c) {
        final t = c.text.trim();
        ketidakhadiran[k] =
            (t == '-' || t.isEmpty) ? 0 : (int.tryParse(t) ?? 0);
      });

      final Map<String, double> uts = {};
      final Map<String, double> uas = {};
      final Map<String, double> hafalan = {};

      _ctrl[_santriId]!['UTS']!
          .forEach((k, c) => uts[k] = double.tryParse(c.text) ?? 0.0);
      _ctrl[_santriId]!['UAS']!
          .forEach((k, c) => uas[k] = double.tryParse(c.text) ?? 0.0);
      _ctrl[_santriId]!['Hafalan Kitab']!
          .forEach((k, c) => hafalan[k] = double.tryParse(c.text) ?? 0.0);

      final avgUts = SkemaPenilaian.hitungRataRataMap(uts);
      final avgUas = SkemaPenilaian.hitungRataRataMap(uas);
      final avgHafal = SkemaPenilaian.hitungRataRataMap(hafalan);

      final nilaiAkhir = SkemaPenilaian.hitungNilaiAkhir(
          kehadiran: kehadiran,
          perilaku: perilaku,
          avgUts: avgUts,
          avgUas: avgUas,
          avgHafalan: avgHafal);
      final predikat = SkemaPenilaian.getPredikat(nilaiAkhir);

      final kenaikan = SkemaPenilaian.cekKenaikanKelas(
          kelasSekarang: _kelas,
          nilaiAkhir: nilaiAkhir,
          kehadiran: kehadiran,
          perilaku: perilaku);

      final bool naik = kenaikan['naik'];
      final String statusKenaikan = naik ? 'NAIK KELAS' : 'TIDAK NAIK KELAS';

      final batch = FirebaseFirestore.instance.batch();
      final nilaiRef =
          FirebaseFirestore.instance.collection('nilai').doc(_docIdNilai);
      final raporRef =
          FirebaseFirestore.instance.collection('rapor').doc(_docIdRapor);

      final payloadDasar = {
        'santriId': _santriId,
        'namaSantri': namaSantri,
        'kelas': _kelas,
        'semester': _kelas,
        'tahunAjaran': _tahunAjaran,
        'nilai_kehadiran': kehadiran,
        'nilai_perilaku': perilaku,
        'ketidakhadiran': ketidakhadiran,
        'uts': uts,
        'uas': uas,
        'hafalan_kitab': hafalan,
        'rata_rata_uts': avgUts,
        'rata_rata_uas': avgUas,
        'rata_rata_hafalan': avgHafal,
        'nilai_akhir': nilaiAkhir,
        'predikat': predikat,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      batch.set(
          nilaiRef,
          {
            'id': nilaiRef.id,
            'id_santri': _santriId,
            'tahun_ajaran': _tahunAjaran,
            ...payloadDasar
          },
          SetOptions(merge: true));
      batch.set(
          raporRef,
          {
            'id': raporRef.id,
            'status_kenaikan': statusKenaikan,
            ...payloadDasar
          },
          SetOptions(merge: true));

      String pesanStatus =
          '⚠️ $namaSantri TIDAK NAIK KELAS.\n\nAlasan:\n• ${kenaikan['pesan']}';

      if (naik) {
        final santriRef =
            FirebaseFirestore.instance.collection('santri').doc(_santriId);
        batch.update(santriRef, {
          'kelas': kenaikan['kelas'],
          'semester': kenaikan['kelas'],
          'status': kenaikan['status']
        });

        final idx = _allSantri.indexWhere((s) => s.id == _santriId);
        if (idx != -1)
          _allSantri[idx] = _allSantri[idx]
              .copyWith(kelas: kenaikan['kelas'], status: kenaikan['status']);

        pesanStatus = kenaikan['kelas'] == 'Lulus'
            ? '🎉 $namaSantri telah LULUS!'
            : '✅ $namaSantri NAIK ke ${kenaikan['kelas']}!';
      }

      await batch.commit();

      setState(() {
        _santriId = '';
        _savedData = null;
        _filterSantri();
      });
      _showDialogHasil(pesanStatus, naik);
    } catch (e) {
      _snack('Gagal menyimpan: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  double get _progressKelengkapan {
    if (_santriId.isEmpty) return 0.0;
    int total = 0, terisi = 0;
    void cek(String kat, String key) {
      total++;
      final v = _ctrl[_santriId]?[kat]?[key]?.text.trim() ?? '';
      if (v.isNotEmpty && v != '-') terisi++;
    }

    cek('Nilai Kehadiran', 'Global');
    cek('Nilai Perilaku', 'Global');
    for (var a in SkemaData.absenList) {
      cek('Ketidakhadiran', a);
    }
    for (var m in _mapelUTS) {
      cek('UTS', m);
    }
    for (var m in _mapelUAS) {
      cek('UAS', m);
    }
    for (var m in _mapelHafalan) {
      cek('Hafalan Kitab', m);
    }

    return total == 0 ? 0 : terisi / total;
  }

  String? _validasi() {
    bool kosong(String kat, String key) =>
        _ctrl[_santriId]?[kat]?[key]?.text.trim().isEmpty ?? true;
    if (kosong('Nilai Kehadiran', 'Global'))
      return 'Nilai Kehadiran belum diisi.';
    if (kosong('Nilai Perilaku', 'Global'))
      return 'Nilai Perilaku belum diisi.';
    for (final a in SkemaData.absenList) {
      if (kosong('Ketidakhadiran', a)) return 'Absensi ($a) belum diisi.';
    }
    for (final m in _mapelUTS) {
      if (kosong('UTS', m)) return 'UTS — $m belum diisi.';
    }
    for (final m in _mapelUAS) {
      if (kosong('UAS', m)) return 'UAS — $m belum diisi.';
    }
    for (final m in _mapelHafalan) {
      if (kosong('Hafalan Kitab', m)) return 'Hafalan — $m belum diisi.';
    }
    return null;
  }

  double _getLiveRataRataHitung() {
    if (_santriId.isEmpty) return 0.0;
    double kh = double.tryParse(
            _ctrl[_santriId]?['Nilai Kehadiran']?['Global']?.text ?? '') ??
        0;
    double pr = double.tryParse(
            _ctrl[_santriId]?['Nilai Perilaku']?['Global']?.text ?? '') ??
        0;

    double avgCtrl(Map<String, TextEditingController>? m) {
      if (m == null) return 0;
      double s = 0;
      int c = 0;
      m.forEach((_, ctrl) {
        final n = double.tryParse(ctrl.text);
        if (n != null && n > 0) {
          s += n;
          c++;
        }
      });
      return c > 0 ? s / c : 0;
    }

    return SkemaPenilaian.hitungNilaiAkhir(
        kehadiran: kh,
        perilaku: pr,
        avgUts: avgCtrl(_ctrl[_santriId]?['UTS']),
        avgUas: avgCtrl(_ctrl[_santriId]?['UAS']),
        avgHafalan: avgCtrl(_ctrl[_santriId]?['Hafalan Kitab']));
  }

  // --- FUNGSI TAMBAH MAPEL CUSTOM ---
  void _dialogTambahMapel() {
    if (_santriId.isEmpty) {
      _snack('Pilih santri terlebih dahulu!', Colors.orange);
      return;
    }

    final TextEditingController mapelCtrl = TextEditingController();
    String selectedKategori =
        _kategori == 'Absensi & Perilaku' ? 'UTS' : _kategori;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Tambah Mapel Baru',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedKategori,
                items: ['Hafalan Kitab', 'UTS', 'UAS']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedKategori = v!),
                decoration: InputDecoration(
                  labelText: 'Kategori',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: mapelCtrl,
                decoration: InputDecoration(
                  labelText: 'Nama Mapel',
                  hintText: 'Contoh: Fikih (Lisan)',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child:
                    const Text('Batal', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              onPressed: () {
                final namaMapel = mapelCtrl.text.trim();
                if (namaMapel.isNotEmpty) {
                  setState(() {
                    if (SkemaData.mapelPerKelas[_kelas] == null) {
                      SkemaData.mapelPerKelas[_kelas] = {
                        'Hafalan Kitab': [],
                        'UTS': [],
                        'UAS': []
                      };
                    }

                    if (!SkemaData.mapelPerKelas[_kelas]![selectedKategori]!
                        .contains(namaMapel)) {
                      SkemaData.mapelPerKelas[_kelas]![selectedKategori]!
                          .add(namaMapel);
                    }

                    if (_ctrl[_santriId] != null &&
                        _ctrl[_santriId]![selectedKategori] != null) {
                      _ctrl[_santriId]![selectedKategori]![namaMapel] =
                          _buatCtrl();
                    }
                  });

                  Navigator.pop(context);
                  _snack(
                      'Mapel "$namaMapel" berhasil ditambahkan ke $selectedKategori',
                      Colors.green);
                }
              },
              child: const Text('Simpan Mapel'),
            ),
          ],
        );
      }),
    );
  }

  // --- FUNGSI HAPUS MAPEL ---
  void _hapusMapel(String kategori, String namaMapel) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Mapel?'),
        content: Text(
            'Apakah Anda yakin ingin menghapus "$namaMapel" dari $kategori?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                SkemaData.mapelPerKelas[_kelas]?[kategori]?.remove(namaMapel);
                _ctrl[_santriId]?[kategori]?.remove(namaMapel);
              });
              Navigator.pop(context);
              _snack('Mapel dihapus', Colors.red);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: _kText),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Kelola Nilai Santri',
            style: TextStyle(
                color: _kText, fontWeight: FontWeight.bold, fontSize: 16)),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: _kPrimary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: _kPrimary,
          tabs: const [
            Tab(icon: Icon(Icons.edit_note, size: 20), text: 'Input Nilai'),
            Tab(
                icon: Icon(Icons.analytics_outlined, size: 20),
                text: 'Rekap Kelas')
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : TabBarView(
              controller: _tabCtrl,
              children: [_buildTabInput(), _buildTabRekap()]),
    );
  }

  Widget _buildTabInput() {
    final namaAktif = _santriTerpilih?.nama ?? 'Pilih Santri...';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _stepLabel('1', 'Tahun Ajaran & Kelas'),
        const SizedBox(height: 8),
        Row(children: [
          _dropTile(
              'Tahun Ajaran',
              _tahunAjaran,
              () => _showPicker('Tahun Ajaran', SkemaData.tahunList, (v) {
                    _tahunAjaran = v;
                    if (_santriId.isNotEmpty) _loadNilai();
                  })),
          const SizedBox(width: 8),
          if (_isAdmin)
            _dropTile(
                'Kelas',
                _kelas,
                () => _showPicker('Pilih Kelas', SkemaData.kelasList, (v) {
                      _kelas = v;
                      _filterSantri();
                    }))
          else
            Expanded(child: _kotakTerkunci('Kelas Anda', _kelas)),
        ]),
        const SizedBox(height: 20),
        _stepLabel('2', 'Pilih Santri'),
        const SizedBox(height: 8),
        _santriTile(namaAktif),
        if (_santriId.isNotEmpty) ...[
          const SizedBox(height: 20),
          _stepLabel('3', 'Input Nilai'),
          const SizedBox(height: 8),
          _progressBar(),
          const SizedBox(height: 10),
          _tabKategori(),
          const SizedBox(height: 10),
          if (_isLoadNilai)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: _kPrimary)))
          else
            _formNilai(),
          const SizedBox(height: 24),
          _stepLabel('4', 'Simpan & Proses Kenaikan'),
          const SizedBox(height: 8),
          _tombolSimpan(),
        ] else
          _emptyState(),
      ]),
    );
  }

  Widget _formNilai() {
    List<_FieldItem> items = [];
    if (_kategori == 'Absensi & Perilaku') {
      items = [
        _FieldItem('Nilai Kehadiran', '0–100',
            _ctrl[_santriId]?['Nilai Kehadiran']?['Global'], true,
            limit: 70),
        _FieldItem('Nilai Perilaku / Sikap', '0–100',
            _ctrl[_santriId]?['Nilai Perilaku']?['Global'], true,
            limit: 70),
        ...SkemaData.absenList.map((a) => _FieldItem('Ketidakhadiran: $a',
            '- jika nihil', _ctrl[_santriId]?['Ketidakhadiran']?[a], false)),
      ];
    } else if (_kategori == 'Hafalan Kitab') {
      // Menambahkan fungsi onDelete pada setiap mapel Hafalan
      items = _mapelHafalan
          .map((m) => _FieldItem(
              m, '0–100', _ctrl[_santriId]?['Hafalan Kitab']?[m], true,
              limit: 65, onDelete: () => _hapusMapel('Hafalan Kitab', m)))
          .toList();
    } else if (_kategori == 'UTS') {
      // Menambahkan fungsi onDelete pada setiap mapel UTS
      items = _mapelUTS
          .map((m) => _FieldItem(m, '0–100', _ctrl[_santriId]?['UTS']?[m], true,
              limit: 65, onDelete: () => _hapusMapel('UTS', m)))
          .toList();
    } else if (_kategori == 'UAS') {
      // Menambahkan fungsi onDelete pada setiap mapel UAS
      items = _mapelUAS
          .map((m) => _FieldItem(m, '0–100', _ctrl[_santriId]?['UAS']?[m], true,
              limit: 65, onDelete: () => _hapusMapel('UAS', m)))
          .toList();
    }

    return Column(children: [
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200)),
        child: Row(children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  'Syarat Lulus / Naik Kelas:\nNilai Rata-rata Akhir ≥ 65, Kedisiplinan/Kehadiran ≥ 70, dan Perilaku ≥ 70.',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.w600,
                      height: 1.4)))
        ]),
      ),
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: _kPrimary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8)),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Form: $_kategori',
              style: const TextStyle(
                  color: _kPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          Text('Rata-rata Live: ${_getLiveRataRataHitung().toStringAsFixed(1)}',
              style: const TextStyle(
                  color: Colors.green,
                  fontSize: 11,
                  fontWeight: FontWeight.bold))
        ]),
      ),
      ...items.map(_buildRow),
      const SizedBox(height: 12),
      if (_kategori != 'Absensi & Perilaku')
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _dialogTambahMapel,
            icon: const Icon(Icons.add_circle_outline, size: 20),
            label: const Text('Tambah Mapel Custom'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kPrimary,
              side: BorderSide(
                  color: _kPrimary.withValues(alpha: 0.5), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
    ]);
  }

  Widget _buildTabRekap() {
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          _dropTile(
              'Tahun Ajaran',
              _tahunAjaran,
              () => _showPicker('Tahun Ajaran', SkemaData.tahunList,
                  (v) => setState(() => _tahunAjaran = v))),
          const SizedBox(width: 8),
          if (_isAdmin)
            _dropTile(
                'Kelas',
                _kelas,
                () => _showPicker('Pilih Kelas', SkemaData.kelasList,
                    (v) => setState(() => _kelas = v)))
          else
            Expanded(child: _kotakTerkunci('Kelas Anda', _kelas)),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('nilai')
              .where('kelas', isEqualTo: _kelas)
              .where('tahunAjaran', isEqualTo: _tahunAjaran)
              .snapshots(),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting)
              return const Center(
                  child: CircularProgressIndicator(color: _kPrimary));
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty)
              return const Center(child: Text('Belum ada data nilai.'));

            final sorted = docs.toList()
              ..sort((a, b) {
                final ra = _toDouble(
                    (a.data() as Map<String, dynamic>)['nilai_akhir']);
                final rb = _toDouble(
                    (b.data() as Map<String, dynamic>)['nilai_akhir']);
                return rb.compareTo(ra);
              });

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              itemBuilder: (_, i) {
                final d = sorted[i].data() as Map<String, dynamic>;
                final rata = _toDouble(d['nilai_akhir']);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: CircleAvatar(
                        backgroundColor: _kPrimary.withValues(alpha: 0.1),
                        child: Text('${i + 1}',
                            style: const TextStyle(color: _kPrimary))),
                    title: Text(d['namaSantri'] ?? 'Santri',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'Rata-rata Akhir: ${rata.toStringAsFixed(1)} • ${SkemaPenilaian.getPredikat(rata)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        setState(() => _santriId = d['santriId']);
                        _tabCtrl.animateTo(0);
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) => _loadNilai());
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  Widget _stepLabel(String n, String title) => Row(children: [
        Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
                color: _kPrimary, borderRadius: BorderRadius.circular(6)),
            child: Center(
                child: Text(n,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)))),
        const SizedBox(width: 8),
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: _kText))),
      ]);

  Widget _dropTile(String label, String value, VoidCallback onTap) => Expanded(
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style:
                              const TextStyle(fontSize: 10, color: _kSubtext)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Expanded(
                            child: Text(value,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _kText),
                                overflow: TextOverflow.ellipsis)),
                        const Icon(Icons.keyboard_arrow_down,
                            size: 16, color: _kSubtext)
                      ])
                    ]))),
      );

  Widget _kotakTerkunci(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: _kSubtext)),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54),
                    overflow: TextOverflow.ellipsis)),
            const Icon(Icons.lock, size: 14, color: Colors.grey)
          ])
        ]),
      );

  Widget _santriTile(String nama) {
    final ada = _santriId.isNotEmpty;
    return InkWell(
      onTap: _showSantriPicker,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: ada ? _kPrimary.withValues(alpha: 0.05) : _kCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ada ? _kPrimary : Colors.grey.shade200)),
        child: Row(children: [
          CircleAvatar(
              radius: 18,
              backgroundColor: ada ? _kPrimary : Colors.grey.shade200,
              child: Icon(Icons.person,
                  size: 18, color: ada ? Colors.white : _kSubtext)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Fokus Santri',
                    style: TextStyle(fontSize: 10, color: _kSubtext)),
                Text(nama,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: ada ? _kPrimary : _kSubtext))
              ])),
          _isLoadNilai
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _kPrimary))
              : Icon(Icons.arrow_drop_down, color: ada ? _kPrimary : _kSubtext)
        ]),
      ),
    );
  }

  Widget _progressBar() {
    final pct = _progressKelengkapan;
    final c = pct < 0.5
        ? Colors.orange
        : pct < 1.0
            ? Colors.amber.shade700
            : Colors.green;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Kelengkapan Nilai',
              style: TextStyle(
                  fontSize: 11, color: _kSubtext, fontWeight: FontWeight.w600)),
          Text('${(pct * 100).toInt()}%',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: c))
        ]),
        const SizedBox(height: 6),
        ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: pct,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(c),
                minHeight: 6)),
      ]),
    );
  }

  Widget _tabKategori() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
            children: SkemaData.kategoriList.map((kat) {
          final sel = _kategori == kat['id'];
          return GestureDetector(
              onTap: () => setState(() => _kategori = kat['id'] as String),
              child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                      color: sel ? _kPrimary.withValues(alpha: 0.1) : _kCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sel ? _kPrimary : Colors.grey.shade300)),
                  child: Text(kat['label'] as String,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                          color: sel ? _kPrimary : _kSubtext))));
        }).toList()),
      );

  Widget _buildRow(_FieldItem item) {
    final inputStr = item.ctrl?.text.trim() ?? '';
    final n = double.tryParse(inputStr) ?? 0;
    final isBawahStandar = inputStr.isNotEmpty &&
        item.isNumber &&
        item.limit != null &&
        n < item.limit!;

    final Color border = isBawahStandar
        ? Colors.orange.shade300
        : inputStr.isEmpty
            ? Colors.grey.shade200
            : Colors.green.shade200;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border)),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _kText)),
          if (isBawahStandar)
            Text('Nilai < ${item.limit} – berisiko gagal syarat nilai minimum',
                style: TextStyle(fontSize: 10, color: Colors.orange.shade700))
        ])),
        const SizedBox(width: 10),
        SizedBox(
            width:
                65, // <-- sedikit dikurangi lebarnya untuk memberi ruang tombol hapus
            child: TextFormField(
                controller: item.ctrl,
                textAlign: TextAlign.center,
                keyboardType: item.isNumber
                    ? const TextInputType.numberWithOptions(decimal: false)
                    : TextInputType.text,
                inputFormatters: item.isNumber
                    ? [
                        FilteringTextInputFormatter.digitsOnly,
                        const _MaxFormatter(100)
                      ]
                    : [],
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isBawahStandar ? Colors.orange.shade800 : _kText),
                decoration: InputDecoration(
                    hintText: item.hint,
                    hintStyle:
                        TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: _kPrimary, width: 2))))),

        // --- TAMPILKAN TOMBOL HAPUS JIKA ADA FUNGSI ONDELETE ---
        if (item.onDelete != null) ...[
          const SizedBox(width: 8),
          InkWell(
              onTap: item.onDelete,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.delete_outline,
                      color: Colors.red.shade700, size: 20)))
        ]
      ]),
    );
  }

  Widget _tombolSimpan() => Row(children: [
        if (_savedData != null) ...[
          OutlinedButton(
              onPressed: _isSaving ? null : () {},
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Icon(Icons.delete_outline, color: Colors.red)),
          const SizedBox(width: 10)
        ],
        Expanded(
            child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _simpan,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(
                    _isSaving ? 'Menyimpan...' : 'Simpan & Proses Kenaikan'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0))),
      ]);

  Widget _emptyState() => Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200)),
          child: Column(children: [
            Icon(Icons.person_search, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('Pilih santri terlebih dahulu',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: _kSubtext)),
            const SizedBox(height: 4),
            Text('Form nilai akan muncul setelah santri dipilih.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400))
          ])));

  void _snack(String msg, Color bg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating));
  void _showPicker(
          String title, List<String> items, Function(String) onSelect) =>
      showModalBottomSheet(
          context: context,
          builder: (_) => Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (_, i) => ListTile(
                      title: Text(items[i], textAlign: TextAlign.center),
                      onTap: () {
                        onSelect(items[i]);
                        Navigator.pop(context);
                      }))));
  void _showSantriPicker() => showModalBottomSheet(
      context: context,
      builder: (_) => Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: _filteredSantri.isEmpty
              ? const Center(child: Text('Tidak ada santri.'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredSantri.length,
                  itemBuilder: (_, i) => ListTile(
                      title: Text(_filteredSantri[i].nama),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _santriId = _filteredSantri[i].id);
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) => _loadNilai());
                      }))));
  void _showDialogHasil(String pesan, bool naik) => showDialog(
      context: context,
      builder: (_) => AlertDialog(
              title: Row(children: [
                Icon(naik ? Icons.check_circle : Icons.cancel,
                    color: naik ? Colors.green : Colors.red),
                const SizedBox(width: 8),
                const Text('Hasil Kenaikan')
              ]),
              content: Text(pesan, style: const TextStyle(height: 1.5)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'))
              ]));
}

class _MaxFormatter extends TextInputFormatter {
  final int max;
  const _MaxFormatter(this.max);
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue updated) {
    if (updated.text.isEmpty) return updated;
    final n = int.tryParse(updated.text);
    return (n == null || n > max) ? old : updated;
  }
}

// --- CLASS_FIELD_ITEM DIUPDATE UNTUK MENERIMA ONDELETE ---
class _FieldItem {
  final String label, hint;
  final TextEditingController? ctrl;
  final bool isNumber;
  final double? limit;
  final VoidCallback? onDelete; // <-- Variabel baru untuk fungsi tombol hapus

  const _FieldItem(this.label, this.hint, this.ctrl, this.isNumber,
      {this.limit, this.onDelete});
}
