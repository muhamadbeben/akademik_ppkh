// File: lib/screens/jadwal_pelajaran_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/jadwal_pelajaran_model.dart';

class JadwalPelajaranScreen extends StatefulWidget {
  const JadwalPelajaranScreen({super.key});

  @override
  State<JadwalPelajaranScreen> createState() => _JadwalPelajaranScreenState();
}

class _JadwalPelajaranScreenState extends State<JadwalPelajaranScreen> {
  // List Kelas Ponpes Khoirul Huda
  final List<String> _kelasList = [
    'Kelas sp',
    'Kelas 1',
    'Kelas 2',
    'Kelas 3',
    'Kelas 4'
  ];
  
  final List<String> _daftarHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  
  // DATA MASTER DROPDOWN (Sama persis dengan huruf besar-kecil di gambar database Anda)
  final List<String> _masterWaktu = [
    'Subuh', 
    'Jam 09:00', 
    'Ba\'da Duhur', 
    'Ba\'da Asar', 
    'Ba\'da Magrib', 
    'Ba\'da Isya', 
    '22:00'
  ];

  final List<String> _masterKitabKegiatan = [
    'Tasrifan', 'Bulugul m.', 'Mabadi fqh', 'Mukh. Hadis', 'Ta\'lim', 'Jurumiah',
    'Safinah', 'J. jawamie', 'Asbah w.', 'Alfiah', 'Kaelani', 'sorogan', 'p. ibadah',
    'aqoid iman', 'Al-qur\'an', 'Pegon', 'bimbingan', 'Btq', 'Awamil', 'Sapinah',
    'Qoaid fiqih', 'Wasiatul m.', 'Khulasoh', 'Adabul alim', 'f. muin', 'prktek b.kitab',
    'Tajwid', 'washoya', 'T.jalalain', 'Nasta\'inu', 'Khulasoh', 'm. burdah', 'alfiah & riad',
    'Kifayatul A.riyadh', 'Tanqih', 'Samar Q.alfiyah', 'j.maknun', 'Samar Q', 'Yasinan&marhaban',
    'Muhadhoroh', 'Libur', 'Gotong royong', 'F.qorib,riyadh,alfiyah', 'F.qorib,riyadh,altiyah'
  ];

  final List<String> _masterUstadz = [
    '- (Kegiatan Bersama)', 'Abah', 'Rofi', 'Mg rifki', 'Mg fahmi', 'Nur', 'Agung', 
    'Rahmat', 'Mg ibad', 'Husnul', 'Upit', 'Indri', 'Rijal', 'Mg iming', 'Ipang', 'Ust hanan'
  ];

  String _selectedKelas = 'Kelas 1';
  String _selectedHari = 'Senin';
  
  List<JadwalPelajaranModel> _jadwalHariIni = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setHariDefault();
    _fetchDataJadwal();
  }

  void _setHariDefault() {
    int weekday = DateTime.now().weekday;
    if (weekday >= 1 && weekday <= 7) {
      _selectedHari = _daftarHari[weekday - 1];
    } else {
      _selectedHari = 'Senin';
    }
  }

  Future<void> _fetchDataJadwal() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('jadwal')
          .where('kelas', isEqualTo: _selectedKelas)
          .where('hari', isEqualTo: _selectedHari)
          .get();

      final List<JadwalPelajaranModel> loadedJadwal = snapshot.docs.map((doc) {
        return JadwalPelajaranModel.fromMap(doc.data(), doc.id);
      }).toList();

      // URUTAN KUSTOM: Sekarang membandingkan huruf besar-kecil secara fleksibel (.toLowerCase())
      loadedJadwal.sort((a, b) {
        int indexA = _masterWaktu.indexWhere((w) => a.jamMulai.toLowerCase().trim() == w.toLowerCase().trim());
        int indexB = _masterWaktu.indexWhere((w) => b.jamMulai.toLowerCase().trim() == w.toLowerCase().trim());
        if (indexA == -1) indexA = 99;
        if (indexB == -1) indexB = 99;
        return indexA.compareTo(indexB);
      });

      if (mounted) {
        setState(() {
          _jadwalHariIni = loadedJadwal;
        });
      }
    } catch (e) {
      debugPrint("Error fetching jadwal: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat jadwal: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onKelasChanged(String? newValue) {
    if (newValue != null && newValue != _selectedKelas) {
      setState(() {
        _selectedKelas = newValue;
      });
      _fetchDataJadwal();
    }
  }

  void _onHariChanged(String hari) {
    if (hari != _selectedHari) {
      setState(() {
        _selectedHari = hari;
      });
      _fetchDataJadwal();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A54)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Jadwal Pengajian',
          style: TextStyle(
            color: Color(0xFF1A1A54),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF1A1A54)),
            onPressed: _fetchDataJadwal,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDropdownKelas(),
                const SizedBox(height: 16),
                _buildFilterHari(),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF3C21F7)))
                : _buildListJadwal(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddJadwalDialog(),
        backgroundColor: const Color(0xFF3C21F7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDropdownKelas() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Jenjang Kelas Ponpes',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedKelas,
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black87),
                items: _kelasList.map((String kelas) {
                  return DropdownMenuItem<String>(
                    value: kelas,
                    child: Row(
                      children: [
                        const Icon(Icons.mosque_outlined, color: Color(0xFF3C21F7), size: 20),
                        const SizedBox(width: 12),
                        Text(
                          kelas == 'Kls sp' ? 'Kelas Sifir (Persiapan)' : kelas,
                          style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _onKelasChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHari() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _daftarHari.map((hari) {
          bool isSelected = _selectedHari == hari;
          return GestureDetector(
            onTap: () => _onHariChanged(hari),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF3C21F7) : const Color(0xFFF4F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                hari,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black54,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildListJadwal() {
    if (_jadwalHariIni.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Belum ada data kitab di $_selectedKelas hari $_selectedHari.',
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _jadwalHariIni.length + 1,
      itemBuilder: (context, index) {
        if (index == _jadwalHariIni.length) {
          return _buildInfoBanner();
        }

        final jadwal = _jadwalHariIni[index];
        
        bool isKegiatanBersama = 
            jadwal.mataPelajaran.toLowerCase().contains('libur') ||
            jadwal.mataPelajaran.toLowerCase().contains('gotong') ||
            jadwal.mataPelajaran.toLowerCase().contains('sorogan') ||
            jadwal.mataPelajaran.toLowerCase().contains('bimbingan');

        if (isKegiatanBersama) {
          return _buildKegiatanBersamaCard(jadwal);
        }

        return _buildPelajaranCard(jadwal);
      },
    );
  }

  Widget _buildPelajaranCard(JadwalPelajaranModel jadwal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.015), blurRadius: 8, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 95,
            child: Text(
              jadwal.jamMulai, 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
            ),
          ),
          Container(
            width: 1, height: 40,
            color: Colors.grey.shade200,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  jadwal.mataPelajaran, 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1A54)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        (jadwal.guru.isEmpty || jadwal.guru == '- (Kegiatan Bersama)') ? 'Kegiatan Bersama' : 'Ustadz: ${jadwal.guru}', 
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            onPressed: () => _deleteJadwal(jadwal.id),
          )
        ],
      ),
    );
  }

  Widget _buildKegiatanBersamaCard(JadwalPelajaranModel jadwal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F1FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 95,
            child: Text(
              jadwal.jamMulai,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF3C21F7)),
            ),
          ),
          Container(
            width: 1, height: 25,
            color: const Color(0xFFD6CFFF),
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          Expanded(
            child: Text(
              jadwal.mataPelajaran,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF3C21F7)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFF3C21F7), size: 20),
            onPressed: () => _deleteJadwal(jadwal.id),
          )
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF4F5F9), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF1A1A54), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Jadwal pengajian di atas mengacu pada kalender akademik Pondok Pesantren Khoirul Huda Nurul Iman Tangerang.',
              style: TextStyle(fontSize: 12, height: 1.4, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteJadwal(String id) async {
    try {
      await FirebaseFirestore.instance.collection('jadwal').doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data jadwal berhasil dihapus'), backgroundColor: Colors.red),
        );
      }
      _fetchDataJadwal();
    } catch (e) {
      debugPrint("Gagal menghapus: $e");
    }
  }

  void _showAddJadwalDialog() {
    String pilihanWaktu = _masterWaktu[0];
    String pilihanKitab = _masterKitabKegiatan[0];
    String pilihanUstadz = _masterUstadz[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Plot Jadwal - $_selectedKelas', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              const SizedBox(height: 14),
              
              // 1. DROPDOWN PILIHAN WAKTU MASUK
              DropdownButtonFormField<String>(
                value: pilihanWaktu,
                decoration: const InputDecoration(labelText: 'Waktu / Jam Pengajian', border: OutlineInputBorder(), prefixIcon: Icon(Icons.access_time)),
                items: _masterWaktu.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                onChanged: (v) => setModalState(() => pilihanWaktu = v!),
              ),
              const SizedBox(height: 14),
              
              // 2. DROPDOWN PILIHAN NAMA KITAB
              DropdownButtonFormField<String>(
                value: pilihanKitab,
                decoration: const InputDecoration(labelText: 'Nama Kitab / Kegiatan', border: OutlineInputBorder(), prefixIcon: Icon(Icons.menu_book)),
                items: _masterKitabKegiatan.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                onChanged: (v) => setModalState(() => pilihanKitab = v!),
              ),
              const SizedBox(height: 14),
              
              // 3. DROPDOWN PILIHAN USTADZ
              DropdownButtonFormField<String>(
                value: pilihanUstadz,
                decoration: const InputDecoration(labelText: 'Ustadz Pengajar', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                items: _masterUstadz.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (v) => setModalState(() => pilihanUstadz = v!),
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3C21F7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () async {
                    // Simpan data pilihan Dropdown langsung ke Firebase
                    await FirebaseFirestore.instance.collection('jadwal').add({
                      'kelas': _selectedKelas,
                      'hari': _selectedHari,
                      'mata_pelajaran': pilihanKitab,
                      'guru': pilihanUstadz == '- (Kegiatan Bersama)' ? '' : pilihanUstadz,
                      'ruangan': '',
                      'jam_mulai': pilihanWaktu, 
                      'jam_selesai': '', 
                      'ruangan': ''
                    });

                    if (ctx.mounted) Navigator.pop(ctx);
                    _fetchDataJadwal();
                  },
                  child: const Text('Simpan Jadwal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}