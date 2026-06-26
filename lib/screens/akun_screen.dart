// File: lib/screens/akun_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:akademik_ppkh/screens/login_screen.dart'; // Import halaman login

// Pastikan path ini sesuai dengan struktur folder Anda
import 'package:akademik_ppkh/models/akun_model.dart';

class AccountScreen extends StatefulWidget {
  final String userRole; 
  
  const AccountScreen({super.key, required this.userRole});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  DocumentReference? _userDocRef; 
  bool _isResolving = true; 

  @override
  void initState() {
    super.initState();
    _findUserDocument();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _findUserDocument() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isResolving = false);
      return;
    }

    List<String> collectionsToCheck;
    final String role = widget.userRole.toLowerCase();

    if (role.contains('guru')) {
      collectionsToCheck = ['guru'];
    } else if (role.contains('wali')) {
      collectionsToCheck = ['walisantri'];
    } else if (role.contains('admin')) {
      collectionsToCheck = ['admin'];
    } else {
      collectionsToCheck = ['walisantri', 'guru', 'admin', 'users']; 
    }

    DocumentReference? foundRef;

    for (String col in collectionsToCheck) {
      try {
        final doc = await _firestore.collection(col).doc(user.uid).get();
        if (doc.exists) {
          foundRef = doc.reference;
          break;
        }
      } catch (_) {}
    }

    if (foundRef == null && user.email != null) {
      for (String col in collectionsToCheck) {
        try {
          final query = await _firestore.collection(col).where('email', isEqualTo: user.email).limit(1).get();
          if (query.docs.isNotEmpty) {
            foundRef = query.docs.first.reference;
            break;
          }
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _userDocRef = foundRef;
        _isResolving = false;
      });
    }
  }

  // =========================================================================
  // FUNGSI LOGOUT DIPERBARUI: Menggunakan pushAndRemoveUntil
  // =========================================================================
  Future<void> _handleLogout() async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      
      // Cara paling aman untuk navigasi logout, menghapus semua riwayat halaman
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false, 
      );
      
    } catch (e) {
      if (!mounted) return;
      _showToastSnackBar('Gagal keluar: $e', Colors.red);
    }
  }

  Future<void> _handleResetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      _showToastSnackBar('Link reset password telah dikirim ke email Anda.', Colors.green);
    } catch (e) {
      if (!mounted) return;
      _showToastSnackBar('Gagal mengirim link: $e', Colors.red);
    }
  }

  void _showEditProfilSheet(String currentName, String currentPhone) {
    if (_userDocRef == null) return;
    
    _nameController.text = currentName;
    _phoneController.text = currentPhone;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Edit Profil Akun', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap',
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF4F46E5)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Nomor WhatsApp / Telepon',
                    prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF4F46E5)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    onPressed: () async {
                      if (_nameController.text.trim().isEmpty) return;
                      try {
                        await _userDocRef!.set({
                          'name': _nameController.text.trim(),
                          'phoneNumber': _phoneController.text.trim(),
                        }, SetOptions(merge: true));
                        
                        if (context.mounted) Navigator.pop(context);
                        _showToastSnackBar('Profil berhasil diperbarui!', Colors.green);
                      } catch (e) {
                        _showToastSnackBar('Gagal memperbarui data: $e', Colors.red);
                      }
                    },
                    child: const Text('Simpan Perubahan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _showToastSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: bgColor, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isResolving) {
      return const Scaffold(
        backgroundColor: Color(0xFFF1F5F9),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
      );
    }

    if (_userDocRef == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          backgroundColor: Colors.white, elevation: 0.5, centerTitle: true,
          title: const Text('Manajemen Akun', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_rounded, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text('Data profil Anda tidak ditemukan di database.', style: TextStyle(fontWeight: FontWeight.bold)),
              const Text('Pastikan alamat email Anda sudah terdaftar oleh Admin.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _handleLogout, child: const Text('Kembali ke Login'))
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: const Text('Manajemen Akun', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userDocRef!.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Gagal memuat profil.'));
          }

          final UserModel user = UserModel.fromFirestore(snapshot.data!);
          final Map<String, dynamic>? rawData = snapshot.data!.data() as Map<String, dynamic>?;
          final String anakId = rawData != null ? (rawData['anakId'] ?? '') : '';

          final String actualRole = (user.role.toLowerCase() == 'user' || user.role.isEmpty) 
              ? widget.userRole.toLowerCase() 
              : user.role.toLowerCase();

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModernProfileHeader(user),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // PROFIL ANAK LANGSUNG TERISI UNTUK WALI SANTRI
                      if (actualRole.contains('wali') && anakId.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildWaliSantriChildCard(anakId),
                      ],

                      // KHUSUS ADMIN
                      if (actualRole.contains('admin')) ...[
                        const SizedBox(height: 16),
                        _buildSectionTitle('Status Administrator'),
                        Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade100)),
                          child: _menuTile(
                            Icons.admin_panel_settings_rounded, 
                            'Kendali Sistem Penuh', 
                            'Hak akses pendaftaran akun, data induk, dan prediksi', 
                            null,
                            iconColor: Colors.blue.shade700
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      _buildSectionTitle('Pengaturan Akun'),
                      _buildAccountMenu(user),
                      
                      const SizedBox(height: 32),
                      _buildLogoutButton(), 
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernProfileHeader(UserModel user) {
    String visualRole = widget.userRole.toUpperCase(); 
    if (visualRole.contains('WALI')) visualRole = 'WALI SANTRI';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: const Color(0xFFEEF2FF),
                backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty) ? NetworkImage(user.photoUrl!) : null,
                child: (user.photoUrl == null || user.photoUrl!.isEmpty) ? const Icon(Icons.person, size: 50, color: Color(0xFF4F46E5)) : null,
              ),
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: () => _showEditProfilSheet(user.name, user.phoneNumber),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: const Color(0xFF4F46E5), border: Border.all(color: Colors.white, width: 2), shape: BoxShape.circle),
                    child: const Icon(Icons.edit, size: 16, color: Colors.white),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          Text(user.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
            child: Text(visualRole, style: const TextStyle(color: Color(0xFF4F46E5), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.email_outlined, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(user.email, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              const SizedBox(width: 16),
              const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(user.phoneNumber.isEmpty ? '-' : user.phoneNumber, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaliSantriChildCard(String anakId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('santri').doc(anakId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String namaAnak = data['nama'] ?? '-';
        final String kelasAnak = data['kelas'] ?? '-';
        final double akademik = double.tryParse(data['nilaiAkademik']?.toString() ?? '0') ?? 0.0;
        final double hafalan = double.tryParse(data['hafalanKitab']?.toString() ?? '0') ?? 0.0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF3730A3)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withAlpha(60), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Profil Anak Terdaftar', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  Icon(Icons.child_care_rounded, color: Colors.white70, size: 18),
                ],
              ),
              const SizedBox(height: 12),
              Text(namaAnak, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Kelas Saat Ini: $kelasAnak', style: const TextStyle(color: Colors.white, fontSize: 13)),
              
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMiniAnakStat('Akademik', akademik.toStringAsFixed(1)),
                    Container(height: 30, width: 1, color: Colors.white30),
                    _buildMiniAnakStat('Hafalan', '${hafalan.toStringAsFixed(0)} Juz'),
                    Container(height: 30, width: 1, color: Colors.white30),
                    _buildMiniAnakStat('Kehadiran', 'Cek Data', isTextOnly: true),
                  ],
                ),
              )
            ],
          ),
        );
      }
    );
  }

  Widget _buildMiniAnakStat(String label, String val, {bool isTextOnly = false}) {
    return Column(
      children: [
        Text(val, style: TextStyle(color: Colors.white, fontSize: isTextOnly ? 11 : 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1E293B))),
    );
  }

  Widget _buildAccountMenu(UserModel user) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          _menuTile(Icons.person_outline, 'Edit Profil', 'Ubah informasi nama & kontak', () => _showEditProfilSheet(user.name, user.phoneNumber)),
          _divider(),
          _menuTile(Icons.lock_outline, 'Ubah Sandi', 'Kirim link reset ke email', () => _handleResetPassword(user.email)),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9));
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFEF2F2),
          foregroundColor: const Color(0xFFEF4444),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14), 
            side: const BorderSide(color: Color(0xFFFECACA)),
          ),
        ),
        onPressed: _handleLogout, 
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }

  Widget _menuTile(IconData icon, String title, String sub, VoidCallback? onTap, {Widget? trailing, Color? iconColor}) {
    Color finalIconColor = iconColor ?? const Color(0xFF4F46E5);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: finalIconColor.withAlpha(20), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: finalIconColor, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, size: 22, color: Color(0xFF94A3B8)),
    );
  }
}