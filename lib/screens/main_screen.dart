import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'absensi_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'absensi_admin_screen.dart';
import 'rekap_absensi_screen.dart';
import 'manajemen_gaji_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  // Memastikan _selectedIndex selalu dimulai dengan 0 (Beranda)
  int _selectedIndex = 0;
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Memulai animasi saat halaman pertama kali dibuka
    _animationController.forward();
    // Memastikan tab Beranda yang aktif
    setState(() {
      _selectedIndex = 0;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    // Animasi saat berganti tab
    _animationController.reset();
    _animationController.forward();
    
    setState(() {
      _selectedIndex = index;
    });
  }

  void _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    setState(() {
      _selectedIndex = 0;
    });
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final bool isAdmin = user != null && user.role == 'ADMIN';

    // Widget dan navigasi sesuai role
    late List<Widget> widgetOptions;
    List<Map<String, dynamic>> navigationItems = [];
    
    if (isAdmin) {
      // Opsi widget untuk admin
      widgetOptions = [
        const HomeScreen(),
        const RekapAbsensiScreen(),
        const AbsensiAdminScreen(),
        const ManajemenGajiScreen(),
        const ProfileScreen(),
      ];
      
      // Item navigasi untuk admin
      navigationItems = [
        {
          'icon': Icons.home_outlined,
          'activeIcon': Icons.home,
          'label': 'Beranda',
        },
        {
          'icon': Icons.bar_chart_outlined,
          'activeIcon': Icons.bar_chart,
          'label': 'Rekap',
        },
        {
          'icon': Icons.assignment_outlined,
          'activeIcon': Icons.assignment_rounded,
          'label': 'Absensi',
          'isMain': true,
        },
        {
          'icon': Icons.monetization_on_outlined,
          'activeIcon': Icons.monetization_on,
          'label': 'Gaji',
        },
        {
          'icon': Icons.person_outlined,
          'activeIcon': Icons.person,
          'label': 'Profil',
        },
      ];
    } else {
      // Opsi widget untuk guru
      widgetOptions = [
        const HomeScreen(),
        const AbsensiScreen(),
        const ProfileScreen(),
      ];
      
      // Item navigasi untuk guru
      navigationItems = [
        {
          'icon': Icons.home_outlined,
          'activeIcon': Icons.home,
          'label': 'Beranda',
        },
        {
          'icon': Icons.assignment_outlined,
          'activeIcon': Icons.assignment_rounded,
          'label': 'Absensi',
          'isMain': true,
        },
        {
          'icon': Icons.person_outlined,
          'activeIcon': Icons.person,
          'label': 'Profil',
        },
      ];
    }

    // Pastikan _selectedIndex tidak melebihi jumlah tab
    if (_selectedIndex >= widgetOptions.length) {
      _selectedIndex = 0;
    }
    
    // Menggunakan AnnotatedRegion untuk mengatur warna navbar dan statusbar
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        // Warna dan brightness status bar (bagian atas)
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        
        // Warna dan brightness navigation bar (bagian bawah)
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        extendBody: true, // Penting agar content bisa scroll di bawah bottom nav
        body: Padding(
          padding: const EdgeInsets.only(bottom: 60), // Kurangi padding bottom
          child: FadeTransition(
            opacity: _animationController.drive(CurveTween(curve: Curves.easeInOut)),
            child: widgetOptions.elementAt(_selectedIndex),
          ),
        ),
        bottomNavigationBar: _buildCustomBottomNavigationBar(context, theme, navigationItems),
      ),
    );
  }
  
  Widget _buildCustomBottomNavigationBar(BuildContext context, ThemeData theme, List<Map<String, dynamic>> items) {
    // Mendapatkan jumlah item dan index tengah
    final int itemCount = items.length;
    
    // Mendapatkan index item yang memiliki isMain = true
    int mainIndex = items.indexWhere((item) => item['isMain'] == true);
    
    // Jika tidak ada main item, gunakan index tengah
    if (mainIndex == -1) {
      mainIndex = (itemCount / 2).floor();
    }
    
    // Menghitung ukuran layar untuk responsivitas
    final Size screenSize = MediaQuery.of(context).size;
    
         return Container(
      height: 72, // Kurangi tinggi lagi dari 75 menjadi 72
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12), // Kurangi margin bottom
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
            spreadRadius: 2,
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.9),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Button utama (absensi) yang menonjol
          Positioned(
            top: 0, // Turunkan lagi dari -8 menjadi -4
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => _onItemTapped(mainIndex),
              child: Center(
                child: Container(
                  height: 65, // Kurangi sedikit ukuran
                  width: 65, // Kurangi sedikit ukuran
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _selectedIndex == mainIndex
                        ? [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                          ]
                        : [
                            theme.colorScheme.primary.withOpacity(0.7),
                            theme.colorScheme.secondary.withOpacity(0.7),
                          ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedIndex == mainIndex 
                              ? items[mainIndex]['activeIcon'] 
                              : items[mainIndex]['icon'],
                          color: Colors.white,
                          size: 26, // Kurangi sedikit ukuran
                        ),
                        const SizedBox(height: 2), // Kurangi space
                        Text(
                          items[mainIndex]['label'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9, // Kurangi ukuran font
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Item navigasi lainnya
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                itemCount,
                (index) {
                                      // Jika item ini adalah yang utama (absensi), berikan ruang kosong
                    if (index == mainIndex) {
                      return const SizedBox(width: 65);
                    }
                  
                  final bool isSelected = _selectedIndex == index;
                  
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onItemTapped(index),
                      behavior: HitTestBehavior.translucent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isSelected ? items[index]['activeIcon'] : items[index]['icon'],
                                color: isSelected ? theme.colorScheme.primary : Colors.grey,
                                size: 24,
                              ),
                            ),
                                                    const SizedBox(height: 2),
                        Text(
                              items[index]['label'],
                              style: TextStyle(
                                color: isSelected ? theme.colorScheme.primary : Colors.grey,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
} 