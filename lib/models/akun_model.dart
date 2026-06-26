// File: lib/models/akun_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String role;
  final String email;
  final String phoneNumber;
  final String? photoUrl; // Menyimpan link foto profil jika ada
  final String? anakId; // PENTING: Untuk menyambungkan akun Wali Santri dengan ID anaknya
  final DateTime? createdAt; // Mengetahui kapan user ini terdaftar
  final bool isNotificationEnabled; // Preferensi notifikasi user

  UserModel({
    required this.uid,
    required this.name,
    required this.role,
    required this.email,
    required this.phoneNumber,
    this.photoUrl,
    this.anakId,
    this.createdAt,
    this.isNotificationEnabled = true,
  });

  /// Fungsi untuk mengubah data dari Firebase Firestore (DocumentSnapshot) menjadi Objek UserModel
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;

    // Mengonversi Timestamp Firestore menjadi DateTime Dart secara aman
    DateTime? parsedDate;
    if (data?['createdAt'] != null) {
      if (data!['createdAt'] is Timestamp) {
        parsedDate = (data['createdAt'] as Timestamp).toDate();
      } else if (data['createdAt'] is String) {
        parsedDate = DateTime.tryParse(data['createdAt']);
      }
    }

    return UserModel(
      uid: doc.id, // UID selalu diambil langsung dari ID Dokumen Firestore
      name: data?['name'] ?? 'Nama Tidak Tersedia',
      role: data?['role'] ?? 'user',
      email: data?['email'] ?? 'Email Tidak Tersedia',
      phoneNumber: data?['phoneNumber'] ?? '-',
      photoUrl: data?['photoUrl'],
      anakId: data?['anakId'], // Mengambil ID anak jika role = walisantri
      createdAt: parsedDate,
      isNotificationEnabled: data?['isNotificationEnabled'] ?? true,
    );
  }

  /// Fungsi untuk mengubah Objek UserModel menjadi format Map/JSON (Untuk Register/Update ke Firestore)
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'role': role,
      'email': email,
      'phoneNumber': phoneNumber,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (anakId != null) 'anakId': anakId, // Menyimpan ID anak jika ada
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'isNotificationEnabled': isNotificationEnabled,
    };
  }

  /// Fungsi Tambahan: Memudahkan kamu meng-update sebagian data saja di masa depan (Copy-With Pattern)
  UserModel copyWith({
    String? name,
    String? role,
    String? email,
    String? phoneNumber,
    String? photoUrl,
    String? anakId,
    DateTime? createdAt,
    bool? isNotificationEnabled,
  }) {
    return UserModel(
      uid: this.uid, // UID tidak boleh berubah
      name: name ?? this.name,
      role: role ?? this.role,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      anakId: anakId ?? this.anakId,
      createdAt: createdAt ?? this.createdAt,
      isNotificationEnabled: isNotificationEnabled ?? this.isNotificationEnabled,
    );
  }
}