import 'package:flutter/material.dart';
import '../models/jadwal_pelajaran_model.dart';
import '../services/jadwal_pelajaran_service.dart';
import '../widgets/custom_textfield.dart';

class JadwalPelajaranScreen extends StatefulWidget {
  const JadwalPelajaranScreen({super.key});

  @override
  State<JadwalPelajaranScreen> createState() => _JadwalPelajaranScreenState();
}

class _JadwalPelajaranScreenState extends State<JadwalPelajaranScreen>
    with SingleTickerProviderStateMixin {
  final JadwalPelajaranService _service = JadwalPelajaranService();
  late TabController _tabController;
  String _selectedKelas = 'Kelas 1';
  final List<String> _kelasList = ['Kelas 1','Kelas 2','Kelas 3','Kelas 4','Kelas 5','Kelas 6'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: JadwalPelajaranService.hariList.length,
      vsync: this,
    );
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
        title: const Text('Jadwal Pelajaran'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: JadwalPelajaranService.hariList
              .map((h) => Tab(text: h))
              .toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormJadwal(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Jadwal'),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              value: _selectedKelas,
              decoration: InputDecoration(
                labelText: 'Pilih Kelas',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.class_),
                isDense: true,
              ),
              items: _kelasList
                  .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedKelas = v!),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: JadwalPelajaranService.hariList
                  .map((hari) => _jadwalList(hari))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _jadwalList(String hari) {
    return StreamBuilder<List<JadwalPelajaranModel>>(
      stream: _service.streamJadwal(_selectedKelas),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data ?? [];
        final list = all.where((j) => j.hari == hari).toList()
          ..sort((a, b) => a.jamMulai.compareTo(b.jamMulai));

        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('Tidak ada jadwal hari $hari',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (ctx, i) {
            final jadwal = list[i];
            return _jadwalCard(jadwal, i);
          },
        );
      },
    );
  }

  Widget _jadwalCard(JadwalPelajaranModel jadwal, int index) {
    final colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple,
      Colors.red, Colors.teal, Colors.indigo, Colors.brown,
    ];
    final color = colors[index % colors.length];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Row(
        children: [
          Container(
            width: 6,
            height: 80,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(jadwal.mataPelajaran,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(jadwal.waktu,
                            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(jadwal.ustadz, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(width: 16),
                      const Icon(Icons.room, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(jadwal.ruangan, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') _showFormJadwal(context, jadwal);
              if (v == 'hapus') _hapusJadwal(jadwal);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'hapus', child: Text('Hapus', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _hapusJadwal(JadwalPelajaranModel jadwal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Jadwal'),
        content: Text('Hapus jadwal ${jadwal.mataPelajaran} hari ${jadwal.hari}?'),
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
    if (confirm == true) await _service.hapusJadwal(jadwal.id);
  }

  void _showFormJadwal(BuildContext context, JadwalPelajaranModel? jadwal) {
    final isEdit = jadwal != null;
    String mapel = jadwal?.mataPelajaran ?? 'Al-Quran';
    String kelas = jadwal?.kelas ?? _selectedKelas;
    String hari = jadwal?.hari ?? JadwalPelajaranService.hariList[0];
    final jamMulaiCtrl = TextEditingController(text: jadwal?.jamMulai ?? '07:00');
    final jamSelesaiCtrl = TextEditingController(text: jadwal?.jamSelesai ?? '08:00');
    final ustadzCtrl = TextEditingController(text: jadwal?.ustadz ?? '');
    final ruanganCtrl = TextEditingController(text: jadwal?.ruangan ?? '');
    final formKey = GlobalKey<FormState>();

    final mapelList = [
      'Al-Quran', 'Hadits', 'Fiqih', 'Akidah Akhlak', 'Bahasa Arab',
      'Bahasa Indonesia', 'Matematika', 'IPA', 'IPS', 'Bahasa Inggris', 'Tahfidz',
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
                  Text(isEdit ? 'Edit Jadwal' : 'Tambah Jadwal',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: mapel,
                    decoration: InputDecoration(labelText: 'Mata Pelajaran',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    items: mapelList.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setLocal(() => mapel = v!),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: kelas,
                        decoration: InputDecoration(labelText: 'Kelas',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        items: _kelasList.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                        onChanged: (v) => setLocal(() => kelas = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: hari,
                        decoration: InputDecoration(labelText: 'Hari',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        items: JadwalPelajaranService.hariList
                            .map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                        onChanged: (v) => setLocal(() => hari = v!),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: CustomTextField(label: 'Jam Mulai', controller: jamMulaiCtrl,
                        hint: '07:00', validator: (v) => v!.isEmpty ? 'Wajib' : null)),
                    const SizedBox(width: 8),
                    Expanded(child: CustomTextField(label: 'Jam Selesai', controller: jamSelesaiCtrl,
                        hint: '08:00', validator: (v) => v!.isEmpty ? 'Wajib' : null)),
                  ]),
                  const SizedBox(height: 12),
                  CustomTextField(label: 'Nama Ustadz/Ustadzah', controller: ustadzCtrl,
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                  const SizedBox(height: 12),
                  CustomTextField(label: 'Ruangan', controller: ruanganCtrl,
                      hint: 'Contoh: Ruang A1', validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final data = JadwalPelajaranModel(
                        id: jadwal?.id ?? '',
                        mataPelajaran: mapel,
                        kelas: kelas,
                        hari: hari,
                        jamMulai: jamMulaiCtrl.text,
                        jamSelesai: jamSelesaiCtrl.text,
                        ustadz: ustadzCtrl.text.trim(),
                        ruangan: ruanganCtrl.text.trim(),
                      );
                      if (isEdit) {
                        await _service.updateJadwal(data);
                      } else {
                        await _service.tambahJadwal(data);
                      }
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Jadwal berhasil ${isEdit ? 'diperbarui' : 'ditambahkan'}')),
                        );
                      }
                    },
                    child: Text(isEdit ? 'Simpan Perubahan' : 'Tambah Jadwal'),
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
