// File: lib/services/rapor_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/rapor_model.dart';
import '../models/santri_model.dart';
import 'rapor_pdf_service.dart';

class RaporService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Format docId harus KONSISTEN dengan nilai_rekap_integrated.dart ──────────
  static String _buildRaporDocId(String santriId, String kelas, String tahun) {
    return '${santriId}_${kelas.replaceAll(' ', '')}_${tahun.replaceAll('/', '')}';
  }

  // Format docId koleksi 'nilai'
  static String _buildNilaiDocId(String santriId, String kelas, String tahun) {
    return '${santriId}_${tahun.replaceAll('/', '-')}_${kelas.replaceAll(' ', '')}';
  }

  // ─── Cetak PDF ────────────────────────────────────────────────────────────────
  static Future<void> cetakRaporPdfWithLogo(
      BuildContext context, RaporModel raporData) async {
    try {
      final bytes    = await rootBundle.load('assets/images/logo rapot.png');
      final logo     = bytes.buffer.asUint8List();
      final pdfService = RaporPdfService();
      await pdfService.generateAndOpenRapor(raporData, logo);
    } catch (e) {
      debugPrint('cetakRaporPdfWithLogo error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal cetak PDF: $e')));
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // GET RAPOR — prioritas koleksi 'rapor', fallback ke generate dari 'nilai'
  // ══════════════════════════════════════════════════════════════════════════════
  static Future<RaporModel?> getRaporBySantri(
      String santriId, String kelas, String tahunAjaran) async {
    try {
      // ── LAPIS 1: Baca dari koleksi 'rapor' dengan docId baru ─────────────────
      final docIdBaru = _buildRaporDocId(santriId, kelas, tahunAjaran);
      final snapBaru  = await _db.collection('rapor').doc(docIdBaru).get();

      if (snapBaru.exists && snapBaru.data() != null) {
        final r = _parseFromRaporDoc(snapBaru.data()!, snapBaru.id);
        if (r != null && r.daftarNilai.isNotEmpty) return r;
      }

      // ── LAPIS 2: Query by field (format lama / backup) ────────────────────────
      final query = await _db
          .collection('rapor')
          .where('santriId',   isEqualTo: santriId)
          .where('kelas',      isEqualTo: kelas)
          .where('tahunAjaran',isEqualTo: tahunAjaran)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final r = _parseFromRaporDoc(query.docs.first.data(), query.docs.first.id);
        if (r != null && r.daftarNilai.isNotEmpty) return r;
      }

      return null;
    } catch (e) {
      debugPrint('getRaporBySantri error: $e');
      return null;
    }
  }

  // ── Parse dokumen koleksi 'rapor' → RaporModel ────────────────────────────────
  static RaporModel? _parseFromRaporDoc(Map<String, dynamic> d, String docId) {
    try {
      final List<NilaiModel> daftarNilai = [];

      // 1. Ambil Nilai Akademik HANYA DARI UAS
      if (d['uas'] is Map) {
        (d['uas'] as Map).forEach((mapel, val) {
          final n = _toDouble(val);
          if (n > 0) {
            daftarNilai.add(NilaiModel(
              id:            mapel.toString().replaceAll(' ', '_'),
              mataPelajaran: mapel.toString(),
              nilaiHarian:   n,
              grade:         _getGrade(n),
            ));
          }
        });
      }

      // 2. Ambil Nilai Hafalan HANYA JIKA MENGANDUNG KATA "LISAN"
      if (d['hafalan_kitab'] is Map) {
        (d['hafalan_kitab'] as Map).forEach((mapel, val) {
          if (mapel.toString().toLowerCase().contains('lisan')) {
            final n = _toDouble(val);
            if (n > 0) {
              daftarNilai.add(NilaiModel(
                id:            mapel.toString().replaceAll(' ', '_'),
                mataPelajaran: mapel.toString(),
                nilaiHarian:   n,
                grade:         _getGrade(n),
              ));
            }
          }
        });
      }

      // Format lama: daftarNilai sebagai List (dari _simpanRaporPermanen format lama)
      if (daftarNilai.isEmpty && d['daftarNilai'] is List) {
        for (final item in d['daftarNilai'] as List) {
          if (item is Map) {
            // Lakukan filter ulang untuk format lama agar seragam
            final mapelName = item['mataPelajaran']?.toString() ?? '';
            final isLisan = mapelName.toLowerCase().contains('lisan');
            
            // Jika bukan lisan (asumsi akademik) ATAU lisan (asumsi hafalan), kita masukkan
            daftarNilai.add(NilaiModel(
              id:            item['mataPelajaran']?.toString().replaceAll(' ', '_') ?? '',
              mataPelajaran: mapelName,
              nilaiHarian:   (item['nilaiHarian'] as num?)?.toDouble() ?? 0.0,
              grade:         item['grade']?.toString() ?? '',
            ));
          }
        }
      }

      if (daftarNilai.isEmpty) return null;

      // Hitung nilai akhir
      final nilaiAkhir = (d['nilai_akhir']     as num?)?.toDouble()
          ?? (d['nilaiRataRata'] as num?)?.toDouble()
          ?? _hitungBerbobot(d);

      // Absensi
      final absen = d['ketidakhadiran'] is Map
          ? d['ketidakhadiran'] as Map<dynamic, dynamic>
          : <dynamic, dynamic>{};

      return RaporModel(
        id:               docId,
        santriId:         d['santriId']?.toString()  ?? '',
        namaSantri:       d['namaSantri']?.toString() ?? '',
        nis:              d['nis']?.toString()       ?? '-',
        kelas:            d['kelas']?.toString()     ?? '',
        tahunAjaran:      d['tahunAjaran']?.toString() ?? '',
        halaqah:          d['halaqah']?.toString()     ?? '-',
        pengajar:         d['pengajar']?.toString()    ?? '-',
        catatanAdab:      d['catatanAdab']?.toString() ?? '',
        absenSakit:       _toInt(absen['Sakit']),
        absenIzin:        _toInt(absen['Izin']),
        absenAlpha:       _toInt(absen['Tanpa Keterangan']),
        nilaiRataRata:    nilaiAkhir,
        predikat:         d['predikat']?.toString() ?? _getPredikat(nilaiAkhir),
        catatanWaliKelas: d['catatanWaliKelas']?.toString()
            ?? 'Tingkatkan terus semangat belajarmu!',
        tanggalCetak:     d['tanggalCetak'] is Timestamp
            ? (d['tanggalCetak'] as Timestamp).toDate()
            : DateTime.now(),
        daftarNilai:      daftarNilai,
      );
    } catch (e) {
      debugPrint('_parseFromRaporDoc error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // GENERATE RAPOR — dari koleksi 'nilai' (fallback jika koleksi 'rapor' kosong)
  // ══════════════════════════════════════════════════════════════════════════════
  static Future<RaporModel?> generateRapor(
      SantriModel santri, String kelas, String tahunAjaran) async {
    try {
      final docIdBaru = _buildNilaiDocId(santri.id, kelas, tahunAjaran);
      DocumentSnapshot<Map<String, dynamic>> snap =
          await _db.collection('nilai').doc(docIdBaru).get();

      if (!snap.exists) {
        final query = await _db
            .collection('nilai')
            .where('santriId',    isEqualTo: santri.id)
            .where('kelas',       isEqualTo: kelas)
            .where('tahunAjaran', isEqualTo: tahunAjaran)
            .limit(1)
            .get();
        if (query.docs.isEmpty) return null;
        snap = query.docs.first;
      }

      if (!snap.exists || snap.data() == null) return null;
      final d = snap.data()!;

      final Map<String, NilaiModel> mapNilai = {};
      double totalUts = 0, totalUas = 0, totalHafal = 0;
      int    countUts = 0, countUas = 0, countHafal = 0;

      // UTS — dipakai untuk menghitung bobot nilai akhir saja
      if (d['uts'] is Map) {
        (d['uts'] as Map).forEach((_, v) {
          final n = _toDouble(v);
          if (n > 0) { totalUts += n; countUts++; }
        });
      }

      // UAS — Ditampilkan sebagai Akademik
      if (d['uas'] is Map) {
        (d['uas'] as Map).forEach((mapel, v) {
          final n = _toDouble(v);
          if (n > 0) {
            mapNilai[mapel.toString()] = NilaiModel(
              id:            mapel.toString().replaceAll(' ', '_'),
              mataPelajaran: mapel.toString(),
              nilaiHarian:   n,
              grade:         _getGrade(n),
            );
            totalUas += n; countUas++;
          }
        });
      }

      // HAFALAN — Hanya dimasukkan ke List jika ada tulisan "lisan"
      if (d['hafalan_kitab'] is Map) {
        (d['hafalan_kitab'] as Map).forEach((mapel, v) {
          final n = _toDouble(v);
          if (n > 0) {
            if (mapel.toString().toLowerCase().contains('lisan')) {
              mapNilai[mapel.toString()] = NilaiModel(
                id:            mapel.toString().replaceAll(' ', '_'),
                mataPelajaran: mapel.toString(),
                nilaiHarian:   n,
                grade:         _getGrade(n),
              );
            }
            // Tetap dihitung totalnya untuk kalkulasi Rata-rata Nilai Akhir
            totalHafal += n; countHafal++;
          }
        });
      }

      final daftarNilai = mapNilai.values.toList();
      if (daftarNilai.isEmpty) return null;

      final kehadiran = _toDouble(d['nilai_kehadiran']);
      final perilaku  = _toDouble(d['nilai_perilaku']);
      final avgUts    = countUts   > 0 ? totalUts   / countUts   : 0.0;
      final avgUas    = countUas   > 0 ? totalUas   / countUas   : 0.0;
      final avgHafal  = countHafal > 0 ? totalHafal / countHafal : 0.0;

      final manualHafal = _toDouble(d['manual_hafalan']);
      final hafalFinal  = manualHafal > 0 ? manualHafal : avgHafal;

      // Rata-rata berbobot
      final nilaiAkhir = (kehadiran * 0.05) + (perilaku  * 0.05) +
                         (avgUts    * 0.20) + (avgUas    * 0.40) +
                         (hafalFinal* 0.30);

      // Absensi
      int sakit = 0, izin = 0, alpha = 0;
      if (d['ketidakhadiran'] is Map) {
        final absen = d['ketidakhadiran'] as Map;
        sakit = _toInt(absen['Sakit']);
        izin  = _toInt(absen['Izin']);
        alpha = _toInt(absen['Tanpa Keterangan']);
      }

      final catatanAdab = perilaku > 0
          ? 'Nilai Sikap/Perilaku: ${perilaku.toStringAsFixed(0)} — ${_labelPerilaku(perilaku)}'
          : 'Baik, pertahankan adab dan sopan santun kepada pengajar.';

      final prediksiAi = d['status_prediksi_ai']?.toString() ?? '';

      return RaporModel(
        id: 'TEMP_${santri.id}_${kelas.replaceAll(' ', '')}_${tahunAjaran.replaceAll('/', '')}',
        santriId:         santri.id,
        namaSantri:       santri.nama,
        nis:              santri.nis ?? '-',
        kelas:            kelas,
        tahunAjaran:      tahunAjaran,
        halaqah:          '-',
        pengajar:         '-',
        catatanAdab:      catatanAdab,
        absenSakit:       sakit,
        absenIzin:        izin,
        absenAlpha:       alpha,
        nilaiRataRata:    nilaiAkhir,
        predikat:         prediksiAi.isNotEmpty
            ? _predikatDariStatusAi(prediksiAi)
            : _getPredikat(nilaiAkhir),
        catatanWaliKelas: 'Tingkatkan terus semangat belajarmu, pertahankan prestasimu.',
        tanggalCetak:     DateTime.now(),
        daftarNilai:      daftarNilai,
      );
    } catch (e, st) {
      debugPrint('generateRapor error: $e\n$st');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // SIMPAN RAPOR PERMANEN
  // ══════════════════════════════════════════════════════════════════════════════
  static Future<void> simpanRaporPermanen(RaporModel rapor) async {
    try {
      final rawId  = rapor.id.replaceAll('TEMP_', '');
      final docId  = rawId.contains('_')
          ? rawId
          : _buildRaporDocId(rapor.santriId, rapor.kelas, rapor.tahunAjaran);

      await _db.collection('rapor').doc(docId).set({
        'id':               docId,
        'santriId':         rapor.santriId,
        'namaSantri':       rapor.namaSantri,
        'nis':              rapor.nis,
        'kelas':            rapor.kelas,
        'tahunAjaran':      rapor.tahunAjaran,
        'halaqah':          rapor.halaqah,
        'pengajar':         rapor.pengajar,
        'catatanAdab':      rapor.catatanAdab,
        'absenSakit':       rapor.absenSakit,
        'absenIzin':        rapor.absenIzin,
        'absenAlpha':       rapor.absenAlpha,
        'nilaiRataRata':    rapor.nilaiRataRata,
        'predikat':         rapor.predikat,
        'catatanWaliKelas': rapor.catatanWaliKelas,
        'tanggalCetak':     FieldValue.serverTimestamp(),
        'daftarNilai': rapor.daftarNilai.map((n) => {
          'mataPelajaran': n.mataPelajaran,
          'nilaiHarian':   n.nilaiHarian,
          'grade':         n.grade,
        }).toList(),
      }, SetOptions(merge: true));

      debugPrint('Rapor tersimpan permanen: $docId');
    } catch (e) {
      debugPrint('simpanRaporPermanen error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // HELPERS YANG SEBELUMNYA TERPOTONG
  // ══════════════════════════════════════════════════════════════════════════════
  
  static double _hitungBerbobot(Map<String, dynamic> d) {
    final kh  = _toDouble(d['nilai_kehadiran']);
    final pr  = _toDouble(d['nilai_perilaku']);
    final uts = _avgMapDyn(d['uts']);
    final uas = _avgMapDyn(d['uas']);
    final haf = _avgMapDyn(d['hafalan_kitab']);
    
    // Formula Bobot: Hadir 5%, Sikap 5%, UTS 20%, UAS 40%, Hafalan 30%
    return (kh * 0.05) + (pr * 0.05) + (uts * 0.20) + (uas * 0.40) + (haf * 0.30);
  }

  static double _avgMapDyn(dynamic m) {
    if (m is! Map) return 0.0;
    double s = 0; 
    int c = 0;
    m.forEach((_, v) {
      final val = _toDouble(v);
      if (val > 0) {
        s += val; 
        c++;
      }
    });
    return c > 0 ? s / c : 0.0;
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  static int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  static String _getGrade(double n) {
    if (n >= 90) return 'A';
    if (n >= 80) return 'B';
    if (n >= 70) return 'C';
    if (n >= 60) return 'D';
    return 'E';
  }

  static String _getPredikat(double n) {
    if (n >= 90) return 'A (Mumtaz)';
    if (n >= 80) return 'B (Jayyid Jiddan)';
    if (n >= 70) return 'C (Jayyid)';
    if (n >= 60) return 'D (Maqbul)';
    return 'E (Rasib)';
  }

  static String _labelPerilaku(double n) {
    if (n >= 90) return 'Sangat Baik';
    if (n >= 80) return 'Baik';
    if (n >= 70) return 'Cukup';
    return 'Perlu Bimbingan';
  }

  static String _predikatDariStatusAi(String status) {
    // Apabila kamu menggunakan ML AI, tampilkan status langsung
    if (status.trim().isEmpty) return 'B (Jayyid Jiddan)'; 
    return status;
  }
}