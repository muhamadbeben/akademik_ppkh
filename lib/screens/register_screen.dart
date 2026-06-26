import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_colors.dart';
import '../widgets/custom_textfield.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String _selectedRole = 'santri'; // Default role

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Buat akun di Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String uid = userCredential.user!.uid;

      // 2. Simpan data tambahan ke Cloud Firestore
      // Role dikonversi ke lowercase agar sinkron dengan dashboard logic
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole.toLowerCase().trim(), 
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSnackBar('Registrasi Berhasil! Silakan Login.', Colors.green);
        Navigator.pop(context); 
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Terjadi kesalahan';
      if (e.code == 'email-already-in-use') {
        message = 'Email sudah digunakan akun lain';
      } else if (e.code == 'weak-password') {
        message = 'Password terlalu lemah (min. 6 karakter)';
      }
      _showSnackBar(message, Colors.redAccent);
    } catch (e) {
      _showSnackBar('Gagal terhubung ke database. Cek koneksi Anda.', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A3D24),
      body: Stack(
        children: [
          // Background Dekoratif
          Positioned(
            top: -30,
            left: -30,
            child: Opacity(
              opacity: 0.1,
              child: const Icon(Icons.mosque, size: 250, color: Colors.white),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // HEADER SECTION
                Expanded(
                  flex: 1,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                          ),
                        ),
                        const Center(
                          child: Text(
                            'DAFTAR AKUN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // FORM SECTION
                Expanded(
                  flex: 6,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 35),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(40),
                          topRight: Radius.circular(40),
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bergabung Sekarang 👋',
                                style: TextStyle(
                                  fontSize: 24, 
                                  fontWeight: FontWeight.bold, 
                                  color: Color(0xFF0A3D24)
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Lengkapi data santri atau pengajar', 
                                style: TextStyle(color: Colors.black54)
                              ),
                              const SizedBox(height: 30),
                              
                              // Input Nama
                              CustomTextField(
                                label: 'Nama Lengkap',
                                hint: 'Sesuai Ijazah/Kartu Identitas',
                                controller: _nameController,
                                prefixIcon: Icons.badge_outlined,
                                validator: (v) => v!.isEmpty ? 'Nama tidak boleh kosong' : null,
                              ),
                              const SizedBox(height: 18),
                              
                              // Input Email
                              CustomTextField(
                                label: 'Alamat Email',
                                hint: 'user@email.com',
                                controller: _emailController,
                                prefixIcon: Icons.mark_as_unread_outlined,
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Email wajib diisi';
                                  if (!v.contains('@')) return 'Format email salah';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              
                              // Input Password
                              CustomTextField(
                                label: 'Password',
                                hint: 'Masukkan minimal 6 karakter',
                                controller: _passwordController,
                                prefixIcon: Icons.fingerprint_rounded,
                                isPassword: true,
                                validator: (v) => v!.length >= 6 ? null : 'Password minimal 6 karakter',
                              ),
                              const SizedBox(height: 18),

                              // Dropdown Pilihan Role
                              DropdownButtonFormField<String>(
                                value: _selectedRole,
                                decoration: InputDecoration(
                                  labelText: 'Daftar Sebagai',
                                  labelStyle: const TextStyle(color: Color(0xFF0A3D24)),
                                  prefixIcon: const Icon(Icons.assignment_ind_outlined, color: Color(0xFF0A3D24)),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'santri', child: Text('SANTRI / WALI SANTRI')),
                                  DropdownMenuItem(value: 'guru', child: Text('GURU / USTADZ')),
                                  DropdownMenuItem(value: 'admin', child: Text('ADMINISTRATOR')),
                                ],
                                onChanged: (v) => setState(() => _selectedRole = v!),
                              ),
                              const SizedBox(height: 35),

                              // Tombol Submit
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _register,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0A3D24),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    elevation: 4,
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : const Text(
                                          'DAFTAR SEKARANG',
                                          style: TextStyle(
                                            color: Colors.white, 
                                            fontWeight: FontWeight.bold, 
                                            fontSize: 16
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}