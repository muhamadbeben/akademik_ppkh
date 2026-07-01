// File: lib/screens/rapor_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/santri_model.dart';
import '../models/rapor_model.dart';
import '../services/firestore_service.dart';
import '../services/rapor_service.dart';

const Color _kPrimary = Color(0xFF3C21F7);
const Color _kSurface = Color(0xFFFAFAFC);

enum _Sumber { raporBaru, raporLama, generated }

class _RaporItem {
  final RaporModel rapor;
  final _Sumber sumber;
  _RaporItem({required this.rapor, required this.sumber});
}

class RaporScreen extends StatefulWidget {
  final String? santriId;
  final String? userRole;
  
  const RaporScreen({super.key, this.santriId, this.userRole});
  
  @override
  State<RaporScreen> createState() => _RaporScreenState();
}

class _RaporScreenState extends State<RaporScreen> {
  // ─── State ────────────────────────────────────────────────────────────────────
  List<SantriModel> _santriList     = [];
  bool _isLoading                   = true;
  bool _isWaliSantriMode            = false;
  
  String _selectedKelas  = 'Semua Kelas';
  String _selectedTahun  = '2025/2026';

  Future<List<_RaporItem>>? _raporFuture;

  final List<String> _kelasList  = ['Semua Kelas','Kelas sp','Kelas 1','Kelas 2','Kelas 3','Kelas 4'];
  final List<String> _tahunList  = ['2025/2026','2024/2025','2023/2024'];
  final List<String> _semuaKelas = ['Kelas sp','Kelas 1','Kelas 2','Kelas 3','Kelas 4'];

  // Urutan tampilan kelas (untuk sorting)
  final List<String> _urutanKelas = ['kelas sp','kelas 1','kelas 2','kelas 3','kelas 4'];

  // ─── Init ─────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadAwal();
  }

  Future<void> _loadAwal() async {
    setState(() => _isLoading = true);
    try {
      String? targetId = widget.santriId;
      String? role     = widget.userRole;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users').doc(user.uid).get();
        if (doc.exists) {
          final d  = doc.data();
          role     ??= d?['role']?.toString().trim();
          targetId ??= d?['santriId']?.toString().trim();
        }
      }

      if (role?.toLowerCase().trim() == 'walisantri') {
        _isWaliSantriMode = true;
        if (targetId != null && targetId.isNotEmpty) {
          final anak = await FirestoreService.getSantriById(targetId);
          if (anak != null) _santriList = [anak];
        }
      } else {
        _isWaliSantriMode = false;
        _santriList = await FirestoreService.getSantriList();
      }

      _refresh();
    } catch (e) {
      debugPrint('_loadAwal error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _refresh() => setState(() { _raporFuture = _fetchSemuaRapor(); });

  // ══════════════════════════════════════════════════════════════════════════════
  // FETCH RAPOR — 3 lapis strategi per santri per kelas
  // ══════════════════════════════════════════════════════════════════════════════
  Future<List<_RaporItem>> _fetchSemuaRapor() async {
    if (_santriList.isEmpty) return [];

    final List<String> targetKelas = (_selectedKelas == 'Semua Kelas' || _isWaliSantriMode)
        ? _semuaKelas
        : [_selectedKelas];

    final nested = await Future.wait(_santriList.map((santri) async {
      final List<_RaporItem> hasil = [];

      for (final kelas in targetKelas) {
        try {
          // Lapis 1: format baru
          final r1 = await _bacaRaporBaru(santri.id, kelas, _selectedTahun);
          if (r1 != null) {
            hasil.add(_RaporItem(rapor: r1, sumber: _Sumber.raporBaru));
            continue;
          }

          // Lapis 2: format lama
          final r2 = await _bacaRaporLama(santri.id, kelas, _selectedTahun);
          if (r2 != null) {
            hasil.add(_RaporItem(rapor: r2, sumber: _Sumber.raporLama));
            continue;
          }

          // Lapis 3: dari koleksi 'nilai'
          final r3 = await _generateDariNilai(santri, kelas, _selectedTahun);
          if (r3 != null) {
            hasil.add(_RaporItem(rapor: r3, sumber: _Sumber.generated));
          }
        } catch (e) {
          debugPrint('Rapor ${santri.nama} $kelas: $e');
        }
      }
      return hasil;
    }));

    final flat = nested.expand((x) => x).toList();

    flat.sort((a, b) {
      final namaComp = a.rapor.namaSantri.compareTo(b.rapor.namaSantri);
      if (namaComp != 0) return namaComp;
      final ia = _urutanKelas.indexOf(a.rapor.kelas.toLowerCase().trim());
      final ib = _urutanKelas.indexOf(b.rapor.kelas.toLowerCase().trim());
      return ia.compareTo(ib);
    });

    return flat;
  }

  Future<RaporModel?> _bacaRaporBaru(String santriId, String kelas, String tahun) async {
    final kelasId = kelas.replaceAll(' ', '');
    final tahunId = tahun.replaceAll('/', '');
    final docId   = '${santriId}_${kelasId}_$tahunId';

    final snap = await FirebaseFirestore.instance.collection('rapor').doc(docId).get();
    if (!snap.exists || snap.data() == null) return null;
    return _parseDoc(snap.data()!, snap.id);
  }

  Future<RaporModel?> _bacaRaporLama(String santriId, String kelas, String tahun) async {
    final List<String> kandidatId = [
      '${santriId}_${tahun.replaceAll("/", "-")}_${kelas.replaceAll(" ", "")}',
      'TEMP_${santriId}_${tahun.replaceAll("/", "-")}_${kelas.replaceAll(" ", "")}',
      '${santriId}_${kelas.replaceAll(" ", "")}_${tahun.replaceAll("/", "")}',
    ];

    for (final docId in kandidatId) {
      final snap = await FirebaseFirestore.instance.collection('rapor').doc(docId).get();
      if (snap.exists && snap.data() != null) return _parseDoc(snap.data()!, snap.id);
    }
    return null;
  }

  Future<RaporModel?> _generateDariNilai(SantriModel santri, String kelas, String tahun) async {
    final tahunDash  = tahun.replaceAll('/', '-');
    final kelasNorm  = kelas.replaceAll(' ', '');
    final kelasLower = kelas.toLowerCase().replaceAll(' ', '');

    final List<String> kandidatDocId = [
      '${santri.id}_${tahunDash}_$kelasNorm',
      '${santri.id}_${tahunDash}_$kelasLower',
      '${santri.id}_${tahunDash}_${kelas.toLowerCase()}',
    ];

    for (final docId in kandidatDocId) {
      final snap = await FirebaseFirestore.instance.collection('nilai').doc(docId).get();
      if (!snap.exists || snap.data() == null) continue;
      
      final d = snap.data()!;
      final List<NilaiModel> daftarNilai = [];

      void tambah(String prefix, dynamic m) {
        if (m is! Map) return;
        m.forEach((k, v) {
          final n = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
          if (n > 0) {
            daftarNilai.add(NilaiModel(
              mataPelajaran: prefix.isEmpty ? k.toString() : '$prefix: $k',
              nilaiHarian:   n,
              grade:         _gradeFromNilai(n),
            ));
          }
        });
      }

      // HANYA AMBIL UAS UNTUK AKADEMIK
      tambah('', d['uas']);

      // HANYA AMBIL LISAN UNTUK HAFALAN
      if (d['hafalan_kitab'] is Map) {
        (d['hafalan_kitab'] as Map).forEach((k, v) {
          if (k.toString().toLowerCase().contains('lisan')) {
            final n = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
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

      if (daftarNilai.isEmpty) continue;

      final nilaiAkhir = (d['nilai_akhir'] as num?)?.toDouble() ?? _hitungRataBerbobot(d);
      
      final absen = d['ketidakhadiran'] is Map ? d['ketidakhadiran'] as Map : {};
      final perilaku = (d['nilai_perilaku'] as num?)?.toDouble() ?? 0;
      final kehadiran = (d['nilai_kehadiran'] as num?)?.toDouble() ?? 0;

      return RaporModel(
        id:               'GEN_${santri.id}_$kelasNorm',
        santriId:         santri.id,
        namaSantri:       santri.nama,
        nis:              santri.nis ?? '-',
        kelas:            kelas,
        tahunAjaran:      tahun,
        nilaiRataRata:    nilaiAkhir,
        predikat:         _getPredikat(nilaiAkhir),
        catatanWaliKelas: '',
        tanggalCetak:     DateTime.now(),
        daftarNilai:      daftarNilai,
        absenSakit:       int.tryParse(absen['Sakit']?.toString() ?? '0') ?? 0,
        absenIzin:        int.tryParse(absen['Izin']?.toString() ?? '0') ?? 0,
        absenAlpha:       int.tryParse(absen['Tanpa Keterangan']?.toString() ?? '0') ?? 0,
        catatanAdab:      perilaku > 0 ? 'Tercatat' : 'Baik',
        nilaiSikap:       perilaku,
        predikatSikap:    _gradeFromNilai(perilaku),
        nilaiKehadiran:   kehadiran,
        predikatKehadiran:_gradeFromNilai(kehadiran),
      );
    }

    try {
      RaporModel? r = await RaporService.generateRapor(santri, kelas, tahun);
      if (r != null && r.daftarNilai.isNotEmpty) return r;
      r = await RaporService.generateRapor(santri, kelas.toLowerCase().replaceAll(' ', ''), tahun);
      if (r != null && r.daftarNilai.isNotEmpty) return r;
    } catch (_) {}

    return null;
  }

  RaporModel _parseDoc(Map<String, dynamic> d, String docId) {
    final List<NilaiModel> daftarNilai = [];

    if (d['daftarNilai'] is List) {
      for (final item in d['daftarNilai'] as List) {
        if (item is Map) {
          final n = (item['nilaiHarian'] as num?)?.toDouble() ?? 0.0;
          daftarNilai.add(NilaiModel(
            mataPelajaran: item['mataPelajaran']?.toString() ?? '',
            nilaiHarian:   n,
            grade:         item['grade']?.toString() ?? _gradeFromNilai(n),
          ));
        }
      }
    }

    if (daftarNilai.isEmpty) {
      void tambah(String prefix, dynamic m) {
        if (m is! Map) return;
        m.forEach((k, v) {
          final n = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
          if (n > 0) {
            daftarNilai.add(NilaiModel(
              mataPelajaran: prefix.isEmpty ? k.toString() : '$prefix: $k',
              nilaiHarian:   n,
              grade:         _gradeFromNilai(n),
            ));
          }
        });
      }
      tambah('', d['uas']);
      if (d['hafalan_kitab'] is Map) {
        (d['hafalan_kitab'] as Map).forEach((k, v) {
          if (k.toString().toLowerCase().contains('lisan')) {
            final n = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
            if (n > 0) {
              daftarNilai.add(NilaiModel(mataPelajaran: k.toString(), nilaiHarian: n, grade: _gradeFromNilai(n)));
            }
          }
        });
      }
    }

    final nilaiAkhir = (d['nilai_akhir'] as num?)?.toDouble() ?? (d['nilaiRataRata'] as num?)?.toDouble() ?? _hitungRataBerbobot(d);
    final perilaku = (d['nilaiSikap'] as num?)?.toDouble() ?? (d['nilai_perilaku'] as num?)?.toDouble() ?? 0.0;
    final kehadiran = (d['nilaiKehadiran'] as num?)?.toDouble() ?? (d['nilai_kehadiran'] as num?)?.toDouble() ?? 0.0;

    return RaporModel(
      id:               docId,
      santriId:         d['santriId']?.toString()        ?? '',
      namaSantri:       d['namaSantri']?.toString()       ?? '',
      nis:              d['nis']?.toString()              ?? '-',
      kelas:            d['kelas']?.toString()            ?? '',
      tahunAjaran:      d['tahunAjaran']?.toString()      ?? '',
      nilaiRataRata:    nilaiAkhir,
      predikat:         d['predikat']?.toString()         ?? _getPredikat(nilaiAkhir),
      catatanWaliKelas: d['catatanWaliKelas']?.toString() ?? '',
      tanggalCetak:     d['tanggalCetak'] != null ? (d['tanggalCetak'] as Timestamp).toDate() : DateTime.now(),
      daftarNilai:      daftarNilai,
      absenSakit:       int.tryParse(d['absenSakit']?.toString() ?? '0') ?? 0,
      absenIzin:        int.tryParse(d['absenIzin']?.toString() ?? '0') ?? 0,
      absenAlpha:       int.tryParse(d['absenAlpha']?.toString() ?? '0') ?? 0,
      catatanAdab:      d['catatanAdab']?.toString() ?? '',
      nilaiSikap:       perilaku,
      predikatSikap:    d['predikatSikap']?.toString() ?? _gradeFromNilai(perilaku),
      nilaiKehadiran:   kehadiran,
      predikatKehadiran:d['predikatKehadiran']?.toString() ?? _gradeFromNilai(kehadiran),
    );
  }

  // ─── Kalkulasi helper ─────────────────────────────────────────────────────────
  double _hitungRataBerbobot(Map<String, dynamic> d) {
    double kh  = (d['nilai_kehadiran'] as num?)?.toDouble() ?? 0;
    double pr  = (d['nilai_perilaku']  as num?)?.toDouble() ?? 0;
    double uts = _avgMap(d['uts']);
    double uas = _avgMap(d['uas']);
    double haf = _avgMap(d['hafalan_kitab']);
    return (kh * 0.05) + (pr * 0.05) + (uts * 0.20) + (uas * 0.40) + (haf * 0.30);
  }

  double _avgMap(dynamic m) {
    if (m is! Map) return 0;
    double s = 0; int c = 0;
    m.forEach((_, v) { s += (v as num?)?.toDouble() ?? 0; c++; });
    return c > 0 ? s / c : 0;
  }

  String _gradeFromNilai(double n) {
    if (n >= 90) return 'A';
    if (n >= 80) return 'B';
    if (n >= 70) return 'C';
    if (n >= 60) return 'D';
    return 'E';
  }

  String _getPredikat(double n) {
    if (n >= 90) return 'A (Mumtaz)';
    if (n >= 80) return 'B (Jayyid Jiddan)';
    if (n >= 70) return 'C (Jayyid)';
    if (n >= 60) return 'D (Maqbul)';
    return 'E (Rasib)';
  }

  // ─── Simpan rapor permanen ───────────────────────────────────────────────
  Future<void> _simpanPermanen(RaporModel rapor) async {
    try {
      final safeId = rapor.id.replaceAll('TEMP_', '').replaceAll('GEN_', '').replaceAll('/', '-');
      await FirebaseFirestore.instance.collection('rapor').doc(safeId).set({
        'id':               safeId,
        'santriId':         rapor.santriId,
        'namaSantri':       rapor.namaSantri,
        'nis':              rapor.nis,
        'kelas':            rapor.kelas,
        'tahunAjaran':      rapor.tahunAjaran,
        'nilaiRataRata':    rapor.nilaiRataRata,
        'predikat':         rapor.predikat,
        'catatanWaliKelas': rapor.catatanWaliKelas,
        'tanggalCetak':     FieldValue.serverTimestamp(),
        'absenSakit':       rapor.absenSakit,
        'absenIzin':        rapor.absenIzin,
        'absenAlpha':       rapor.absenAlpha,
        'catatanAdab':      rapor.catatanAdab,
        'nilaiSikap':       rapor.nilaiSikap,
        'predikatSikap':    rapor.predikatSikap,
        'nilaiKehadiran':   rapor.nilaiKehadiran,
        'predikatKehadiran':rapor.predikatKehadiran,
        'daftarNilai': rapor.daftarNilai.map((n) => {
          'mataPelajaran': n.mataPelajaran,
          'nilaiHarian':   n.nilaiHarian,
          'grade':         n.grade,
        }).toList(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('_simpanPermanen error: $e');
    }
  }

  Color _warnaPredikat(String p) {
    if (p.contains('A')) return Colors.green.shade600;
    if (p.contains('B')) return Colors.blue.shade600;
    if (p.contains('C')) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  Color _bgPredikat(String p) {
    if (p.contains('A')) return Colors.green.shade50;
    if (p.contains('B')) return Colors.blue.shade50;
    if (p.contains('C')) return Colors.orange.shade50;
    return Colors.red.shade50;
  }

  String _arabicPredikat(String p) {
    if (p.contains('A')) return 'ممتاز';
    if (p.contains('B')) return 'جيد جداً';
    if (p.contains('C')) return 'جيد';
    return 'راسب';
  }

  void _showPicker(String title, List<String> items, Function(String) onSelect) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.only(top: 16, bottom: 20),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(height: 24),
          Expanded(child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (_, i) => ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 24),
              title: Text(items[i], textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                Future.delayed(const Duration(milliseconds: 150), () => onSelect(items[i]));
              },
            ),
          )),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : Column(children: [
              _buildHeader(),
              if (!_isWaliSantriMode) ...[
                const SizedBox(height: 14),
                _buildFilterRow(),
              ],
              const SizedBox(height: 8),
              if (!_isLoading) _buildInfoBar(),
              const SizedBox(height: 4),
              Expanded(child: FutureBuilder<List<_RaporItem>>(
                future: _raporFuture,
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: _kPrimary));
                  }
                  final list = snap.data ?? [];
                  if (list.isEmpty) return _emptyState();
                  return RefreshIndicator(
                    color: _kPrimary,
                    onRefresh: () async => _refresh(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _buildKartuRapor(list[i]),
                    ),
                  );
                },
              )),
            ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 14,
          left: 20, right: 20, bottom: 24),
      decoration: const BoxDecoration(
        color: _kPrimary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          InkWell(onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20)),
            child: const Row(children: [
              Icon(Icons.mosque_rounded, color: Colors.white, size: 13),
              SizedBox(width: 6),
              Text('Ponpes Khoirul Huda', style: TextStyle(color: Colors.white, fontSize: 11)),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        Text(
          _isWaliSantriMode ? 'Rapor Akademik Anak' : 'Rapor Digital Santri',
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _isWaliSantriMode
              ? 'Riwayat rapor dari semua kelas'
              : 'Semua santri · $_selectedKelas · $_selectedTahun',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
        ),
      ]),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        _filterTile(Icons.layers_outlined, _selectedKelas,
            () => _showPicker('Pilih Kelas', _kelasList, (v) {
              setState(() => _selectedKelas = v);
              _refresh();
            })),
        const SizedBox(width: 10),
        _filterTile(Icons.calendar_month_outlined, _selectedTahun,
            () => _showPicker('Tahun Ajaran', _tahunList, (v) {
              setState(() => _selectedTahun = v);
              _refresh();
            })),
      ]),
    );
  }

  Widget _filterTile(IconData icon, String label, VoidCallback onTap) => Expanded(
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200)),
        child: Row(children: [
          Icon(icon, size: 16, color: _kPrimary), const SizedBox(width: 8),
          Expanded(child: Text(label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis)),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.grey),
        ]),
      ),
    ),
  );

  Widget _buildInfoBar() {
    return FutureBuilder<List<_RaporItem>>(
      future: _raporFuture,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting || snap.data == null) {
          return const SizedBox.shrink();
        }
        final total = snap.data!.length;
        final gen   = snap.data!.where((r) => r.sumber == _Sumber.generated).length;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: _kPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6)),
              child: Text('$total rapor ditemukan',
                  style: const TextStyle(fontSize: 11, color: _kPrimary, fontWeight: FontWeight.w600))),
            if (gen > 0) ...[
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.shade200)),
                child: Text('$gen perlu dicetak untuk disimpan',
                    style: TextStyle(fontSize: 10, color: Colors.orange.shade700, fontWeight: FontWeight.w600))),
            ],
          ]),
        );
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('Belum ada data rapor.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildKartuRapor(_RaporItem item) {
    final rapor    = item.rapor;
    final isLulus  = rapor.kelas.toLowerCase().contains('lulus') || rapor.kelas.toLowerCase().contains('alumni');
    final cardColor = isLulus ? Colors.green.shade600 : _warnaPredikat(rapor.predikat);
    final bgColor   = isLulus ? Colors.green.shade50  : _bgPredikat(rapor.predikat);
    final sudahSimpan = item.sumber != _Sumber.generated;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Container(height: 4, decoration: BoxDecoration(color: cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)))),

        Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 10), child: Column(children: [
          Row(children: [
            CircleAvatar(radius: 22, backgroundColor: bgColor,
              child: Icon(isLulus ? Icons.school_rounded : Icons.person_rounded, color: cardColor, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(rapor.namaSantri,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
                if (isLulus)
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(4)),
                    child: const Text('LULUS', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFEEECFC), borderRadius: BorderRadius.circular(4)),
                  child: Text(rapor.kelas, style: const TextStyle(fontSize: 9, color: _kPrimary, fontWeight: FontWeight.bold))),
                const SizedBox(width: 6),
                Text(rapor.tahunAjaran, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                const SizedBox(width: 6),
                if (!sudahSimpan)
                  Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orange.shade200)),
                    child: Text('⟳ Belum disimpan', style: TextStyle(fontSize: 8, color: Colors.orange.shade700, fontWeight: FontWeight.bold)))
                else
                  Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.green.shade200)),
                    child: Text('✓ Tersimpan', style: TextStyle(fontSize: 8, color: Colors.green.shade700, fontWeight: FontWeight.bold))),
              ]),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
              child: Text(isLulus ? 'خريج' : _arabicPredikat(rapor.predikat),
                  style: TextStyle(color: cardColor, fontWeight: FontWeight.bold, fontSize: 13))),
          ]),

          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nilai Akhir', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              Text(rapor.nilaiRataRata.toStringAsFixed(1), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cardColor)),
              Text(_getPredikat(rapor.nilaiRataRata), style: TextStyle(fontSize: 10, color: cardColor, fontWeight: FontWeight.w600)),
            ]),
            ElevatedButton.icon(
              onPressed: () => _showDetail(item),
              icon: const Icon(Icons.receipt_long_rounded, size: 15),
              label: const Text('Detail & Cetak', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                elevation: 0),
            ),
          ]),
        ])),
      ]),
    );
  }

  // ─── Modal detail & cetak (Tombol Sticky di Bawah) ──────────────────────────
  void _showDetail(_RaporItem item) {
    final rapor   = item.rapor;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (_, setModal) => DraggableScrollableSheet(
          initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5,
          expand: false,
          builder: (_, scrollCtrl) => Column(children: [
            // Handle Bar Atas
            Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),

            // Header Identitas
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(rapor.namaSantri, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('${rapor.kelas} · ${rapor.tahunAjaran}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ])),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ])),
            const Divider(height: 1),

            // AREA SCROLL: Isi Nilai
            Expanded(child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              children: [
                // Ringkasan
                _sectionLabel('Ringkasan Nilai'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _nilaiBox('Nilai Akhir', rapor.nilaiRataRata.toStringAsFixed(1), _warnaPredikat(rapor.predikat))),
                  const SizedBox(width: 8),
                  Expanded(child: _nilaiBox('Predikat', rapor.predikat.split(' ').first, _warnaPredikat(rapor.predikat))),
                ]),
                const SizedBox(height: 24),

                // 1. BAGIAN NILAI AKADEMIK (HANYA UAS)
                _sectionLabel('1. Nilai Akademik (UAS)'),
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: rapor.daftarNilai
                        .where((n) => !n.mataPelajaran.toLowerCase().contains('lisan'))
                        .map((n) => ListTile(
                              dense: true,
                              title: Text(n.mataPelajaran, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              trailing: Text('${n.nilaiHarian.toStringAsFixed(0)} (${n.grade})', 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _kPrimary)),
                            )).toList(),
                  ),
                ),

                // 2. BAGIAN PERILAKU & KEHADIRAN
                _sectionLabel('2. Penilaian Sikap & Kehadiran'),
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildRowItem('Perilaku / Sikap', rapor.catatanAdab.isNotEmpty ? 'Tercatat' : 'Baik'),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider(color: Colors.white)),
                    _buildRowItem('Sakit', '${rapor.absenSakit} Hari'),
                    const SizedBox(height: 6),
                    _buildRowItem('Izin', '${rapor.absenIzin} Hari'),
                    const SizedBox(height: 6),
                    _buildRowItem('Tanpa Keterangan', '${rapor.absenAlpha} Hari'),
                  ]),
                ),

                // 3. BAGIAN NILAI HAFALAN (HANYA LISAN)
                _sectionLabel('3. Nilai Hafalan Lisan'),
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: rapor.daftarNilai
                        .where((n) => n.mataPelajaran.toLowerCase().contains('lisan'))
                        .map((n) => ListTile(
                              dense: true,
                              title: Text(n.mataPelajaran, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              trailing: Text('${n.nilaiHarian.toStringAsFixed(0)} (${n.grade})', 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                            )).toList(),
                  ),
                ),
              ],
            )),

            // AREA STICKY: Tombol Cetak PDF Selalu di Bawah
            Container(
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, -2))],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (item.sumber == _Sumber.generated) {
                      await _simpanPermanen(rapor);
                    }
                    await RaporService.cetakRaporPdfWithLogo(context, rapor);
                  },
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('Cetak Rapor PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
            
          ]),
        ),
      ),
    );
  }

  // WIDGET HELPER DALAM UI
  Widget _sectionLabel(String title) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87));
  }

  Widget _nilaiBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildRowItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.blue.shade900)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
      ],
    );
  }
}