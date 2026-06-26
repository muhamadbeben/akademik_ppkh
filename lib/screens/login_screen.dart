// File: lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_textfield.dart';
import 'package:akademik_ppkh/screens/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showErrorSnackBar("Silakan isi username/email terlebih dahulu.");
      return;
    }

    try {
      String resetEmail = email.contains('@') ? email : '$email@ppkh.com';
      await FirebaseAuth.instance.sendPasswordResetEmail(email: resetEmail);
      _showSuccessSnackBar("Link reset kata sandi telah dikirim.");
    } catch (e) {
      _showErrorSnackBar("Gagal mengirim email reset.");
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final String rawUsername = _emailController.text.trim();
      final String inputPassword = _passwordController.text.trim();
      final String authEmail =
          rawUsername.contains('@') ? rawUsername : '$rawUsername@ppkh.com';

      // 1. Login Firebase Auth
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: authEmail,
        password: inputPassword,
      );

      final String uid = userCredential.user!.uid;
      String role = '';
      String namaPengguna = '';
      String? santriId;
      bool isUserFound = false;

      // 2. Cek Koleksi 'guru'
      QuerySnapshot<Map<String, dynamic>> guruQuery = await FirebaseFirestore
          .instance
          .collection('guru')
          .where('username', isEqualTo: rawUsername)
          .get();

      if (guruQuery.docs.isNotEmpty) {
        isUserFound = true;
        final data = guruQuery.docs.first.data();
        if (data['status'] == 'Nonaktif') {
          throw Exception("Akun dinonaktifkan Admin");
        }
        role = 'guru';
        namaPengguna = data['nama'] ?? 'Guru';
      }

      // 3. Cek Koleksi 'walisantri'
      if (!isUserFound) {
        DocumentSnapshot<Map<String, dynamic>> waliDoc = await FirebaseFirestore
            .instance
            .collection('walisantri')
            .doc(uid)
            .get();
        if (waliDoc.exists) {
          isUserFound = true;
          final data = waliDoc.data()!;
          if (data['status'] == 'Nonaktif') {
            throw Exception("Akun dinonaktifkan Admin");
          }
          role = 'walisantri';
          namaPengguna = data['namaWali'] ?? 'Wali Santri';
          santriId = data['santriId']?.toString();
        }
      }

      // 4. Cek Koleksi 'users' (Admin)
      if (!isUserFound) {
        DocumentSnapshot<Map<String, dynamic>> adminDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (adminDoc.exists) {
          isUserFound = true;
          final data = adminDoc.data()!;
          role = (data['role'] ?? 'admin').toString().toLowerCase();
          namaPengguna = data['name'] ?? 'Admin';
        }
      }

      // 5. Navigasi Langsung ke DashboardScreen (Satu Dashboard Utama)
      if (isUserFound && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              userName: namaPengguna,
              userRole: role,
              santriId:
                  santriId, // Tetap dikirim, berguna jika role-nya walisantri
            ),
          ),
        );
      } else {
        throw Exception("Data profil tidak ditemukan.");
      }
    } on FirebaseAuthException catch (_) {
      _showErrorSnackBar("Email atau kata sandi salah.");
    } catch (e) {
      _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent));

  void _showSuccessSnackBar(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A3D24),
      body: Stack(
        children: [
          _buildBackgroundDesign(),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 4,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                      width: 2),
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.mosque_rounded,
                                          color: Colors.white, size: 60);
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text('KHOIRUL HUDA',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 4)),
                              const Text('SISTEM AKADEMIK',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      letterSpacing: 2)),
                            ],
                          ),
                        ),
                      ),
                      SlideTransition(
                        position: _slideAnimation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 40),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(35),
                                topRight: Radius.circular(35)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 15,
                                  offset: Offset(0, -5))
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Masuk',
                                    style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0A3D24))),
                                const SizedBox(height: 25),
                                CustomTextField(
                                    label: 'Username/Email',
                                    hint: 'contoh@email.com',
                                    controller: _emailController,
                                    prefixIcon: Icons.alternate_email_rounded,
                                    validator: (v) => v!.isEmpty
                                        ? 'Username wajib diisi'
                                        : null),
                                const SizedBox(height: 15),
                                CustomTextField(
                                    label: 'Kata Sandi',
                                    hint: '******',
                                    controller: _passwordController,
                                    prefixIcon: Icons.lock_person_outlined,
                                    isPassword: true,
                                    validator: (v) => v!.isEmpty
                                        ? 'Password wajib diisi'
                                        : null),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                      onPressed: _resetPassword,
                                      child: const Text('Lupa Kata Sandi?',
                                          style: TextStyle(
                                              color: Color(0xFF0A3D24),
                                              fontWeight: FontWeight.w600))),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  height: 55,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF0A3D24),
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12))),
                                    child: _isLoading
                                        ? const CircularProgressIndicator(
                                            color: Colors.white)
                                        : const Text('MASUK KE SISTEM',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundDesign() {
    final double screenHeight = MediaQuery.of(context).size.height;
    return Stack(
      children: [
        Positioned(
          top: -60,
          right: -60,
          child: Opacity(
            opacity: 0.08,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 24),
              ),
            ),
          ),
        ),
        Positioned(
          top: 20,
          right: -30,
          child: Opacity(
            opacity: 0.05,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 12),
              ),
            ),
          ),
        ),
        Positioned(
          top: screenHeight * 0.25,
          left: -80,
          child: Opacity(
            opacity: 0.04,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
