import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'main_screen.dart';
import 'package:another_flushbar/flushbar.dart';
import 'dart:async';
import '../services/api_service.dart';

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
  DateTime? _rateLimitStart;
  Duration _rateLimitDuration = const Duration(minutes: 15);
  Timer? _countdownTimer;
  int _secondsLeft = 0;
  // Tambahan untuk status server
  bool? _serverOk;
  bool _loadingServer = false;
  String _serverMsg = '';
  // Tambahkan variabel untuk animasi kedip
  Timer? _blinkTimer;
  double _circleOpacity = 1.0;

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
    _checkApiStatus();
    _startBlinking();
  }

  void _startBlinking() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      setState(() {
        _circleOpacity = _circleOpacity == 1.0 ? 0.3 : 1.0;
      });
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    _countdownTimer?.cancel();
    _blinkTimer?.cancel();
    super.dispose();
  }

  void _startRateLimitCountdown() {
    setState(() {
      _rateLimitStart = DateTime.now();
      _secondsLeft = _rateLimitDuration.inSeconds;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final elapsed = DateTime.now().difference(_rateLimitStart!);
      final left = _rateLimitDuration - elapsed;
      if (left.isNegative) {
        timer.cancel();
        setState(() {
          _rateLimitStart = null;
          _secondsLeft = 0;
        });
      } else {
        setState(() {
          _secondsLeft = left.inSeconds;
        });
      }
    });
  }

  void _login() async {
    if (_formKey.currentState!.validate() && _rateLimitStart == null) {
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
        if (_errorMessage.contains('Terlalu banyak percobaan login')) {
          _startRateLimitCountdown();
        }
        if (!_errorMessage.contains('Username atau password salah')) {
          Flushbar(
            message: _errorMessage,
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
            flushbarPosition: FlushbarPosition.TOP,
            borderRadius: BorderRadius.circular(12),
            margin: const EdgeInsets.all(16),
            icon: const Icon(Icons.error, color: Colors.white),
            shouldIconPulse: false,
            isDismissible: true,
            forwardAnimationCurve: Curves.easeOutBack,
            reverseAnimationCurve: Curves.easeInBack,
          )..show(context);
        }
      }
    }
  }

  void _clearError() {
    setState(() {
      _errorMessage = '';
    });
  }

  // Fungsi helper untuk mencoba terhubung ke server dan cek URL
  void _checkServerConnection() async {
    setState(() {
      _errorMessage = 'Memeriksa koneksi ke server...';
    });
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.checkServerConnection();
    
    setState(() {
      if (result['success']) {
        _errorMessage = 'Koneksi ke server berhasil! Silakan coba login.';
      } else {
        _errorMessage = result['message'];
      }
    });
  }

  Future<void> _checkApiStatus() async {
    setState(() {
      _loadingServer = true;
    });
    final result = await ApiService().checkApiStatus();
    setState(() {
      _loadingServer = false;
      if (result['success'] == true) {
        _serverOk = true;
        _serverMsg = 'server status ok';
      } else if (result['message'] == 'Tidak ada koneksi internet') {
        _serverOk = null;
        _serverMsg = 'tidak ada koneksi internet';
      } else {
        _serverOk = false;
        _serverMsg = 'kesalahan server';
      }
    });
  }

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
              // Indikator status server di pojok kiri atas
              Positioned(
                top: 16,
                left: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _loadingServer
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: _circleOpacity,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: _serverOk == true
                                        ? Colors.green
                                        : _serverOk == null
                                            ? Colors.orange
                                            : Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                        const SizedBox(width: 8),
                        Text(
                          _serverOk == true
                              ? 'server status ok'
                              : _serverOk == null
                                  ? 'tidak ada koneksi internet'
                                  : 'kesalahan server',
                          style: TextStyle(
                            color: _serverOk == true
                                ? Colors.green
                                : _serverOk == null
                                    ? Colors.orange
                                    : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
              Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            const Hero(
                              tag: 'app_logo',
                              child: RepaintBoundary(
                                child: _LogoWidget(),
                              ),
                            ),
                            const SizedBox(height: 24),
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
                            Text(
                              _serverOk == null
                                  ? 'Perangkat Anda tidak terhubung ke internet.\nPastikan Wi-Fi atau data seluler aktif dan stabil.'
                                  : _serverOk == false
                                      ? 'Kami tidak dapat terhubung ke server saat ini.\nSilakan coba lagi beberapa saat lagi.'
                                      : 'Masuk untuk melanjutkan',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF6C757D),
                              ),
                            ),
                            const SizedBox(height: 32),
                            if (_serverOk == true) ...[
                              _LoginForm(
                                formKey: _formKey,
                                usernameController: _usernameController,
                                passwordController: _passwordController,
                                obscurePassword: _obscurePassword,
                                onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                                isLoginError: isLoginError,
                                errorMessage: _errorMessage,
                                clearError: _clearError,
                                loginButton: Consumer<AuthProvider>(
                                  builder: (context, auth, child) {
                                    return SizedBox(
                                      height: 48,
                                      child: ElevatedButton(
                                        onPressed: (auth.isLoginLoading || _rateLimitStart != null) ? null : _login,
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
                              if (_rateLimitStart != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16.0),
                                  child: Text(
                                    'Coba login lagi dalam ${_secondsLeft ~/ 60}:${(_secondsLeft % 60).toString().padLeft(2, '0')}',
                                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(top: 20.0),
                                child: TextButton.icon(
                                  onPressed: _loadingServer ? null : _checkApiStatus,
                                  icon: const Icon(Icons.refresh, color: Colors.blue),
                                  label: const Text(
                                    'Cek Koneksi',
                                    style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton.icon(
                                  onPressed: _loadingServer ? null : _checkApiStatus,
                                  icon: const Icon(Icons.refresh, size: 28, color: Colors.white),
                                  label: const Text(
                                    'Cek Koneksi',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(56),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
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
            autofillHints: const [AutofillHints.username],
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
            autofillHints: const [AutofillHints.password],
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