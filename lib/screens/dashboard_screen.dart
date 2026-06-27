// File: lib/screens/dashboard_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:akademik_ppkh/services/firestore_service.dart';
import 'package:akademik_ppkh/screens/santri_screen.dart';
import 'package:akademik_ppkh/screens/nilai_screen.dart';
import 'package:akademik_ppkh/screens/jadwal_pelajaran_screen.dart';
import 'package:akademik_ppkh/screens/rapor_screen.dart';
import 'package:akademik_ppkh/screens/prediksi_screen.dart';
import 'package:akademik_ppkh/screens/laporan_screen.dart';
import 'package:akademik_ppkh/screens/guru_screen.dart';
import 'package:akademik_ppkh/screens/walisantri_screen.dart';
import 'package:akademik_ppkh/screens/akun_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  final String userRole;
  final String? santriId;

  const DashboardScreen({
    super.key,
    required this.userName,
    required this.userRole,
    this.santriId,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animController;
  int _totalSantri = 256;

  final List<_MenuData> _allMenus = const [
    _MenuData(
      'Kelola Santri',
      'Kelola data santri',
      Icons.people_alt_rounded,
      Color(0xFF5E48E8),
    ),
    _MenuData(
      'Input Nilai',
      'Input dan kelola\nnilai santri',
      Icons.assignment_turned_in_rounded,
      Color(0xFF00A3FF),
    ),
    _MenuData(
      'Jadwal Pelajaran',
      'Atur jadwal\npelajaran santri',
      Icons.calendar_month_rounded,
      Color(0xFFFF9F1C),
    ),
    _MenuData(
      'Cetak Rapot',
      'Cetak rapot\nsantri',
      Icons.print_rounded,
      Color(0xFF00B69B),
    ),
    _MenuData(
      'Prediksi AI',
      'Prediksi prestasi\nsantri dengan AI',
      Icons.psychology_rounded,
      Color(0xFF7B61FF),
    ),
    _MenuData(
      'Laporan',
      'Lihat dan unduh\nlaporan',
      Icons.description_rounded,
      Color(0xFFEF4444),
    ),
    _MenuData(
      'Kelola Guru',
      'Kelola data\ndan akun guru',
      Icons.school_rounded,
      Color(0xFF5E48E8),
    ),
    _MenuData(
      'Kelola Wali Santri',
      'Kelola data\ndan akun wali santri',
      Icons.people_rounded,
      Color(0xFFFFB800),
    ),
  ];

  String get _cleanedRole => widget.userRole.trim().toLowerCase();

  List<_MenuData> get _displayMenus {
    if (_cleanedRole == 'admin') {
      return _allMenus;
    }
    if (_cleanedRole == 'guru') {
      return _allMenus
          .where(
            (menu) =>
                menu.title.contains('Nilai') ||
                menu.title.contains('Jadwal') ||
                menu.title.contains('Rapot') ||
                menu.title.contains('Prediksi'),
          )
          .toList();
    }
    return _allMenus
        .where(
          (menu) =>
              menu.title.contains('Rapot') || menu.title.contains('Prediksi'),
        )
        .toList();
  }

  // Nav Bar Items yang disesuaikan secara dinamis berdasarkan role akun
  List<BottomNavigationBarItem> get _navItems {
    final List<BottomNavigationBarItem> items = [
      const BottomNavigationBarItem(
          icon: Icon(Icons.home_filled), label: 'Dasbor'),
    ];

    if (_cleanedRole == 'admin' || _cleanedRole == 'guru') {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.people_outline_rounded),
        label: 'Santri',
      ));
    }

    items.add(const BottomNavigationBarItem(
      icon: Icon(Icons.menu_book_rounded),
      label: 'Akademik',
    ));

    if (_cleanedRole == 'admin') {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.description_outlined),
        label: 'Laporan',
      ));
    }

    items.add(const BottomNavigationBarItem(
      icon: Icon(Icons.person_outline_rounded),
      label: 'Akun',
    ));

    return items;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _animController.forward();
    _loadRealStats();
  }

  Future<void> _loadRealStats() async {
    try {
      final tSantri = await FirestoreService.getTotalSantriAktif();
      if (mounted && tSantri > 0) {
        setState(() {
          _totalSantri = tSantri;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleNavigation(String title) {
    Widget targetScreen;
    switch (title) {
      case 'Kelola Santri':
        targetScreen = const SantriScreen();
        break;
      case 'Input Nilai':
        targetScreen = const NilaiScreen();
        break;
      case 'Jadwal Pelajaran':
        targetScreen = const JadwalPelajaranScreen();
        break;
      case 'Cetak Rapot':
        targetScreen = RaporScreen(
          userRole: widget.userRole,
          santriId: widget.santriId,
        );
        break;
      case 'Prediksi AI':
        targetScreen = PrediksiScreen();
        break;
      case 'Laporan':
        targetScreen = const LaporanScreen();
        break;
      case 'Kelola Guru':
        targetScreen = const KelolaGuruScreen();
        break;
      case 'Kelola Wali Santri':
        targetScreen = const WaliSantriScreen();
        break;
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => targetScreen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBFC),
      body: _currentIndex == 0
          ? _buildMainDashboard()
          : _buildAlternativeScreen(),
      bottomNavigationBar: _buildModernBottomNav(),
    );
  }

  // PERBAIKAN LOGIKA NAVIGASI: Menggunakan pembacaan label item Nav Bar aktif agar tidak kosong
  // Cari blok kode ini di dashboard_screen.dart dan ubah baris AccountScreen-nya
  Widget _buildAlternativeScreen() {
    final String currentLabel = _navItems[_currentIndex].label ?? '';

    switch (currentLabel) {
      case 'Santri':
        return const SantriScreen();
      case 'Akademik':
        return (_cleanedRole == 'admin' || _cleanedRole == 'guru')
            ? const NilaiScreen()
            : RaporScreen(userRole: widget.userRole, santriId: widget.santriId);
      case 'Laporan':
        return const LaporanScreen();
      case 'Akun':
        // PERBAIKAN DI SINI: Kirimkan userRole ke dalam halaman akun
        return AccountScreen(userRole: widget.userRole); 
      default:
        return const Center(child: Text('Halaman Tidak Ditemukan'));
    }
  }
  Widget _buildMainDashboard() {
    final dynamicMenus = _displayMenus;

    return SingleChildScrollView(
      child: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFFF9FBFC))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGradientVisualHeader(),
              const SizedBox(height: 50),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Menu Utama',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A0E29),
                      ),
                    ),
                    const SizedBox(height: 14),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: dynamicMenus.length,
                      itemBuilder: (_, i) {
                        final cardAnim = CurvedAnimation(
                          parent: _animController,
                          curve: Interval(
                            i * 0.04,
                            0.35 + (i * 0.04),
                            curve: Curves.easeOutQuad,
                          ),
                        );
                        return ScaleTransition(
                          scale: cardAnim,
                          child: _buildModernMenuCard(dynamicMenus[i]),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ringkasan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A0E29),
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Row(
                            children: [
                              Text(
                                'Lihat semua ',
                                style: TextStyle(
                                  color: Color(0xFF4A32E5),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 11,
                                color: Color(0xFF4A32E5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildVisualAnalyticsSection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 210,
            left: 18,
            right: 18,
            child: _buildFloatingDateCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientVisualHeader() {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A32E5), Color(0xFF2813A5)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            right: 0,
            left: 0,
            child: Opacity(
              opacity: 0.12,
              child: Icon(
                Icons.mosque,
                size: 160,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () {
                        // Langsung mengarah ke index paling ujung (Menu Akun) secara aman
                        setState(() => _currentIndex = _navItems.length - 1);
                      },
                      child: const CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white24,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, color: Color(0xFF2813A5)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  "Assalamu'alaikum,",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Selamat datang di Sistem Academic Santri',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingDateCard() {
    final now = DateTime.now();
    final List<String> hari = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu'
    ];
    final List<String> bulan = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    final formatTanggal =
        '${hari[now.weekday - 1]}, ${now.day} ${bulan[now.month - 1]} ${now.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEEECFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: Color(0xFF4A32E5),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatTanggal,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF0A0E29),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernMenuCard(_MenuData menu) {
    return GestureDetector(
      onTap: () => _handleNavigation(menu.title),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              child: Icon(menu.icon, color: menu.themeColor, size: 34),
            ),
            const SizedBox(height: 6),
            Text(
              menu.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A0E29),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              menu.subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.grey,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualAnalyticsSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 11,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Grafik Nilai Rata-rata',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF0A0E29),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Semester Genap ',
                        style: TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                      Icon(Icons.keyboard_arrow_down,
                          size: 14, color: Colors.black54),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _barIndicator('Jan', 55),
                    _barIndicator('Feb', 68),
                    _barIndicator('Mar', 88),
                    _barIndicator('Apr', 78),
                    _barIndicator('Mei', 92),
                    _barIndicator('Jun', 74),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 10,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Distribusi Santri',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: const Color(0xFF0A0E29),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 90,
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(90, 90),
                        painter: _DonutChartPainter(),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$_totalSantri',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0A0E29),
                            ),
                          ),
                          const Text(
                            'Santri',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 2.2,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  children: const [
                    _LegendRow(
                        label: 'Kelas SP',
                        percent: '20%',
                        color: Color(0xFF5E48E8)),
                    _LegendRow(
                        label: 'Kelas 1',
                        percent: '25%',
                        color: Color(0xFF00A3FF)),
                    _LegendRow(
                        label: 'Kelas 2',
                        percent: '25%',
                        color: Color(0xFF00B69B)),
                    _LegendRow(
                        label: 'Kelas 3',
                        percent: '15%',
                        color: Color(0xFFFF9F1C)),
                    _LegendRow(
                        label: 'Kelas 4',
                        percent: '15%',
                        color: Color(0xFFEF4444)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _barIndicator(String label, double heightVal) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          height: heightVal,
          width: 16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF9F8FFF), Color(0xFF5E48E8)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildModernBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (i) => setState(() => _currentIndex = i),
      selectedItemColor: const Color(0xFF4A32E5),
      unselectedItemColor: Colors.grey.shade400,
      showUnselectedLabels: true,
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle:
          const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      unselectedLabelStyle:
          const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
      items: _navItems,
    );
  }
}

class _LegendRow extends StatelessWidget {
  final String label;
  final String percent;
  final Color color;

  const _LegendRow(
      {required this.label, required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                    fontSize: 8,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                percent,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A0E29)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color themeColor;
  const _MenuData(this.title, this.subtitle, this.icon, this.themeColor);
}

class _DonutChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double strokeWidth = 12.0;
    Rect rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - strokeWidth) / 2,
    );

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    List<double> values = [0.20, 0.25, 0.25, 0.15, 0.15];
    List<Color> colors = [
      const Color(0xFF5E48E8), // SP
      const Color(0xFF00A3FF), // 1
      const Color(0xFF00B69B), // 2
      const Color(0xFFFF9F1C), // 3
      const Color(0xFFEF4444), // 4
    ];

    double startAngle = -pi / 2;

    for (int i = 0; i < values.length; i++) {
      paint.color = colors[i];
      double sweepAngle = values[i] * 2 * pi;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}