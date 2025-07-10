import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/guru_model.dart';
import '../models/absensi_model.dart';
import '../utils/api_mock.dart';

class ApiService {
  // Ganti dengan URL API Anda
  // Gunakan 10.0.2.2 untuk emulator Android (localhost dari emulator)
  // Gunakan localhost atau IP komputer Anda untuk perangkat fisik
  static const String baseUrl = 'http://192.168.12.99:3000/api'; // atau http://localhost:3000/api atau IP lainnya
  
  // Flag untuk menggunakan mock data jika server tidak tersedia
  static const bool useMockData = true;
  
  // Endpoint untuk autentikasi
  static const String loginEndpoint = '/auth/login';
  static const String testTokenEndpoint = '/test-token';
  static const String guruEndpoint = '/guru';
  static const String absensiEndpoint = '/absensi';

  // Menyimpan token ke SharedPreferences
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  // Mengambil token dari SharedPreferences
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Menyimpan data user ke SharedPreferences
  Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user.toJson()));
  }

  // Mengambil data user dari SharedPreferences
  Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      return User.fromJson(jsonDecode(userStr));
    }
    return null;
  }

  // Menghapus token dan data user (logout)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
  }

  // Login
  Future<Map<String, dynamic>> login(String username, String password) async {
    // Menggunakan mock data jika flag useMockData diaktifkan
    if (useMockData) {
      final mockResponse = ApiMock.mockLoginResponse(username: username, password: password);
      
      if (mockResponse['success']) {
        final data = mockResponse['data'];
        // Simpan token
        await saveToken(data['token']);
        
        // Buat objek User dan simpan
        final user = User(
          id: data['id'] ?? '',
          username: username,
          token: data['token'],
          role: data['role'] ?? 'user',
          name: data['name'],
        );
        await saveUser(user);
      }
      
      return mockResponse;
    }

    // Menggunakan API jika tidak menggunakan mock data
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$loginEndpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        if (responseData['token'] != null) {
          // Simpan token
          await saveToken(responseData['token']);
          
          // Buat objek User dan simpan
          final user = User(
            id: responseData['id'] ?? '',
            username: username,
            token: responseData['token'],
            role: responseData['role'] ?? 'user',
            name: responseData['name'],
          );
          await saveUser(user);
        }
        return {'success': true, 'data': responseData};
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Login gagal',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // Fungsi untuk mendapatkan data dengan token
  Future<Map<String, dynamic>> fetchWithToken(String endpoint) async {
    // Memeriksa token terlebih dahulu
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'Token tidak tersedia'};
    }

    // Menggunakan mock data jika flag useMockData diaktifkan
    if (useMockData) {
      switch (endpoint) {
        case guruEndpoint:
          return ApiMock.mockGuruData();
        case absensiEndpoint:
          return ApiMock.mockAbsensiData();
        case testTokenEndpoint:
          return ApiMock.mockTestToken();
        default:
          return {'success': false, 'message': 'Endpoint tidak tersedia di mock data'};
      }
    }

    // Menggunakan API jika tidak menggunakan mock data
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData};
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Permintaan gagal',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // Fungsi untuk mengirim data dengan token (POST)
  Future<Map<String, dynamic>> postWithToken(String endpoint, Map<String, dynamic> data) async {
    // Memeriksa token terlebih dahulu
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'Token tidak tersedia'};
    }

    // Menggunakan mock data jika flag useMockData diaktifkan
    if (useMockData) {
      if (endpoint == absensiEndpoint) {
        return ApiMock.mockCreateAbsensi(data);
      } else {
        return {'success': false, 'message': 'Endpoint tidak tersedia di mock data'};
      }
    }

    // Menggunakan API jika tidak menggunakan mock data
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': responseData};
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Permintaan gagal',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // Fungsi untuk mengupdate data dengan token (PUT)
  Future<Map<String, dynamic>> putWithToken(String endpoint, Map<String, dynamic> data) async {
    // Memeriksa token terlebih dahulu
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'Token tidak tersedia'};
    }

    // Menggunakan mock data jika flag useMockData diaktifkan
    if (useMockData) {
      // Mengembalikan respons sukses untuk semua update di mock mode
      return {'success': true, 'data': data};
    }

    // Menggunakan API jika tidak menggunakan mock data
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData};
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Permintaan gagal',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // Mendapatkan data guru
  Future<Map<String, dynamic>> getGuruData() async {
    return fetchWithToken(guruEndpoint);
  }

  // Verifikasi token
  Future<Map<String, dynamic>> testToken() async {
    return fetchWithToken(testTokenEndpoint);
  }

  // Mendapatkan data absensi
  Future<Map<String, dynamic>> getAbsensiData() async {
    return fetchWithToken(absensiEndpoint);
  }

  // Tambah absensi baru
  Future<Map<String, dynamic>> createAbsensi(Map<String, dynamic> absensiData) async {
    return postWithToken(absensiEndpoint, absensiData);
  }

  // Update absensi (misalnya untuk checkout)
  Future<Map<String, dynamic>> updateAbsensi(String absensiId, Map<String, dynamic> absensiData) async {
    return putWithToken('$absensiEndpoint/$absensiId', absensiData);
  }
} 