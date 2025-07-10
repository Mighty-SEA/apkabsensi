import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

void main() {
  // Inisialisasi locale untuk bahasa Indonesia
  initializeDateFormatting('id_ID', null).then((_) {
    Intl.defaultLocale = 'id_ID';
    runApp(const MyApp());
  });
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
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
                useMaterial3: true,
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              home: authProvider.isLoading
                  ? const Scaffold(
                      body: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
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

class InitializerWidget extends StatefulWidget {
  final Widget child;

  const InitializerWidget({Key? key, required this.child}) : super(key: key);

  @override
  State<InitializerWidget> createState() => _InitializerWidgetState();
}

class _InitializerWidgetState extends State<InitializerWidget> {
  @override
  void initState() {
    super.initState();
    // Menginisialisasi authProvider di initState, bukan di build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
