// File: lib/screens/guru_screen.dart

import 'package:flutter/material.dart';
import '../models/guru_model.dart';
import '../services/guru_service.dart';

class KelolaGuruScreen extends StatefulWidget {
  const KelolaGuruScreen({super.key});

  @override
  State<KelolaGuruScreen> createState() => _KelolaGuruScreenState();
}

class _KelolaGuruScreenState extends State<KelolaGuruScreen> {
  final KelolaGuruService _guruService = KelolaGuruService();
  
  List<GuruModel> _semuaGuru = [];
  List<GuruModel> _guruDitampilkan = [];
  bool _isLoading = true;
  
  String _searchQuery = '';
  String _selectedTab = 'Semua';
  
  final int _itemsPerPage = 5;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _guruService.getDaftarGuru();
      if (mounted) {
        setState(() {
          _semuaGuru = data;
          _filterData();
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterData() {
    List<GuruModel> filtered = _semuaGuru;
    if (_selectedTab != 'Semua') {
      filtered = filtered.where((g) => g.status == _selectedTab).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((g) => 
        g.nama.toLowerCase().contains(query) ||
        g.kelas.toLowerCase().contains(query) || 
        g.username.toLowerCase().contains(query)
      ).toList();
    }
    
    setState(() {
      _guruDitampilkan = filtered;
      _currentPage = 1;
    });
  }

  List<GuruModel> get _paginatedData {
    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (endIndex > _guruDitampilkan.length) endIndex = _guruDitampilkan.length;
    if (startIndex >= _guruDitampilkan.length) return [];
    return _guruDitampilkan.sublist(startIndex, endIndex);
  }

  int get _totalPages => (_guruDitampilkan.length / _itemsPerPage).ceil();
  int get _totalSemua => _semuaGuru.length;
  int get _totalAktif => _semuaGuru.where((g) => g.status == 'Aktif').length;
  int get _totalNonaktif => _semuaGuru.where((g) => g.status == 'Nonaktif').length;

  // --- DIALOG FORM TAMBAH / EDIT ---
  void _showFormDialog({GuruModel? guru}) {
    final nameCtrl = TextEditingController(text: guru?.nama ?? '');
    final nipCtrl = TextEditingController(text: guru?.nip ?? '');
    final userCtrl = TextEditingController(text: guru?.username ?? '');
    final passCtrl = TextEditingController(); 

    // Default langsung mengarah ke Kelas SP
    String selectedKelas = guru?.kelas ?? 'Kelas sp'; 
    final List<String> daftarKelas = ['Kelas sp', 'Kelas 1', 'Kelas 2', 'Kelas 3', 'Kelas 4'];

    if (!daftarKelas.contains(selectedKelas)) {
      selectedKelas = daftarKelas[0];
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              guru == null ? 'Tambah Akun Guru' : 'Edit Data Guru', 
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl, 
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap Guru', 
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nipCtrl, 
                    decoration: const InputDecoration(
                      labelText: 'NIP / ID Guru', 
                      prefixIcon: Icon(Icons.badge),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // --- PERBAIKAN DROPDOWN OVERFLOW ---
                  DropdownButtonFormField<String>(
                    isExpanded: true, // Menambahkan ini agar dropdown menyesuaikan lebar dan tidak overflow
                    value: selectedKelas,
                    decoration: const InputDecoration(
                      labelText: 'Mengajar Kelas', 
                      prefixIcon: Icon(Icons.class_),
                      border: OutlineInputBorder(),
                    ),
                    items: daftarKelas.map((String kls) {
                      return DropdownMenuItem(
                        value: kls, 
                        child: Text(
                          kls == 'Kelas sp' ? 'Kelas Sifir (Persiapan)' : kls,
                          overflow: TextOverflow.ellipsis, // Memotong teks panjang menjadi '...'
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedKelas = val);
                      }
                    },
                  ),
                  // -----------------------------------
                  
                  const SizedBox(height: 12),
                  TextField(
                    controller: userCtrl, 
                    decoration: const InputDecoration(
                      labelText: 'Alamat Email (Username)', 
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (guru == null) 
                    TextField(
                      controller: passCtrl, 
                      decoration: const InputDecoration(
                        labelText: 'Password', 
                        prefixIcon: Icon(Icons.lock),
                      ), 
                      obscureText: true,
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx), 
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3C21F7), 
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (nameCtrl.text.isEmpty || userCtrl.text.isEmpty || (guru == null && passCtrl.text.length < 6)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Harap lengkapi semua data dengan benar. Password min 6 karakter.'), 
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  setState(() => _isLoading = true);
                  
                  try {
                    if (guru == null) {
                      await _guruService.tambahGuru({
                        'nama': nameCtrl.text, 
                        'nip': nipCtrl.text, 
                        'kelas': selectedKelas, 
                        'username': userCtrl.text, 
                        'password': passCtrl.text, 
                        'role': 'guru', // Role wajib huruf kecil
                        'status': 'Aktif'
                      });
                    } else {
                      await _guruService.updateGuru(guru.id, {
                        'nama': nameCtrl.text, 
                        'nip': nipCtrl.text, 
                        'kelas': selectedKelas,
                        'username': userCtrl.text
                      });
                    }
                    _fetchData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Akun Guru berhasil disimpan!'), 
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                    setState(() => _isLoading = false);
                  }
                },
                child: const Text('Simpan Akun', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  // --- DIALOG RESET PASSWORD ---
  void _showResetPasswordDialog(GuruModel guru) {
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: passCtrl, 
          decoration: const InputDecoration(labelText: 'Password Baru'), 
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _guruService.resetPassword(guru.id, passCtrl.text);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password berhasil direset', style: TextStyle(color: Colors.white)), 
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  // --- UI UTAMA ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC), 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E1E24)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3C21F7)))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildSearchBar(),
                  const SizedBox(height: 20),
                  _buildTabs(),
                  const SizedBox(height: 20),
                  _buildTableHeader(),
                  const SizedBox(height: 10),
                  _buildListGuru(),
                  const SizedBox(height: 20),
                  _buildPagination(),
                  const SizedBox(height: 30),
                  _buildInfoBanner(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kelola Guru', 
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E1E24)),
            ),
            const SizedBox(height: 6),
            Text(
              'Kelola data dan akun guru', 
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _showFormDialog(), 
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Tambah Guru', style: TextStyle(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3C21F7), 
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        )
      ],
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(12), 
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              onChanged: (val) {
                setState(() { _searchQuery = val; });
                _filterData();
              },
              decoration: InputDecoration(
                hintText: 'Cari nama guru, kelas, atau email...', 
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        _buildTabItem('Semua', _totalSemua),
        const SizedBox(width: 10),
        _buildTabItem('Aktif', _totalAktif),
        const SizedBox(width: 10),
        _buildTabItem('Nonaktif', _totalNonaktif),
      ],
    );
  }

  Widget _buildTabItem(String title, int count) {
    bool isSelected = _selectedTab == title;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTab = title);
          _filterData();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3C21F7) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? null : Border.all(color: Colors.grey.shade200),
          ),
          alignment: Alignment.center,
          child: Text(
            '$title ($count)',
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87, 
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, 
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F1FF), 
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('Nama Guru', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1E1E24)))),
          Expanded(flex: 2, child: Text('Kelas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1E1E24)))),
          Expanded(flex: 2, child: Text('Username', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1E1E24)))),
          Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1E1E24)))),
        ],
      ),
    );
  }

  Widget _buildListGuru() {
    if (_paginatedData.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('Data guru tidak ditemukan.', style: TextStyle(color: Colors.grey))),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _paginatedData.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final guru = _paginatedData[index];
        return _buildGuruCard(guru);
      },
    );
  }

  Widget _buildGuruCard(GuruModel guru) {
    bool isAktif = guru.status == 'Aktif';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: guru.imageUrl != null ? NetworkImage(guru.imageUrl!) : null,
                  child: guru.imageUrl == null ? const Icon(Icons.person, color: Colors.grey) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(guru.nama, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1A1A3A))),
                      const SizedBox(height: 4),
                      Text('NIP: ${guru.nip}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2, 
            child: Text(
              guru.kelas == 'Kelas sp' ? 'Kelas Sifir' : guru.kelas, 
              style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold),
            ),
          ), 
          Expanded(
            flex: 2, 
            child: Text(
              guru.username, 
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAktif ? const Color(0xFFE6F8E8) : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    guru.status,
                    style: TextStyle(
                      color: isAktif ? const Color(0xFF4CAF50) : const Color(0xFFF44336), 
                      fontSize: 10, 
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showActionMenu(guru),
                  child: const Icon(Icons.more_vert, size: 20, color: Colors.black54),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    int start = ((_currentPage - 1) * _itemsPerPage) + 1;
    int end = start + _paginatedData.length - 1;
    if (_guruDitampilkan.isEmpty) { start = 0; end = 0; }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Menampilkan $start - $end dari ${_guruDitampilkan.length} data', 
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        Row(
          children: [
            GestureDetector(
              onTap: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
              child: Icon(Icons.chevron_left, color: _currentPage > 1 ? Colors.black87 : Colors.grey.shade300),
            ),
            const SizedBox(width: 12),
            ...List.generate(_totalPages, (index) {
              int page = index + 1;
              bool isActive = page == _currentPage;
              return GestureDetector(
                onTap: () => setState(() => _currentPage = page),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF3C21F7) : Colors.transparent, 
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    page.toString(), 
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.black87, 
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal, 
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _currentPage < _totalPages ? () => setState(() => _currentPage++) : null,
              child: Icon(Icons.chevron_right, color: _currentPage < _totalPages ? Colors.black87 : Colors.grey.shade300),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FF), 
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info, color: Color(0xFF3C21F7), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informasi', 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E1E24)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kelola akun guru untuk mengatur akses ke aplikasi.', 
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Akun baru secara otomatis akan diarahkan ke Kelas SP (Persiapan).', 
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _showActionMenu(GuruModel guru) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.black87),
              title: const Text('Edit Data Guru'),
              onTap: () { 
                Navigator.pop(context); 
                _showFormDialog(guru: guru); 
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_reset, color: Colors.orange),
              title: const Text('Reset Password'),
              onTap: () { 
                Navigator.pop(context); 
                _showResetPasswordDialog(guru); 
              },
            ),
            ListTile(
              leading: Icon(guru.status == 'Aktif' ? Icons.block : Icons.check_circle, color: Colors.blue),
              title: Text(guru.status == 'Aktif' ? 'Nonaktifkan Akun' : 'Aktifkan Akun'),
              onTap: () async {
                Navigator.pop(context);
                String statusBaru = guru.status == 'Aktif' ? 'Nonaktif' : 'Aktif';
                await _guruService.toggleStatusAkun(guru.id, statusBaru);
                _fetchData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Hapus Akun', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(guru);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(GuruModel guru) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Guru'),
        content: Text('Anda yakin ingin menghapus data ${guru.nama}? Data yang dihapus tidak dapat dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _guruService.hapusGuru(guru.id);
              _fetchData();
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}