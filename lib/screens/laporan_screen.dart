import 'package:flutter/material.dart';
import '../models/prediksi_model.dart';
import '../models/santri_model.dart';
import '../services/laporan_pdf_service.dart';
import '../services/prediksi_service.dart';
import '../services/santri_service.dart';

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  final LaporanPdfService _pdfService = LaporanPdfService();
  final PrediksiService _prediksiService = PrediksiService();
  final SantriService _santriService = SantriService();

  String _selectedKelas = 'Kelas 1';
  String _selectedSemester = '1';
  String _selectedTahunAjaran = '2024/2025';
  bool _loading = false;

  final List<String> _kelasList = ['Kelas 1','Kelas 2','Kelas 3','Kelas 4','Kelas 5','Kelas 6'];
  final List<String> _tahunList = ['2023/2024','2024/2025','2025/2026'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Section
            _buildSection(
              'Filter Laporan',
              child: Column(
                children: [
                  _dropdown(_kelasList, _selectedKelas, 'Pilih Kelas', Icons.class_,
                      (v) => setState(() => _selectedKelas = v!)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _dropdown(['Sem 1', 'Sem 2'], 'Sem $_selectedSemester',
                            'Semester', Icons.calendar_today,
                            (v) => setState(() => _selectedSemester = v!.replaceAll('Sem ', ''))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dropdown(_tahunList, _selectedTahunAjaran,
                            'Tahun Ajaran', Icons.school,
                            (v) => setState(() => _selectedTahunAjaran = v!)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Ringkasan Statistik
            FutureBuilder<Map<String, int>>(
              future: _prediksiService.getStatistikPrediksi(
                kelas: _selectedKelas,
                semester: _selectedSemester,
              ),
              builder: (ctx, snap) {
                final stat = snap.data ?? {};
                return _buildSection(
                  'Ringkasan Prediksi',
                  child: Row(
                    children: [
                      Expanded(child: _statCard('Total', '${stat['total'] ?? 0}', Colors.blue, Icons.people)),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard('Lulus', '${stat['lulus'] ?? 0}', Colors.green, Icons.check_circle)),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard('Tdk Lulus', '${stat['tidakLulus'] ?? 0}', Colors.red, Icons.cancel)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Daftar Laporan
            _buildSection(
              'Cetak Laporan',
              child: Column(
                children: [
                  _laporanMenuItem(
                    icon: Icons.psychology,
                    color: Colors.purple,
                    title: 'Laporan Prediksi Kelulusan',
                    subtitle: 'Laporan hasil prediksi Decision Tree per kelas',
                    onTap: _cetakLaporanPrediksi,
                  ),
                  const Divider(),
                  _laporanMenuItem(
                    icon: Icons.people_alt,
                    color: Colors.blue,
                    title: 'Laporan Data Santri',
                    subtitle: 'Daftar lengkap santri per kelas',
                    onTap: _cetakLaporanSantri,
                  ),
                  const Divider(),
                  _laporanMenuItem(
                    icon: Icons.grade,
                    color: Colors.orange,
                    title: 'Laporan Rekap Nilai',
                    subtitle: 'Rekap nilai santri per semester',
                    onTap: _cetakLaporanNilai,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _dropdown(List<String> items, String value, String label, IconData icon, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
      ),
      items: items.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 13)))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _laporanMenuItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: _loading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.picture_as_pdf, color: color, size: 20),
            ),
      onTap: _loading ? null : onTap,
    );
  }

  Future<void> _cetakLaporanPrediksi() async {
    setState(() => _loading = true);
    try {
      final prediksiList = await _prediksiService.getAllPrediksi(
        kelas: _selectedKelas,
        semester: _selectedSemester,
        tahunAjaran: _selectedTahunAjaran,
      );
      if (prediksiList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Belum ada data prediksi untuk filter ini')),
        );
        return;
      }
      await _pdfService.generateLaporanPrediksi(
        prediksiList: prediksiList,
        kelas: _selectedKelas,
        semester: _selectedSemester,
        tahunAjaran: _selectedTahunAjaran,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cetakLaporanSantri() async {
    setState(() => _loading = true);
    try {
      final santriList = await _santriService.getSantri(kelas: _selectedKelas);
      if (santriList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada santri di kelas ini')),
        );
        return;
      }
      await _pdfService.generateLaporanSantri(
        santriList: santriList,
        kelas: _selectedKelas,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cetakLaporanNilai() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fitur laporan nilai sedang dalam pengembangan')),
    );
  }
}
