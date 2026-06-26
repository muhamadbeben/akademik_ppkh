// File: lib/screens/rapor_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data'; 
import '../models/santri_model.dart';
import '../models/rapor_model.dart';
import '../services/firestore_service.dart';
import '../services/rapor_service.dart';
import '../services/rapor_pdf_service.dart';

class RaporScreen extends StatefulWidget {
  final String? santriId;
  final String? userRole;

  const RaporScreen({super.key, this.santriId, this.userRole});

  @override
  State<RaporScreen> createState() => _RaporScreenState();
}

class _RaporScreenState extends State<RaporScreen> {
  final RaporPdfService _pdfService = RaporPdfService();
  List<SantriModel> _santriList = [];
  bool _isLoading = true;
  bool _isWaliSantriMode = false;
  
  bool _isPrintingGlobal = false;

  String _selectedKelasName = 'Semua Kelas';
  String _selectedTahunAjaran = '2025/2026';

  Future<List<RaporModel>>? _raporFuture;

  final List<String> _listKelasName = [
    'Semua Kelas',
    'Kelas sp',
    'Kelas 1',
    'Kelas 2',
    'Kelas 3',
    'Kelas 4',
  ];

  final List<String> _listTahunAjaran = ['2025/2026', '2024/2025'];

  final List<String> _masterKelas = [
    'Kelas sp',
    'Kelas 1',
    'Kelas 2',
    'Kelas 3',
    'Kelas 4',
  ];

  @override
  void initState() {
    super.initState();
    _loadDataAwal();
  }

  Future<void> _loadDataAwal() async {
    setState(() => _isLoading = true);
    try {
      String? targetSantriId = widget.santriId;
      String? role = widget.userRole;

      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
          role ??= userData?['role']?.toString().trim();
          targetSantriId ??= userData?['santriId']?.toString().trim();
        }
      }

      if (role?.toLowerCase().trim() == 'walisantri') {
        _isWaliSantriMode = true;
        if (targetSantriId != null && targetSantriId.isNotEmpty) {
          SantriModel? anak = await FirestoreService.getSantriById(targetSantriId);
          if (anak != null) {
            _santriList = [anak];
          }
        }
      } else {
        _isWaliSantriMode = false;
        _santriList = await FirestoreService.getSantriList();
      }

      _refreshRaporData();
    } catch (e) {
      debugPrint("Error loading data awal: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _refreshRaporData() {
    setState(() {
      _raporFuture = _fetchRaporBySelectedFilter();
    });
  }

  Future<List<RaporModel>> _fetchRaporBySelectedFilter() async {
    if (_santriList.isEmpty) return [];

    List<String> targetKelasToCheck = [];
    
    // PERBAIKAN: Jika yang login adalah Wali Santri, paksa untuk mencari di SEMUA KELAS 
    // agar riwayat rapor anak dari kelas SP hingga kelas saat ini muncul semua.
    if (_selectedKelasName == 'Semua Kelas' || _isWaliSantriMode) {
      targetKelasToCheck = _masterKelas;
    } else {
      targetKelasToCheck = [_selectedKelasName];
    }

    final List<List<RaporModel>> urutanHasilParalel = await Future.wait(
      _santriList.map((santri) async {
        List<RaporModel> raporSantriIni = [];
        
        String kelasSantri = santri.kelas.toLowerCase().trim();
        
        // Pengecualian khusus jika ingin mengecek nilai lampau alumni
        // Jika tidak, biarkan di skip
        if ((kelasSantri.contains('lulus') || kelasSantri.contains('alumni')) && !_isWaliSantriMode) {
          return raporSantriIni;
        }

        for (var currentKelas in targetKelasToCheck) {
          try {
            // 1. Cek apakah dokumen Rapor permanen sudah ada di Firebase
            RaporModel? raporExisting = await RaporService.getRaporBySantri(
                santri.id, currentKelas, _selectedTahunAjaran);
            
            if (raporExisting != null && raporExisting.daftarNilai.isNotEmpty) {
              raporSantriIni.add(raporExisting);
              continue; 
            }

            // 2. PERBAIKAN: Jika rapor belum ada, tapi guru SUDAH INPUT nilai di koleksi 'nilai',
            // sistem akan LANGSUNG men-generate Rapor secara on-the-fly agar bisa dicetak!
            RaporModel? raporGenerated = await RaporService.generateRapor(
                santri, currentKelas, _selectedTahunAjaran);

            if (raporGenerated == null || raporGenerated.daftarNilai.isEmpty) {
              String alternatifKelas = currentKelas.toLowerCase().replaceAll(' ', '');
              raporGenerated = await RaporService.generateRapor(
                  santri, alternatifKelas, _selectedTahunAjaran);
            }

            if (raporGenerated == null || raporGenerated.daftarNilai.isEmpty) {
              String alternatifKelas2 = currentKelas.toLowerCase();
              raporGenerated = await RaporService.generateRapor(
                  santri, alternatifKelas2, _selectedTahunAjaran);
            }

            // Jika berhasil digenerate dari koleksi nilai, tambahkan ke list untuk ditampilkan
            if (raporGenerated != null && raporGenerated.daftarNilai.isNotEmpty) {
              raporSantriIni.add(raporGenerated);
            }
          } catch (e) {
            debugPrint("Error mencari rapor untuk ${santri.nama} di $currentKelas: $e");
          }
        }
        return raporSantriIni;
      }),
    );

    List<RaporModel> daftarRaporHasilPencarian = urutanHasilParalel.expand((x) => x).toList();

    // Urutkan berdasarkan kelas dari SP ke Kelas 4
    daftarRaporHasilPencarian.sort((a, b) => a.kelas.compareTo(b.kelas));
    
    return daftarRaporHasilPencarian;
  }

  Future<void> _simpanRaporKeFirebase(RaporModel rapor) async {
    try {
      String safeId = rapor.id.replaceAll('TEMP_', '').replaceAll('/', '-');
      final docRef = FirebaseFirestore.instance.collection('rapor').doc(safeId);

      await docRef.set({
        'id': safeId,
        'santriId': rapor.santriId,
        'namaSantri': rapor.namaSantri,
        'nis': rapor.nis,
        'kelas': rapor.kelas, 
        'tahunAjaran': rapor.tahunAjaran,
        'nilaiRataRata': rapor.nilaiRataRata,
        'predikat': rapor.predikat,
        'catatanWaliKelas': rapor.catatanWaliKelas,
        'tanggalCetak': FieldValue.serverTimestamp(),
        'daftarNilai': rapor.daftarNilai
            .map((n) => {
                  'mataPelajaran': n.mataPelajaran,
                  'nilaiHarian': n.nilaiHarian,
                  'grade': n.grade,
                })
            .toList(),
      }, SetOptions(merge: true));
      debugPrint("Rapor berhasil disimpan secara permanen dengan ID: $safeId");
    } catch (e) {
      debugPrint("Gagal menyimpan rapor ke firebase: $e");
    }
  }

  Color _getColorByPredicate(String predikat) {
    if (predikat.contains('A')) return Colors.green.shade600;
    if (predikat.contains('B')) return Colors.blue.shade600;
    if (predikat.contains('C')) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  Color _getBgColorByPredicate(String predikat) {
    if (predikat.contains('A')) return Colors.green.shade50;
    if (predikat.contains('B')) return Colors.blue.shade50;
    if (predikat.contains('C')) return Colors.orange.shade50;
    return Colors.red.shade50;
  }

  String _getArabicPredicate(String predikat) {
    if (predikat.contains('A')) return 'ممتاز';
    if (predikat.contains('B')) return 'جيد جداً';
    if (predikat.contains('C')) return 'جيد'; // Diperbaiki dari typo 'جid'
    return 'راسب';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3C21F7)))
          : Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                
                // Menyembunyikan filter kelas untuk Wali Santri agar riwayat lengkap tidak terfilter tidak sengaja
                if (!_isWaliSantriMode) _buildFilterRow(), 
                
                if (!_isWaliSantriMode) const SizedBox(height: 16),
                
                Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3C21F7)),
                  ),
                  child: Expanded(
                    child: FutureBuilder<List<RaporModel>>(
                        future: _raporFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator(color: Color(0xFF3C21F7)));
                          }

                          final listRapor = snapshot.data ?? [];

                          if (listRapor.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Text(
                                  _isWaliSantriMode
                                      ? 'Belum ada nilai yang diinput oleh Guru untuk anak Anda.'
                                      : 'Tidak ada data nilai lengkap santri aktif yang ditemukan untuk $_selectedKelasName.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                      height: 1.4),
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            itemCount: listRapor.length,
                            itemBuilder: (context, index) => _buildRaporCard(listRapor[index]),
                          );
                        }),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          left: 20,
          right: 20,
          bottom: 30),
      decoration: const BoxDecoration(
        color: Color(0xFF3C21F7),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(38),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.mosque_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text('Ponpes Khoirul Huda',
                        style: TextStyle(color: Colors.white, fontSize: 11))
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          Text(
            _isWaliSantriMode ? 'Rapor Akademik Anak' : 'Rapor Digital Santri',
            style: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _showPicker('Pilih Kelas', _listKelasName, (val) {
                _selectedKelasName = val;
                _refreshRaporData();
              }),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.layers_outlined, size: 18, color: Color(0xFF3C21F7)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedKelasName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => _showPicker('Tahun Ajaran', _listTahunAjaran, (val) {
                _selectedTahunAjaran = val;
                _refreshRaporData();
              }),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 18, color: Color(0xFF3C21F7)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedTahunAjaran,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRaporCard(RaporModel rapor) {
    Color cardColor = _getColorByPredicate(rapor.predikat);
    Color bgColor = _getBgColorByPredicate(rapor.predikat);

    bool isLulus = rapor.kelas.toLowerCase().trim().contains('lulus') || 
                  rapor.kelas.toLowerCase().trim().contains('alumni');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
                color: isLulus ? Colors.green : cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                    radius: 24,
                    backgroundColor: isLulus ? Colors.green.shade50 : bgColor,
                    child: Icon(
                      isLulus ? Icons.school_rounded : Icons.person_rounded,
                      color: isLulus ? Colors.green.shade700 : cardColor,
                    )),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(rapor.namaSantri,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(width: 6),
                          if (isLulus)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade600,
                                borderRadius: BorderRadius.circular(4)
                              ),
                              child: const Text('LULUS', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                            )
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text('NIS: ${rapor.nis}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEECFC),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              rapor.kelas, 
                              style: const TextStyle(fontSize: 9, color: Color(0xFF3C21F7), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isLulus ? Colors.green.shade50 : bgColor, 
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Text(
                    isLulus ? 'خريج' : _getArabicPredicate(rapor.predikat),
                    style: TextStyle(
                      color: isLulus ? Colors.green.shade700 : cardColor, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Rata-rata: ${rapor.nilaiRataRata.toStringAsFixed(1)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isLulus ? Colors.green.shade700 : cardColor)),
                ElevatedButton(
                  onPressed: () => _showModalPreviewRingkasan(rapor),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Row(
                    children: [
                      Text('Lihat Detail', style: TextStyle(fontSize: 11)),
                      Icon(Icons.chevron_right_rounded, size: 14)
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // PERBAIKAN: Modal Picker yang Bisa Di-Scroll
  // =========================================================================
  void _showPicker(String title, List<String> items, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      // Supaya tingginya tidak melebihi layar namun bisa scroll dengan aman
      isScrollControlled: true, 
      builder: (context) => Container(
        padding: const EdgeInsets.only(top: 16, bottom: 20),
        // Batasi tinggi maksimum modal agar menu terpanjang tetap bisa discroll
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            const Divider(height: 30),
            // Expanded ini yang membuat List di dalamnya bisa di-scroll tanpa error "bottom overflowed"
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 24),
                    title: Text(
                      items[index], 
                      textAlign: TextAlign.center, 
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Future.delayed(const Duration(milliseconds: 200), () {
                        onSelect(items[index]);
                      });
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

  void _showModalPreviewRingkasan(RaporModel rapor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).padding.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('Detail Rapor: ${rapor.namaSantri} (${rapor.kelas})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                  ],
                ),
                const Divider(height: 24),
                ...rapor.daftarNilai.map((n) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(n.mataPelajaran, style: const TextStyle(fontSize: 13)),
                          Text('${n.nilaiHarian.toStringAsFixed(0)} (${n.grade})',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('NILAI RATA-RATA:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(rapor.nilaiRataRata.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3C21F7))),
                  ],
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isPrintingGlobal
                        ? null
                        : () async {
                            setModalState(() {
                              _isPrintingGlobal = true;
                            });

                            try {
                              if (!_isWaliSantriMode) {
                                // Akan mengeksekusi simpan permanen ke database koleksi 'rapor'
                                await _simpanRaporKeFirebase(rapor);
                              }

                              final ByteData bytes = await rootBundle.load('assets/images/logo rapot.png');
                              final Uint8List logoBytes = bytes.buffer.asUint8List();

                              await _pdfService.generateAndOpenRapor(rapor, logoBytes);
                              
                              if (bottomSheetContext.mounted) {
                                _refreshRaporData();
                              }
                            } catch (e) {
                              if (bottomSheetContext.mounted) {
                                ScaffoldMessenger.of(bottomSheetContext).showSnackBar(
                                  SnackBar(content: Text('Gagal membuat PDF: $e'), backgroundColor: Colors.red),
                                );
                              }
                            } finally {
                              setModalState(() {
                                _isPrintingGlobal = false;
                              });
                            }
                          },
                    icon: _isPrintingGlobal
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.print_outlined, size: 18),
                    label: Text(
                      _isPrintingGlobal ? 'Memproses PDF...' : 'Cetak Rapor PDF',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3C21F7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}