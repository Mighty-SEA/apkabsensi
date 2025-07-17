import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String _errorMessage = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isServerOnline = false;
  String _serverStatus = 'Memeriksa status server...';
  bool _isCheckingServer = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    
    // Periksa status server saat halaman dibuka
    _checkServerStatus();
  }
  
  // Fungsi untuk memeriksa status server
  Future<void> _checkServerStatus() async {
    if (_isCheckingServer) return;
    
    setState(() {
      _isCheckingServer = true;
      _serverStatus = 'Memeriksa status server...';
    });
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.checkServerConnection();
    
    setState(() {
      _isServerOnline = result['success'];
      _serverStatus = result['message'];
      _isCheckingServer = false;
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      setState(() {
        _errorMessage = '';
      });
      final success = await authProvider.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );
      if (success && mounted) {
        setState(() {
          _errorMessage = '';
        });
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const MainScreen(),
            transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 250),
          ),
        );
      } else if (mounted) {
        setState(() {
          _errorMessage = authProvider.errorMessage;
        });
        if (!_errorMessage.contains('Username atau password salah')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorMessage),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(12),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  void _clearError() {
    setState(() {
      _errorMessage = '';
    });
  }

  // Fungsi ini tidak digunakan lagi - kita menggunakan _checkServerStatus sebagai gantinya

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final isLoginError = _errorMessage.contains('Username atau password salah');
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Stack(
            children: [
              const _LoginBackground(),
              Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: _LoginForm(
                          formKey: _formKey,
                          usernameController: _usernameController,
                          passwordController: _passwordController,
                          obscurePassword: _obscurePassword,
                          onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                          isLoginError: isLoginError,
                          errorMessage: _errorMessage,
                          clearError: _clearError,
                          isServerOnline: _isServerOnline,
                          serverStatus: _serverStatus,
                          isCheckingServer: _isCheckingServer,
                          onCheckServer: _checkServerStatus,
                          loginButton: Consumer<AuthProvider>(
                            builder: (context, auth, child) {
                              return SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: auth.isLoginLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: auth.isLoginLoading
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Text(
                                              'Memproses...',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Text(
                                          'MASUK',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned(
          top: -size.width * 0.3,
          right: -size.width * 0.3,
          child: const RepaintBoundary(
            child: _CircleBackground(radius: 0.8, colorKey: 'primary'),
          ),
        ),
        Positioned(
          bottom: -size.width * 0.4,
          left: -size.width * 0.2,
          child: const RepaintBoundary(
            child: _CircleBackground(radius: 0.7, colorKey: 'secondary'),
          ),
        ),
      ],
    );
  }
}

class _CircleBackground extends StatelessWidget {
  final double radius;
  final String colorKey;
  const _CircleBackground({required this.radius, required this.colorKey});
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final color = colorKey == 'primary'
        ? theme.colorScheme.primary.withOpacity(0.1)
        : theme.colorScheme.secondary.withOpacity(0.1);
    return Container(
      width: size.width * radius,
      height: size.width * radius,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ServerStatusIndicator extends StatelessWidget {
  final bool isOnline;
  final String statusMessage;
  final bool isChecking;
  final VoidCallback onRefresh;

  const _ServerStatusIndicator({
    required this.isOnline,
    required this.statusMessage,
    required this.isChecking,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Color statusColor = isOnline ? Colors.green : Colors.red;
    IconData statusIcon = isOnline ? Icons.check_circle : Icons.error_outline;
    
    if (isChecking) {
      statusColor = Colors.orange;
      statusIcon = Icons.sync;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          if (isChecking)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            )
          else
            Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusMessage,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: isChecking ? null : onRefresh,
            color: statusColor,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final bool isLoginError;
  final String errorMessage;
  final VoidCallback clearError;
  final Widget loginButton;
  final bool isServerOnline;
  final String serverStatus;
  final bool isCheckingServer;
  final VoidCallback onCheckServer;
  const _LoginForm({
    required this.formKey,
    required this.usernameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.isLoginError,
    required this.errorMessage,
    required this.clearError,
    required this.loginButton,
    required this.isServerOnline,
    required this.serverStatus,
    required this.isCheckingServer,
    required this.onCheckServer,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo
          const Hero(
            tag: 'app_logo',
            child: RepaintBoundary(
              child: _LogoWidget(),
            ),
          ),
          const SizedBox(height: 24),
          // Judul
          const Hero(
            tag: 'app_title',
            child: Material(
              color: Colors.transparent,
              child: Text(
                'Aplikasi Absensi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4361EE),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Masuk untuk melanjutkan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6C757D),
            ),
          ),
          const SizedBox(height: 32),
          // Username
          TextFormField(
            controller: usernameController,
            decoration: InputDecoration(
              labelText: 'Username',
              hintText: 'Masukkan username Anda',
              prefixIcon: const Icon(Icons.person_rounded),
              enabledBorder: isLoginError
                  ? OutlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.error, width: 1.5),
                    )
                  : null,
              focusedBorder: isLoginError
                  ? OutlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
                    )
                  : null,
            ),
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.text,
            autocorrect: false,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Username tidak boleh kosong';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          // Password
          TextFormField(
            controller: passwordController,
            obscureText: obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Masukkan password Anda',
              prefixIcon: const Icon(Icons.lock_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
                onPressed: onTogglePassword,
              ),
              enabledBorder: isLoginError
                  ? OutlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.error, width: 1.5),
                    )
                  : null,
              focusedBorder: isLoginError
                  ? OutlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
                    )
                  : null,
            ),
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.visiblePassword,
            onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password tidak boleh kosong';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          // Tombol login
          loginButton,
          // Pesan error SELALU di bawah tombol login
          if (errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.08),
                  border: Border.all(color: theme.colorScheme.error, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isLoginError ? Icons.person_off_rounded : Icons.error_outline_rounded,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLoginError ? 'Login Gagal' : 'Error',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            errorMessage,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                            ),
                          ),
                          if (isLoginError)
                            const Padding(
                              padding: EdgeInsets.only(top: 4.0),
                              child: Text(
                                'Pastikan username dan password benar.',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  fontSize: 13,
                                  color: Color(0xFFE63946),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      color: theme.colorScheme.error,
                      tooltip: 'Tutup',
                      onPressed: clearError,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          // Status Server
          _ServerStatusIndicator(
            isOnline: isServerOnline,
            statusMessage: serverStatus,
            isChecking: isCheckingServer,
            onRefresh: onCheckServer,
          ),
          const SizedBox(height: 16),
          // Bantuan
          Center(
            child: TextButton.icon(
              onPressed: onCheckServer,
              icon: const Icon(Icons.wifi_rounded),
              label: const Text('Periksa Koneksi Server'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoWidget extends StatelessWidget {
  const _LogoWidget();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Icon(
      Icons.school_rounded,
      size: 80,
      color: theme.colorScheme.primary,
    );
  }
} 