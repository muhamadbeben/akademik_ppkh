import 'package:flutter/material.dart';
import '../models/santri_model.dart';
import '../services/santri_service.dart';
import '../widgets/custom_textfield.dart';

class SantriScreen extends StatefulWidget {
  const SantriScreen({super.key});

  @override
  State<SantriScreen> createState() => _SantriScreenState();
}

class _SantriScreenState extends State<SantriScreen> {
  final SantriService _santriService = SantriService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _filterKelas;
  List<String> _kelasList = [];

  @override
  void initState() {
    super.initState();
    _loadKelas();
  }

  Future<void> _loadKelas() async {
    final list = await _santriService.getKelasList();
    setState(() => _kelasList = list);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Santri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormSantri(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Santri'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nama atau NIS santri...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          if (_filterKelas != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Chip(
                    label: Text('Kelas: $_filterKelas'),
                    onDeleted: () => setState(() => _filterKelas = null),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<SantriModel>>(
              stream: _santriService.streamSantri(kelas: _filterKelas),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                var list = snapshot.data ?? [];
                if (_searchQuery.isNotEmpty) {
                  list = list
                      .where((s) =>
                          s.nama.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                          s.nis.contains(_searchQuery))
                      .toList();
                }
                if (list.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Belum ada data santri', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) => _santriCard(list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _santriCard(SantriModel santri) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1B5E20),
          child: Text(
            santri.nama.isNotEmpty ? santri.nama[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(santri.nama, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NIS: ${santri.nis}'),
            Row(
              children: [
                _badge(santri.kelas, Colors.blue),
                const SizedBox(width: 6),
                _badge(
                  santri.status,
                  santri.status == 'aktif' ? Colors.green : Colors.orange,
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _showFormSantri(context, santri);
            if (v == 'hapus') _konfirmasiHapus(santri);
            if (v == 'detail') _showDetailSantri(santri);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'detail', child: Text('Lihat Detail')),
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'hapus', child: Text('Hapus', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filter Kelas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Semua Kelas'),
              leading: Radio<String?>(
                value: null,
                groupValue: _filterKelas,
                onChanged: (v) { setState(() => _filterKelas = v); Navigator.pop(ctx); },
              ),
            ),
            ..._kelasList.map((k) => ListTile(
              title: Text(k),
              leading: Radio<String?>(
                value: k,
                groupValue: _filterKelas,
                onChanged: (v) { setState(() => _filterKelas = v); Navigator.pop(ctx); },
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _showDetailSantri(SantriModel santri) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFF1B5E20),
                  child: Text(
                    santri.nama[0].toUpperCase(),
                    style: const TextStyle(fontSize: 28, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(santri.nama, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 24),
              _detailRow('NIS', santri.nis),
              _detailRow('Kelas', santri.kelas),
              _detailRow('Jenis Kelamin', santri.jenisKelamin),
              _detailRow('Tempat Lahir', santri.tempatLahir),
              _detailRow('Tanggal Lahir', santri.tanggalLahir.toString().substring(0, 10)),
              _detailRow('Alamat', santri.alamat),
              _detailRow('Nama Wali', santri.namaWali),
              _detailRow('No HP Wali', santri.noHpWali),
              _detailRow('Tahun Masuk', santri.tahunMasuk),
              _detailRow('Status', santri.status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey))),
          const Text(': '),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  void _konfirmasiHapus(SantriModel santri) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Santri'),
        content: Text('Apakah Anda yakin ingin menghapus data ${santri.nama}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _santriService.hapusSantri(santri.id);
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data santri berhasil dihapus')),
                );
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showFormSantri(BuildContext context, SantriModel? santri) {
    final isEdit = santri != null;
    final namaCtrl = TextEditingController(text: santri?.nama);
    final nisCtrl = TextEditingController(text: santri?.nis);
    final tempatCtrl = TextEditingController(text: santri?.tempatLahir);
    final alamatCtrl = TextEditingController(text: santri?.alamat);
    final waliCtrl = TextEditingController(text: santri?.namaWali);
    final hpCtrl = TextEditingController(text: santri?.noHpWali);
    final tahunCtrl = TextEditingController(text: santri?.tahunMasuk);
    String jk = santri?.jenisKelamin ?? 'Laki-laki';
    String kelas = santri?.kelas ?? 'Kelas 1';
    DateTime tglLahir = santri?.tanggalLahir ?? DateTime(2005);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => Padding(
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
                  Text(
                    isEdit ? 'Edit Data Santri' : 'Tambah Santri Baru',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(label: 'Nama Lengkap', controller: namaCtrl,
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                  const SizedBox(height: 12),
                  CustomTextField(label: 'NIS', controller: nisCtrl,
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: jk,
                    decoration: InputDecoration(
                      labelText: 'Jenis Kelamin',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: ['Laki-laki', 'Perempuan']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => setLocalState(() => jk = v!),
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(label: 'Tempat Lahir', controller: tempatCtrl,
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                  const SizedBox(height: 12),
                  ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300)),
                    title: const Text('Tanggal Lahir'),
                    subtitle: Text(tglLahir.toString().substring(0, 10)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: tglLahir,
                        firstDate: DateTime(1990),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setLocalState(() => tglLahir = d);
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(label: 'Alamat', controller: alamatCtrl, maxLines: 2,
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: kelas,
                    decoration: InputDecoration(
                      labelText: 'Kelas',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: ['Kelas 1', 'Kelas 2', 'Kelas 3', 'Kelas 4', 'Kelas 5', 'Kelas 6']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => setLocalState(() => kelas = v!),
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(label: 'Nama Wali', controller: waliCtrl,
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                  const SizedBox(height: 12),
                  CustomTextField(label: 'No HP Wali', controller: hpCtrl,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  CustomTextField(label: 'Tahun Masuk', controller: tahunCtrl,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final data = SantriModel(
                        id: santri?.id ?? '',
                        nama: namaCtrl.text.trim(),
                        nis: nisCtrl.text.trim(),
                        jenisKelamin: jk,
                        tempatLahir: tempatCtrl.text.trim(),
                        tanggalLahir: tglLahir,
                        alamat: alamatCtrl.text.trim(),
                        namaWali: waliCtrl.text.trim(),
                        noHpWali: hpCtrl.text.trim(),
                        kelas: kelas,
                        tahunMasuk: tahunCtrl.text.trim(),
                      );
                      if (isEdit) {
                        await _santriService.updateSantri(data);
                      } else {
                        await _santriService.tambahSantri(data);
                      }
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Data santri berhasil ${isEdit ? 'diperbarui' : 'ditambahkan'}')),
                        );
                      }
                    },
                    child: Text(isEdit ? 'Simpan Perubahan' : 'Tambah Santri'),
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
