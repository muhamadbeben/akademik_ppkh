// File: lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:akademik_ppkh/firebase_options.dart';
import 'package:akademik_ppkh/screens/login_screen.dart';

void main() async {
  // Memastikan binding Flutter terinisialisasi sebelum menjalankan fungsi async
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase menggunakan konfigurasi otomatis dari CLI
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Akademik PPKH',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          primary: const Color(0xFF0A3D24), // Sesuai warna tema loginmu
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        // Jika nanti ada halaman dasbor/home, daftarkan juga di sini:
        // '/dasbor': (context) => const DasborScreen(userRole: 'role_disini'),
      },
    );
  }
}