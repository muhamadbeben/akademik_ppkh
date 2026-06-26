import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:akademik_ppkh/config/app_colors.dart';
import 'package:akademik_ppkh/services/firestore_service.dart';
import 'package:akademik_ppkh/widgets/custom_textfield.dart';

class KelolaAkunScreen extends StatefulWidget {
  const KelolaAkunScreen({super.key});

  @override
  State<KelolaAkunScreen> createState() => _KelolaAkunScreenState();
}

class _KelolaAkunScreenState extends State<KelolaAkunScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _formGuruKey = GlobalKey<FormState>();
  final _namaGuruCtrl = TextEditingController();
  final _emailGuruCtrl = TextEditingController();
  final _passwordGuruCtrl = TextEditingController();

  final _formWaliKey = GlobalKey<FormState>();
  final _namaSantriCtrl = TextEditingController(); 
  final _emailWaliCtrl = TextEditingController();
  final _passwordWaliCtrl = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _namaGuruCtrl.dispose();
    _emailGuruCtrl.dispose();
    _passwordGuruCtrl.dispose();
    _namaSantriCtrl.dispose();
    _emailWaliCtrl.dispose();
    _passwordWaliCtrl.dispose();
    super.dispose();
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _registerGuru() async {
    if (!_formGuruKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await FirestoreService.buatAkunUser(
        nama: _namaGuruCtrl.text,
        email: _emailGuruCtrl.text,
        password: _passwordGuruCtrl.text,
        role: 'guru',
      );
      _showSnackBar('Akun Guru Berhasil Dibuat!', Colors.green);
      _namaGuruCtrl.clear();
      _emailGuruCtrl.clear();
      _passwordGuruCtrl.clear();
    } catch (e) {
      _showSnackBar('Gagal membuat akun: $e', Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _registerWali() async {
    if (!_formWaliKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await FirestoreService.buatAkunWaliMasingMasing(
        namaSantri: _namaSantriCtrl.text,
        email: _emailWaliCtrl.text,
        password: _passwordWaliCtrl.text,
      );
      _showSnackBar('Akun Wali Santri Berhasil Dibuat!', Colors.green);
      _namaSantriCtrl.clear();
      _emailWaliCtrl.clear();
      _passwordWaliCtrl.clear();
    } catch (e) {
      _showSnackBar('Gagal membuat akun: $e', Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Registrasi Akun Baru', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.co_present), text: 'Akun Guru'),
            Tab(icon: Icon(Icons.family_restroom), text: 'Akun Wali Santri'),
          ],
        ),
      ),
      body: _isSaving 
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : TabBarView(
            controller: _tabController,
            children: [
              _buildFormGuru(),
              _buildFormWali(),
            ],
          ),
    );
  }

  Widget _buildFormGuru() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formGuruKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('BUAT AKUN GURU BARU', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 4),
            const Text('Sistem akan mendaftarkan email resmi guru ke dalam data autentikasi.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(height: 24),
            CustomTextField(
              label: 'Nama Lengkap Guru *',
              hint: 'Masukkan Nama Lengkap beserta Gelar',
              controller: _namaGuruCtrl,
              prefixIcon: Icons.person,
              validator: (v) => v!.isEmpty ? 'Nama lengkap wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Email Akun Guru *',
              hint: 'Contoh: guru.nama@pesantren.com',
              controller: _emailGuruCtrl,
              prefixIcon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v!.isEmpty || !v.contains('@') ? 'Masukkan email login yang valid' : null,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Password Akun *',
              hint: 'Masukkan Minimal 6 Karakter',
              controller: _passwordGuruCtrl,
              prefixIcon: Icons.lock,
              validator: (v) => v!.length < 6 ? 'Password minimal 6 karakter' : null,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _registerGuru,
                child: const Text('DAFTARKAN AKUN GURU', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFormWali() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formWaliKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('BUAT AKUN WALI SANTRI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
            const SizedBox(height: 4),
            const Text('Akun ini akan langsung terhubung secara otomatis ke data akademik anak berdasarkan Nama Santri.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(height: 24),
            
            const Text('Nama Santri *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('santri').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: LinearProgressIndicator(color: Colors.orange));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text(
                    'Data santri tidak ditemukan. Silakan isi menu kelola santri terlebih dahulu.',
                    style: TextStyle(color: Colors.red, fontSize: 13),
                  );
                }

                List<String> daftarSantri = snapshot.data!.docs.map((doc) {
                  return doc['nama'].toString();
                }).toList();

                daftarSantri.sort();

                final String? currentSelection = daftarSantri.contains(_namaSantriCtrl.text) && _namaSantriCtrl.text.isNotEmpty 
                    ? _namaSantriCtrl.text 
                    : null;

                return DropdownButtonFormField<String>(
                  // Menggunakan 'initialValue' menggantikan properti 'value' lama yang deprecated
                  initialValue: currentSelection,
                  hint: const Text('Pilih Nama Lengkap Santri'),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.face_rounded, color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: daftarSantri.map((String nama) {
                    return DropdownMenuItem<String>(
                      value: nama,
                      child: Text(nama),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _namaSantriCtrl.text = newValue ?? "";
                    });
                  },
                  validator: (v) => v == null || v.isEmpty ? 'Nama santri wajib dipilih' : null,
                );
              },
            ),

            const SizedBox(height: 16),
            CustomTextField(
              label: 'Email Wali Santri *',
              hint: 'Contoh: wali.santri@email.com',
              controller: _emailWaliCtrl,
              prefixIcon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v!.isEmpty || !v.contains('@') ? 'Masukkan email wali yang valid' : null,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Password Akun Wali *',
              hint: 'Masukkan Password Kustom',
              controller: _passwordWaliCtrl,
              prefixIcon: Icons.lock,
              validator: (v) => v!.length < 6 ? 'Password minimal 6 karakter' : null,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _registerWali,
                child: const Text('DAFTARKAN AKUN WALI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}