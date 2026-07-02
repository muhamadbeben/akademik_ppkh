// File: lib/screens/santri_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; // [TAMBAHAN]: Untuk mengecek sesi login
import 'package:akademik_ppkh/models/santri_model.dart';
import 'package:akademik_ppkh/services/firestore_service.dart';
import 'package:akademik_ppkh/widgets/custom_textfield.dart';

class SantriScreen extends StatefulWidget {
  const SantriScreen({super.key});

  @override
  State<SantriScreen> createState() => _SantriScreenState();
}

class _SantriScreenState extends State<SantriScreen> {
  List<SantriModel> _santriList = [];
  List<SantriModel> _filteredList = [];
  
  // SINKRONISASI KELAS: Dikunci mati sesuai dengan jadwal pelajaran Ponpes Khoirul Huda
  final List<String> _dbKelasList = ['Kelas sp', 'Kelas 1', 'Kelas 2', 'Kelas 3', 'Kelas 4']; 
  
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'Semua';

  // [TAMBAHAN]: Variabel untuk menyimpan profil user yang sedang login
  String _roleUser = 'admin'; 
  String _kelasGuru = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // [TAMBAHAN]: Cek Role & Kelas dari User yang Login
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          _roleUser = userDoc.data()?['role'] ?? 'admin';
          _kelasGuru = userDoc.data()?['kelas'] ?? '';
        }
      }

      // [TAMBAHAN]: Logika Pembatasan Pengambilan Data
      // Jika guru dan punya kelas, hanya request data kelas tersebut. Jika tidak (admin), parameter = null (ambil semua).
      String? filterKelas = (_roleUser == 'guru' && _kelasGuru.isNotEmpty) ? _kelasGuru : null;

      // Panggil service yang sudah diperbaiki sebelumnya
      _santriList = await FirestoreService.getSantriList(kelas: filterKelas);
      _filteredList = List.from(_santriList);
    } catch (e) {
      _showSnackBar('Gagal memuat data: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// FUNGSI OTOMATIS KENAIKAN KELAS MASSAL (SINKRONISASI SKRIPSI PONPES)
  Future<void> _prosesKenaikanKelasMassal() async {
    // Keamanan ekstra: Cegah guru menaikkan kelas massal, hanya admin yang boleh
    if (_roleUser != 'admin') {
      _showSnackBar('Akses ditolak! Hanya Admin yang bisa memproses Kenaikan Kelas Massal.', Colors.red);
      return;
    }

    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Kenaikan Kelas', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Apakah Anda yakin ingin memproses kenaikan kelas untuk seluruh santri aktif?\n\n'
          '• Kelas sp → Kelas 1\n• Kelas 1 → Kelas 2\n• Kelas 2 → Kelas 3\n• Kelas 3 → Kelas 4\n• Kelas 4 → Lulus',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D38F5)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Proses', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    int counter = 0;

    try {
      final batch = FirebaseFirestore.instance.batch();
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('santri')
          .where('status', isEqualTo: 'Aktif')
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        String kelasSekarang = data['kelas'] ?? '';
        String kelasBaru = kelasSekarang;
        String statusBaru = 'Aktif';

        if (kelasSekarang == 'Kelas sp') kelasBaru = 'Kelas 1';
        else if (kelasSekarang == 'Kelas 1') kelasBaru = 'Kelas 2';
        else if (kelasSekarang == 'Kelas 2') kelasBaru = 'Kelas 3';
        else if (kelasSekarang == 'Kelas 3') kelasBaru = 'Kelas 4';
        else if (kelasSekarang == 'Kelas 4') {
          statusBaru = 'Lulus'; 
        }

        if (kelasBaru != kelasSekarang || statusBaru != 'Aktif') {
          batch.update(doc.reference, {
            'kelas': kelasBaru,
            'status': statusBaru,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          counter++;
        }
      }

      if (counter > 0) {
        await batch.commit(); 
        _showSnackBar('Alhamdulillah! Berhasil menaikkan kelas $counter santri.', Colors.green);
      } else {
        _showSnackBar('Tidak ada data santri aktif yang bisa diproses.', Colors.orange);
      }

      _loadData(); 
    } catch (e) {
      _showSnackBar('Gagal memproses kenaikan kelas: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter(String query) {
    setState(() {
      _filteredList = _santriList.where((s) {
        bool matchSearch = query.isEmpty ||
            s.nama.toLowerCase().contains(query.toLowerCase()) ||
            s.nis.contains(query);
        bool matchStatus = _filterStatus == 'Semua' || s.status == _filterStatus;
        return matchSearch && matchStatus;
      }).toList();
    });
  }

  void _showFilterStatusDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Filter Status Santri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Semua', 'Aktif', 'Lulus', 'Keluar'].map((status) {
            final bool isSelected = _filterStatus == status;
            return ListTile(
              title: Text(
                status, 
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFF5D38F5) : const Color(0xFF1E293B),
                ),
              ),
              trailing: isSelected 
                  ? const Icon(Icons.check_circle, color: Color(0xFF5D38F5)) 
                  : Icon(Icons.radio_button_off, color: Colors.grey.shade300), 
              onTap: () {
                setState(() {
                  _filterStatus = status;
                  _applyFilter(_searchController.text);
                });
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  int get totalSantri => _santriList.length;
  int get santriAktif => _santriList.where((s) => s.status == 'Aktif').length;
  int get santriNonAktif => _santriList.where((s) => s.status != 'Aktif').length;

  @override
  Widget build(BuildContext context) {
    Color backgroundColor = const Color(0xFFF8F9FD);
    Color primaryPurple = const Color(0xFF5D38F5);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Kelola Santri',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          // Sembunyikan ikon massal jika dia hanya guru
          if (_roleUser == 'admin')
            IconButton(
              icon: const Icon(Icons.trending_up_rounded, color: Color(0xFF5D38F5)),
              tooltip: 'Kenaikan Kelas Otomatis',
              onPressed: _isLoading ? null : _prosesKenaikanKelasMassal,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _applyFilter,
                      decoration: InputDecoration(
                        hintText: 'Cari nama santri...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _showFilterStatusDialog,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _filterStatus != 'Semua' ? const Color(0xFFEEF0FF) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _filterStatus != 'Semua' ? const Color(0xFF5D38F5) : Colors.grey.shade200, 
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.tune, 
                      color: _filterStatus != 'Semua' ? const Color(0xFF5D38F5) : Colors.grey.shade600, 
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                _buildSummaryCard('Total Santri', totalSantri.toString(), const Color(0xFFEEF0FF), const Color(0xFF5D38F5), Icons.people_alt),
                const SizedBox(width: 8),
                _buildSummaryCard('Santri Aktif', santriAktif.toString(), const Color(0xFFE8FDF0), const Color(0xFF22C55E), Icons.check_circle),
                const SizedBox(width: 8),
                _buildSummaryCard('Nonaktif', santriNonAktif.toString(), const Color(0xFFFFF2EC), const Color(0xFFF97316), Icons.group_remove),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF5D38F5)))
                : _filteredList.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: _filteredList.length,
                        itemBuilder: (_, i) => _buildSantriCard(_filteredList[i]),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(null),
        backgroundColor: primaryPurple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String count, Color bgColor, Color iconColor, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count,
                    style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSantriCard(SantriModel santri) {
    bool isAktif = santri.status == 'Aktif';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetailDialog(santri),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  santri.jenisKelamin == 'P' 
                    ? 'https://img.freepik.com/free-vector/hijab-avatar-girl-wearing-hijab-vector-illustration-hijab-fashion-style_611388-129.jpg'
                    : 'https://img.freepik.com/free-vector/businessman-character-avatar-isolated_24877-60111.jpg', 
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.person, color: Colors.grey);
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      santri.nama, 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${santri.kelas == 'Kelas sp' ? 'Kelas Sifir' : santri.kelas} - ${santri.jenisKelamin == 'L' ? 'Putra' : 'Putri'}',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NIS: ${santri.nis}', 
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isAktif ? const Color(0xFFE8FDF0) : const Color(0xFFFFF2EC),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      santri.status,
                      style: TextStyle(
                        color: isAktif ? const Color(0xFF22C55E) : const Color(0xFFF97316),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (v) {
                      if (v == 'edit') _showFormDialog(santri);
                      if (v == 'delete') _confirmDelete(santri);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue, size: 18), SizedBox(width: 8), Text('Edit')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('Hapus')])),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Belum ada data santri', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
        ],
      ),
    );
  }

  void _showDetailDialog(SantriModel santri) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 35, backgroundColor: const Color(0xFF5D38F5), child: Text(santri.nama.isNotEmpty ? santri.nama[0] : '?', style: const TextStyle(fontSize: 28, color: Colors.white))),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(santri.nama, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              Text('NIS: ${santri.nis}', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 40, thickness: 1),
                    const Text('Data Akademik', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5D38F5))),
                    const SizedBox(height: 10),
                    _detailRow('Kelas', santri.kelas == 'Kelas sp' ? 'Kelas Santri (Persiapan)' : santri.kelas, Icons.class_),
                    _detailRow('Asrama', santri.asrama, Icons.hotel), 
                    _detailRow('Tahun Masuk', santri.tahunMasuk, Icons.date_range),
                    _detailRow('Status', santri.status, Icons.info_outline),
                    
                    const SizedBox(height: 20),
                    const Text('Data Pribadi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5D38F5))),
                    const SizedBox(height: 10),
                    _detailRow('Jenis Kelamin', santri.jenisKelamin == 'L' ? 'Laki-laki' : 'Perempuan', Icons.person),
                    _detailRow('Tempat, Tgl Lahir', '${santri.tempatLahir}, ${santri.tanggalLahir}', Icons.cake),
                    _detailRow('Alamat Lengkap', santri.alamat, Icons.location_on),
                    
                    const SizedBox(height: 20),
                    const Text('Data Orang Tua / Wali', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5D38F5))),
                    const SizedBox(height: 10),
                    _detailRow('Nama Wali (${santri.hubunganWali})', santri.namaWali, Icons.family_restroom),
                    _detailRow('No HP Wali', santri.teleponWali, Icons.phone),
                    _detailRow('Pekerjaan Wali', santri.pekerjaanWali ?? '-', Icons.work),
                    _detailRow('Alamat Wali', santri.alamatWali ?? '-', Icons.home_work),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                Text(value.isEmpty ? '-' : value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFormDialog(SantriModel? santri) {
    final nisCtrl = TextEditingController(text: santri?.nis ?? '');
    final namaCtrl = TextEditingController(text: santri?.nama ?? '');
    final tempatLahirCtrl = TextEditingController(text: santri?.tempatLahir ?? '');
    final tglLahirCtrl = TextEditingController(text: santri?.tanggalLahir ?? '');
    final alamatCtrl = TextEditingController(text: santri?.alamat ?? '');
    final tahunMasukCtrl = TextEditingController(text: santri?.tahunMasuk ?? DateTime.now().year.toString());
    
    final waliCtrl = TextEditingController(text: santri?.namaWali ?? '');
    final telWaliCtrl = TextEditingController(text: santri?.teleponWali ?? '');
    final pekerjaanWaliCtrl = TextEditingController(text: santri?.pekerjaanWali ?? '');
    final alamatWaliCtrl = TextEditingController(text: santri?.alamatWali ?? '');

    String jk = (santri?.jenisKelamin == 'P') ? 'P' : 'L';
    String status = santri?.status ?? 'Aktif';
    
    String hubunganWali = santri?.hubunganWali ?? 'Ayah';
    String asrama = santri?.asrama ?? 'Asrama Putera A';
    
    // [TAMBAHAN]: Set kelas default & paksa kunci form jika itu adalah guru
    String kelas = _dbKelasList[1]; 
    if (santri != null && _dbKelasList.contains(santri.kelas)) {
      kelas = santri.kelas;
    } else if (_roleUser == 'guru' && _kelasGuru.isNotEmpty) {
      kelas = _kelasGuru; // Paksa inputan baru ke kelas milik guru tersebut
    }

    bool isGuru = (_roleUser == 'guru'); // Flag untuk mengunci dropdown

    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(santri == null ? 'Tambah Santri Baru' : 'Edit Data Santri', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.school, color: Color(0xFF5D38F5), size: 20),
                              SizedBox(width: 8),
                              Text('DATA SANTRI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF5D38F5))),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 10),
                          CustomTextField(
                            label: 'NIS', 
                            hint: 'Masukkan NIS Santri', 
                            controller: nisCtrl, 
                            prefixIcon: Icons.badge, 
                            keyboardType: TextInputType.number, 
                            validator: (v) => v!.isEmpty ? 'NIS wajib diisi' : null
                          ),
                          const SizedBox(height: 12),
                          CustomTextField(
                            label: 'Nama Lengkap', 
                            hint: 'Masukkan Nama Lengkap', 
                            controller: namaCtrl, 
                            prefixIcon: Icons.person, 
                            validator: (v) => v!.isEmpty ? 'Nama lengkap wajib diisi' : null
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: jk,
                            decoration: const InputDecoration(labelText: 'Jenis Kelamin', border: OutlineInputBorder(), prefixIcon: Icon(Icons.wc)),
                            items: const [
                              DropdownMenuItem(value: 'L', child: Text('Laki-laki')),
                              DropdownMenuItem(value: 'P', child: Text('Perempuan')),
                            ],
                            onChanged: (v) => setModalState(() => jk = v!),
                          ),
                          const SizedBox(height: 12),
                          CustomTextField(
                            label: 'Tempat Lahir', 
                            hint: 'Masukkan Tempat Lahir', 
                            controller: tempatLahirCtrl, 
                            prefixIcon: Icons.location_city,
                            validator: (v) => v!.isEmpty ? 'Tempat lahir wajib diisi' : null,
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () async {
                              DateTime? picked = await showDatePicker(
                                context: context, 
                                initialDate: DateTime(2012), 
                                firstDate: DateTime(1990), 
                                lastDate: DateTime.now()
                              );
                              if (picked != null) {
                                setModalState(() => tglLahirCtrl.text = DateFormat('dd/MM/yyyy').format(picked));
                              }
                            },
                            child: AbsorbPointer(
                              child: CustomTextField(
                                label: 'Tanggal Lahir', 
                                hint: 'dd/mm/yyyy', 
                                controller: tglLahirCtrl, 
                                prefixIcon: Icons.calendar_month,
                                validator: (v) => v!.isEmpty ? 'Tanggal lahir wajib diisi' : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          CustomTextField(
                            label: 'Alamat', 
                            hint: 'Masukkan Alamat Lengkap', 
                            controller: alamatCtrl, 
                            prefixIcon: Icons.home, 
                            maxLines: 2,
                            validator: (v) => v!.isEmpty ? 'Alamat wajib diisi' : null,
                          ),
                          const SizedBox(height: 12),
                          CustomTextField(
                            label: 'Tahun Masuk', 
                            hint: 'Contoh: 2024', 
                            controller: tahunMasukCtrl, 
                            prefixIcon: Icons.date_range, 
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'Tahun masuk wajib diisi' : null,
                          ),
                          const SizedBox(height: 12),
                          
                          // [TAMBAHAN]: PENGUNCIAN KELAS UNTUK GURU
                          DropdownButtonFormField<String>(
                            value: _dbKelasList.contains(kelas) ? kelas : (_kelasGuru.isNotEmpty ? _kelasGuru : _dbKelasList[0]),
                            decoration: const InputDecoration(labelText: 'Kelas', border: OutlineInputBorder(), prefixIcon: Icon(Icons.class_)),
                            // Jika Guru: Pilihan cuma kelasnya sendiri. Jika Admin: Tampilkan semua.
                            items: isGuru 
                                ? [DropdownMenuItem(value: _kelasGuru, child: Text(_kelasGuru == 'Kelas sp' ? 'Kelas Sifir (Persiapan)' : _kelasGuru))]
                                : _dbKelasList.map((e) => DropdownMenuItem(value: e, child: Text(e == 'Kelas sp' ? 'Kelas Sifir (Persiapan)' : e))).toList(),
                            // Matikan tombol pilih (disable/null) jika dia guru, biarkan bisa diganti kalau admin
                            onChanged: isGuru 
                                ? null 
                                : (v) => setModalState(() => kelas = v!),
                          ),
                          const SizedBox(height: 12),
                          
                          DropdownButtonFormField<String>(
                            value: status,
                            decoration: const InputDecoration(labelText: 'Status Santri', border: OutlineInputBorder(), prefixIcon: Icon(Icons.info_outline)),
                            items: ['Aktif', 'Lulus', 'Keluar'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) => setModalState(() => status = v!),
                          ),
                          
                          const SizedBox(height: 28),
                          const Row(
                            children: [
                              Icon(Icons.family_restroom, color: Color(0xFF5D38F5), size: 20),
                              SizedBox(width: 8),
                              Text('DATA WALI SANTRI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF5D38F5))),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 10),
                          CustomTextField(
                            label: 'Nama Wali', 
                            hint: 'Masukkan Nama Lengkap Wali', 
                            controller: waliCtrl, 
                            prefixIcon: Icons.person_outline,
                            validator: (v) => v!.isEmpty ? 'Nama wali wajib diisi' : null,
                          ),
                          const SizedBox(height: 12),
                          CustomTextField(
                            label: 'Nomor HP Wali', 
                            hint: 'Contoh: 08xxxxxxxxxx', 
                            controller: telWaliCtrl, 
                            prefixIcon: Icons.phone, 
                            keyboardType: TextInputType.phone,
                            validator: (v) => v!.isEmpty ? 'Nomor HP wali wajib diisi' : null,
                          ),
                          const SizedBox(height: 12),
                          CustomTextField(label: 'Pekerjaan Wali', hint: 'Masukkan Pekerjaan', controller: pekerjaanWaliCtrl, prefixIcon: Icons.work_outline),
                          const SizedBox(height: 12),
                          CustomTextField(label: 'Alamat Wali', hint: 'Masukkan Alamat Wali', controller: alamatWaliCtrl, prefixIcon: Icons.map, maxLines: 2),

                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D38F5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              onPressed: () async {
                                if (formKey.currentState!.validate()) {
                                  Navigator.pop(ctx);
                                  
                                  final newData = SantriModel(
                                    id: santri?.id ?? '',
                                    nis: nisCtrl.text,
                                    nama: namaCtrl.text,
                                    kelas: kelas,
                                    asrama: asrama,
                                    kamar: '', 
                                    status: status,
                                    jenisKelamin: jk,
                                    tempatLahir: tempatLahirCtrl.text,
                                    tanggalLahir: tglLahirCtrl.text,
                                    alamat: alamatCtrl.text,
                                    tahunMasuk: tahunMasukCtrl.text,
                                    tanggalMasuk: santri?.tanggalMasuk ?? DateTime.now(),
                                    namaWali: waliCtrl.text,
                                    hubunganWali: hubunganWali,
                                    teleponWali: telWaliCtrl.text,
                                    pekerjaanWali: pekerjaanWaliCtrl.text,
                                    alamatWali: alamatWaliCtrl.text,
                                    usernameWali: santri?.usernameWali ?? '',
                                    passwordWali: santri?.passwordWali ?? '',
                                    prediksiKelulusan: santri?.prediksiKelulusan,
                                  );

                                  try {
                                    if (santri == null) {
                                      await FirestoreService.tambahSantri(newData);
                                    } else {
                                      await FirestoreService.updateSantri(newData);
                                    }
                                    _showSnackBar('Data berhasil disimpan!', Colors.green);
                                    _loadData();
                                  } catch (e) {
                                    _showSnackBar('Gagal menyimpan: $e', Colors.red);
                                  }
                                }
                              },
                              child: const Text('SIMPAN DATA', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
        ),
      ),
    );
  }

  void _confirmDelete(SantriModel santri) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Santri?'),
        content: Text('Yakin ingin menghapus data ${santri.nama}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirestoreService.hapusSantri(santri.id);
                _showSnackBar('Santri berhasil dihapus', Colors.red);
                _loadData();
              } catch (e) {
                _showSnackBar('Gagal menghapus: $e', Colors.red);
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}