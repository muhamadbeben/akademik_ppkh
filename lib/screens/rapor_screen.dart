import 'package:flutter/material.dart';
import '../models/rapor_model.dart';
import '../models/santri_model.dart';
import '../services/rapor_service.dart';
import '../services/santri_service.dart';
import '../services/rapor_pdf_service.dart';
import '../widgets/custom_textfield.dart';

class RaporScreen extends StatefulWidget {
  const RaporScreen({super.key});

  @override
  State<RaporScreen> createState() => _RaporScreenState();
}

class _RaporScreenState extends State<RaporScreen> {
  final RaporService _raporService = RaporService();
  final SantriService _santriService = SantriService();
  final RaporPdfService _pdfService = RaporPdfService();

  String _selectedKelas = 'Kelas 1';
  String _selectedSemester = '1';
  String _selectedTahunAjaran = '2024/2025';

  final List<String> _kelasList = ['Kelas 1','Kelas 2','Kelas 3','Kelas 4','Kelas 5','Kelas 6'];
  final List<String> _tahunList = ['2023/2024','2024/2025','2025/2026'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rapor Santri')),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: _dropdown(_kelasList, _selectedKelas,
                    (v) => setState(() => _selectedKelas = v!))),
                const SizedBox(width: 8),
                Expanded(child: _dropdown(['Sem 1', 'Sem 2'], 'Sem $_selectedSemester',
                    (v) => setState(() => _selectedSemester = v!.replaceAll('Sem ', '')))),
                const SizedBox(width: 8),
                Expanded(child: _dropdown(_tahunList, _selectedTahunAjaran,
                    (v) => setState(() => _selectedTahunAjaran = v!))),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<SantriModel>>(
              future: _santriService.getSantri(kelas: _selectedKelas),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return const Center(child: Text('Tidak ada santri di kelas ini'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) => _raporCard(list[i], i + 1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown(List<String> items, String value, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
      items: items.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12)))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _raporCard(SantriModel santri, int peringkat) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF1B5E20),
                  child: Text(santri.nama[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(santri.nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('NIS: ${santri.nis} | ${santri.kelas}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Peringkat $peringkat',
                      style: TextStyle(color: Colors.amber.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<RaporModel>>(
              future: _raporService.getRaporSantri(santri.id),
              builder: (ctx, snap) {
                final raporList = snap.data ?? [];
                final raporExists = raporList.any(
                  (r) => r.semester == _selectedSemester && r.tahunAjaran == _selectedTahunAjaran,
                );
                final existingRapor = raporExists
                    ? raporList.firstWhere(
                        (r) => r.semester == _selectedSemester && r.tahunAjaran == _selectedTahunAjaran)
                    : null;

                return Row(
                  children: [
                    if (existingRapor != null) ...[
                      Expanded(
                        child: _raporInfoChip(
                          'Rata-rata: ${existingRapor.rataRata.toStringAsFixed(1)}',
                          existingRapor.naik ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _raporInfoChip(
                          existingRapor.statusKenaikan,
                          existingRapor.naik ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(raporExists ? Icons.picture_as_pdf : Icons.receipt_long, size: 16),
                        label: Text(raporExists ? 'Cetak PDF' : 'Generate', style: const TextStyle(fontSize: 12)),
                        onPressed: () => raporExists
                            ? _cetakRapor(existingRapor!)
                            : _generateRapor(santri, peringkat),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _raporInfoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center),
    );
  }

  Future<void> _generateRapor(SantriModel santri, int peringkat) async {
    final catatanCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Rapor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Generate rapor untuk ${santri.nama}?\nSemester $_selectedSemester TA $_selectedTahunAjaran'),
            const SizedBox(height: 12),
            CustomTextField(
              label: 'Catatan Wali Kelas (opsional)',
              controller: catatanCtrl,
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Generate')),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
        final rapor = await _raporService.generateRapor(
          santri: santri,
          semester: _selectedSemester,
          tahunAjaran: _selectedTahunAjaran,
          peringkat: peringkat,
          catatanWaliKelas: catatanCtrl.text,
        );
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rapor berhasil digenerate!')),
        );
        setState(() {});
        await _pdfService.generateAndOpenRapor(rapor);
      } catch (e) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cetakRapor(RaporModel rapor) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      await _pdfService.generateAndOpenRapor(rapor);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal cetak PDF: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
