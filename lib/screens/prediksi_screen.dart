import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/prediksi_service.dart'; // Sesuaikan dengan path service prediksi Anda
import '../services/firestore_service.dart'; // Sesuaikan dengan path firestore Anda
import '../models/santri_model.dart'; // Sesuaikan dengan path model santri Anda

class PrediksiScreen extends StatefulWidget {
  final String role; 
  const PrediksiScreen({super.key, this.role = 'ustadz'}); 

  @override
  State<PrediksiScreen> createState() => _PrediksiScreenState(); 
}

class _PrediksiScreenState extends State<PrediksiScreen> {
  final TextEditingController _hafalanController = TextEditingController();
  final TextEditingController _kehadiranController = TextEditingController();
  final TextEditingController _akademikController = TextEditingController();
  final TextEditingController _perilakuController = TextEditingController();

  String _hasilPrediksi = "";
  bool _isLoading = false;
  bool _isFetchingData = false;

  bool get _isWaliSantri => widget.role == 'wali_santri';

  List<SantriModel> _allSantriList = [];
  List<SantriModel> _filteredSantriList = [];
  
  final List<String> _kelasList = ['Kelas sp', 'Kelas 1', 'Kelas 2', 'Kelas 3', 'Kelas 4'];
  String _selectedKelas = 'Kelas 4'; 
  String _selectedSantriId = '';
  final String _selectedTahunAjaran = '2025/2026'; 
  String _namaSantriTerpilih = 'Pilih Nama Santri...';

  @override
  void initState() {
    super.initState();
    _loadDataSantri();
  }

  Future<void> _loadDataSantri() async {
    try {
      _allSantriList = await FirestoreService.getSantriList();
      _allSantriList = _allSantriList.where((s) => s.status.toLowerCase().contains('aktif')).toList();
      _filterSantriBerdasarkanKelas();
    } catch (e) {
      debugPrint("Gagal load data santri: $e");
    }
  }

  void _filterSantriBerdasarkanKelas() {
    setState(() {
      _filteredSantriList = _allSantriList.where((s) {
        return s.kelas.toLowerCase().trim() == _selectedKelas.toLowerCase().trim();
      }).toList();
      _filteredSantriList.sort((a, b) => a.nama.compareTo(b.nama));
      
      _selectedSantriId = '';
      _namaSantriTerpilih = 'Pilih Nama Santri...';
      _bersihkanForm();
    });
  }

  void _bersihkanForm() {
    _hafalanController.clear();
    _kehadiranController.clear();
    _akademikController.clear();
    _perilakuController.clear();
    _hasilPrediksi = "";
  }

  Future<void> _tarikDataNilaiOtomatis() async {
    if (_selectedSantriId.isEmpty) return;

    setState(() {
      _isFetchingData = true;
      _hasilPrediksi = "";
    });

    try {
      String semester = _selectedKelas; 
      String docId = "${_selectedSantriId}_${_selectedTahunAjaran.replaceAll('/', '-')}_${semester.replaceAll(' ', '')}";
      
      final docSnapshot = await FirebaseFirestore.instance.collection('nilai').doc(docId).get();

      if (!mounted) return;

      if (docSnapshot.exists && docSnapshot.data() != null) {
        Map<String, dynamic> data = docSnapshot.data()!;
        
        double kehadiran = double.tryParse(data['nilai_kehadiran']?.toString() ?? '0') ?? 0.0;
        double perilaku = double.tryParse(data['nilai_perilaku']?.toString() ?? '0') ?? 0.0;

        double totalUts = 0; int countUts = 0;
        if (data['uts'] is Map) {
          (data['uts'] as Map).forEach((_, v) { totalUts += double.tryParse(v.toString()) ?? 0; countUts++; });
        }
        double avgUts = countUts > 0 ? totalUts / countUts : 0.0;

        double totalUas = 0; int countUas = 0;
        if (data['uas'] is Map) {
          (data['uas'] as Map).forEach((_, v) { totalUas += double.tryParse(v.toString()) ?? 0; countUas++; });
        }
        double avgUas = countUas > 0 ? totalUas / countUas : 0.0;
        double nilaiAkademikGabungan = (avgUts + avgUas) / 2;

        double totalHafalan = 0; int countHafalan = 0;
        if (data['hafalan_kitab'] is Map) {
          (data['hafalan_kitab'] as Map).forEach((_, v) { totalHafalan += double.tryParse(v.toString()) ?? 0; countHafalan++; });
        }
        double avgHafalan = countHafalan > 0 ? totalHafalan / countHafalan : 0.0;

        _hafalanController.text = avgHafalan.toStringAsFixed(1);
        _kehadiranController.text = kehadiran.toStringAsFixed(1);
        _akademikController.text = nilaiAkademikGabungan.toStringAsFixed(1);
        _perilakuController.text = perilaku.toStringAsFixed(1);

        if (data['status_prediksi_ai'] != null) {
          _hasilPrediksi = "Prediksi: ${data['status_prediksi_ai']}";
        } else {
          if (_isWaliSantri) {
            _hasilPrediksi = "Belum ada hasil analisis dari Ustadz";
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data nilai berhasil ditarik!"), backgroundColor: Colors.green));
      } else {
        _bersihkanForm();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Belum ada data nilai tersimpan untuk santri ini."), backgroundColor: Colors.orange));
      }
    } catch (e) {
      debugPrint("Error tarik nilai: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingData = false;
        });
      }
    }
  }

  Future<void> _prosesPrediksi() async {
    if (_hafalanController.text.isEmpty ||
        _kehadiranController.text.isEmpty ||
        _akademikController.text.isEmpty ||
        _perilakuController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Harap isi semua nilai!")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _hasilPrediksi = "";
    });

    try {
      double hafalan = double.parse(_hafalanController.text);
      double kehadiran = double.parse(_kehadiranController.text);
      double akademik = double.parse(_akademikController.text);
      double perilaku = double.parse(_perilakuController.text);

      int hasilApi = await PrediksiApiService.getPrediksiKelulusan(
        hafalanKitab: hafalan,
        kehadiran: kehadiran,
        nilaiAkademik: akademik,
        nilaiPerilaku: perilaku,
      );

      String teksHasil = "";
      bool isKelas4 = _selectedKelas.toLowerCase().trim() == 'kelas 4';

      if (hasilApi == 0) {
        teksHasil = isKelas4 ? "LULUS TEPAT WAKTU" : "NAIK KELAS";
      } else {
        teksHasil = isKelas4 ? "TIDAK LULUS" : "TINGGAL KELAS";
      }

      if (_selectedSantriId.isNotEmpty) {
        String semester = _selectedKelas; 
        String docId = "${_selectedSantriId}_${_selectedTahunAjaran.replaceAll('/', '-')}_${semester.replaceAll(' ', '')}";
        
        await FirebaseFirestore.instance.collection('nilai').doc(docId).set({
          'status_prediksi_ai': teksHasil,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;

      setState(() {
        _hasilPrediksi = "Prediksi: $teksHasil";
      });

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Terjadi kesalahan: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getCatatanSpesial() {
    final kelasKecil = _selectedKelas.toLowerCase().trim();
    if (kelasKecil == 'kelas sp' || kelasKecil == 'kelas 1' || kelasKecil == 'kelas 2' || kelasKecil == 'kelas 3') {
      if (_hasilPrediksi.contains("NAIK KELAS")) {
        return "Pertahankan Hafalan nya lebih giat lagi belajar";
      } else if (_hasilPrediksi.contains("TINGGAL KELAS")) {
        return "Lebih giat lagi belajar dan menghafal nya";
      }
    }
    return "";
  }

  void _showSantriPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pilih Santri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: _filteredSantriList.isEmpty
                    ? const Center(child: Text('Tidak ada santri di kelas ini'))
                    : ListView.builder(
                        itemCount: _filteredSantriList.length,
                        itemBuilder: (context, idx) {
                          final santri = _filteredSantriList[idx];
                          return ListTile(
                            leading: CircleAvatar(backgroundColor: Colors.blue[50], child: const Icon(Icons.person, color: Colors.blue)),
                            title: Text(santri.nama, style: const TextStyle(fontWeight: FontWeight.w600)),
                            onTap: () {
                              final navigator = Navigator.of(context);
                              setState(() {
                                _selectedSantriId = santri.id;
                                _namaSantriTerpilih = santri.nama;
                              });
                              navigator.pop();
                              _tarikDataNilaiOtomatis(); 
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

  Widget _buildCustomTextField(String label, TextEditingController controller, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        readOnly: true, 
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: Colors.blue[900]),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade900, width: 2)),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catatanSpesial = _getCatatanSpesial();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC), 
      appBar: AppBar(
        title: Text(_isWaliSantri ? 'Hasil Prediksi Santri' : 'Analisis Prediksi AI', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: Colors.blue[900], 
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isWaliSantri) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.grey.withAlpha(20), blurRadius: 10, offset: const Offset(0, 5))]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.manage_search_rounded, color: Colors.blue[900]),
                        const SizedBox(width: 8),
                        const Text("Tarik Data Santri", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: const Color(0xFFFAFAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedKelas,
                          items: _kelasList.map((k) => DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedKelas = val);
                              _filterSantriBerdasarkanKelas();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _showSantriPicker,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFFFAFAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_namaSantriTerpilih, style: TextStyle(fontWeight: FontWeight.w600, color: _selectedSantriId.isEmpty ? Colors.grey : Colors.black)),
                            _isFetchingData 
                                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                                : const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text("Parameter Penilaian (Otomatis)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12),
              _buildCustomTextField('Nilai Rata-Rata Hafalan Kitab', _hafalanController, Icons.menu_book_rounded),
              _buildCustomTextField('Persentase Kehadiran (%)', _kehadiranController, Icons.co_present_rounded),
              _buildCustomTextField('Nilai Rata-rata Academic', _akademikController, Icons.school_rounded),
              _buildCustomTextField('Nilai Perilaku / Akhlak', _perilakuController, Icons.emoji_emotions_rounded),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _prosesPrediksi,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: Colors.blue[900],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Jalankan Analisis AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 24),
            ],

            if (_isWaliSantri && _hasilPrediksi.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: const Center(
                  child: Text("Belum ada data hasil analisis yang dirilis oleh Ustadz.", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
                ),
              ),
            
            if (_hasilPrediksi.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _hasilPrediksi.contains("TIDAK") || _hasilPrediksi.contains("TINGGAL") 
                        ? [Colors.red.shade50, Colors.red.shade100]
                        : [Colors.green.shade50, Colors.green.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _hasilPrediksi.contains("TIDAK") || _hasilPrediksi.contains("TINGGAL") ? Colors.red.shade200 : Colors.green.shade200,
                    width: 2,
                  ),
                  boxShadow: [BoxShadow(color: Colors.grey.withAlpha(20), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Column(
                  children: [
                    Icon(
                      _hasilPrediksi.contains("TIDAK") || _hasilPrediksi.contains("TINGGAL") ? Icons.cancel_rounded : Icons.check_circle_rounded,
                      size: 40,
                      color: _hasilPrediksi.contains("TIDAK") || _hasilPrediksi.contains("TINGGAL") ? Colors.red[700] : Colors.green[700],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _hasilPrediksi,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _hasilPrediksi.contains("TIDAK") || _hasilPrediksi.contains("TINGGAL") ? Colors.red[800] : Colors.green[800],
                      ),
                    ),
                    
                    if (catatanSpesial.isNotEmpty) ...[
  // Tambahkan const di depan Padding untuk menghilangkan warning linter
  const Padding( 
    padding: EdgeInsets.symmetric(horizontal: 20.0),
    child: Divider(color: Colors.black26, height: 20), 
  ),
  Text(
    catatanSpesial,
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      fontStyle: FontStyle.italic,
      color: _hasilPrediksi.contains("TINGGAL") ? Colors.red.shade900 : Colors.green.shade900,
    ),
  ),
],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}