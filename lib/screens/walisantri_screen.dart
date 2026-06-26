import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:akademik_ppkh/firebase_options.dart';
import 'package:akademik_ppkh/models/walisantri_model.dart';
import 'package:akademik_ppkh/services/wali_santri_service.dart';

class WaliSantriScreen extends StatefulWidget {
  const WaliSantriScreen({super.key});

  @override
  State<WaliSantriScreen> createState() => _WaliSantriScreenState();
}

class _WaliSantriScreenState extends State<WaliSantriScreen> {
  final WaliSantriService _waliService = WaliSantriService();

  List<WaliSantriModel> _semuaWali = [];
  List<WaliSantriModel> _filteredWali = [];

  String _searchQuery = '';
  String _selectedTab = 'Semua';

  final int _itemsPerPage = 5;
  int _currentPage = 1;

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
      body: StreamBuilder<List<WaliSantriModel>>(
        stream: _waliService.getWaliSantriStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF3C21F7)));
          }

          if (snapshot.hasData) {
            _semuaWali = snapshot.data!;
            _applyFilters();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                _buildListWali(),
                const SizedBox(height: 20),
                _buildPagination(),
                const SizedBox(height: 30),
                _buildInfoBanner(),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  void _applyFilters() {
    List<WaliSantriModel> temp = _semuaWali;

    if (_selectedTab != 'Semua') {
      temp = temp.where((w) => w.status == _selectedTab).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      temp = temp.where((w) {
        return w.namaWali.toLowerCase().contains(query) ||
            w.namaSantri.toLowerCase().contains(query) ||
            w.username.toLowerCase().contains(query);
      }).toList();
    }

    _filteredWali = temp;
  }

  List<WaliSantriModel> get _paginatedData {
    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (endIndex > _filteredWali.length) endIndex = _filteredWali.length;
    if (startIndex >= _filteredWali.length) return [];
    return _filteredWali.sublist(startIndex, endIndex);
  }

  int get _totalPages => (_filteredWali.length / _itemsPerPage).ceil();

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kelola Wali Santri',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E24)),
              ),
              const SizedBox(height: 6),
              Text(
                'Kelola data dan akun wali santri',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _openFormDialog(),
          icon: const Icon(Icons.add, size: 14),
          label: const Text('Tambah Wali',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3C21F7),
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _currentPage = 1;
                });
              },
              decoration: InputDecoration(
                hintText: 'Cari nama wali, santri, atau username...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.grey, size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: IconButton(
            icon: const Icon(Icons.filter_alt_outlined,
                color: Colors.black87, size: 18),
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    int total = _semuaWali.length;
    int aktif = _semuaWali.where((w) => w.status == 'Aktif').length;
    int nonaktif = _semuaWali.where((w) => w.status == 'Nonaktif').length;

    return Row(
      children: [
        _buildTabItem('Semua', total),
        const SizedBox(width: 10),
        _buildTabItem('Aktif', aktif),
        const SizedBox(width: 10),
        _buildTabItem('Nonaktif', nonaktif),
      ],
    );
  }

  Widget _buildTabItem(String title, int count) {
    bool isSelected = _selectedTab == title;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = title;
            _currentPage = 1;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3C21F7) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? null : Border.all(color: Colors.grey.shade200),
          ),
          alignment: Alignment.center,
          child: Text(
            '$title ($count)',
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF3F1FF),
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 3,
            child: Text('Nama Wali',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF1E1E24))),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text('Santri',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF1E1E24))),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text('Hubungan',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF1E1E24))),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text('Username',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF1E1E24))),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: 55,
            child: Text('Status',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF1E1E24)),
                textAlign: TextAlign.center),
          ),
          SizedBox(width: 25),
        ],
      ),
    );
  }

  Widget _buildListWali() {
    if (_paginatedData.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
            child: Text('Data wali santri tidak ditemukan.',
                style: TextStyle(color: Colors.grey))),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _paginatedData.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildWaliCard(_paginatedData[index]),
    );
  }

  Widget _buildWaliCard(WaliSantriModel wali) {
    bool isAktif = wali.status == 'Aktif';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.grey.shade100,
                  child: Icon(
                    wali.hubungan == 'Ibu'
                        ? Icons.face_3_outlined
                        : Icons.face_outlined,
                    color: Colors.grey,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wali.namaWali.isEmpty ? 'Tanpa Nama' : wali.namaWali,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xFF1A1A3A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        wali.noHp,
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wali.namaSantri,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  wali.kelasSantri,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              wali.hubungan,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              wali.username,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 55,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isAktif
                      ? const Color(0xFFE6F8E8)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  wali.status,
                  style: TextStyle(
                    color: isAktif
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFF44336),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 25,
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.more_vert,
                    size: 18, color: Colors.black54),
                onPressed: () => _showActionMenu(wali),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    int start =
        _filteredWali.isEmpty ? 0 : ((_currentPage - 1) * _itemsPerPage) + 1;
    int end = start + _paginatedData.length - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Menampilkan $start - $end dari ${_filteredWali.length} data',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        Row(
          children: [
            GestureDetector(
              onTap: _currentPage > 1
                  ? () => setState(() => _currentPage--)
                  : null,
              child: Icon(Icons.chevron_left,
                  color:
                      _currentPage > 1 ? Colors.black87 : Colors.grey.shade300),
            ),
            const SizedBox(width: 8),
            ...List.generate(_totalPages, (index) {
              int page = index + 1;
              bool isActive = page == _currentPage;
              return GestureDetector(
                onTap: () => setState(() => _currentPage = page),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color:
                        isActive ? const Color(0xFF3C21F7) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text('$page',
                      style: TextStyle(
                          color: isActive ? Colors.white : Colors.black87,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12)),
                ),
              );
            }),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _currentPage < _totalPages
                  ? () => setState(() => _currentPage++)
                  : null,
              child: Icon(Icons.chevron_right,
                  color: _currentPage < _totalPages
                      ? Colors.black87
                      : Colors.grey.shade300),
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
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info, color: Color(0xFF3C21F7), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Informasi',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF1E1E24))),
                const SizedBox(height: 6),
                Text(
                    'Akun wali santri terhubung dengan data santri. Wali dapat melihat nilai, jadwal, dan rapot santri.',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _showActionMenu(WaliSantriModel wali) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10)),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.blue),
                title: const Text('Edit Data Wali Santri',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _openFormDialog(model: wali);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.lock_reset_outlined, color: Colors.orange),
                title: const Text('Reset Password',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _showResetPasswordDialog(wali.id);
                },
              ),
              ListTile(
                leading: Icon(
                    wali.status == 'Aktif'
                        ? Icons.block_outlined
                        : Icons.check_circle_outline,
                    color: wali.status == 'Aktif'
                        ? Colors.redAccent
                        : Colors.green),
                title: Text(
                    wali.status == 'Aktif'
                        ? 'Nonaktifkan Akun'
                        : 'Aktifkan Akun',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                onTap: () async {
                  Navigator.pop(context);
                  String nextStatus =
                      wali.status == 'Aktif' ? 'Nonaktif' : 'Aktif';
                  await _waliService.toggleStatusAkun(wali.id, nextStatus);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Hapus Akun',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(context);
                  _showConfirmDeleteDialog(wali.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConfirmDeleteDialog(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Akun?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'Apakah Anda yakin ingin menghapus akun wali santri ini secara permanen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              await _waliService.hapusWaliSantri(id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Hapus',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openFormDialog({WaliSantriModel? model}) {
    final isEdit = model != null;
    final namaCtrl = TextEditingController(text: isEdit ? model.namaWali : '');
    final noHpCtrl = TextEditingController(text: isEdit ? model.noHp : '');
    final userCtrl = TextEditingController(text: isEdit ? model.username : '');
    final passCtrl = TextEditingController();
    String hubunganSel = isEdit ? model.hubungan : 'Ayah';
    String santriIdSel = isEdit ? model.santriId : '';
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setCtx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(isEdit ? 'Edit Data Wali Santri' : 'Tambah Wali Santri',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSaving) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF3C21F7))),
                  )
                ] else ...[
                  TextField(
                      controller: namaCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Nama Wali')),
                  TextField(
                      controller: noHpCtrl,
                      decoration: const InputDecoration(labelText: 'No HP'),
                      keyboardType: TextInputType.phone),
                  DropdownButtonFormField<String>(
                    initialValue: hubunganSel,
                    items: ['Ayah', 'Ibu', 'Wali']
                        .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                        .toList(),
                    onChanged: (val) => setCtx(() => hubunganSel = val!),
                    decoration:
                        const InputDecoration(labelText: 'Hubungan Keluarga'),
                  ),
                  if (!isEdit) ...[
                    FutureBuilder<QuerySnapshot>(
                      future:
                          FirebaseFirestore.instance.collection('santri').get(),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const LinearProgressIndicator();
                        }
                        if (santriIdSel.isEmpty && snap.data!.docs.isNotEmpty) {
                          santriIdSel = snap.data!.docs.first.id;
                        }
                        return DropdownButtonFormField<String>(
                          initialValue:
                              santriIdSel.isEmpty ? null : santriIdSel,
                          items: snap.data!.docs
                              .map((doc) => DropdownMenuItem(
                                  value: doc.id,
                                  child: Text(doc['nama'] ?? '')))
                              .toList(),
                          onChanged: (val) => setCtx(() => santriIdSel = val!),
                          decoration: const InputDecoration(
                              labelText: 'Hubungkan ke Santri'),
                        );
                      },
                    ),
                    TextField(
                        controller: userCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Username (Tanpa Spasi)')),
                    TextField(
                        controller: passCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Password (Min. 6 Karakter)'),
                        obscureText: true),
                  ]
                ]
              ],
            ),
          ),
          actions: isSaving
              ? []
              : [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3C21F7),
                        foregroundColor: Colors.white),
                    onPressed: () async {
                      if (namaCtrl.text.trim().isEmpty ||
                          (!isEdit && userCtrl.text.trim().isEmpty)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Nama dan Username wajib diisi!'),
                                backgroundColor: Colors.redAccent));
                        return;
                      }

                      if (!isEdit && passCtrl.text.trim().length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Gagal: Password wajib minimal 6 karakter!'),
                                backgroundColor: Colors.redAccent));
                        return;
                      }

                      setCtx(() => isSaving = true);

                      try {
                        if (isEdit) {
                          await _waliService.editWaliSantri(
                              id: model.id,
                              namaWali: namaCtrl.text,
                              noHp: noHpCtrl.text,
                              hubungan: hubunganSel,
                              username: userCtrl.text);
                        } else {
                          String uniqueAppName =
                              'SecondaryApp_${DateTime.now().millisecondsSinceEpoch}';

                          String rawUsername = userCtrl.text.trim();

                          String authEmail = rawUsername.contains('@')
                              ? rawUsername
                              : '$rawUsername@ppkh.com';

                          FirebaseApp secondaryApp =
                              await Firebase.initializeApp(
                            name: uniqueAppName,
                            options: DefaultFirebaseOptions.currentPlatform,
                          );

                          UserCredential secondaryUserCreds =
                              await FirebaseAuth.instanceFor(app: secondaryApp)
                                  .createUserWithEmailAndPassword(
                            email: authEmail,
                            password: passCtrl.text.trim(),
                          );

                          String userUid = secondaryUserCreds.user!.uid;

                          await _waliService.tambahWaliSantri(
                            uid: userUid,
                            namaWali: namaCtrl.text.trim(),
                            noHp: noHpCtrl.text.trim(),
                            santriId: santriIdSel,
                            hubungan: hubunganSel,
                            username: rawUsername,
                            password: passCtrl.text.trim(),
                          );

                          await secondaryApp.delete();
                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Akun Wali Santri berhasil disinkronkan ke Firebase Auth & Firestore!'),
                              backgroundColor: Colors.green));
                        }
                      } catch (error) {
                        setCtx(() => isSaving = false);

                        String errorMsg = error.toString();
                        if (errorMsg.contains('email-already-in-use')) {
                          errorMsg =
                              'Username tersebut sudah terdaftar di sistem!';
                        } else if (errorMsg.contains('invalid-email')) {
                          errorMsg =
                              'Format penulisan username tidak valid (jangan gunakan karakter aneh).';
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Gagal membuat akun: $errorMsg'),
                              backgroundColor: Colors.redAccent));
                        }
                      }
                    },
                    child: const Text('Simpan'),
                  )
                ],
        ),
      ),
    );
  }

  void _showResetPasswordDialog(String id) {
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
            controller: passCtrl,
            decoration: const InputDecoration(labelText: 'Password Baru'),
            obscureText: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () async {
              if (passCtrl.text.trim().length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Password baru minimal harus 6 karakter!'),
                    backgroundColor: Colors.redAccent));
                return;
              }
              await _waliService.resetPassword(id, passCtrl.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Reset'),
          )
        ],
      ),
    );
  }
}
