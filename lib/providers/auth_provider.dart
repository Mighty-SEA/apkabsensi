import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  User? _user;
  bool _isLoading = false;
  String _errorMessage = '';

  User? get user => _user;
  bool get isLoading => _isLoading;
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
        }
      }
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan saat inisialisasi: $e';
      await logout();
    }
    
    _isLoading = false;
    notifyListeners();
  }

  // Login
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    
    try {
      final result = await _apiService.login(username, password);
      
      if (result['success']) {
        _user = await _apiService.getUser();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan saat login: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    await _apiService.logout();
    _user = null;
    
    _isLoading = false;
    notifyListeners();
  }
} 