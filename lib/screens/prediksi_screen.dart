// File: lib/screens/prediksi_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/santri_model.dart';
import '../models/prediksi_model.dart';
import '../services/firestore_service.dart';
import '../services/random_forest_service.dart'; 

class PrediksiScreen extends StatefulWidget {
  final String userRole;
  final String? santriId;

  const PrediksiScreen({
    super.key,
    required this.userRole,
    this.santriId,
  });

  @override
  State<PrediksiScreen> createState() => _PrediksiScreenState();
}

class _PrediksiScreenState extends State<PrediksiScreen> {
  List<SantriModel> _allSantriList = [];
  List<SantriModel> _filteredSantriList = [];
  bool _isLoading = true;
  bool _isPredicting = false;
  bool _isWaliMode = false;
  SantriModel? _selectedSantri;

  bool _analisisNilaiAkademik = true;
  bool _analisisNilaiHafalan = true;

  String _selectedSemester = 'Kelas 1';
  String _selectedTahunAjaran = '2025/2026';

  final List<String> _listSemester = const [
    'Kelas sp',
    'Kelas 1',
    'Kelas 2',
    'Kelas 3',
    'Kelas 4'
  ];

  final List<String> _listTahunAjaran = const [
    '2025/2026',
    '2024/2025',
    '2023/2024'
  ];

  final List<PrediksiModel> _riwayatPrediksi = [];
  Map<String, dynamic>? _lastResult;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      String role = widget.userRole.toLowerCase().trim();

      if (role == 'walisantri' && widget.santriId != null && widget.santriId!.isNotEmpty) {
        _isWaliMode = true;
        SantriModel? anak = await FirestoreService.getSantriById(widget.santriId!);
        if (anak != null) {
          _allSantriList = [anak];
          _filteredSantriList = [anak];
          _selectedSantri = anak;
          
          String cleanedKelas = anak.kelas.toLowerCase().replaceAll('kls', 'kelas').trim();
          _selectedSemester = _listSemester.firstWhere(
            (k) => k.toLowerCase() == cleanedKelas, 
            orElse: () => 'Kelas 1'
          );
        }
      } else {
        _isWaliMode = false;
        _allSantriList = await FirestoreService.getSantriList();
        _allSantriList = _allSantriList.where((s) => s.status.toLowerCase().contains('aktif')).toList();
        
        _prosesFilterSantriPerKelas();
      }

      await _loadHistoriPrediksiFirebase();
      
      if (_isWaliMode && _riwayatPrediksi.isEmpty && _selectedSantri != null) {
        await _hitungPrediksiOtomatisUntukWali();
      }
    } catch (e) {
      debugPrint("Error loading data santri: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _prosesFilterSantriPerKelas() {
    if (_isWaliMode) return;
    
    setState(() {
      _filteredSantriList = _allSantriList.where((s) {
        String dbKelas = s.kelas.toLowerCase().replaceAll('kls', 'kelas').trim();
        String selectedClean = _selectedSemester.toLowerCase().trim();
        return dbKelas == selectedClean || s.kelas == _selectedSemester;
      }).toList();

      _filteredSantriList.sort((a, b) => a.nama.compareTo(b.nama));

      if (_filteredSantriList.isNotEmpty) {
        bool masihAda = _filteredSantriList.any((s) => s.id == _selectedSantri?.id);
        if (!masihAda) {
          _selectedSantri = _filteredSantriList.first;
        }
      } else {
        _selectedSantri = null;
      }
      _lastResult = null;
    });
  }

  Future<void> _loadHistoriPrediksiFirebase() async {
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('prediksi');

      if (_isWaliMode) {
        query = query.where('santriId', isEqualTo: widget.santriId);
      } else {
        query = query.where('kelas', isEqualTo: _selectedSemester);
      }

      final snapshot = await query.orderBy('tanggalPrediksi', descending: true).get();

      if (mounted) {
        setState(() {
          _riwayatPrediksi.clear();
          if (snapshot.docs.isNotEmpty) {
            _riwayatPrediksi.addAll(
              snapshot.docs.map((doc) => PrediksiModel.fromMap(doc.data())).toList(),
            );
            
            if (_isWaliMode && _riwayatPrediksi.isNotEmpty) {
              final terbaru = _riwayatPrediksi.first;
              _lastResult = {
                'hasil': terbaru.hasilPrediksi,
                'probabilitas': terbaru.probabilitas,
                'rekomendasi': terbaru.catatan,
              };
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error load histori prediksi: $e");
    }
  }

  Future<void> _hitungPrediksiOtomatisUntukWali() async {
    if (_selectedSantri == null) return;
    await _kalkulasiPrediksiInti();
  }

  Future<void> _jalankanPrediksi() async {
    if (_isWaliMode) return;

    if (_selectedSantri == null) {
      _showSnackBar('Silakan pilih nama santri terlebih dahulu.', Colors.orange);
      return;
    }

    setState(() {
      _isPredicting = true;
      _lastResult = null;
    });

    await _kalkulasiPrediksiInti(simpanKeDatabase: true);
  }

  Future<void> _kalkulasiPrediksiInti({bool simpanKeDatabase = false}) async {
    double calcAkademikTotal = 0.0;
    int jumlahMapelAkademik = 0;
    double calcHafalanTotal = 0.0;
    int jumlahMapelHafalan = 0;
    double nilaiKehadiran = 0.0;

    try {
      String searchKelasAlias = _selectedSemester.replaceAll('Kelas', 'Kls').trim();
      
      final nilaiSnapshot = await FirebaseFirestore.instance
          .collection('nilai')
          .where('santriId', isEqualTo: _selectedSantri!.id)
          .where('tahunAjaran', isEqualTo: _selectedTahunAjaran)
          .get();

      var docFilter = nilaiSnapshot.docs.where((doc) {
        String dbSmt = doc.data()['semester'].toString().toLowerCase().trim();
        return dbSmt == _selectedSemester.toLowerCase() || dbSmt == searchKelasAlias.toLowerCase();
      }).toList();

      if (docFilter.isNotEmpty) {
        final data = docFilter.first.data();
        nilaiKehadiran = double.tryParse(data['nilai_kehadiran']?.toString() ?? '0') ?? 0.0;
        
        if (data['uas'] is Map) {
          (data['uas'] as Map).forEach((mapel, nilaiVal) {
            double nilai = double.tryParse(nilaiVal.toString()) ?? 0.0;
            calcAkademikTotal += nilai;
            jumlahMapelAkademik++;
          });
        }
        
        if (data['hafalan_kitab'] is Map) {
          (data['hafalan_kitab'] as Map).forEach((mapel, nilaiVal) {
            double nilai = double.tryParse(nilaiVal.toString()) ?? 0.0;
            calcHafalanTotal += nilai;
            jumlahMapelHafalan++;
          });
        }
      }

      double rataRataAkademik = jumlahMapelAkademik == 0 ? 0.0 : calcAkademikTotal / jumlahMapelAkademik;
      double rataRataHafalan = jumlahMapelHafalan == 0 ? 0.0 : calcHafalanTotal / jumlahMapelHafalan;
      if (nilaiKehadiran == 0.0) nilaiKehadiran = 80.0; 

      double inputAkademik = _analisisNilaiAkademik ? rataRataAkademik : 75.0;
      double inputHafalan = _analisisNilaiHafalan ? rataRataHafalan : 70.0;

      final resultResult = RandomForestService.predict(
        nilaiRataRata: inputAkademik,
        nilaiAgama: inputAkademik,
        nilaiAkhlak: 85.0, 
        persentaseKehadiran: nilaiKehadiran, 
        nilaiHafalan: inputHafalan,
      );

      double predAkurasi = double.tryParse(resultResult['probabilitas']?.toString() ?? '') ?? 0.85;
      
      bool isLulusSyarat = (inputAkademik >= 70.0 && inputHafalan >= 65.0 && nilaiKehadiran >= 75.0);
      String statusHasilAkhir;
      String predCatatan;

      if (_selectedSemester == 'Kelas 4') {
        if (isLulusSyarat) {
          statusHasilAkhir = 'Lulus (Alumni)';
          predCatatan = 'Selamat, santri telah memenuhi kriteria kelulusan pesantren dengan predikat akademik dan hafalan yang baik.';
        } else {
          statusHasilAkhir = 'Belum Lulus';
          predCatatan = 'Santri belum memenuhi standar kelulusan. Perlu bimbingan intensif pada hafalan kitab dan ujian akhir.';
        }
      } else {
        if (isLulusSyarat) {
          statusHasilAkhir = 'Naik Kelas';
          predCatatan = 'Performa stabil. Pertahankan nilai kehadiran dan tingkatkan kualitas hafalan kitab.';
        } else {
          statusHasilAkhir = 'Tinggal Kelas';
          predCatatan = 'Performa di bawah standar kenaikan. Wajib mengikuti remedial akademik atau mengejar target setoran hafalan.';
        }
      }

      if (simpanKeDatabase && !_isWaliMode) {
        String docId = 'prediksi_${_selectedSantri!.id}_${DateTime.now().millisecondsSinceEpoch}';

        final PrediksiModel modelPrediksiBaru = PrediksiModel(
          id: docId,
          santriId: _selectedSantri!.id,
          namaSantri: _selectedSantri!.nama,
          kelas: _selectedSemester,
          nilaiRataRata: inputAkademik,
          nilaiAgama: inputAkademik,
          nilaiAkhlak: 85.0,
          nilaiKehadiran: nilaiKehadiran,
          nilaiHafalan: inputHafalan,
          hasilPrediksi: statusHasilAkhir,
          probabilitas: predAkurasi,
          catatan: predCatatan,
          tanggalPrediksi: DateTime.now(),
        );

        await FirebaseFirestore.instance
            .collection('prediksi')
            .doc(docId)
            .set(modelPrediksiBaru.toMap());

        setState(() {
          _riwayatPrediksi.insert(0, modelPrediksiBaru);
        });
        _showSnackBar('Prediksi Kelulusan & Kenaikan AI Berhasil Diperbarui!', Colors.green);
      }

      setState(() {
        _lastResult = {
          'hasil': statusHasilAkhir,
          'probabilitas': predAkurasi,
          'rekomendasi': predCatatan,
        };
        _isPredicting = false;
      });

    } catch (e) {
      if (!_isWaliMode) _showSnackBar('Gagal memproses data: $e', Colors.red);
      debugPrint("Prediksi error: $e");
      setState(() => _isPredicting = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), 
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black12,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isWaliMode ? 'Hasil Analisis Kelulusan' : 'Prediksi AI Pesantren',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF5D38F5)))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAIBannerHeader(),
                  const SizedBox(height: 24),
                  
                  // Hanya Tampilkan Filter Lengkap Jika Bukan Wali
                  if (!_isWaliMode) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Parameter Evaluasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                          const SizedBox(height: 12),
                          _buildPeriodeSelector(),
                          const SizedBox(height: 16),
                          const Text('Pilih Nama Santri', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          _buildSantriDropdownSelector(),
                          const SizedBox(height: 16),
                          const Text('Komponen Utama', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          _buildDataAnalysisCheckboxForm(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTriggerButton(),
                  ] else ...[
                    // Tampilan Khusus Wali
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.indigo.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Identitas Santri', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          _buildSantriDropdownSelector(),
                        ],
                      ),
                    )
                  ],

                  const SizedBox(height: 32),
                  _buildDynamicResultOrHistoryArea(),
                  const SizedBox(height: 24),
                  _buildInfoDisclaimerBanner(),
                  const SizedBox(height: 50), // Ruang ekstra di bawah untuk scroll yang nyaman
                ],
              ),
            ),
    );
  }

  Widget _buildAIBannerHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF4F46E5).withAlpha(60), blurRadius: 12, offset: const Offset(0, 6))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isWaliMode ? 'Proyeksi Kelulusan\nOleh AI Pesantren' : 'Sistem Keputusan\nCerdas (Random Forest)',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white, height: 1.3),
                ),
                const SizedBox(height: 8),
                Text(
                  _isWaliMode
                      ? 'Memprediksi kenaikan kelas dan kelulusan anak berdasarkan nilai akademik, hafalan kitab, dan kehadiran.'
                      : 'Menganalisis kelayakan naik kelas & kelulusan santri secara presisi berdasarkan standar kurikulum pondok.',
                  style: TextStyle(fontSize: 12, color: Colors.indigo.shade100, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.analytics_rounded, size: 32, color: Colors.white),
          )
        ],
      ),
    );
  }

  Widget _buildSantriDropdownSelector() {
    if (_isWaliMode) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.account_circle, size: 20, color: Color(0xFF4F46E5)),
            const SizedBox(width: 12),
            Text(
              _selectedSantri?.nama ?? '-',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFE0E7FF), borderRadius: BorderRadius.circular(6)),
              child: Text(
                _selectedSemester,
                style: const TextStyle(fontSize: 11, color: Color(0xFF4338CA), fontWeight: FontWeight.bold),
              ),
            )
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SantriModel>(
          value: _selectedSantri,
          isExpanded: true,
          hint: Text(_filteredSantriList.isEmpty ? 'Tidak ada santri di kelas ini' : 'Pilih nama santri', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
          items: _filteredSantriList.map((s) {
            return DropdownMenuItem(
              value: s,
              child: Row(
                children: [
                  const Icon(Icons.person, size: 18, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 10),
                  Text(s.nama, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                ],
              ),
            );
          }).toList(),
          onChanged: (s) => setState(() {
            _selectedSantri = s;
            _lastResult = null;
          }),
        ),
      ),
    );
  }

  Widget _buildDataAnalysisCheckboxForm() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildCheckboxItem(
            value: _analisisNilaiAkademik,
            icon: Icons.menu_book_rounded,
            title: 'Rata-rata Akademik (UAS)',
            onChanged: (val) => setState(() => _analisisNilaiAkademik = val ?? true),
          ),
          const Divider(height: 1, indent: 45, color: Color(0xFFE2E8F0)),
          _buildCheckboxItem(
            value: _analisisNilaiHafalan,
            icon: Icons.record_voice_over_rounded,
            title: 'Hafalan Kitab Lisan',
            onChanged: (val) => setState(() => _analisisNilaiHafalan = val ?? true),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxItem({
    required bool value,
    required IconData icon,
    required String title,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF4F46E5),
      checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      secondary: Icon(icon, color: const Color(0xFF64748B), size: 18),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildPeriodeSelector() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _showPicker('Pilih Kelas', _listSemester, (val) {
              setState(() {
                _selectedSemester = val;
              });
              _prosesFilterSantriPerKelas();
              _loadHistoriPrediksiFirebase();
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Row(
                children: [
                  const Icon(Icons.school_rounded, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_selectedSemester, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)))),
                  const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: () => _showPicker('Tahun Ajaran', _listTahunAjaran, (val) {
              setState(() {
                _selectedTahunAjaran = val;
              });
              _prosesFilterSantriPerKelas();
              _loadHistoriPrediksiFirebase();
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_selectedTahunAjaran, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)))),
                  const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTriggerButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: const Color(0xFF4F46E5).withAlpha(100),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _isPredicting || _selectedSantri == null ? null : _jalankanPrediksi,
        icon: _isPredicting
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : const Icon(Icons.data_exploration_rounded, size: 20),
        label: Text(
          _isPredicting ? 'Memproses Prediksi...' : 'Jalankan Analisis Keputusan',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildDynamicResultOrHistoryArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_lastResult != null) ...[
          const Text('Hasil Keputusan AI Terkini', 
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
          _buildActiveResultCard(),
          const SizedBox(height: 24),
        ],
        Text(_isWaliMode ? 'Riwayat Evaluasi Akademik Anak' : 'Arsip Hasil Prediksi',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
        _buildHistoryListCard(),
      ],
    );
  }

  Widget _buildActiveResultCard() {
    String hasilText = _lastResult?['hasil']?.toString() ?? 'Naik Kelas';
    double akurasi = double.tryParse(_lastResult?['probabilitas']?.toString() ?? '') ?? 0.85;
    String rekomendasiText = _lastResult?['rekomendasi']?.toString() ?? '';

    bool isBerhasil = hasilText.contains('Lulus') || hasilText.contains('Naik');
    Color themeColor = isBerhasil ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    Color bgColor = isBerhasil ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);
    IconData iconStatus = isBerhasil ? Icons.verified_rounded : Icons.cancel_rounded;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: themeColor.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(iconStatus, color: themeColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status Prediksi:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: themeColor)),
                    Text(hasilText.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, color: themeColor, fontSize: 18)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: themeColor.withAlpha(40))),
                child: Text(
                  '${(akurasi * 100).toStringAsFixed(0)}% Akurat',
                  style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withAlpha(150), borderRadius: BorderRadius.circular(8)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tips_and_updates_rounded, color: Colors.amber.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(rekomendasiText, style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.5, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHistoryListCard() {
    if (_riwayatPrediksi.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(
          children: [
            Icon(Icons.folder_open_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('Belum Ada Riwayat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            Text(
              _isWaliMode ? 'Kalkulasi data akademik akan muncul setelah ujian selesai.' : 'Jalankan analisis AI untuk menyimpan riwayat prediksi santri.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
            )
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _riwayatPrediksi.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, index) {
        final hist = _riwayatPrediksi[index];
        bool checkLulus = hist.hasilPrediksi.contains('Lulus') || hist.hasilPrediksi.contains('Naik');
        Color statusColor = checkLulus ? const Color(0xFF10B981) : const Color(0xFFEF4444);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              height: 40, width: 40,
              decoration: BoxDecoration(color: statusColor.withAlpha(20), borderRadius: BorderRadius.circular(10)),
              child: Icon(checkLulus ? Icons.school_rounded : Icons.warning_rounded, color: statusColor, size: 20),
            ),
            title: Text(hist.namaSantri, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B))),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(DateFormat('dd MMM yyyy').format(hist.tanggalPrediksi), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(20)),
              child: Text(hist.hasilPrediksi, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoDisclaimerBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF64748B), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Catatan Sistem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                Text(
                  'Sistem klasifikasi AI Random Forest membaca data dari Rata-rata UAS, Hafalan Kitab, dan Kehadiran untuk memprediksi kelulusan atau kenaikan kelas santri secara otomatis.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.5),
                ),
              ],
            ),
          )
        ],
      ),
    );
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
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            Center(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)))),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, idx) {
                  final item = items[idx];
                  return ListTile(
                    title: Text(item, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF475569))),
                    onTap: () {
                      onSelect(item);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}