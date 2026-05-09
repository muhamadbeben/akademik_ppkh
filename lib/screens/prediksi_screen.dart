import 'package:flutter/material.dart';
import '../models/prediksi_model.dart';
import '../models/santri_model.dart';
import '../services/prediksi_service.dart';
import '../services/santri_service.dart';
import '../widgets/custom_textfield.dart';

class PrediksiScreen extends StatefulWidget {
  const PrediksiScreen({super.key});

  @override
  State<PrediksiScreen> createState() => _PrediksiScreenState();
}

class _PrediksiScreenState extends State<PrediksiScreen>
    with SingleTickerProviderStateMixin {
  final PrediksiService _prediksiService = PrediksiService();
  final SantriService _santriService = SantriService();
  late TabController _tabController;

  String _selectedKelas = 'Kelas 1';
  String _selectedSemester = '1';
  String _selectedTahunAjaran = '2024/2025';

  final List<String> _kelasList = ['Kelas 1','Kelas 2','Kelas 3','Kelas 4','Kelas 5','Kelas 6'];
  final List<String> _tahunList = ['2023/2024','2024/2025','2025/2026'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prediksi Kelulusan'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: 'Prediksi Baru'), Tab(text: 'Riwayat Prediksi')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_prediksiTab(), _riwayatTab()],
      ),
    );
  }

  Widget _prediksiTab() {
    return Column(
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
                itemBuilder: (ctx, i) => _santriPrediksiCard(list[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _santriPrediksiCard(SantriModel santri) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1B5E20),
          child: Text(santri.nama[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text(santri.nama, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${santri.kelas} | NIS: ${santri.nis}'),
        trailing: ElevatedButton.icon(
          icon: const Icon(Icons.psychology, size: 16),
          label: const Text('Prediksi', style: TextStyle(fontSize: 12)),
          onPressed: () => _showFormPrediksi(santri),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
        ),
      ),
    );
  }

  Widget _riwayatTab() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(child: _dropdown(_kelasList, _selectedKelas,
                  (v) => setState(() => _selectedKelas = v!))),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<PrediksiModel>>(
            stream: _prediksiService.streamPrediksi(kelas: _selectedKelas),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.psychology_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Belum ada riwayat prediksi', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              // Statistik singkat di atas
              final lulus = list.where((p) => p.isLulus).length;
              final total = list.length;

              return Column(
                children: [
                  _buildStatistikBar(total: total, lulus: lulus),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder: (ctx, i) => _hasilPrediksiCard(list[i]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatistikBar({required int total, required int lulus}) {
    final tidakLulus = total - lulus;
    final pctLulus = total > 0 ? (lulus / total * 100) : 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Total', '$total', Colors.white),
          _statItem('Lulus', '$lulus', Colors.lightGreenAccent),
          _statItem('Tidak Lulus', '$tidakLulus', Colors.redAccent.shade100),
          _statItem('% Lulus', '${pctLulus.toStringAsFixed(0)}%', Colors.yellowAccent),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _hasilPrediksiCard(PrediksiModel prediksi) {
    final isLulus = prediksi.isLulus;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isLulus ? Colors.green.shade100 : Colors.red.shade100,
          child: Icon(
            isLulus ? Icons.check_circle : Icons.cancel,
            color: isLulus ? Colors.green : Colors.red,
          ),
        ),
        title: Text(prediksi.namaSantri, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${prediksi.kelas} | ${prediksi.semester} TA ${prediksi.tahunAjaran}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isLulus ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                prediksi.hasilPrediksi,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            Text('${prediksi.confidence.toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Row(
                  children: [
                    _infoChip('Rata-rata', prediksi.rataRataNilai.toStringAsFixed(1), Colors.blue),
                    const SizedBox(width: 8),
                    _infoChip('Kehadiran', '${prediksi.persentaseKehadiran.toStringAsFixed(0)}%', Colors.green),
                    const SizedBox(width: 8),
                    _infoChip('Pelanggaran', '${prediksi.jumlahMelanggar}x', Colors.orange),
                  ],
                ),
                const SizedBox(height: 12),
                if (prediksi.faktorPendukung.isNotEmpty) ...[
                  const Text('Faktor Pendukung:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  ...prediksi.faktorPendukung.map((f) => Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(f, style: const TextStyle(fontSize: 12))),
                    ],
                  )),
                ],
                if (prediksi.rekomendasiPerbaikan.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Rekomendasi:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  ...prediksi.rekomendasiPerbaikan.map((r) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.arrow_right, color: Colors.orange, size: 20),
                      Expanded(child: Text(r, style: const TextStyle(fontSize: 12))),
                    ],
                  )),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                    label: const Text('Hapus', style: TextStyle(color: Colors.red)),
                    onPressed: () => _prediksiService.hapusPrediksi(prediksi.id),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
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

  void _showFormPrediksi(SantriModel santri) {
    final kehadiranCtrl = TextEditingController();
    final melanggarCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

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
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Input Data Prediksi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Santri: ${santri.nama}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Nilai akademik akan diambil otomatis dari database.',
                          style: TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Persentase Kehadiran (%)',
                  hint: 'Contoh: 85.5',
                  controller: kehadiranCtrl,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.how_to_reg,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Wajib diisi';
                    final d = double.tryParse(v);
                    if (d == null || d < 0 || d > 100) return 'Masukkan angka 0-100';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Jumlah Pelanggaran',
                  hint: 'Contoh: 2',
                  controller: melanggarCtrl,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.warning_amber,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Wajib diisi';
                    if (int.tryParse(v) == null) return 'Masukkan angka bulat';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: loading
                      ? const SizedBox(height: 18, width: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.psychology),
                  label: const Text('Jalankan Prediksi'),
                  onPressed: loading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setLocal(() => loading = true);
                          try {
                            final prediksi = await _prediksiService.prediksikanSantri(
                              santri: santri,
                              semester: _selectedSemester,
                              tahunAjaran: _selectedTahunAjaran,
                              persentaseKehadiran: double.parse(kehadiranCtrl.text),
                              jumlahMelanggar: int.parse(melanggarCtrl.text),
                            );
                            if (mounted) {
                              Navigator.pop(ctx);
                              _showHasilPrediksi(prediksi);
                              _tabController.animateTo(1);
                            }
                          } catch (e) {
                            setLocal(() => loading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHasilPrediksi(PrediksiModel prediksi) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(
              prediksi.isLulus ? Icons.check_circle : Icons.cancel,
              color: prediksi.isLulus ? Colors.green : Colors.red,
              size: 48,
            ),
            const SizedBox(height: 8),
            Text('Hasil Prediksi', style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: prediksi.isLulus ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    prediksi.namaSantri,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    prediksi.hasilPrediksi.toUpperCase(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: prediksi.isLulus ? Colors.green : Colors.red,
                    ),
                  ),
                  Text(
                    'Tingkat keyakinan: ${prediksi.confidence.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }
}
