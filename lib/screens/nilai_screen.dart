import 'package:flutter/material.dart';
import '../models/nilai_model.dart';
import '../models/santri_model.dart';
import '../services/nilai_service.dart';
import '../services/santri_service.dart';
import '../widgets/custom_textfield.dart';

class NilaiScreen extends StatefulWidget {
  const NilaiScreen({super.key});

  @override
  State<NilaiScreen> createState() => _NilaiScreenState();
}

class _NilaiScreenState extends State<NilaiScreen> {
  final NilaiService _nilaiService = NilaiService();
  final SantriService _santriService = SantriService();

  String _selectedKelas = 'Kelas 1';
  String _selectedSemester = '1';
  String _selectedTahunAjaran = '2024/2025';

  final List<String> _kelasList = ['Kelas 1', 'Kelas 2', 'Kelas 3', 'Kelas 4', 'Kelas 5', 'Kelas 6'];
  final List<String> _semesterList = ['1', '2'];
  final List<String> _tahunList = ['2023/2024', '2024/2025', '2025/2026'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nilai Santri')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormNilai(context, null, null),
        icon: const Icon(Icons.add),
        label: const Text('Input Nilai'),
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: _dropdown(_kelasList, _selectedKelas, (v) => setState(() => _selectedKelas = v!))),
                const SizedBox(width: 8),
                Expanded(child: _dropdown(_semesterList.map((s) => 'Sem $s').toList(), 'Sem $_selectedSemester',
                    (v) => setState(() => _selectedSemester = v!.replaceAll('Sem ', '')))),
                const SizedBox(width: 8),
                Expanded(child: _dropdown(_tahunList, _selectedTahunAjaran, (v) => setState(() => _selectedTahunAjaran = v!))),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<SantriModel>>(
              future: _santriService.getSantri(kelas: _selectedKelas),
              builder: (ctx, santriSnap) {
                if (santriSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final santriList = santriSnap.data ?? [];
                if (santriList.isEmpty) {
                  return const Center(child: Text('Tidak ada santri di kelas ini'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: santriList.length,
                  itemBuilder: (ctx, i) => _santriNilaiCard(santriList[i]),
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

  Widget _santriNilaiCard(SantriModel santri) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1B5E20),
          child: Text(santri.nama[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
        ),
        title: Text(santri.nama, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text('NIS: ${santri.nis}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFF1B5E20)),
              onPressed: () => _showFormNilai(context, santri, null),
              tooltip: 'Tambah Nilai',
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          StreamBuilder<List<NilaiModel>>(
            stream: _nilaiService.streamNilai(
              santriId: santri.id,
              semester: _selectedSemester,
              tahunAjaran: _selectedTahunAjaran,
            ),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }
              final nilaiList = snap.data ?? [];
              if (nilaiList.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Belum ada nilai', style: TextStyle(color: Colors.grey)),
                );
              }
              return Column(
                children: nilaiList.map((n) => _nilaiTile(n, santri)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _nilaiTile(NilaiModel nilai, SantriModel santri) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nilai.mataPelajaran, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _nilaiChip('H', nilai.nilaiHarian, Colors.blue),
                    const SizedBox(width: 6),
                    _nilaiChip('UTS', nilai.nilaiUTS, Colors.orange),
                    const SizedBox(width: 6),
                    _nilaiChip('UAS', nilai.nilaiUAS, Colors.purple),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                nilai.nilaiAkhir.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: nilai.lulus ? Colors.green : Colors.red,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: nilai.lulus ? Colors.green.shade100 : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(nilai.grade, style: TextStyle(color: nilai.lulus ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: () => _showFormNilai(context, santri, nilai),
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            onPressed: () => _hapusNilai(nilai),
          ),
        ],
      ),
    );
  }

  Widget _nilaiChip(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text('$label: ${value.toStringAsFixed(0)}', style: TextStyle(color: color, fontSize: 11)),
    );
  }

  Future<void> _hapusNilai(NilaiModel nilai) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Nilai'),
        content: Text('Hapus nilai ${nilai.mataPelajaran}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _nilaiService.hapusNilai(nilai.id);
    }
  }

  void _showFormNilai(BuildContext context, SantriModel? santri, NilaiModel? nilai) {
    final isEdit = nilai != null;
    SantriModel? selectedSantri = santri;
    final mapelCtrl = TextEditingController(text: nilai?.mataPelajaran);
    final harianCtrl = TextEditingController(text: nilai?.nilaiHarian.toString() ?? '');
    final utsCtrl = TextEditingController(text: nilai?.nilaiUTS.toString() ?? '');
    final uasCtrl = TextEditingController(text: nilai?.nilaiUAS.toString() ?? '');
    String semester = nilai?.semester ?? _selectedSemester;
    String tahunAjaran = nilai?.tahunAjaran ?? _selectedTahunAjaran;
    final formKey = GlobalKey<FormState>();

    final mapelList = [
      'Al-Quran', 'Hadits', 'Fiqih', 'Akidah Akhlak',
      'Bahasa Arab', 'Bahasa Indonesia', 'Matematika',
      'IPA', 'IPS', 'Bahasa Inggris',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(isEdit ? 'Edit Nilai' : 'Input Nilai Santri',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (santri == null)
                    FutureBuilder<List<SantriModel>>(
                      future: _santriService.getSantri(kelas: _selectedKelas),
                      builder: (ctx, snap) {
                        final list = snap.data ?? [];
                        return DropdownButtonFormField<SantriModel>(
                          decoration: InputDecoration(
                            labelText: 'Pilih Santri',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: list.map((s) => DropdownMenuItem(value: s, child: Text(s.nama))).toList(),
                          onChanged: (v) => setLocal(() => selectedSantri = v),
                          validator: (v) => v == null ? 'Pilih santri' : null,
                        );
                      },
                    ),
                  if (santri == null) const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: mapelCtrl.text.isEmpty ? null : (mapelList.contains(mapelCtrl.text) ? mapelCtrl.text : null),
                    decoration: InputDecoration(
                      labelText: 'Mata Pelajaran',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: mapelList.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => mapelCtrl.text = v ?? '',
                    validator: (v) => v == null ? 'Pilih mata pelajaran' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: CustomTextField(label: 'Nilai Harian', controller: harianCtrl,
                        keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Wajib' : null)),
                    const SizedBox(width: 8),
                    Expanded(child: CustomTextField(label: 'Nilai UTS', controller: utsCtrl,
                        keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Wajib' : null)),
                    const SizedBox(width: 8),
                    Expanded(child: CustomTextField(label: 'Nilai UAS', controller: uasCtrl,
                        keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Wajib' : null)),
                  ]),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      if (selectedSantri == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pilih santri terlebih dahulu')));
                        return;
                      }
                      final newNilai = NilaiModel(
                        id: nilai?.id ?? '',
                        santriId: selectedSantri!.id,
                        mataPelajaran: mapelCtrl.text,
                        nilaiHarian: double.tryParse(harianCtrl.text) ?? 0,
                        nilaiUTS: double.tryParse(utsCtrl.text) ?? 0,
                        nilaiUAS: double.tryParse(uasCtrl.text) ?? 0,
                        semester: semester,
                        tahunAjaran: tahunAjaran,
                        kelas: selectedSantri!.kelas,
                      );
                      if (isEdit) {
                        await _nilaiService.updateNilai(newNilai);
                      } else {
                        await _nilaiService.tambahNilai(newNilai);
                      }
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Nilai berhasil ${isEdit ? 'diperbarui' : 'disimpan'}')),
                        );
                      }
                    },
                    child: Text(isEdit ? 'Simpan Perubahan' : 'Simpan Nilai'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
