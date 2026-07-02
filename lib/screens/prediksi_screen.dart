// File: lib/screens/prediksi_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/prediksi_service.dart';
import '../services/firestore_service.dart';
import '../models/santri_model.dart';

class PrediksiScreen extends StatefulWidget {
  final String role;
  final String? santriId; // wajib diisi saat role == 'wali_santri'

  const PrediksiScreen({
    super.key,
    this.role = 'ustadz',
    this.santriId,
  });

  @override
  State<PrediksiScreen> createState() => _PrediksiScreenState();
}

class _PrediksiScreenState extends State<PrediksiScreen> {
  // ─── Controllers (Sekarang Bisa Diedit Manual) ──────────────────────────────
  final TextEditingController _hafalanCtrl = TextEditingController();
  final TextEditingController _kehadiranCtrl = TextEditingController();
  final TextEditingController _akademikCtrl = TextEditingController();
  final TextEditingController _perilakuCtrl = TextEditingController();

  // ─── State ────────────────────────────────────────────────────────────────────
  String _hasilPrediksi = "";
  bool _isLoading = false; 
  bool _isFetching = false; 
  bool _isAdmin = true;

  bool get _isWali => widget.role == 'wali_santri';

  // ─── Data Santri (hanya ustadz/admin) ─────────────────────────────────────────
  List<SantriModel> _allSantri = [];
  List<SantriModel> _filteredSantri = [];

  final List<String> _kelasList = ['Kelas sp', 'Kelas 1', 'Kelas 2', 'Kelas 3', 'Kelas 4'];
  String _selectedKelas = 'Kelas 4';
  String _selectedSantriId = '';
  String _namaSantriTerpilih = 'Pilih Nama Santri...';

  // Data Wali Santri
  String _namaAnak = '';
  String _kelasAnak = '';

  static const String _tahunAjaran = '2025/2026';

  // ─── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (_isWali) {
      _initWaliSantri();
    } else {
      _checkRoleAndLoadSantri();
    }
  }

  @override
  void dispose() {
    _hafalanCtrl.dispose();
    _kehadiranCtrl.dispose();
    _akademikCtrl.dispose();
    _perilakuCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // WALI SANTRI — hanya ambil hasil prediksi
  // ══════════════════════════════════════════════════════════════════════════════
  Future<void> _initWaliSantri() async {
    if (widget.santriId == null || widget.santriId!.isEmpty) return;
    setState(() => _isFetching = true);
    try {
      final santriDoc = await FirebaseFirestore.instance.collection('santri').doc(widget.santriId).get();
      if (!mounted) return;

      if (!santriDoc.exists) return;
      final santriData = santriDoc.data()!;
      _namaAnak = santriData['nama'] ?? 'Santri';
      _kelasAnak = santriData['kelas'] ?? '';

      final tahun = _tahunAjaran.replaceAll('/', '-');
      final kelasId = _kelasAnak.replaceAll(' ', '');
      final docId = '${widget.santriId}_${tahun}_$kelasId';

      final nilaiDoc = await FirebaseFirestore.instance.collection('nilai').doc(docId).get();
      if (!mounted) return;

      if (nilaiDoc.exists && nilaiDoc.data() != null) {
        final pred = nilaiDoc.data()!['status_prediksi_ai']?.toString() ?? '';
        setState(() {
          _hasilPrediksi = pred.isNotEmpty ? pred : '';
        });
      }
    } catch (e) {
      debugPrint('_initWaliSantri error: $e');
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // USTADZ / ADMIN — Load Role & Santri
  // ══════════════════════════════════════════════════════════════════════════════
  Future<void> _checkRoleAndLoadSantri() async {
    setState(() => _isFetching = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docUser = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (docUser.exists) {
          final userData = docUser.data()!;
          final String role = (userData['role'] ?? '').toString().toLowerCase();

          if (role == 'guru') {
            _isAdmin = false;
            _selectedKelas = userData['kelas'] ?? 'Kelas 1'; 
          } else {
            _isAdmin = true;
          }
        }
      }
      
      final list = await FirestoreService.getSantriList(
        kelas: _isAdmin ? null : _selectedKelas
      );

      _allSantri = list.where((s) {
        final st = s.status.toLowerCase().trim();
        return st.contains('aktif') || st.isEmpty;
      }).toList();
      
      _filterSantri();
    } catch (e) {
      debugPrint('_checkRoleAndLoadSantri error: $e');
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  void _filterSantri() {
    setState(() {
      _filteredSantri = _allSantri
          .where((s) => s.kelas.toLowerCase().trim() == _selectedKelas.toLowerCase().trim())
          .toList()
        ..sort((a, b) => a.nama.compareTo(b.nama));
      _resetPilihan();
    });
  }

  void _resetPilihan() {
    _selectedSantriId = '';
    _namaSantriTerpilih = 'Pilih Nama Santri...';
    _bersihkan();
  }

  void _bersihkan() {
    _hafalanCtrl.clear();
    _kehadiranCtrl.clear();
    _akademikCtrl.clear();
    _perilakuCtrl.clear();
    setState(() => _hasilPrediksi = '');
  }

  String _docId(String santriId, String kelas) {
    final tahun = _tahunAjaran.replaceAll('/', '-');
    final kelasId = kelas.replaceAll(' ', '');
    return '${santriId}_${tahun}_$kelasId';
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TARIK NILAI AWAL (Sebagai Default Input)
  // ══════════════════════════════════════════════════════════════════════════════
  Future<void> _tarikNilaiOtomatis(String santriId, String kelas) async {
    setState(() {
      _isFetching = true;
      _hasilPrediksi = '';
    });
    try {
      final snap = await FirebaseFirestore.instance.collection('nilai').doc(_docId(santriId, kelas)).get();
      if (!mounted) return;

      if (snap.exists && snap.data() != null) {
        final d = snap.data()!;

        final kehadiran = _toDouble(d['nilai_kehadiran']);
        final perilaku = _toDouble(d['nilai_perilaku']);
        
        final avgUas = _avgMap(d['uas']);
        final akademik = avgUas;

        double totalHafalan = 0;
        int countHafalan = 0;
        if (d['hafalan_kitab'] is Map) {
          (d['hafalan_kitab'] as Map).forEach((k, v) {
            if (k.toString().toLowerCase().contains('lisan')) {
              final n = _toDouble(v);
              if (n > 0) {
                totalHafalan += n;
                countHafalan++;
              }
            }
          });
        }
        final hafalan = countHafalan > 0 ? (totalHafalan / countHafalan) : 0.0;
        final pred = d['status_prediksi_ai']?.toString() ?? '';

        setState(() {
          _kehadiranCtrl.text = kehadiran > 0 ? kehadiran.toStringAsFixed(1) : '';
          _akademikCtrl.text = akademik > 0 ? akademik.toStringAsFixed(1) : '';
          _perilakuCtrl.text = perilaku > 0 ? perilaku.toStringAsFixed(1) : '';
          _hafalanCtrl.text = hafalan > 0 ? hafalan.toStringAsFixed(1) : '';
          _hasilPrediksi = pred;
        });

        if (kehadiran == 0 || akademik == 0 || perilaku == 0 || hafalan == 0) {
          _snack('⚠️ Ada nilai yang kosong. Silakan input manual nilainya.', Colors.orange);
        } else {
          _snack('✅ Nilai berhasil dimuat. Silakan sesuaikan atau langsung jalankan AI.', Colors.green);
        }
      } else {
        _bersihkan();
        _snack('⚠️ Belum ada data otomatis. Silakan ketik nilai secara manual.', Colors.orange);
      }
    } catch (e) {
      _snack('Gagal tarik data: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  double _toDouble(dynamic val) => double.tryParse(val?.toString().replaceAll(',', '.') ?? '0') ?? 0.0;

  double _avgMap(dynamic m) {
    if (m is! Map) return 0.0;
    double s = 0;
    int c = 0;
    m.forEach((_, v) {
      s += double.tryParse(v.toString()) ?? 0;
      c++;
    });
    return c > 0 ? s / c : 0.0;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // PROSES PREDIKSI AI + SIMPAN KE FIRESTORE
  // ══════════════════════════════════════════════════════════════════════════════
  Future<void> _prosesPrediksi() async {
    if (_hafalanCtrl.text.trim().isEmpty || _kehadiranCtrl.text.trim().isEmpty ||
        _akademikCtrl.text.trim().isEmpty || _perilakuCtrl.text.trim().isEmpty) {
      _snack('⚠️ Seluruh parameter nilai harus diisi (ketik manual) sebelum AI bisa dijalankan.', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
      _hasilPrediksi = '';
    });

    try {
      final hafalan = _toDouble(_hafalanCtrl.text);
      final kehadiran = _toDouble(_kehadiranCtrl.text);
      final akademik = _toDouble(_akademikCtrl.text);
      final perilaku = _toDouble(_perilakuCtrl.text);

      final hasilApi = await PrediksiApiService.getPrediksiKelulusan(
        hafalanKitab: hafalan,
        kehadiran: kehadiran,
        nilaiAkademik: akademik,
        nilaiPerilaku: perilaku,
      );

      final isKelas4 = _selectedKelas.toLowerCase().trim() == 'kelas 4';
      final teksHasil = hasilApi == 0
          ? (isKelas4 ? 'LULUS TEPAT WAKTU' : 'NAIK KELAS')
          : (isKelas4 ? 'TIDAK LULUS' : 'TINGGAL KELAS');

      if (_selectedSantriId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('nilai').doc(_docId(_selectedSantriId, _selectedKelas)).set({
          'status_prediksi_ai': teksHasil,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      setState(() => _hasilPrediksi = teksHasil);
      _snack('✅ Prediksi AI berhasil dijalankan!', Colors.green);
    } catch (e) {
      if (!mounted) return;
      _snack('Terjadi kesalahan AI: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getCatatan() {
    final k = _isWali ? _kelasAnak : _selectedKelas;
    final bukan4 = ['kelas sp', 'kelas 1', 'kelas 2', 'kelas 3'].contains(k.toLowerCase().trim());
    if (!bukan4) return '';
    if (_hasilPrediksi.contains('NAIK KELAS')) {
      return 'Alhamdulillah! Pertahankan semangat hafalan dan belajarnya. 🌟';
    } else if (_hasilPrediksi.contains('TINGGAL KELAS')) {
      return 'Ayo lebih giat lagi belajar dan menghafal. Kamu pasti bisa! 💪';
    }
    return '';
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: bg, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 3)));
  }

  void _showSantriPicker() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          const Text('Pilih Santri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: _filteredSantri.isEmpty
                ? const Center(child: Text('Tidak ada santri aktif di kelas ini'))
                : ListView.builder(
                    itemCount: _filteredSantri.length,
                    itemBuilder: (_, idx) {
                      final santri = _filteredSantri[idx];
                      return ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.blue[50], child: Text(santri.nama[0], style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                        title: Text(santri.nama, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(santri.kelas, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _selectedSantriId = santri.id;
                            _namaSantriTerpilih = santri.nama;
                          });
                          _tarikNilaiOtomatis(santri.id, _selectedKelas);
                        },
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        title: Text(
          _isWali ? 'Hasil Prediksi Anak Saya' : 'Analisis Prediksi AI',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: Colors.blue[900],
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isFetching
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Mengambil data...', style: TextStyle(color: Colors.grey))]))
          : _isWali
              ? _buildWaliView()
              : _buildUstadzView(),
    );
  }

  Widget _buildWaliView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.blue[900], borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white)),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Santri', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(_namaAnak, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(_kelasAnak, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ]),
        ),
        const SizedBox(height: 28),
        if (_hasilPrediksi.isNotEmpty) _buildHasilCard(_hasilPrediksi) else _buildBelumAdaHasil(),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _buildBelumAdaHasil() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.amber.shade200)),
      child: const Column(children: [
        Icon(Icons.hourglass_empty_rounded, color: Colors.orange, size: 48),
        SizedBox(height: 14),
        Text('Hasil prediksi belum tersedia.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15), textAlign: TextAlign.center),
        SizedBox(height: 8),
        Text('Pengurus pesantren belum menjalankan analisis AI untuk anak ini.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5)),
      ]),
    );
  }

  Widget _buildUstadzView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _stepLabel('1', 'Tahun Ajaran & Kelas'),
        const SizedBox(height: 10),
        
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Tahun Ajaran', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Expanded(child: Text(_tahunAjaran, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54), overflow: TextOverflow.ellipsis)),
                    const Icon(Icons.lock, size: 14, color: Colors.grey),
                  ]),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            if (_isAdmin)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true, value: _selectedKelas, icon: const Icon(Icons.keyboard_arrow_down),
                      items: _kelasList.map((k) => DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)))).toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() => _selectedKelas = val);
                        _filterSantri();
                      },
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Kelas Anda', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(child: Text(_selectedKelas, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54), overflow: TextOverflow.ellipsis)),
                      const Icon(Icons.lock, size: 14, color: Colors.grey),
                    ]),
                  ]),
                ),
              ),
          ],
        ),

        const SizedBox(height: 20),
        _stepLabel('2', 'Pilih Santri'),
        const SizedBox(height: 10),
        InkWell(
          onTap: _showSantriPicker,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: _selectedSantriId.isNotEmpty ? Colors.blue.shade50 : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _selectedSantriId.isNotEmpty ? Colors.blue.shade300 : Colors.grey.shade300)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Icon(Icons.person_search, color: _selectedSantriId.isNotEmpty ? Colors.blue[900] : Colors.grey, size: 20),
                const SizedBox(width: 8),
                Text(_namaSantriTerpilih, style: TextStyle(fontWeight: FontWeight.w600, color: _selectedSantriId.isEmpty ? Colors.grey : Colors.black87)),
              ]),
              const Icon(Icons.arrow_drop_down, color: Colors.grey),
            ]),
          ),
        ),

        if (_selectedSantriId.isNotEmpty) ...[
          const SizedBox(height: 24),
          _stepLabel('3', 'Input Parameter AI'), // Judul Diubah
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade100)),
            child: Row(children: [
              Icon(Icons.edit_note_rounded, color: Colors.blue[800], size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Ketik manual nilai santri di bawah ini, atau gunakan data otomatis jika sudah tersedia.', style: TextStyle(fontSize: 11, color: Colors.blue[900], fontWeight: FontWeight.w500))),
            ]),
          ),
          const SizedBox(height: 12),

          _buildFieldManual(label: 'Hafalan Kitab (Lisan)', hint: 'Ketik hafalan Kitab...', icon: Icons.menu_book_rounded, ctrl: _hafalanCtrl),
          _buildFieldManual(label: 'Kehadiran (%)', hint: 'Ketik persentase kehadiran...', icon: Icons.co_present_rounded, ctrl: _kehadiranCtrl),
          _buildFieldManual(label: 'Nilai Akademik (Rata-rata UAS)', hint: 'Ketik nilai akademik...', icon: Icons.school_rounded, ctrl: _akademikCtrl),
          _buildFieldManual(label: 'Nilai Perilaku / Akhlak', hint: 'Ketik nilai perilaku...', icon: Icons.emoji_emotions_rounded, ctrl: _perilakuCtrl),

          const SizedBox(height: 20),
          _stepLabel('4', 'Jalankan Analisis'),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _prosesPrediksi,
            icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.auto_awesome, color: Colors.white),
            label: Text(_isLoading ? 'Memproses...' : 'Simpan & Jalankan AI', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blue[900], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2),
          ),
          const SizedBox(height: 24),
        ],

        if (_hasilPrediksi.isNotEmpty) _buildHasilCard(_hasilPrediksi),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _stepLabel(String n, String title) => Row(children: [
        Container(width: 24, height: 24, decoration: BoxDecoration(color: Colors.blue[900], borderRadius: BorderRadius.circular(6)), child: Center(child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
      ]);

  Widget _buildFieldManual({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController ctrl,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        ]),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          readOnly: false, // DIUBAH: Sekarang bisa diketik bebas
          keyboardType: const TextInputType.numberWithOptions(decimal: true), // DIUBAH: Menggunakan keyboard angka
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey[800]),
          decoration: InputDecoration(
            hintText: hint, 
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
            filled: true, 
            fillColor: Colors.white, // DIUBAH: Latar belakang putih menandakan bisa diedit
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade400, width: 2)), // Highlight saat diklik
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          ),
        ),
      ]),
    );
  }

  Widget _buildHasilCard(String hasil) {
    final isNegatif = hasil.contains('TIDAK') || hasil.contains('TINGGAL');
    final catatan = _getCatatan();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isNegatif ? [Colors.red.shade50, Colors.red.shade100] : [Colors.green.shade50, Colors.green.shade100], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isNegatif ? Colors.red.shade200 : Colors.green.shade200, width: 2),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(children: [
        Icon(isNegatif ? Icons.cancel_rounded : Icons.check_circle_rounded, size: 52, color: isNegatif ? Colors.red[700] : Colors.green[700]),
        const SizedBox(height: 12),
        Text(hasil, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isNegatif ? Colors.red[800] : Colors.green[800])),
        if (catatan.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(color: isNegatif ? Colors.red.shade200 : Colors.green.shade200)),
          Text(catatan, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic, color: isNegatif ? Colors.red.shade900 : Colors.green.shade900)),
        ],
      ]),
    );
  }
}