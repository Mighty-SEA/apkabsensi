import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';
import '../models/user_model.dart';
import '../models/guru_model.dart';
import '../models/absensi_model.dart';
import '../utils/api_mock.dart';
import 'package:intl/intl.dart';

class ApiService {
  // Ganti dengan URL API Anda
  // Gunakan 10.0.2.2 untuk emulator Android (localhost dari emulator)
  // Gunakan 192.168.x.x atau alamat IP komputer Anda untuk perangkat fisik
  static const String baseUrl = 'https://absensi.mdtbilal.sch.id/api';
  
  // Flag untuk menggunakan mock data jika server tidak tersedia
  static const bool useMockData = false;
  
  // Endpoint untuk autentikasi
  static const String loginEndpoint = '/auth/login';
  static const String refreshTokenEndpoint = '/auth/refresh';
  static const String testTokenEndpoint = '/test-token';
  static const String guruEndpoint = '/guru';
  static const String absensiEndpoint = '/absensi';

  // Timeout dan jumlah retry
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const int _maxRetries = 3;

  // Cache storage
  final Map<String, _CachedResponse> _cache = {};
  
  // Optimasi HTTP client dengan connection pooling
  final http.Client _client = http.Client();
  
  // Logger
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: true,
      printTime: false,
    ),
  );

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();
  
  // Dispose resources when app is closed
  void dispose() {
    _client.close();
  }

  // Mengoptimalkan cache untuk mengurangi network calls
  bool isCacheValid(String endpoint) {
    return _cache.containsKey(endpoint) && !_cache[endpoint]!.isExpired();
  }
  
  void updateCache(String endpoint, Map<String, dynamic> data, {Duration? validity}) {
    _cache[endpoint] = _CachedResponse(
      data, 
      validity != null ? DateTime.now().add(validity) : DateTime.now().add(const Duration(minutes: 5))
    );
  }

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
    // Bersihkan cache saat logout
    _cache.clear();
  }

  // Cek konektivitas - optimized with memory caching
  DateTime? _lastConnectivityCheck;
  bool? _lastConnectivityResult;
  
  Future<bool> hasInternetConnection() async {
    // Cache konektivitas untuk 3 detik
    if (_lastConnectivityCheck != null && 
        _lastConnectivityResult != null && 
        DateTime.now().difference(_lastConnectivityCheck!) < const Duration(seconds: 3)) {
      return _lastConnectivityResult!;
    }
    
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _lastConnectivityCheck = DateTime.now();
        _lastConnectivityResult = false;
        return false;
      }
      
      // Tambahan pengecekan dengan ping ke DNS Google
      final result = await InternetAddress.lookup('google.com');
      final hasConnection = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
      _lastConnectivityCheck = DateTime.now();
      _lastConnectivityResult = hasConnection;
      
      return hasConnection;
    } on SocketException catch (_) {
      _lastConnectivityCheck = DateTime.now();
      _lastConnectivityResult = false;
      return false;
    } catch (e) {
      _logger.e('Error checking internet connection: $e');
      _lastConnectivityCheck = DateTime.now();
      _lastConnectivityResult = false;
      return false;
    }
  }

  // Refresh token
  Future<bool> refreshToken() async {
    try {
      final currentToken = await getToken();
      if (currentToken == null) return false;
      
      final response = await _client.post(
        Uri.parse('$baseUrl$refreshTokenEndpoint'),
        headers: {
          'Authorization': 'Bearer $currentToken',
          'Content-Type': 'application/json',
        },
      ).timeout(_requestTimeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) {
          await saveToken(data['token']);
          return true;
        }
      }
      return false;
    } catch (e) {
      _logger.e('Error refreshing token: $e');
      return false;
    }
  }

  // Memeriksa koneksi server
  Future<Map<String, dynamic>> checkServerConnection() async {
    if (!await hasInternetConnection()) {
      return {'success': false, 'message': 'Tidak ada koneksi internet'};
    }
    
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/test-token'),
      ).timeout(_requestTimeout);
      
      return {
        'success': response.statusCode >= 200 && response.statusCode < 300,
        'message': response.statusCode >= 200 && response.statusCode < 300 
            ? 'Koneksi ke server berhasil' 
            : 'Koneksi ke server gagal dengan kode ${response.statusCode}'
      };
    } catch (e) {
      _logger.e('Error checking server connection: $e');
      String errorMessage = 'Tidak dapat terhubung ke server';
      if (e is SocketException) {
        errorMessage = 'Server tidak dapat dijangkau. Periksa alamat dan port server.';
      } else if (e is TimeoutException) {
        errorMessage = 'Koneksi ke server timeout. Server mungkin lambat atau tidak responsif.';
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  // Login
  Future<Map<String, dynamic>> login(String username, String password) async {
    if (!await hasInternetConnection()) {
      return {'success': false, 'message': 'Tidak ada koneksi internet'};
    }

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
          guruId: data['guruId']?.toString(),
        );
        await saveUser(user);
      }
      
      return mockResponse;
    }

    // Menggunakan API jika tidak menggunakan mock data
    try {
      _logger.i('Trying login for user: $username');
      
      final response = await _client.post(
        Uri.parse('$baseUrl$loginEndpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(_requestTimeout);

      _logger.d('Login response status: ${response.statusCode}');
      
      final Map<String, dynamic> responseData;
      try {
        responseData = jsonDecode(response.body);
      } catch (e) {
        _logger.e('Error parsing JSON: $e');
        return {'success': false, 'message': 'Format respons tidak valid'};
      }
      
      if (response.statusCode == 200) {
        if (responseData['token'] != null) {
          // Simpan token
          await saveToken(responseData['token']);
          
          // Buat objek User dan simpan
          final userData = responseData['user'] ?? responseData;
          final user = User(
            id: (userData['id'] ?? '').toString(),
            username: username,
            token: responseData['token'],
            role: userData['role'] ?? 'user',
            name: userData['name'],
            guruId: userData['guruId']?.toString() ?? userData['guru']?['id']?.toString(),
          );
          await saveUser(user);
          
          // Bersihkan cache setelah login berhasil
          _cache.clear();
          
          return {'success': true, 'data': responseData};
        } else {
          return {'success': false, 'message': 'Token tidak ditemukan dalam respons'};
        }
      } else {
        final errorMsg = responseData['error'] ?? responseData['message'] ?? 'Login gagal (${response.statusCode})';
        
        // Berikan pesan yang lebih spesifik untuk error 401 (Unauthorized)
        if (response.statusCode == 401) {
          return {'success': false, 'message': 'Username atau password salah. Silakan coba lagi.'};
        }
        
        return {'success': false, 'message': errorMsg};
      }
    } catch (e) {
      _logger.e('Error during login: $e');
      String errorDetail = e.toString();
      if (e is SocketException) {
        return {'success': false, 'message': 'Tidak dapat terhubung ke server. Pastikan server berjalan dan URL API benar.'};
      } else if (e is TimeoutException) {
        return {'success': false, 'message': 'Koneksi timeout. Server mungkin lambat atau tidak responsif.'};
      } else {
        return {'success': false, 'message': 'Terjadi kesalahan: $errorDetail'};
      }
    }
  }

  // Verifikasi token masih valid
  Future<Map<String, dynamic>> testToken() async {
    return await _fetchWithRetry(testTokenEndpoint, useCache: false);
  }

  // Fungsi untuk mendapatkan data dengan token dan retry
  Future<Map<String, dynamic>> _fetchWithRetry(
    String endpoint, {
    bool useCache = true,
    Duration cacheDuration = const Duration(minutes: 5),
    int retryCount = 0,
  }) async {
    // Memeriksa koneksi internet
    if (!await hasInternetConnection()) {
      // Jika tidak ada koneksi internet, coba ambil dari cache
      if (useCache && _cache.containsKey(endpoint)) {
        final cachedResponse = _cache[endpoint]!;
        if (!cachedResponse.isExpired()) {
          _logger.i('Using cached data for $endpoint (no internet)');
          return cachedResponse.data;
        }
      }
      return {'success': false, 'message': 'Tidak ada koneksi internet'};
    }
    
    // Memeriksa token terlebih dahulu
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'Token tidak tersedia'};
    }

    // Cek cache jika diaktifkan
    if (useCache && _cache.containsKey(endpoint)) {
      final cachedResponse = _cache[endpoint]!;
      if (!cachedResponse.isExpired()) {
        _logger.i('Using cached data for $endpoint');
        return cachedResponse.data;
      }
    }

    // Menggunakan mock data jika flag useMockData diaktifkan
    if (useMockData) {
      Map<String, dynamic> mockResponse;
      switch (endpoint) {
        case guruEndpoint:
          mockResponse = ApiMock.mockGuruData();
          break;
        case absensiEndpoint:
          mockResponse = ApiMock.mockAbsensiData();
          break;
        case testTokenEndpoint:
          mockResponse = ApiMock.mockTestToken();
          break;
        default:
          mockResponse = {'success': false, 'message': 'Endpoint tidak tersedia di mock data'};
      }
      
      if (useCache && mockResponse['success']) {
        _cache[endpoint] = _CachedResponse(
          mockResponse,
          DateTime.now().add(cacheDuration),
        );
      }
      return mockResponse;
    }

    // Menggunakan API jika tidak menggunakan mock data
    try {
      _logger.d('Fetching from $endpoint');
      final response = await _client.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(_requestTimeout);

      Map<String, dynamic> responseData;
      try {
        responseData = jsonDecode(response.body);
      } catch (e) {
        _logger.e('Error parsing JSON for $endpoint: $e');
        return {'success': false, 'message': 'Format respons tidak valid'};
      }
      
      if (response.statusCode == 200) {
        final result = {'success': true, 'data': responseData};
        
        // Simpan hasil ke cache jika perlu
        if (useCache) {
          _cache[endpoint] = _CachedResponse(
            result,
            DateTime.now().add(cacheDuration),
          );
        }
        
        return result;
      } else if (response.statusCode == 401 && retryCount < _maxRetries) {
        // Token mungkin kedaluwarsa, coba refresh dan coba lagi
        _logger.w('Token expired, trying to refresh...');
        if (await refreshToken()) {
          return _fetchWithRetry(
            endpoint,
            useCache: useCache,
            cacheDuration: cacheDuration,
            retryCount: retryCount + 1,
          );
        } else {
          return {'success': false, 'message': 'Token tidak valid dan tidak dapat diperbarui'};
        }
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Permintaan gagal (${response.statusCode})',
        };
      }
    } catch (e) {
      _logger.e('Error fetching from $endpoint: $e');
      // Coba ambil dari cache jika ada error dan cache tersedia
      if (useCache && _cache.containsKey(endpoint)) {
        _logger.w('Using cached data due to error');
        return _cache[endpoint]!.data;
      }
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // Wrapper untuk fetchWithToken yang memanggil _fetchWithRetry
  Future<Map<String, dynamic>> fetchWithToken(
    String endpoint, {
    bool useCache = true,
    Duration cacheDuration = const Duration(minutes: 5),
  }) async {
    return _fetchWithRetry(endpoint, useCache: useCache, cacheDuration: cacheDuration);
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
      final response = await _client.post(
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
      final response = await _client.put(
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
    try {
      if (!await hasInternetConnection()) {
        return {'success': false, 'message': 'Tidak ada koneksi internet'};
      }

      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Token tidak ditemukan'};
      }

      print('Mengambil data guru dari: $baseUrl$guruEndpoint');
      
      final response = await _client.get(
        Uri.parse('$baseUrl$guruEndpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(_requestTimeout);

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['guru'] ?? []};
      } else {
        return {
          'success': false,
          'message': 'Gagal mengambil data guru: ${response.statusCode}',
        };
      }
    } catch (e) {
      _logger.e('Error fetching guru data: $e');
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // Menambahkan guru baru (beserta user)
  Future<Map<String, dynamic>> createGuru(Map<String, dynamic> guruData) async {
    try {
      if (!await hasInternetConnection()) {
        return {'success': false, 'message': 'Tidak ada koneksi internet'};
      }

      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Token tidak ditemukan'};
      }

      // Pastikan ada username dan password untuk user
      if (!guruData.containsKey('username') || !guruData.containsKey('password')) {
        return {'success': false, 'message': 'Username dan password diperlukan untuk membuat akun'};
      }

      print('Mengirim data guru ke: $baseUrl$guruEndpoint');
      print('Data guru: $guruData');
      
      final dataToSend = {
        'nip': guruData['nip'],
        'nama': guruData['nama'],
        'jenisKelamin': guruData['jenisKelamin'] ?? 'Laki-laki',
        'alamat': guruData['alamat'] ?? '',
        'noTelp': guruData['noTelp'] ?? '',
        'email': guruData['email'] ?? '',
        'mataPelajaran': guruData['mataPelajaran'] ?? '',
        'user': {
          'username': guruData['username'],
          'password': guruData['password'],
          'role': 'GURU'
        }
      };
      
      final response = await _client.post(
        Uri.parse('$baseUrl$guruEndpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(dataToSend),
      ).timeout(_requestTimeout);

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true, 
          'data': responseData['guru'],
          'message': 'Guru berhasil ditambahkan'
        };
      } else {
        final errorMessage = responseData['error'] ?? 
                           responseData['message'] ?? 
                           'Gagal menambahkan guru: ${response.statusCode}';
        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } catch (e) {
      _logger.e('Error creating guru: $e');
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // Memperbarui data guru
  Future<Map<String, dynamic>> updateGuru(String guruId, Map<String, dynamic> guruData) async {
    try {
      if (!await hasInternetConnection()) {
        return {'success': false, 'message': 'Tidak ada koneksi internet'};
      }

      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Token tidak ditemukan'};
      }

      print('Memperbarui data guru: $baseUrl$guruEndpoint/$guruId');
      print('Data update: $guruData');
      
      // Data yang akan dikirim (hanya field yang diizinkan)
      final dataToSend = {
        'nip': guruData['nip'],
        'nama': guruData['nama'],
        'jenisKelamin': guruData['jenisKelamin'],
        'alamat': guruData['alamat'],
        'noTelp': guruData['noTelp'],
        'email': guruData['email'],
        'mataPelajaran': guruData['mataPelajaran'],
      };
      
      // Hapus field null atau undefined
      dataToSend.removeWhere((key, value) => value == null);
      
      final response = await _client.put(
        Uri.parse('$baseUrl$guruEndpoint/$guruId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(dataToSend),
      ).timeout(_requestTimeout);

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true, 
          'data': responseData['guru'],
          'message': 'Data guru berhasil diperbarui'
        };
      } else {
        final errorMessage = responseData['error'] ?? 
                           responseData['message'] ?? 
                           'Gagal memperbarui data guru: ${response.statusCode}';
        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } catch (e) {
      _logger.e('Error updating guru: $e');
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // Menghapus guru
  Future<Map<String, dynamic>> deleteGuru(String guruId) async {
    try {
      if (!await hasInternetConnection()) {
        return {'success': false, 'message': 'Tidak ada koneksi internet'};
      }

      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Token tidak ditemukan'};
      }

      print('Menghapus guru: $baseUrl$guruEndpoint/$guruId');
      
      final response = await _client.delete(
        Uri.parse('$baseUrl$guruEndpoint/$guruId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(_requestTimeout);

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        String message;
        try {
          final responseData = jsonDecode(response.body);
          message = responseData['message'] ?? 'Guru berhasil dihapus';
        } catch (e) {
          message = 'Guru berhasil dihapus';
        }
        
        return {
          'success': true,
          'message': message
        };
      } else {
        String errorMessage;
        try {
          final responseData = jsonDecode(response.body);
          errorMessage = responseData['error'] ?? 
                       responseData['message'] ?? 
                       'Gagal menghapus guru: ${response.statusCode}';
        } catch (e) {
          errorMessage = 'Gagal menghapus guru: ${response.statusCode}';
        }
        
        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } catch (e) {
      _logger.e('Error deleting guru: $e');
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // Mendapatkan data absensi
  Future<Map<String, dynamic>> getAbsensiData({bool useCache = true}) async {
    // Cek cache jika useCache == true
    if (useCache && _cache.containsKey(absensiEndpoint)) {
      final cachedData = _cache[absensiEndpoint];
      if (cachedData != null && !cachedData.isExpired()) {
        return cachedData.data;
      }
    }
    
    // Jika menggunakan mock data
    if (useMockData) {
      return ApiMock.mockAbsensiData();
    }

    // Jika menggunakan API
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Token tidak tersedia'};
      }
      
      final user = await getUser();
      if (user == null) {
        return {'success': false, 'message': 'Data user tidak tersedia'};
      }
      
      // Filter absensi berdasarkan guruId jika role adalah GURU
      String endpoint = absensiEndpoint;
      if (user.role?.toUpperCase() == 'GURU' && user.guruId != null) {
        endpoint += '?guruId=${user.guruId}';
      }
      
      final response = await _client.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        // Backend mengembalikan data dalam format { absensi: [] }
        final absensiList = responseData['absensi'] ?? [];
        
        // Transform data untuk sesuai dengan format yang diharapkan frontend
        final transformedData = absensiList.map((item) {
          // Dapatkan nama guru dari relasi
          String namaGuru = '';
          if (item['guru'] != null) {
            namaGuru = item['guru']['nama'] ?? '';
          }
          
          // Format tanggal dan waktu
          String tanggal = '';
          String jamMasuk = '';
          String jamKeluar = '';
          
          if (item['tanggal'] != null) {
            final date = DateTime.parse(item['tanggal']);
            tanggal = DateFormat('yyyy-MM-dd').format(date);
          }
          
          if (item['jamMasuk'] != null) {
            final masuk = DateTime.parse(item['jamMasuk']);
            jamMasuk = DateFormat('HH:mm:ss').format(masuk);
          }
          
          if (item['jamKeluar'] != null) {
            final keluar = DateTime.parse(item['jamKeluar']);
            jamKeluar = DateFormat('HH:mm:ss').format(keluar);
          }
          
          // Return format yang sesuai dengan yang diharapkan
          return {
            'id': item['id'].toString(),
            'guruId': item['guruId'].toString(),
            'namaGuru': namaGuru,
            'tanggal': tanggal,
            'jamMasuk': jamMasuk,
            'jamKeluar': jamKeluar,
            'status': item['status'].toLowerCase(),
            'keterangan': item['keterangan'] ?? '',
          };
        }).toList();
        
        // Simpan hasil ke cache
        final result = {'success': true, 'data': transformedData};
        _cache[absensiEndpoint] = _CachedResponse(
          result, 
          DateTime.now().add(const Duration(minutes: 5))
        );
        
        return result;
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? 'Gagal memuat data absensi',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // Tambah absensi baru
  Future<Map<String, dynamic>> createAbsensi(Map<String, dynamic> absensiData) async {
    // Jika menggunakan mock data
    if (useMockData) {
      return ApiMock.mockCreateAbsensi(absensiData);
    }

    // Jika menggunakan API
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Token tidak tersedia'};
      }

      print('Mengirim data absensi ke: $baseUrl$absensiEndpoint');
      print('Data absensi: $absensiData');
      
      // Pastikan guruId dalam bentuk integer
      var dataToSend = Map<String, dynamic>.from(absensiData);
      if (dataToSend.containsKey('guruId')) {
        // Jika sudah integer, tetap gunakan nilai asli
        if (dataToSend['guruId'] is int) {
          print('GuruId sudah dalam bentuk integer: ${dataToSend['guruId']}');
        } 
        // Jika string, convert ke integer
        else if (dataToSend['guruId'] is String) {
          try {
            dataToSend['guruId'] = int.parse(dataToSend['guruId']);
            print('GuruId dikonversi ke integer: ${dataToSend['guruId']}');
          } catch (e) {
            print('Error parsing guruId: ${dataToSend['guruId']} - $e');
            return {
              'success': false,
              'message': 'ID Guru tidak valid: ${dataToSend['guruId']}'
            };
          }
        }
      } else {
        print('Data tidak memiliki field guruId!');
        return {
          'success': false,
          'message': 'Data absensi tidak memiliki ID guru'
        };
      }
      
      // Pastikan field wajib lainnya
      if (!dataToSend.containsKey('status') || dataToSend['status'] == null) {
        dataToSend['status'] = 'HADIR';
      }
      
      if (!dataToSend.containsKey('jamMasuk') || dataToSend['jamMasuk'] == null) {
        dataToSend['jamMasuk'] = DateTime.now().toIso8601String();
      }
      
      // Pastikan field opsional memiliki nilai default
      if (!dataToSend.containsKey('keterangan') || dataToSend['keterangan'] == null) {
        dataToSend['keterangan'] = '';
      }
      
      if (!dataToSend.containsKey('longitude') || dataToSend['longitude'] == null) {
        dataToSend['longitude'] = 0.0;
      }
      
      if (!dataToSend.containsKey('latitude') || dataToSend['latitude'] == null) {
        dataToSend['latitude'] = 0.0;
      }
      
      // Format ulang data untuk memastikan konsistensi
      final finalData = {
        'guruId': dataToSend['guruId'],
        'status': dataToSend['status'].toString().toUpperCase(),
        'jamMasuk': dataToSend['jamMasuk'],
        'keterangan': dataToSend['keterangan'],
        'longitude': dataToSend['longitude'],
        'latitude': dataToSend['latitude'],
      };
      
      print('Data akhir yang dikirim: $finalData');

      final response = await _client.post(
        Uri.parse('$baseUrl$absensiEndpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(finalData),
      );

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      try {
        final responseData = jsonDecode(response.body);
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          return {
            'success': true, 
            'data': responseData['absensi'],
            'message': responseData['message'] ?? 'Absensi berhasil ditambahkan'
          };
        } else {
          final errorMessage = responseData['error'] ?? 
                             responseData['message'] ?? 
                             'Gagal menambahkan absensi: ${response.statusCode}';
          return {
            'success': false,
            'message': errorMessage,
          };
        }
      } catch (e) {
        print('Error parsing response: $e');
        return {
          'success': false,
          'message': 'Format respons tidak valid: ${response.body}',
        };
      }
    } catch (e) {
      print('Error saat menambahkan absensi: $e');
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // Update absensi (misalnya untuk checkout)
  Future<Map<String, dynamic>> updateAbsensi(String absensiId, Map<String, dynamic> absensiData) async {
    // Jika menggunakan mock data
    if (useMockData) {
      return {'success': true, 'data': {'message': 'Absensi berhasil diupdate (mock)'}};
    }

    // Jika menggunakan API
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Token tidak tersedia'};
      }

      print('Mengirim update absensi ke: $baseUrl$absensiEndpoint/$absensiId');
      print('Data update: $absensiData');

      // Pastikan format data yang benar
      var dataToSend = Map<String, dynamic>.from(absensiData);
      
      // Pastikan format tanggal yang benar untuk jamKeluar
      if (dataToSend.containsKey('jamKeluar')) {
        if (dataToSend['jamKeluar'] is DateTime) {
          dataToSend['jamKeluar'] = dataToSend['jamKeluar'].toIso8601String();
        } else if (dataToSend['jamKeluar'] is String) {
          // Pastikan string dalam format ISO
          try {
            final date = DateTime.parse(dataToSend['jamKeluar']);
            dataToSend['jamKeluar'] = date.toIso8601String();
          } catch (e) {
            print('Format jamKeluar tidak valid: ${dataToSend['jamKeluar']}');
            // Gunakan waktu saat ini jika format tidak valid
            dataToSend['jamKeluar'] = DateTime.now().toIso8601String();
          }
        } else if (dataToSend['jamKeluar'] == null) {
          // Gunakan waktu saat ini jika null
          dataToSend['jamKeluar'] = DateTime.now().toIso8601String();
        }
      }
      
      print('Data akhir yang dikirim: $dataToSend');

      final response = await _client.put(
        Uri.parse('$baseUrl$absensiEndpoint/$absensiId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(dataToSend),
      );

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      try {
        final responseData = jsonDecode(response.body);
        
        if (response.statusCode == 200) {
          return {
            'success': true, 
            'data': responseData['absensi'],
            'message': responseData['message'] ?? 'Absensi berhasil diupdate'
          };
        } else {
          final errorMessage = responseData['error'] ?? 
                             responseData['message'] ?? 
                             'Gagal mengupdate absensi: ${response.statusCode}';
          return {
            'success': false,
            'message': errorMessage,
          };
        }
      } catch (e) {
        print('Error parsing response: $e');
        return {
          'success': false,
          'message': 'Format respons tidak valid: ${response.body}',
        };
      }
    } catch (e) {
      print('Error saat mengupdate absensi: $e');
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // Mendapatkan rekap absensi bulanan untuk user yang login
  Future<Map<String, dynamic>> getAbsensiMonthlyReport() async {
    try {
      final user = await getUser();
      if (user == null || user.guruId == null) {
        return {'success': false, 'message': 'Data user tidak tersedia'};
      }
      
      // Dapatkan data absensi user
      final absensiResult = await getAbsensiData();
      if (!absensiResult['success']) {
        return absensiResult; // Return error jika gagal mendapatkan data absensi
      }
      
      final absensiList = absensiResult['data'] as List;
      
      // Jika tidak ada data absensi
      if (absensiList.isEmpty) {
        return {
          'success': true,
          'data': {
            'totalHadir': 0,
            'totalIzin': 0,
            'totalSakit': 0,
            'totalAlpa': 0,
            'avgJamMasuk': '00:00',
            'avgJamKeluar': '00:00',
            'absensiPerTanggal': [],
          }
        };
      }
      
      // Filter untuk bulan ini saja
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;
      
      final thisMonthAbsensi = absensiList.where((absen) {
        if (absen['tanggal'] == null) return false;
        
        try {
          final tanggal = DateTime.parse(absen['tanggal']);
          return tanggal.month == currentMonth && tanggal.year == currentYear;
        } catch (e) {
          print('Error parsing tanggal: ${absen['tanggal']} - $e');
          return false;
        }
      }).toList();
      
      // Hitung rekap
      int totalHadir = 0;
      int totalIzin = 0;
      int totalSakit = 0;
      int totalAlpa = 0;
      
      // Untuk menghitung rata-rata jam masuk dan keluar
      List<int> jamMasukMinutes = [];
      List<int> jamKeluarMinutes = [];
      
      for (var absen in thisMonthAbsensi) {
        // Hitung berdasarkan status
        final status = absen['status']?.toLowerCase() ?? '';
        if (status == 'hadir') {
          totalHadir++;
        } else if (status == 'izin') {
          totalIzin++;
        } else if (status == 'sakit') {
          totalSakit++;
        } else if (status == 'alpa') {
          totalAlpa++;
        }
        
        // Hitung rata-rata jam masuk
        if (absen['jamMasuk'] != null && absen['jamMasuk'] != '-') {
          try {
            final parts = absen['jamMasuk'].split(':');
            if (parts.length >= 2) {
              final hour = int.parse(parts[0]);
              final minute = int.parse(parts[1]);
              jamMasukMinutes.add(hour * 60 + minute);
            }
          } catch (e) {
            print('Error parsing jamMasuk: ${absen['jamMasuk']} - $e');
          }
        }
        
        // Hitung rata-rata jam keluar
        if (absen['jamKeluar'] != null && absen['jamKeluar'] != '-') {
          try {
            final parts = absen['jamKeluar'].split(':');
            if (parts.length >= 2) {
              final hour = int.parse(parts[0]);
              final minute = int.parse(parts[1]);
              jamKeluarMinutes.add(hour * 60 + minute);
            }
          } catch (e) {
            print('Error parsing jamKeluar: ${absen['jamKeluar']} - $e');
          }
        }
      }
      
      // Hitung rata-rata jam masuk
      String avgJamMasuk = '00:00';
      if (jamMasukMinutes.isNotEmpty) {
        final totalMinutes = jamMasukMinutes.reduce((a, b) => a + b);
        final avgMinutes = totalMinutes ~/ jamMasukMinutes.length;
        final hours = avgMinutes ~/ 60;
        final minutes = avgMinutes % 60;
        avgJamMasuk = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
      }
      
      // Hitung rata-rata jam keluar
      String avgJamKeluar = '00:00';
      if (jamKeluarMinutes.isNotEmpty) {
        final totalMinutes = jamKeluarMinutes.reduce((a, b) => a + b);
        final avgMinutes = totalMinutes ~/ jamKeluarMinutes.length;
        final hours = avgMinutes ~/ 60;
        final minutes = avgMinutes % 60;
        avgJamKeluar = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
      }
      
      // Kelompokkan absensi per tanggal
      Map<String, Map<String, dynamic>> absensiPerTanggal = {};
      for (var absen in thisMonthAbsensi) {
        final tanggal = absen['tanggal'];
        if (tanggal != null) {
          absensiPerTanggal[tanggal] = absen;
        }
      }
      
      // Buat data rekap
      final rekapData = {
        'totalHadir': totalHadir,
        'totalIzin': totalIzin,
        'totalSakit': totalSakit,
        'totalAlpa': totalAlpa,
        'avgJamMasuk': avgJamMasuk,
        'avgJamKeluar': avgJamKeluar,
        'absensiPerTanggal': absensiPerTanggal.values.toList(),
      };
      
      return {'success': true, 'data': rekapData};
    } catch (e) {
      print('Error saat mendapatkan rekap absensi: $e');
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // Rekap bulanan semua guru untuk dashboard admin
  Future<Map<String, dynamic>> getAbsensiRekapAllGuru() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Token tidak tersedia'};
      }
      final response = await _client.get(
        Uri.parse('$baseUrl/absensi/rekap-all'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data['rekap'] ?? data['data'] ?? data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Gagal memuat rekap'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // Mengambil data absensi hari ini saja
  Future<Map<String, dynamic>> getAbsensiHariIni() async {
    try {
      if (!await hasInternetConnection()) {
        return {'success': false, 'message': 'Tidak ada koneksi internet'};
      }

      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Token tidak ditemukan'};
      }

      // Format tanggal hari ini
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      final response = await _client.get(
        Uri.parse('$baseUrl$absensiEndpoint?tanggal=$today'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['absensi'] ?? []};
      } else {
        return {
          'success': false,
          'message': 'Gagal mengambil data absensi: ${response.statusCode}',
        };
      }
    } catch (e) {
      _logger.e('Error fetching today\'s absensi data: $e');
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // Mengupdate absensi yang sudah ada
  Future<Map<String, dynamic>> updateAbsensiStatus(int guruId, String status) async {
    try {
      if (!await hasInternetConnection()) {
        return {'success': false, 'message': 'Tidak ada koneksi internet'};
      }

      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Token tidak ditemukan'};
      }

      // Format tanggal hari ini untuk mencari absensi yang mau diupdate
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // Cek dulu apakah sudah ada absensi hari ini
      final response = await _client.get(
        Uri.parse('$baseUrl$absensiEndpoint?tanggal=$today&guruId=$guruId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final absensiList = data['absensi'] ?? [];
        
        if (absensiList.isNotEmpty) {
          // Ada absensi hari ini, update status
          final absensiId = absensiList[0]['id'];
          
          final updateResponse = await _client.put(
            Uri.parse('$baseUrl$absensiEndpoint/$absensiId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'status': status,
            }),
          ).timeout(_requestTimeout);

          if (updateResponse.statusCode == 200) {
            final updateData = jsonDecode(updateResponse.body);
            return {'success': true, 'data': updateData, 'message': 'Status absensi berhasil diperbarui'};
          } else {
            return {
              'success': false,
              'message': 'Gagal memperbarui status absensi: ${updateResponse.statusCode}',
            };
          }
        } else {
          // Belum ada absensi hari ini, buat baru
          return createAbsensi({
            'guruId': guruId,
            'status': status,
            'jamMasuk': DateTime.now().toIso8601String(),
          });
        }
      } else {
        return {
          'success': false,
          'message': 'Gagal memeriksa absensi hari ini: ${response.statusCode}',
        };
      }
    } catch (e) {
      _logger.e('Error updating absensi status: $e');
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }
} 

// Class untuk mengelola data cache
class _CachedResponse {
  final Map<String, dynamic> data;
  final DateTime expiryTime;

  _CachedResponse(this.data, this.expiryTime);

  bool isExpired() {
    return DateTime.now().isAfter(expiryTime);
  }
} 