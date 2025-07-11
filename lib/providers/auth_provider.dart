import 'package:flutter/material.dart';
import 'dart:async';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  User? _user;
  bool _isLoading = false;
  bool _isLoginLoading = false; // Loading khusus untuk login
  String _errorMessage = '';
  Timer? _refreshTimer;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoginLoading => _isLoginLoading; // Getter untuk login loading
  bool get isAuthenticated => _user != null;
  String get errorMessage => _errorMessage;

  // Inisialisasi provider
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Cek apakah user sudah login sebelumnya
      _user = await _apiService.getUser();
      
      // Jika user ada, verifikasi token
      if (_user != null) {
        final result = await _apiService.testToken();
        if (!result['success']) {
          // Token tidak valid, logout
          await logout();
        } else {
          // Token valid, mulai timer untuk refresh token secara periodik
          _startRefreshTimer();
        }
      }
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan saat inisialisasi: $e';
      await logout();
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  // Memulai timer untuk refresh token secara periodik
  void _startRefreshTimer() {
    // Batalkan timer sebelumnya jika ada
    _refreshTimer?.cancel();
    
    // Set timer untuk refresh token setiap 15 menit
    _refreshTimer = Timer.periodic(const Duration(minutes: 15), (timer) async {
      if (_user != null) {
        await _apiService.refreshToken();
      } else {
        timer.cancel();
      }
    });
  }
  
  // Refresh user state
  Future<void> refreshUserState() async {
    if (_user != null) {
      final result = await _apiService.testToken();
      if (!result['success']) {
        // Token tidak valid, coba refresh
        final refreshed = await _apiService.refreshToken();
        if (!refreshed) {
          // Jika refresh gagal, logout
          await logout();
        }
      }
    }
  }

  // Login
  Future<bool> login(String username, String password) async {
    _isLoginLoading = true; // Gunakan loading khusus untuk login
    _errorMessage = '';
    notifyListeners();
    
    try {
      final result = await _apiService.login(username, password);
      
      if (result['success']) {
        _user = await _apiService.getUser();
        // Mulai timer untuk refresh token secara periodik
        _startRefreshTimer();
        _isLoginLoading = false; // Reset loading login
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        print('Login error: $_errorMessage'); // Debug log
        _isLoginLoading = false; // Reset loading login
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan saat login: $e';
      _isLoginLoading = false; // Reset loading login
      notifyListeners();
      return false;
    }
  }
  
  // Memeriksa koneksi ke server
  Future<Map<String, dynamic>> checkServerConnection() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final result = await _apiService.checkServerConnection();
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan saat memeriksa koneksi: $e';
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': _errorMessage};
    }
  }

  // Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    // Batalkan timer refresh token
    _refreshTimer?.cancel();
    _refreshTimer = null;
    
    await _apiService.logout();
    _user = null;
    
    _isLoading = false;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
} 