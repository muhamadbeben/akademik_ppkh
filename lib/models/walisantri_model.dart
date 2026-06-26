import 'package:cloud_firestore/cloud_firestore.dart';

class WaliSantriModel {
  final String id;
  final String namaWali;
  final String noHp;
  final String hubungan;
  final String santriId;
  final String namaSantri;
  final String kelasSantri;
  final String username;
  final String status;

  WaliSantriModel({
    required this.id,
    required this.namaWali,
    required this.noHp,
    required this.hubungan,
    required this.santriId,
    required this.namaSantri,
    required this.kelasSantri,
    required this.username,
    required this.status,
  });

  // Mengubah data dari Firestore (Map) menjadi Objek Model
  factory WaliSantriModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return WaliSantriModel(
      id: doc.id,
      namaWali: data['namaWali'] ?? '',
      noHp: data['noHp'] ?? '',
      hubungan: data['hubungan'] ?? 'Ayah',
      santriId: data['santriId'] ?? '',
      namaSantri: data['namaSantri'] ?? '',
      kelasSantri: data['kelasSantri'] ?? '',
      username: data['username'] ?? '',
      status: data['status'] ?? 'Aktif',
    );
  }

  // Mengubah Objek Model menjadi Map untuk disimpan ke Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'namaWali': namaWali,
      'noHp': noHp,
      'hubungan': hubungan,
      'santriId': santriId,
      'namaSantri': namaSantri,
      'kelasSantri': kelasSantri,
      'username': username,
      'status': status,
    };
  }
}