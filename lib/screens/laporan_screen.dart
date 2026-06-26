// File: lib/screens/laporan_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/santri_model.dart';
import '../services/firestore_service.dart';
import '../services/laporan_pdf_service.dart'; 

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  List<SantriModel> _allSantriList = [];
  List<SantriModel> _filteredSantriList = [];
  bool _isLoading = true;

  String _selectedTahunAjaran = '2025/2026';
  String _selectedKelas = 'Semua Kelas';
  String _selectedSantriId = 'Semua Santri';

  final List<String> _listTahunAjaran = const [
    '2025/2026',
    '2024/2025',
    '2023/2024'
  ];

  // Daftar kelas diatur statis agar tidak hilang
  final List<String> _listKelas = const [
    'Semua Kelas',
    'Kelas sp',
    'Kelas 1',
    'Kelas 2',
    'Kelas 3',
    'Kelas 4'
  ];
  
  List<String> _listSantri = const ['Semua Santri'];

  @override
  void initState() {
    super.initState();
    _fetchFirebaseData();
  }

  // Menarik master data dari Firebase
  Future<void> _fetchFirebaseData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Ambil SEMUA data santri (termasuk yang tidak aktif / lulus / sudah pindah kelas)
      // agar histori nilai masa lalu tetap bisa dihubungkan dengan namanya.
      _allSantriList = await FirestoreService.getSantriList();
      
      if (mounted) {
        // 2. Terapkan filter berdasarkan histori nilai yang ada di database
        await _applyFilters();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showSnackBar('Gagal membuat data master Firestore: $e', Colors.red);
    }
  }

  // Fungsi pintar: Mencari nama berdasarkan jejak rekam nilai yang diinput guru
  Future<void> _applyFilters() async {
    setState(() => _isLoading = true);
    try {
      // Mulai kueri ke koleksi 'nilai' (bukan 'santri')
      Query query = FirebaseFirestore.instance.collection('nilai')
          .where('tahunAjaran', isEqualTo: _selectedTahunAjaran);
          
      if (_selectedKelas != 'Semua Kelas') {
        query = query.where('kelas', isEqualTo: _selectedKelas);
      }
      
      final snapshot = await query.get();
      
      // Ambil kumpulan ID Santri yang memiliki nilai di kelas & tahun tersebut
      final Set<String> santriIdsWithGrades = snapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['santriId'].toString())
          .toSet();

      // Ekstrak model santri lengkap (Nama & NIS) berdasarkan ID yang ditemukan
      List<SantriModel> temp = _allSantriList.where((s) => santriIdsWithGrades.contains(s.id)).toList();
      temp.sort((a, b) => a.nama.compareTo(b.nama));
      
      // Perbarui dropdown pilihan Nama Santri
      List<String> updatedSantriList = ['Semua Santri', ...temp.map((s) => s.nama)];
      
      // Jika nama yang dipilih sebelumnya tidak ada di daftar kelas ini, kembalikan ke Semua Santri
      if (!updatedSantriList.contains(_selectedSantriId)) {
        _selectedSantriId = 'Semua Santri';
      }

      // Filter spesifik ke satu santri jika dipilih
      if (_selectedSantriId != 'Semua Santri') {
        temp = temp.where((s) => s.nama == _selectedSantriId).toList();
      }
      
      if (mounted) {
        setState(() {
          _listSantri = updatedSantriList;
          _filteredSantriList = temp;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Gagal memfilter riwayat kelas: $e");
    }
  }

  Future<void> _simpanLogLaporanKeFirebase(String jenisLaporan, String formatFile) async {
    try {
      final logId = 'REP_${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseFirestore.instance.collection('rekap_laporan').doc(logId).set({
        'id': logId,
        'jenisLaporan': jenisLaporan,
        'formatFile': formatFile,
        'tahunAjaran': _selectedTahunAjaran,
        'kelas': _selectedKelas,
        'filterSantri': _selectedSantriId,
        'jumlahSantriTercakup': _filteredSantriList.length,
        'tanggalDibuat': FieldValue.serverTimestamp(),
        'daftarSantriMencakup': _filteredSantriList.map((s) => {
          'id': s.id,
          'nama': s.nama,
          'nis': s.nis,
          'kelas': s.kelas
        }).toList(),
      });
    } catch (e) {
      debugPrint("Gagal menyimpan log laporan ke Firebase: $e");
    }
  }

  // ==================== FUNGSI UTAMA EKSPOR MENGGUNAKAN SERVICE PDF ====================
  Future<void> _prosesEksporLaporan(String tipeAksi, String jenisLaporan, Color temaWarna) async {
    if (_filteredSantriList.isEmpty) {
      _showSnackBar('Tidak ada jejak nilai santri di Kelas dan Tahun Ajaran ini.', Colors.orange);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              CircularProgressIndicator(color: temaWarna),
              const SizedBox(height: 20),
              const Text(
                'Memproses dokumen PDF...', 
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );

    try {
      final pdfService = LaporanPdfService();
      
      // Deteksi Eksekusi PDF Sesuai Kategori
      if (jenisLaporan.contains('Rekap Nilai')) {
        await pdfService.generateLaporanRekapNilai(
          santriList: _filteredSantriList,
          kelas: _selectedKelas,
          tahunAjaran: _selectedTahunAjaran
        );
      } else {
        // Untuk Laporan AI, langsung lempar santriList, Service yang akan menarik riwayat AI-nya
        await pdfService.generateLaporanPrediksiAI(
          santriList: _filteredSantriList, 
          kelas: _selectedKelas, 
          tahunAjaran: _selectedTahunAjaran
        );
      }

      await _simpanLogLaporanKeFirebase(jenisLaporan, tipeAksi);

      if (mounted) {
        Navigator.pop(context); // Tutup dialog loading
        _showSnackBar('Berkas laporan PDF berhasil dibuat & dibuka!', temaWarna);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Gagal memproses dokumen laporan: $e', Colors.red);
      debugPrint("Error generate PDF: $e");
    }
  }

  void _showSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
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
                      _applyFilters();
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
              const Text('Pilih Fokus Santri', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _listSantri.length,
                  itemBuilder: (context, idx) {
                    final name = _listSantri[idx];
                    return ListTile(
                      title: Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      onTap: () {
                        setState(() => _selectedSantriId = name);
                        _applyFilters();
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
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      value, 
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), 
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
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
    const Color brandPurple = Color(0xFF4F2EE7);
    const Color textDarkColor = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textDarkColor, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Rekap Laporan Hasil', style: TextStyle(color: textDarkColor, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: brandPurple))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildDropdownItem(
                        label: 'Kelas Pengajian',
                        value: _selectedKelas,
                        onTap: () => _showPicker('Pilih Kelas', _listKelas, (val) => _selectedKelas = val),
                      ),
                      const SizedBox(width: 8),
                      _buildDropdownItem(
                        label: 'Tahun Ajaran',
                        value: _selectedTahunAjaran,
                        onTap: () => _showPicker('Tahun Ajaran', _listTahunAjaran, (val) => _selectedTahunAjaran = val),
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
                          const Icon(Icons.person_outline, size: 20, color: brandPurple),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Fokus Santri Tercakup', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                Text(_selectedSantriId, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text('Pilih Jenis Dokumen Cetak', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDarkColor)),
                  const SizedBox(height: 12),

                  _buildMenuLaporanRow(
                    Icons.assignment_turned_in_rounded,
                    const Color(0xFF6366F1),
                    'Laporan Rekap Transkrip Nilai',
                    'Unduh dokumen PDF resmi berisi kompilasi absensi, rata-rata setoran lisan, serta nilai UTS & UAS santri.',
                    () => _prosesEksporLaporan('Ekspor PDF', 'Laporan Rekap Nilai Santri', const Color(0xFF6366F1)),
                  ),

                  _buildMenuLaporanRow(
                    Icons.insights_rounded,
                    const Color(0xFF9333EA),
                    'Laporan Analisis Kelulusan AI',
                    'Unduh rekapitulasi performa kelulusan dan kenaikan jenjang kelas santri berdasarkan komparasi algoritma Random Forest.',
                    () => _prosesEksporLaporan('Ekspor PDF', 'Laporan Prediksi AI (Random Forest)', const Color(0xFF9333EA)),
                  ),
                  
                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }

  Widget _buildMenuLaporanRow(IconData icon, Color iconBgColor, String title, String subtitle, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: iconBgColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconBgColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, height: 1.4, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}