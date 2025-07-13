import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/api_service.dart';
import 'screens/absensi_admin_screen.dart';
import 'screens/dashboard_admin_screen.dart';
import 'screens/manajemen_guru_screen.dart';

void main() async {
  // Pastikan binding Flutter sudah diinisialisasi
  WidgetsFlutterBinding.ensureInitialized();
  
  // Preload assets dan konfigurasi
  await Future.wait([
    initializeDateFormatting('id_ID', null),
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
  ]);
  
  // Konfigurasi cache untuk performa lebih baik
  PaintingBinding.instance.imageCache.maximumSizeBytes = 1024 * 1024 * 100; // 100MB
  PaintingBinding.instance.imageCache.maximumSize = 500;
  
  // Mengatur warna statusbar dan navbar di seluruh aplikasi
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.white,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  
  // Set locale untuk format tanggal
  Intl.defaultLocale = 'id_ID';
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: InitializerWidget(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            return MaterialApp(
              title: 'Aplikasi Absensi',
              debugShowCheckedModeBanner: false,
              // Optimalkan performa dengan builder
              builder: (context, child) {
                // Tambahkan scrollbehavior global untuk scrolling yang smooth
                final scrollBehavior = ScrollConfiguration.of(context).copyWith(
                  physics: const BouncingScrollPhysics(),
                  scrollbars: false,
                );
                
                // Pastikan text scaling tidak terlalu besar
                final mediaQuery = MediaQuery.of(context);
                final scale = mediaQuery.textScaleFactor.clamp(0.85, 1.15);
                
                return MediaQuery(
                  data: mediaQuery.copyWith(textScaleFactor: scale),
                  child: ScrollConfiguration(
                    behavior: scrollBehavior,
                    child: child!,
                  ),
                );
              },
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF4361EE),
                  brightness: Brightness.light,
                  primary: const Color(0xFF4361EE),
                  secondary: const Color(0xFF3F37C9),
                  tertiary: const Color(0xFF4CC9F0),
                  error: const Color(0xFFE63946),
                ),
                textTheme: GoogleFonts.poppinsTextTheme(
                  Theme.of(context).textTheme,
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF4361EE),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  centerTitle: true,
                ),
                cardColor: Colors.white,
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4361EE),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4361EE),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF4361EE),
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFE63946),
                      width: 2,
                    ),
                  ),
                  floatingLabelStyle: const TextStyle(
                    color: Color(0xFF4361EE),
                  ),
                ),
                bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                  backgroundColor: Colors.white,
                  selectedItemColor: Color(0xFF4361EE),
                  unselectedItemColor: Colors.grey,
                  type: BottomNavigationBarType.fixed,
                  elevation: 8,
                ),
                scaffoldBackgroundColor: Colors.white,
              ),
              home: authProvider.isLoading
                  ? const SplashScreen()
                  : authProvider.isAuthenticated
                      ? const MainScreen()
                      : const LoginScreen(),
            );
          },
        ),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo aplikasi
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.school_rounded,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            
            // Judul aplikasi
            Text(
              'Aplikasi Absensi',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class InitializerWidget extends StatefulWidget {
  final Widget child;

  const InitializerWidget({Key? key, required this.child}) : super(key: key);

  @override
  State<InitializerWidget> createState() => _InitializerWidgetState();
}

class _InitializerWidgetState extends State<InitializerWidget> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Menginisialisasi authProvider di initState, bukan di build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).initialize();
    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh token saat aplikasi dibuka kembali
      if (mounted) {
        final apiService = Provider.of<AuthProvider>(context, listen: false);
        apiService.refreshUserState();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// Tambahkan AdminMainScreen
class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({Key? key}) : super(key: key);
  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _selectedIndex = 0;
  static const List<Widget> _pages = [
    AbsensiAdminScreen(),
    DashboardAdminScreen(),
    ManajemenGuruScreen(),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.checklist), label: 'Absensi'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Manajemen Guru'),
        ],
      ),
    );
  }
}
