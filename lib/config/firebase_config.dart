// firebase_config.dart
// Konfigurasi Firebase untuk aplikasi Khoirul Huda
// Ganti nilai di bawah dengan konfigurasi Firebase project Anda

class FirebaseConfig {
  static const String apiKey = "YOUR_API_KEY";
  static const String authDomain = "khoirulhuda.firebaseapp.com";
  static const String projectId = "khoirulhuda";
  static const String storageBucket = "khoirulhuda.appspot.com";
  static const String messagingSenderId = "YOUR_SENDER_ID";
  static const String appId = "YOUR_APP_ID";

  // Untuk demo / prototype, gunakan auth lokal
  static const bool useDemoMode = true;

  // Demo credentials
  static const Map<String, Map<String, String>> demoUsers = {
    'admin': {
      'password': 'admin123',
      'role': 'Admin',
      'name': 'Admin Ustaz Yusuf',
    },
    'ustadz': {
      'password': 'ustadz123',
      'role': 'Guru',
      'name': 'Ustadz Ahmad',
    },
    'santri001': {
      'password': 'santri123',
      'role': 'Santri',
      'name': 'Muhammad Fauzi',
    },
  };
}
