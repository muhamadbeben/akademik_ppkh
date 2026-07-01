import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/santri_model.dart';
import '../services/firestore_service.dart';

// ─── Konstanta warna ──────────────────────────────────────────────────────────
const Color _kPrimary  = Color(0xFF5D38F5);
const Color _kSurface  = Color(0xFFFAFAFC);
const Color _kCard     = Colors.white;
const Color _kText     = Color(0xFF1E293B);
const Color _kSubtext  = Color(0xFF64748B);

class NilaiScreen extends StatefulWidget {
  const NilaiScreen({super.key});
  @override
  State<NilaiScreen> createState() => _NilaiScreenState();
}

class _NilaiScreenState extends State<NilaiScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabCtrl;

  // ─── Data ─────────────────────────────────────────────────────────────────────
  List<SantriModel> _allSantri      = [];
  List<SantriModel> _filteredSantri = [];

  bool _isLoading  = true;
  bool _isSaving   = false;
  bool _isLoadNilai = false;
  
  // ROLE BASED ACCESS
  bool _isAdmin    = true; 

  // ─── Pilihan aktif ────────────────────────────────────────────────────────────
  String _kelas         = 'Kelas 1';
  String _tahunAjaran   = '2025/2026';
  String _santriId      = '';
  String _kategori      = 'Absensi & Perilaku';

  // Data dokumen nilai yang sudah ada di Firestore (untuk tahu apakah edit/baru)
  Map<String, dynamic>? _savedData;

  // ─── Master data ──────────────────────────────────────────────────────────────
  final List<String> _kelasList    = ['Kelas sp','Kelas 1','Kelas 2','Kelas 3','Kelas 4'];
  final List<String> _tahunList    = ['2025/2026','2024/2025','2023/2024'];
  final List<String> _absenList    = ['Sakit','Izin','Tanpa Keterangan'];

  final List<Map<String,dynamic>> _kategoriList = [
    {'id':'Absensi & Perilaku','label':'Absensi & Sikap'},
    {'id':'Hafalan Kitab',     'label':'Hafalan'},
    {'id':'UTS',               'label':'UTS'},
    {'id':'UAS',               'label':'UAS'},
  ];

  // Mapel per kelas
  final Map<String,List<String>> _mapelMap = {
    'Kelas sp': [
      'BTQ (Tulis)','Tashrif Bina shahih (Lisan)','Praktek Ibadah (Lisan)',
      'Aqoidul Iman (Lisan)','Tahsin Al-Quran','Hafalan Kitab: Aqoidul Iman',
    ],
    'Kelas 1': [
      'Awamil (Tulis)','Tajwid (Tulis)','Safinah (Tulis)','Jurmiyah (Tulis)',
      'Tashrif Bina Shahih (Lisan)','Tahsin Al-Qur\u02bcaan',
      'Qira\u02bcatul Kutub (Safinah)','Hafalan Kitab: Safinah & Awamil',
    ],
    'Kelas 2': [
      'Kaelani (Tulis)','Nastainu (Tulis)','Imrity (Tulis)','Jurmiyah (Lisan)',
      'Qowaid Fiqhiyah (Lisan)','Ngelal \u2013 Ngasal (Lisan)',
      'Tahsin Al-Qur\u02bcaan','Qira\u02bcatul Kutub (Riyadul Badiah)',
      'Hafalan Kitab: Nadhom Imrity',
    ],
    'Kelas 3': [
      'Samar Qondi (Tulis)','Jauhar Maknun (Tulis)','Qowaid Fiqhiyah (Lisan)',
      'Alfiyyah (Lisan)','Tahsin Al-Quran',
      'Qiro\u02bcatul Kutub (Fathul Mu\u02bcin)','Hafalan Kitab: Nadhom Alfiyyah (Bab 1)',
    ],
    'Kelas 4': [
      'Samar Qondi (Tulis)','Jauhar Maknun (Tulis)','Qowaid Fiqhiyah (Lisan)',
      'Alfiyyah (Lisan)','Tahsin Al-Quran',
      'Qiro\u02bcatul Kutub (Fathul Mu\u02bcin)','Hafalan Kitab: Nadhom Alfiyyah (Khatam)',
    ],
  };

  // ─── Controllers ──────────────────────────────────────────────────────────────
  // Struktur: { santriId: { kategoriKey: { fieldKey: controller } } }
  final Map<String,Map<String,Map<String,TextEditingController>>> _ctrl = {};

  // ─── Getters ──────────────────────────────────────────────────────────────────
  List<String> get _mapelKelas   => _mapelMap[_kelas] ?? [];
  List<String> get _mapelHafalan => _mapelKelas
      .where((m) => m.toLowerCase().contains('(lisan)') || m.toLowerCase().contains('hafalan'))
      .toList();

  String get _docIdNilai {
    final t = _tahunAjaran.replaceAll('/', '-');
    final k = _kelas.replaceAll(' ', '');
    return '${_santriId}_${t}_$k';
  }

  String get _docIdRapor {
    final t = _tahunAjaran.replaceAll('/', '');
    final k = _kelas.replaceAll(' ', '');
    return '${_santriId}_${k}_$t';
  }

  SantriModel? get _santriTerpilih =>
      _filteredSantri.where((s) => s.id == _santriId).firstOrNull;

  double get _progressKelengkapan {
    if (_santriId.isEmpty) return 0.0;
    int total = 0, terisi = 0;

    void cek(String kat, String key) {
      total++;
      final v = _ctrl[_santriId]?[kat]?[key]?.text.trim() ?? '';
      if (v.isNotEmpty && v != '-') terisi++;
    }

    cek('Nilai Kehadiran', 'Global');
    cek('Nilai Perilaku',  'Global');
    
    for (var a in _absenList) {
      cek('Ketidakhadiran', a);
    }
    for (var m in _mapelKelas) {
      cek('UTS', m);
    }
    for (var m in _mapelKelas) {
      cek('UAS', m);
    }
    for (var m in _mapelHafalan) {
      cek('Hafalan Kitab', m);
    }

    return total == 0 ? 0 : terisi / total;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _checkRoleAndLoadSantri();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    for (final k in _ctrl.values) {
      for (final m in k.values) {
        for (final c in m.values) {
          c.dispose();
        }
      }
    }
    _ctrl.clear();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // STEP 1 — CEK ROLE LALU LOAD SANTRI
  // ══════════════════════════════════════════════════════════════════════════════
  Future<void> _checkRoleAndLoadSantri() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docUser = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (docUser.exists) {
          final userData = docUser.data()!;
          final String role = (userData['role'] ?? '').toString().toLowerCase();

          if (role == 'guru') {
            _isAdmin = false;
            _kelas = userData['kelas'] ?? 'Kelas 1'; 
          } else {
            _isAdmin = true;
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
      final list  = await FirestoreService.getSantriList();
      _allSantri  = list
          .where((s) => s.status.toLowerCase().contains('aktif'))
          .toList();
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
          .where((s) => s.kelas.toLowerCase().trim() == _kelas.toLowerCase().trim())
          .toList()
        ..sort((a, b) => a.nama.compareTo(b.nama));

      if (!_filteredSantri.any((s) => s.id == _santriId)) {
        _santriId  = '';
        _savedData = null;
        _bersihkanCtrl();
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // CONTROLLER MANAGEMENT 
  // ══════════════════════════════════════════════════════════════════════════════
  void _siapkanCtrl(String id) {
    final sudahAda   = _ctrl.containsKey(id);
    final keysLama   = _ctrl[id]?['UTS']?.keys.toSet() ?? <String>{};
    final keysBaru   = _mapelKelas.toSet();
    final mapelSama  = keysLama.containsAll(keysBaru) && keysBaru.containsAll(keysLama);

    if (sudahAda && mapelSama) {
      _bersihkanCtrl();
      return;
    }

    final oldCtrl = _ctrl[id];
    _ctrl.remove(id);

    _ctrl[id] = {
      'Nilai Kehadiran': {'Global': _buatCtrl()},
      'Nilai Perilaku':  {'Global': _buatCtrl()},
      'Ketidakhadiran':  {for (var a in _absenList)    a: _buatCtrl()},
      'UTS':             {for (var m in _mapelKelas)   m: _buatCtrl()},
      'UAS':             {for (var m in _mapelKelas)   m: _buatCtrl()},
      'Hafalan Kitab':   {for (var m in _mapelHafalan) m: _buatCtrl()},
    };

    if (oldCtrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldCtrl.forEach((_, m) => m.forEach((_, c) => c.dispose()));
      });
    }
  }

  TextEditingController _buatCtrl() =>
      TextEditingController()..addListener(() { if (mounted) setState(() {}); });

  void _bersihkanCtrl() {
    if (_santriId.isEmpty) {
      _ctrl.forEach((_, k) => k.forEach((_, m) => m.forEach((_, c) => c.clear())));
    } else {
      _ctrl[_santriId]?.forEach((_, m) => m.forEach((_, c) => c.clear()));
    }
  }

  void _isiCtrl(String kat, String key, dynamic val) {
    if (val == null) return;
    final n = val is num ? val.toDouble() : double.tryParse(val.toString());
    if (n == null || n == 0) return;
    _ctrl[_santriId]?[kat]?[key]?.text = n.toStringAsFixed(0);
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // STEP 2 — LOAD NILAI DARI FIRESTORE (setelah pilih santri)
  // ══════════════════════════════════════════════════════════════════════════════
  Future<void> _loadNilai() async {
    if (_santriId.isEmpty) return;
    _siapkanCtrl(_santriId);

    setState(() => _isLoadNilai = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('nilai').doc(_docIdNilai).get();
      if (!mounted) return;

      if (snap.exists && snap.data() != null) {
        final d = snap.data()!;
        _savedData = d;

        _isiCtrl('Nilai Kehadiran', 'Global', d['nilai_kehadiran']);
        _isiCtrl('Nilai Perilaku',  'Global', d['nilai_perilaku']);

        if (d['ketidakhadiran'] is Map) {
          (d['ketidakhadiran'] as Map).forEach((k, v) {
            _ctrl[_santriId]?['Ketidakhadiran']?[k]?.text =
                (v == 0) ? '-' : v.toString();
          });
        }

        void isiMapValues(String field, String kat) {
          if (d[field] is Map) {
            (d[field] as Map).forEach((k, v) {
              final n = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
              _ctrl[_santriId]?[kat]?[k]?.text = n == 0 ? '' : n.toStringAsFixed(0);
            });
          }
        }
        isiMapValues('uts',           'UTS');
        isiMapValues('uas',           'UAS');
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

  // ══════════════════════════════════════════════════════════════════════════════
  // STEP 3 — VALIDASI
  // ══════════════════════════════════════════════════════════════════════════════
  String? _validasi() {
    bool kosong(String kat, String key) =>
        _ctrl[_santriId]?[kat]?[key]?.text.trim().isEmpty ?? true;

    if (kosong('Nilai Kehadiran', 'Global')) return 'Nilai Kehadiran belum diisi.';
    if (kosong('Nilai Perilaku',  'Global')) return 'Nilai Perilaku belum diisi.';

    for (final a in _absenList) {
      if (kosong('Ketidakhadiran', a)) return 'Absensi ($a) belum diisi.\nIsi tanda "-" jika nihil.';
    }
    for (final m in _mapelKelas) {
      if (kosong('UTS', m)) return 'UTS — $m belum diisi.';
    }
    for (final m in _mapelKelas) {
      if (kosong('UAS', m)) return 'UAS — $m belum diisi.';
    }
    for (final m in _mapelHafalan) {
      if (kosong('Hafalan Kitab', m)) return 'Hafalan — $m belum diisi.';
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // STEP 4 — HITUNG RATA-RATA BERBOBOT
  // ══════════════════════════════════════════════════════════════════════════════
  double _hitungRataRata({Map<String,dynamic>? fromDoc}) {
    double kh = 0, pr = 0, avgUts = 0, avgUas = 0, avgH = 0;

    if (fromDoc != null) {
      kh     = (fromDoc['nilai_kehadiran'] as num?)?.toDouble() ?? 0;
      pr     = (fromDoc['nilai_perilaku']  as num?)?.toDouble() ?? 0;
      avgUts = _avgMapDyn(fromDoc['uts']);
      avgUas = _avgMapDyn(fromDoc['uas']);
      avgH   = _avgMapDyn(fromDoc['hafalan_kitab']);
    } else if (_santriId.isNotEmpty) {
      kh     = double.tryParse(_ctrl[_santriId]?['Nilai Kehadiran']?['Global']?.text ?? '') ?? 0;
      pr     = double.tryParse(_ctrl[_santriId]?['Nilai Perilaku']?['Global']?.text  ?? '') ?? 0;
      avgUts = _avgCtrl(_ctrl[_santriId]?['UTS']);
      avgUas = _avgCtrl(_ctrl[_santriId]?['UAS']);
      avgH   = _avgCtrl(_ctrl[_santriId]?['Hafalan Kitab']);
    }

    return (kh * 0.05) + (pr * 0.05) + (avgUts * 0.20) + (avgUas * 0.40) + (avgH * 0.30);
  }

  double _avgMapDyn(dynamic m) {
    if (m is! Map) return 0;
    double s = 0; int c = 0;
    m.forEach((_, v) { s += (v as num?)?.toDouble() ?? 0; c++; });
    return c > 0 ? s / c : 0;
  }

  double _avgCtrl(Map<String,TextEditingController>? m) {
    if (m == null) return 0;
    double s = 0; int c = 0;
    m.forEach((_, ctrl) {
      final n = double.tryParse(ctrl.text);
      if (n != null && n > 0) { s += n; c++; }
    });
    return c > 0 ? s / c : 0;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // STEP 5 — SIMPAN KE FIRESTORE + PROSES KENAIKAN KELAS
  // ══════════════════════════════════════════════════════════════════════════════
  Future<void> _simpan() async {
    if (_santriId.isEmpty) return;

    final pesanError = _validasi();
    if (pesanError != null) {
      _snack('⚠️ $pesanError', Colors.orange.shade800);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final santri = _santriTerpilih;
      final namaSantri = santri?.nama ?? _savedData?['namaSantri']?.toString() ?? 'Santri';

      final kehadiran = double.tryParse(_ctrl[_santriId]!['Nilai Kehadiran']!['Global']!.text) ?? 0.0;
      final perilaku  = double.tryParse(_ctrl[_santriId]!['Nilai Perilaku']!['Global']!.text)  ?? 0.0;

      final Map<String,int>    ketidakhadiran = {};
      final Map<String,double> uts     = {};
      final Map<String,double> uas     = {};
      final Map<String,double> hafalan = {};
      int   bawah70 = 0; 

      _ctrl[_santriId]!['Ketidakhadiran']!.forEach((k, c) {
        final t = c.text.trim();
        ketidakhadiran[k] = (t == '-' || t.isEmpty) ? 0 : (int.tryParse(t) ?? 0);
      });
      
      _ctrl[_santriId]!['UTS']!.forEach((k, c) => uts[k] = double.tryParse(c.text) ?? 0.0);
      
      _ctrl[_santriId]!['UAS']!.forEach((k, c) {
        final n = double.tryParse(c.text) ?? 0.0;
        uas[k] = n;
        if (n < 70) bawah70++;
      });
      
      _ctrl[_santriId]!['Hafalan Kitab']!.forEach((k, c) => hafalan[k] = double.tryParse(c.text) ?? 0.0);

      final avgUts    = _avgCtrl(_ctrl[_santriId]!['UTS']);
      final avgUas    = _avgCtrl(_ctrl[_santriId]!['UAS']);
      final avgHafal  = _avgCtrl(_ctrl[_santriId]!['Hafalan Kitab']);
      final nilaiAkhir = (kehadiran * 0.05) + (perilaku * 0.05) + (avgUts * 0.20) + (avgUas * 0.40) + (avgHafal * 0.30);
      final predikat   = _getPredikat(nilaiAkhir);

      final nilaiRef = FirebaseFirestore.instance.collection('nilai').doc(_docIdNilai);
      final payloadNilai = {
        'id':              nilaiRef.id,
        'santriId':        _santriId,
        'id_santri':       _santriId,
        'namaSantri':      namaSantri,
        'kelas':           _kelas,
        'semester':        _kelas,
        'tahunAjaran':     _tahunAjaran,
        'tahun_ajaran':    _tahunAjaran,
        'nilai_kehadiran': kehadiran,
        'nilai_perilaku':  perilaku,
        'ketidakhadiran':  ketidakhadiran,
        'uts':             uts,
        'uas':             uas,
        'hafalan_kitab':   hafalan,
        'rata_rata_uts':   avgUts,
        'rata_rata_uas':   avgUas,
        'rata_rata_hafalan': avgHafal,
        'nilai_akhir':     nilaiAkhir,
        'predikat':        predikat,
        'updatedAt':       FieldValue.serverTimestamp(),
      };

      final raporRef  = FirebaseFirestore.instance.collection('rapor').doc(_docIdRapor);
      final statusKenaikan = bawah70 >= 3 ? 'TIDAK NAIK KELAS' : 'NAIK KELAS';
      final payloadRapor = {
        'id':              raporRef.id,
        'santriId':        _santriId,
        'namaSantri':      namaSantri,
        'kelas':           _kelas,
        'semester':        _kelas,
        'tahunAjaran':     _tahunAjaran,
        'nilai_kehadiran': kehadiran,
        'nilai_perilaku':  perilaku,
        'ketidakhadiran':  ketidakhadiran,
        'uts':             uts,
        'uas':             uas,
        'hafalan_kitab':   hafalan,
        'rata_rata_uts':   avgUts,
        'rata_rata_uas':   avgUas,
        'rata_rata_hafalan': avgHafal,
        'nilai_akhir':     nilaiAkhir,
        'predikat':        predikat,
        'status_kenaikan': statusKenaikan,
        'updatedAt':       FieldValue.serverTimestamp(),
      };

      final batch = FirebaseFirestore.instance.batch();
      batch.set(nilaiRef, payloadNilai, SetOptions(merge: true));
      batch.set(raporRef, payloadRapor, SetOptions(merge: true));

      String pesanStatus;
      bool   naik = bawah70 < 3;

      if (naik) {
        final next = _kelasBerikutnya(_kelas);
        final santriRef = FirebaseFirestore.instance.collection('santri').doc(_santriId);
        batch.update(santriRef, {
          'kelas':    next['kelas'],
          'semester': next['kelas'],
          'status':   next['status'],
        });

        final idx = _allSantri.indexWhere((s) => s.id == _santriId);
        if (idx != -1) {
          _allSantri[idx] = _allSantri[idx].copyWith(kelas: next['kelas']!, status: next['status']!);
        }

        pesanStatus = next['kelas'] == 'Lulus'
            ? '🎉 $namaSantri telah LULUS!\nRapor tersimpan otomatis.'
            : '✅ $namaSantri NAIK ke ${next["kelas"]}!\nRapor tersimpan otomatis.';
      } else {
        pesanStatus = '⚠️ $namaSantri TIDAK NAIK KELAS.\n'
            '$bawah70 mapel UAS di bawah 70.\nRapor tersimpan otomatis.';
      }

      await batch.commit();

      setState(() {
        _santriId  = '';
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

  Map<String,String> _kelasBerikutnya(String kelas) {
    const map = {
      'kelas sp': {'kelas': 'Kelas 1', 'status': 'Aktif'},
      'kelas 1':  {'kelas': 'Kelas 2', 'status': 'Aktif'},
      'kelas 2':  {'kelas': 'Kelas 3', 'status': 'Aktif'},
      'kelas 3':  {'kelas': 'Kelas 4', 'status': 'Aktif'},
      'kelas 4':  {'kelas': 'Lulus',   'status': 'Lulus'},
    };
    return map[kelas.toLowerCase().trim()] ?? {'kelas': kelas, 'status': 'Aktif'};
  }

  String _getPredikat(double n) {
    if (n >= 90) return 'A (Mumtaz)';
    if (n >= 80) return 'B (Jayyid Jiddan)';
    if (n >= 70) return 'C (Jayyid)';
    if (n >= 60) return 'D (Maqbul)';
    return 'E (Rasib)';
  }

  Future<void> _hapus() async {
    if (_santriId.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Hapus Data Nilai'),
        content: const Text('Seluruh nilai & rapor santri ini akan dihapus. Lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _isSaving = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.delete(FirebaseFirestore.instance.collection('nilai').doc(_docIdNilai));
      batch.delete(FirebaseFirestore.instance.collection('rapor').doc(_docIdRapor));
      await batch.commit();
      _snack('✅ Data nilai & rapor dihapus.', Colors.green);
      setState(() { _santriId = ''; _savedData = null; });
      _filterSantri();
    } catch (e) { _snack('Gagal hapus: $e', Colors.red); }
    finally { if (mounted) setState(() => _isSaving = false); }
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: bg,
      behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 4)));
  }

  void _showDialogHasil(String pesan, bool naik) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(naik ? Icons.emoji_events_rounded : Icons.warning_rounded, color: naik ? Colors.amber : Colors.orange),
          const SizedBox(width: 8),
          const Text('Status Kenaikan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(pesan, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.6)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
            child: const Row(children: [
              Icon(Icons.receipt_long_rounded, color: Colors.green, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Rapor siap dicetak di menu Cetak Rapor.', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600))),
            ]),
          ),
        ]),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white), child: const Text('OK'))],
      ),
    );
  }

  void _showPicker(String title, List<String> items, Function(String) onSelect) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(items[i], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              onTap: () { setState(() => onSelect(items[i])); Navigator.pop(context); },
            ),
          )),
        ]),
      ),
    );
  }

  void _showSantriPicker() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Pilih Santri', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: _filteredSantri.isEmpty
                ? Center(child: Text('Tidak ada santri aktif di $_kelas.', style: const TextStyle(color: _kSubtext, fontSize: 12)))
                : ListView.builder(
                    itemCount: _filteredSantri.length,
                    itemBuilder: (_, i) {
                      final s = _filteredSantri[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _kPrimary.withValues(alpha: 0.1),
                          child: Text(s.nama[0], style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(s.nama, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _santriId = s.id);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _loadNilai();
                          });
                        },
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: _kText),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Kelola Nilai Santri',
            style: TextStyle(color: _kText, fontWeight: FontWeight.bold, fontSize: 16)),
        bottom: TabBar(
          controller: _tabCtrl, labelColor: _kPrimary,
          unselectedLabelColor: Colors.grey, indicatorColor: _kPrimary,
          tabs: const [
            Tab(icon: Icon(Icons.edit_note, size: 20), text: 'Input Nilai'),
            Tab(icon: Icon(Icons.analytics_outlined, size: 20), text: 'Rekap Kelas'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : TabBarView(
              controller: _tabCtrl, 
              children: [
                _buildTabInput(),
                _buildTabRekap(),
              ],
            ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB INPUT NILAI
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildTabInput() {
    final namaAktif = _filteredSantri
        .where((s) => s.id == _santriId)
        .map((s) => s.nama)
        .firstOrNull ?? 'Pilih Santri...';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── LANGKAH 1: Kelas & Tahun Ajaran ─────────────────────────────────
        _stepLabel('1', 'Tahun Ajaran & Kelas'),
        const SizedBox(height: 8),
        Row(children: [
          _dropTile('Tahun Ajaran', _tahunAjaran, () =>
              _showPicker('Tahun Ajaran', _tahunList, (v) {
                _tahunAjaran = v;
                if (_santriId.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _loadNilai();
                  });
                }
              })),
          const SizedBox(width: 8),
          
          if (_isAdmin)
            _dropTile('Kelas', _kelas, () => _showPicker('Pilih Kelas', _kelasList, (v) {
              _kelas = v;
              _filterSantri();
            }))
          else
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Kelas Anda', style: TextStyle(fontSize: 10, color: _kSubtext)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Expanded(child: Text(_kelas, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54), overflow: TextOverflow.ellipsis)),
                    const Icon(Icons.lock, size: 14, color: Colors.grey),
                  ]),
                ]),
              ),
            ),
        ]),

        // ── LANGKAH 2: Pilih Santri ──────────────────────────────────────────
        const SizedBox(height: 20),
        _stepLabel('2', 'Pilih Santri'),
        const SizedBox(height: 8),
        _santriTile(namaAktif),

        // ── LANGKAH 3: Input Nilai ───────────────────────────────────────────
        if (_santriId.isNotEmpty) ...[
          const SizedBox(height: 20),
          _stepLabel('3', 'Input Nilai'),
          const SizedBox(height: 8),

          _progressBar(),
          const SizedBox(height: 10),

          _tabKategori(),
          const SizedBox(height: 10),

          if (_isLoadNilai)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: _kPrimary)))
          else
            _formNilai(),

          // ── LANGKAH 4: Simpan ─────────────────────────────────────────────
          const SizedBox(height: 24),
          _stepLabel('4', 'Simpan & Proses Kenaikan'),
          const SizedBox(height: 8),
          _tombolSimpan(),
        ] else
          _emptyState(),
      ]),
    );
  }

  Widget _stepLabel(String n, String title) => Row(children: [
    Container(width: 24, height: 24, decoration: BoxDecoration(color: _kPrimary, borderRadius: BorderRadius.circular(6)), child: Center(child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))),
    const SizedBox(width: 8),
    Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kText))),
  ]);

  Widget _dropTile(String label, String value, VoidCallback onTap) => Expanded(
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: _kSubtext)),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kText), overflow: TextOverflow.ellipsis)),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: _kSubtext),
          ]),
        ]),
      ),
    ),
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
          border: Border.all(color: ada ? _kPrimary : Colors.grey.shade200)
        ),
        child: Row(children: [
          CircleAvatar(radius: 18, backgroundColor: ada ? _kPrimary : Colors.grey.shade200, child: Icon(Icons.person, size: 18, color: ada ? Colors.white : _kSubtext)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Fokus Santri', style: TextStyle(fontSize: 10, color: _kSubtext)),
            Text(nama, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ada ? _kPrimary : _kSubtext)),
          ])),
          _isLoadNilai ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary)) : Icon(Icons.arrow_drop_down, color: ada ? _kPrimary : _kSubtext),
        ]),
      ),
    );
  }

  Widget _progressBar() {
    final pct    = _progressKelengkapan;
    final pctInt = (pct * 100).toInt();
    final Color c = pct < 0.5 ? Colors.orange : pct < 1.0 ? Colors.amber.shade700 : Colors.green;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Kelengkapan Nilai', style: TextStyle(fontSize: 11, color: _kSubtext, fontWeight: FontWeight.w600)),
          Text('$pctInt%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(c), minHeight: 6)),
        if (pct == 1.0) ...[
          const SizedBox(height: 6),
          const Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 14), SizedBox(width: 4), Text('Semua nilai sudah lengkap!', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600))]),
        ],
      ]),
    );
  }

  Widget _tabKategori() => SingleChildScrollView(
    scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(),
    child: Row(children: _kategoriList.map((kat) {
      final sel     = _kategori == kat['id'];
      final adaKosong = _adaFieldKosong(kat['id'] as String);
      return GestureDetector(
        onTap: () => setState(() => _kategori = kat['id'] as String),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: sel ? _kPrimary.withValues(alpha: 0.1) : _kCard, 
            borderRadius: BorderRadius.circular(10), 
            border: Border.all(color: sel ? _kPrimary : Colors.grey.shade300)
          ),
          child: Row(children: [
            Text(kat['label'] as String, style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.w500, color: sel ? _kPrimary : _kSubtext)),
            if (adaKosong) ...[const SizedBox(width: 4), Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle))],
          ]),
        ),
      );
    }).toList()),
  );

  bool _adaFieldKosong(String katId) {
    if (_santriId.isEmpty) return false;
    bool c(String kat, String key) => _ctrl[_santriId]?[kat]?[key]?.text.trim().isEmpty ?? true;
    switch (katId) {
      case 'Absensi & Perilaku': return c('Nilai Kehadiran','Global') || c('Nilai Perilaku','Global') || _absenList.any((a) => c('Ketidakhadiran', a));
      case 'Hafalan Kitab': return _mapelHafalan.any((m) => c('Hafalan Kitab', m));
      case 'UTS':           return _mapelKelas.any((m) => c('UTS', m));
      case 'UAS':           return _mapelKelas.any((m) => c('UAS', m));
      default:              return false;
    }
  }

  Widget _formNilai() {
    List<_FieldItem> items = [];
    switch (_kategori) {
      case 'Absensi & Perilaku':
        items = [
          _FieldItem('Nilai Kehadiran',       '0–100', _ctrl[_santriId]?['Nilai Kehadiran']?['Global'], true),
          _FieldItem('Nilai Perilaku / Sikap','0–100', _ctrl[_santriId]?['Nilai Perilaku']?['Global'],  true),
          ..._absenList.map((a) => _FieldItem('Ketidakhadiran: $a', '- jika nihil', _ctrl[_santriId]?['Ketidakhadiran']?[a], false)),
        ]; break;
      case 'Hafalan Kitab':
        items = _mapelHafalan.map((m) => _FieldItem(m, '0–100', _ctrl[_santriId]?['Hafalan Kitab']?[m], true)).toList(); break;
      case 'UTS':
        items = _mapelKelas.map((m) => _FieldItem(m, '0–100', _ctrl[_santriId]?['UTS']?[m], true)).toList(); break;
      case 'UAS':
        items = _mapelKelas.map((m) {
          final n       = double.tryParse(_ctrl[_santriId]?['UAS']?[m]?.text ?? '') ?? 0;
          final sudahIsi = _ctrl[_santriId]?['UAS']?[m]?.text.trim().isNotEmpty ?? false;
          return _FieldItem(m, '0–100', _ctrl[_santriId]?['UAS']?[m], true, warn: sudahIsi && n < 70);
        }).toList(); break;
    }

    return Column(children: [
      Container(
        margin: const EdgeInsets.only(bottom: 8), 
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), 
        decoration: BoxDecoration(color: _kPrimary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)), 
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
          children: [
            Text('Form: $_kategori', style: const TextStyle(color: _kPrimary, fontSize: 12, fontWeight: FontWeight.w600)), 
            Text('Rata-rata: ${_hitungRataRata().toStringAsFixed(1)}', style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold))
          ]
        )
      ),
      if (_kategori == 'UAS')
        Container(
          margin: const EdgeInsets.only(bottom: 8), 
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)), 
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 16), 
              const SizedBox(width: 8), 
              Expanded(child: Text('Santri TIDAK NAIK jika ≥ 3 mapel UAS di bawah 70.', style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w500)))
            ]
          )
        ),
      ...items.map(_buildRow),
    ]);
  }

  Widget _buildRow(_FieldItem item) {
    final empty  = item.ctrl?.text.trim().isEmpty ?? true;
    final Color border = item.warn ? Colors.orange.shade300 : empty ? Colors.grey.shade200 : Colors.green.shade200;

    return Container(
      margin: const EdgeInsets.only(bottom: 8), 
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), 
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: border)),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              Text(item.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText)), 
              if (item.warn) Text('Nilai < 70 – berisiko tidak naik kelas', style: TextStyle(fontSize: 10, color: Colors.orange.shade700))
            ]
          )
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 72, 
          child: TextFormField(
            controller: item.ctrl, textAlign: TextAlign.center, 
            keyboardType: item.isNumber ? const TextInputType.numberWithOptions(decimal: false) : TextInputType.text, 
            inputFormatters: item.isNumber ? [FilteringTextInputFormatter.digitsOnly, const _MaxFormatter(100)] : [], 
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: item.warn ? Colors.orange.shade800 : _kText), 
            decoration: InputDecoration(
              hintText: item.hint, hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400), 
              isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4), 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)), 
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)), 
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kPrimary, width: 2))
            )
          )
        ),
      ]),
    );
  }

  Widget _tombolSimpan() => Row(children: [
    if (_savedData != null) ...[
      OutlinedButton(
        onPressed: _isSaving ? null : _hapus, 
        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), 
        child: const Icon(Icons.delete_outline, color: Colors.red)
      ), 
      const SizedBox(width: 10)
    ],
    Expanded(
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _simpan, 
        icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_rounded, size: 18), 
        label: Text(_isSaving ? 'Menyimpan...' : 'Simpan & Proses Kenaikan'), 
        style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0)
      )
    ),
  ]);

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Container(
      width: double.infinity, padding: const EdgeInsets.all(32), 
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)), 
      child: Column(
        children: [
          Icon(Icons.person_search, size: 48, color: Colors.grey.shade300), 
          const SizedBox(height: 12), 
          const Text('Pilih santri terlebih dahulu', style: TextStyle(fontWeight: FontWeight.bold, color: _kSubtext)), 
          const SizedBox(height: 4), 
          Text('Form nilai akan muncul setelah santri dipilih.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade400))
        ]
      )
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB REKAP KELAS
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildTabRekap() {
    return Column(
      children: [
        Container(
          color: Colors.white, 
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), 
          child: Row(
            children: [
              _dropTile('Tahun Ajaran', _tahunAjaran, () => _showPicker('Tahun Ajaran', _tahunList, (v) => setState(() => _tahunAjaran = v))),
              const SizedBox(width: 8),
              if (_isAdmin)
                _dropTile('Kelas', _kelas, () => _showPicker('Pilih Kelas', _kelasList, (v) => setState(() => _kelas = v)))
              else
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        const Text('Kelas Anda', style: TextStyle(fontSize: 10, color: _kSubtext)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(child: Text(_kelas, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54), overflow: TextOverflow.ellipsis)),
                            const Icon(Icons.lock, size: 14, color: Colors.grey),
                          ]
                        ),
                      ]
                    ),
                  ),
                ),
            ]
          )
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('nilai').where('kelas', isEqualTo: _kelas).where('tahunAjaran', isEqualTo: _tahunAjaran).snapshots(),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _kPrimary));
              
              final docs = snap.data?.docs ?? [];
              
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min, 
                    children: [
                      Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300), 
                      const SizedBox(height: 12), 
                      Text('Belum ada data nilai\n$_kelas · TA $_tahunAjaran', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, height: 1.5))
                    ]
                  )
                );
              }

              final sorted = docs.toList()..sort((a, b) {
                final ra = _hitungRataRata(fromDoc: a.data() as Map<String,dynamic>);
                final rb = _hitungRataRata(fromDoc: b.data() as Map<String,dynamic>);
                return rb.compareTo(ra);
              });

              final rataList  = sorted.map((d) => _hitungRataRata(fromDoc: d.data() as Map<String,dynamic>)).toList();
              final rataKelas = rataList.reduce((a, b) => a + b) / rataList.length;
              final tertinggi = rataList.reduce((a, b) => a > b ? a : b);
              final terendah  = rataList.reduce((a, b) => a < b ? a : b);

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                itemCount: sorted.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) return _headerStatistik(rataKelas, tertinggi, terendah, sorted.length);
                  
                  final d    = sorted[i-1].data() as Map<String,dynamic>;
                  final rata = _hitungRataRata(fromDoc: d);
                  final sId  = d['santriId'] ?? '';
                  final nama = (d['namaSantri'] as String?)?.isNotEmpty == true ? d['namaSantri'] as String : 'Santri';
                  final Color warna = _warnaRata(rata);

                  Widget avatar = i <= 3 
                    ? SizedBox(width: 44, child: Center(child: Text(['🥇','🥈','🥉'][i-1], style: const TextStyle(fontSize: 22)))) 
                    : CircleAvatar(radius: 22, backgroundColor: warna.withValues(alpha: 0.1), child: Text(nama[0], style: TextStyle(color: warna, fontWeight: FontWeight.bold)));

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10), 
                    decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))]),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                      leading: avatar, 
                      title: Text(nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _kText)), 
                      subtitle: Row(
                        children: [
                          Icon(Icons.star_rounded, size: 13, color: warna), 
                          const SizedBox(width: 3), 
                          Text('${rata.toStringAsFixed(1)} · ${_getPredikat(rata)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: warna))
                        ]
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_note, color: Colors.blue), 
                        tooltip: 'Edit nilai',
                        onPressed: () async {
                          setState(() => _santriId = sId);
                          _tabCtrl.animateTo(0);
                          WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _loadNilai(); });
                          _snack('Data $nama dimuat. Silakan edit.', Colors.blue);
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _headerStatistik(double rata, double tinggi, double rendah, int total) => Container(
    margin: const EdgeInsets.only(bottom: 14), 
    padding: const EdgeInsets.all(14), 
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [_kPrimary, _kPrimary.withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight), 
      borderRadius: BorderRadius.circular(12)
    ), 
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        Text('Statistik $_kelas · $_tahunAjaran', style: const TextStyle(color: Colors.white70, fontSize: 11)), 
        const SizedBox(height: 8), 
        Row(
          children: [
            _sBox('Rata-rata', rata.toStringAsFixed(1), Colors.white), 
            _sBox('Tertinggi', tinggi.toStringAsFixed(1), Colors.greenAccent), 
            _sBox('Terendah', rendah.toStringAsFixed(1), Colors.orangeAccent), 
            _sBox('Total', '$total santri', Colors.lightBlueAccent)
          ]
        )
      ]
    )
  );

  Widget _sBox(String label, String val, Color c) => Expanded(
    child: Column(
      children: [
        Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c), overflow: TextOverflow.ellipsis), 
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: Colors.white70))
      ]
    )
  );

  Color _warnaRata(double r) {
    if (r >= 80) return Colors.green.shade700;
    if (r >= 70) return Colors.blue.shade700;
    if (r >= 60) return Colors.orange.shade700;
    return Colors.red.shade700;
  }
}

class _MaxFormatter extends TextInputFormatter {
  final int max;
  const _MaxFormatter(this.max);
  
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue updated) {
    if (updated.text.isEmpty) return updated;
    final n = int.tryParse(updated.text);
    if (n == null || n > max) return old;
    return updated;
  }
}

class _FieldItem {
  final String label, hint;
  final TextEditingController? ctrl;
  final bool isNumber, warn;
  const _FieldItem(this.label, this.hint, this.ctrl, this.isNumber, {this.warn = false});
}