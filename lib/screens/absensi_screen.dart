import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/absensi_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'package:flutter/foundation.dart'; // Added for kDebugMode

// Komentar: Perbaikan pada 2023-07-18 untuk isu tampilan tombol absen

class AbsensiScreen extends StatefulWidget {
  const AbsensiScreen({super.key});

  @override
  State<AbsensiScreen> createState() => _AbsensiScreenState();
}

class _AbsensiScreenState extends State<AbsensiScreen> with AutomaticKeepAliveClientMixin {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _isRefreshing = false;
  List<dynamic> _absensiData = [];
  String _errorMessage = '';
  bool _isAbsenToday = false;
  bool _isAbsenPulangToday = false;
  String? _todayAbsensiId;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  // Keep alive state untuk mencegah rebuild saat berpindah tab
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Reset variabel status terlebih dahulu
    _isAbsenToday = false;
    _isAbsenPulangToday = false;
    _todayAbsensiId = null;
    
    // Ambil data dan status absen
    _fetchAbsensiData();
  }

  Future<void> _fetchAbsensiData() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isLoading = !_isRefreshing;
      _isRefreshing = false;
      _errorMessage = '';
    });

    try {
      final result = await _apiService.getAbsensiData(useCache: false); // Selalu gunakan data terbaru
      
      if (result['success']) {
        final data = result['data'];
        
        // Gunakan setState yang efisien dengan memeriksa perubahan data
        if (mounted) {
          setState(() {
            _absensiData = data;
            _isLoading = false;
          });
        }
        
        // Cek apakah user sudah absen hari ini dengan mengambil data langsung dari server
        await _checkTodayAbsensi();
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = result['message'] ?? 'Gagal memuat data absensi';
            _isLoading = false;
          });
        }

        // Memeriksa koneksi server jika ada masalah
        final connectionCheck = await _apiService.checkServerConnection();
        if (!connectionCheck['success'] && mounted) {
          setState(() {
            _errorMessage += '\n\nStatus server: ${connectionCheck['message']}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Terjadi kesalahan: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _isRefreshing = true;
    });
    await _fetchAbsensiData();
    
    // Pastikan status absen juga direfresh
    await _checkTodayAbsensi();
    
    return;
  }

  // Fungsi debug - untuk memeriksa status variabel
  void _debugPrintAbsenStatus(String location) {
    print('$location - Status: masuk=$_isAbsenToday, pulang=$_isAbsenPulangToday, id=$_todayAbsensiId');
  }
  
  // Memeriksa apakah user sudah absen hari ini dengan mengambil data langsung dari server
  Future<void> _checkTodayAbsensi() async {
    _debugPrintAbsenStatus('Before check');
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    
    // Set nilai default ke false untuk memastikan tidak ada status yang tertinggal
    bool newIsAbsenToday = false;
    bool newIsAbsenPulangToday = false;
    String? newTodayAbsensiId;
    
    if (user == null || user.guruId == null) {
      if (mounted) {
        setState(() {
          _isAbsenToday = false;
          _isAbsenPulangToday = false;
          _todayAbsensiId = null;
        });
      }
      return;
    }
    
    try {
      // Ambil data absen hari ini langsung dari server untuk memastikan data terbaru
      print('Memeriksa absensi hari ini untuk guru: ${user.guruId}, tanggal: $today');
      
      final token = await _apiService.getToken();
      if (token == null) {
        throw Exception('Token tidak tersedia');
      }
      
      final url = "${ApiService.baseUrl}${ApiService.absensiEndpoint}?tanggal=$today&guruId=${user.guruId}";
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Data absensi hari ini: ${response.body}');
        final absensiList = data['absensi'] ?? [];
        
        // Proses data dari server
        if (absensiList.isNotEmpty) {
          final absen = absensiList[0]; // Ambil data absensi pertama hari ini
          newIsAbsenToday = true;
          newTodayAbsensiId = absen['id'].toString();
          
          // Cek keberadaan jam keluar dan pastikan bukan nilai kosong
          final hasJamKeluar = 
            absen['jamKeluar'] != null && 
            absen['jamKeluar'].toString() != '' && 
            absen['jamKeluar'].toString() != '-';
          
          print('Jam keluar: ${absen['jamKeluar']}, hasJamKeluar: $hasJamKeluar');
          newIsAbsenPulangToday = hasJamKeluar;
          print('Set newIsAbsenPulangToday to $newIsAbsenPulangToday');
        } else {
          // Tidak ada absensi hari ini
          newIsAbsenToday = false;
          newIsAbsenPulangToday = false;
          newTodayAbsensiId = null;
          print('No absensi found for today');
        }
        
        // Update state dengan nilai baru
        if (mounted) {
          setState(() {
            _isAbsenToday = newIsAbsenToday;
            _isAbsenPulangToday = newIsAbsenPulangToday;
            _todayAbsensiId = newTodayAbsensiId;
            print('Updated state: masuk=$_isAbsenToday, pulang=$_isAbsenPulangToday');
          });
        }
        _debugPrintAbsenStatus('After API check');
      } else {
        print('Gagal mengambil data absensi: ${response.statusCode}');
        print('Response body: ${response.body}');
        // Set nilai ke default
        newIsAbsenToday = false;
        newIsAbsenPulangToday = false;
        newTodayAbsensiId = null;
        
        if (mounted) {
          setState(() {
            _isAbsenToday = newIsAbsenToday;
            _isAbsenPulangToday = newIsAbsenPulangToday;
            _todayAbsensiId = newTodayAbsensiId;
          });
        }
      }
    } catch (e) {
      print('Error saat memeriksa absensi hari ini: $e');
      // Set nilai ke default
      newIsAbsenToday = false;
      newIsAbsenPulangToday = false;
      newTodayAbsensiId = null;
      
      if (mounted) {
        setState(() {
          _isAbsenToday = newIsAbsenToday;
          _isAbsenPulangToday = newIsAbsenPulangToday;
          _todayAbsensiId = newTodayAbsensiId;
        });
      }
    }
  }

  // Fungsi untuk melakukan absen (masuk atau pulang)
  Future<void> _doAbsen() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    
    if (user == null) {
      _showMessage('Anda harus login terlebih dahulu', isError: true);
      return;
    }
    
    // Periksa apakah guruId tersedia
    if (user.guruId == null || user.guruId!.isEmpty) {
      _showMessage('ID guru tidak tersedia. Silakan hubungi administrator.', isError: true);
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Verifikasi status absensi terbaru terlebih dahulu dari server
      await _checkTodayAbsensi();
      
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      
      if (_isAbsenToday && !_isAbsenPulangToday) {
        // Absen pulang (checkout)
        if (_todayAbsensiId == null) {
          throw Exception('ID absensi tidak ditemukan untuk proses absen pulang');
        }
        
        final updateData = {
          'jamKeluar': now.toIso8601String(),
        };
        
        print('Doing checkout for absensi with ID: $_todayAbsensiId');
        print('Update data: $updateData');
        print('User role: ${user.role}');
        
        // Dapatkan token baru untuk memastikan token valid
        final token = await _apiService.getToken();
        if (token == null) {
          throw Exception('Token tidak tersedia');
        }
        
        // Gunakan endpoint khusus checkout untuk guru
        final response = await http.post(
          Uri.parse('${ApiService.baseUrl}${ApiService.absensiCheckoutEndpoint}/${_todayAbsensiId}'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(updateData),
        );
        
        print('Status code absen pulang: ${response.statusCode}');
        print('Response body absen pulang: ${response.body}');
        
        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          _showMessage('Absen pulang berhasil', isError: false);
          
          // Refresh data absensi dan status secara menyeluruh
          await _fetchAbsensiData(); 
          
          // Pastikan state sudah diupdate sebelum menampilkan
          if (mounted) {
            setState(() {
              _isAbsenPulangToday = true;
            });
          }
        } else {
          String errorMessage;
          try {
            final errorData = jsonDecode(response.body);
            errorMessage = errorData['message'] ?? errorData['error'] ?? 'Gagal melakukan absen pulang';
          } catch (e) {
            errorMessage = 'Gagal melakukan absen pulang: ${response.statusCode}';
          }
          
          _showMessage(errorMessage, isError: true);
          
          // Coba refresh status setelah error untuk memastikan data terbaru
          await _checkTodayAbsensi();
        }
      } else if (_isAbsenToday && _isAbsenPulangToday) {
        // Sudah absen masuk dan pulang
        _showMessage('Anda sudah melakukan absensi lengkap hari ini', isError: true, backgroundColor: Colors.orange);
      } else {
        // Absen masuk (create)
        // Convert guruId to integer
        int guruIdInt;
        try {
          guruIdInt = int.parse(user.guruId!);
        } catch (e) {
          _showMessage('ID guru tidak valid: ${user.guruId}', isError: true);
          setState(() {
            _isLoading = false;
          });
          return;
        }
        
        final absensiData = {
          'guruId': guruIdInt,
          'status': 'HADIR',
          'tanggal': "${today}T00:00:00.000Z", // Format tanggal dengan benar
          'jamMasuk': now.toIso8601String(),
          'keterangan': '',
          'longitude': 0.0,
          'latitude': 0.0,
        };
        
        print('Creating new absensi with data: $absensiData');
        
        // Kirim permintaan ke backend
        final token = await _apiService.getToken();
        if (token == null) {
          throw Exception('Token tidak tersedia');
        }
        
        // Gunakan HTTP client langsung untuk lebih banyak informasi debug
        final response = await http.post(
          Uri.parse('${ApiService.baseUrl}${ApiService.absensiEndpoint}'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(absensiData),
        );
        
        print('Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          _showMessage('Absen masuk berhasil', isError: false);
          await _fetchAbsensiData(); // Tunggu fetch selesai
          await _checkTodayAbsensi(); // Refresh status absen
        } else {
          // Parse error message dari response
          String errorMessage;
          try {
            final errorData = jsonDecode(response.body);
            errorMessage = errorData['message'] ?? errorData['error'] ?? 'Gagal melakukan absen masuk';
          } catch (e) {
            errorMessage = 'Gagal melakukan absen masuk: ${response.statusCode}';
          }
          
          _showMessage(errorMessage, isError: true);
          
          // Cek jika absensi sudah ada (mungkin error karena duplikat)
          if (errorMessage.contains('sudah ada absensi') || 
              errorMessage.contains('duplicate')) {
            // Coba refresh data untuk mengecek status terbaru
            await _fetchAbsensiData();
            await _checkTodayAbsensi();
          }
        }
      }
    } catch (e) {
      _showMessage('Error: $e', isError: true);
      print('Error saat melakukan absensi: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _showMessage(String message, {bool isError = false, Color? backgroundColor}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? (isError ? Colors.red : Colors.green),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 5),
      ),
    );
  }
  
  // Format tanggal untuk display
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return '-';
    }
    
    try {
      // Handle format tanggal yang hanya berisi tanggal (tanpa waktu)
      final date = DateTime.parse(dateStr);
      return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
    } catch (e) {
      print('Error format tanggal: $e - Input: $dateStr');
      
      // Jika format tanggal standar gagal, coba format yyyy-MM-dd
      if (dateStr.length >= 10 && dateStr.contains('-')) {
        try {
          final parts = dateStr.split('-');
          if (parts.length >= 3) {
            final year = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final day = int.parse(parts[2].substring(0, 2)); // Ambil 2 karakter pertama untuk hari
            
            final date = DateTime(year, month, day);
            return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
          }
        } catch (innerE) {
          print('Error format tanggal level 2: $innerE');
        }
      }
      
      return dateStr ?? '-';
    }
  }
  
  // Format jam untuk display
  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty || timeStr == '-') {
      return '-';
    }
    
    try {
      // Periksa format waktu, jika hanya berisi waktu tanpa tanggal
      if (timeStr.contains(':') && !timeStr.contains('-') && !timeStr.contains('T')) {
        // Format waktu sederhana seperti "07:05:02" - tampilkan langsung
        // Ambil hanya jam dan menit (hapus detik)
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          return '${parts[0]}:${parts[1]}';
        }
        return timeStr;
      }
      
      // Untuk format datetime lengkap
      final dateTime = DateTime.parse(timeStr);
      return DateFormat('HH:mm', 'id_ID').format(dateTime);
    } catch (e) {
      // Jika gagal parsing, coba ambil bagian waktu saja
      print('Error format waktu: $e - Input: $timeStr - Tipe: ${timeStr.runtimeType}');
      
      // Cek apakah string mengandung karakter ":"
      if (timeStr.contains(':')) {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          return '${parts[0]}:${parts[1]}';
        }
      }
      
      // Fallback: kembalikan string asli
      return timeStr;
    }
  }
  
  Widget _buildSkeletonLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Absen button skeleton
            Container(
              margin: const EdgeInsets.all(20),
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            
            // History header skeleton
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 30,
              width: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            
            const SizedBox(height: 10),
            
            // History items skeleton
            for (int i = 0; i < 7; i++)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Diperlukan untuk AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final user = Provider.of<AuthProvider>(context).user;
    
    return Scaffold(
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _handleRefresh,
        child: _isLoading
            ? _buildSkeletonLoading()
            : _errorMessage.isNotEmpty
                ? _buildErrorView(theme)
                : SafeArea(
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // Tombol Absen
                        SliverToBoxAdapter(
                          child: RepaintBoundary(
                            child: _buildAbsenButton(theme),
                          ),
                        ),
                        
                        // Header Riwayat Absensi
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Riwayat Absensi',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _refreshIndicatorKey.currentState?.show(),
                                  icon: const Icon(Icons.refresh),
                                  tooltip: 'Refresh',
                                  style: IconButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primaryContainer,
                                    foregroundColor: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Daftar Absensi
                        SliverToBoxAdapter(
                          child: Builder(
                            builder: (context) {
                              // Filter absensi untuk guru yang login
                              List<dynamic> filteredAbsensi = [];
                              if (_absensiData.isNotEmpty && user?.guruId != null) {
                                filteredAbsensi = _absensiData.where((absen) => 
                                  absen['guruId'] != null && 
                                  absen['guruId'].toString() == user!.guruId.toString()
                                ).toList();
                              }
                            
                              if (filteredAbsensi.isEmpty) {
                                return _buildEmptyAbsensiView();
                              }
                              
                              // Urutkan berdasarkan tanggal terbaru
                              filteredAbsensi.sort((a, b) {
                                try {
                                  final tanggalA = a['tanggal'] != null ? DateTime.parse(a['tanggal'].toString()) : DateTime(1900);
                                  final tanggalB = b['tanggal'] != null ? DateTime.parse(b['tanggal'].toString()) : DateTime(1900);
                                  return tanggalB.compareTo(tanggalA); // Descending
                                } catch (e) {
                                  return 0;
                                }
                              });
                              
                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                itemCount: filteredAbsensi.length,
                                itemBuilder: (context, index) {
                                  final absensi = filteredAbsensi[index];
                                  return RepaintBoundary(
                                    child: _buildAbsensiItem(absensi, theme),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                              
                        // Extra space di bawah
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 100),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  // Extracted method untuk absen button (mengurangi rebuilds)
  Widget _buildAbsenButton(ThemeData theme) {
    // Debug - tampilkan status absensi di console hanya saat development
    // Hapus atau batasi output debug
    if (kDebugMode) {
      _debugPrintAbsenStatus('Building button');
    }
    
    // Hapus post frame callback yang menyebabkan rebuild terus menerus
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (mounted) setState(() {});
    // });
    
    final bool isActive = !(_isAbsenToday && _isAbsenPulangToday);
    final Color primaryColor = isActive ? theme.colorScheme.primary : Colors.grey.shade400;
    final Color secondaryColor = isActive ? theme.colorScheme.secondary : Colors.grey.shade300;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Background card dengan glow effect
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor,
                  secondaryColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: isActive ? [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: primaryColor.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ] : [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Builder(
                  builder: (context) {
                    IconData iconData;
                    if (_isAbsenToday) {
                      iconData = _isAbsenPulangToday ? Icons.check_circle_outline : Icons.logout;
                    } else {
                      iconData = Icons.login;
                    }
                    
                    return Icon(
                      iconData,
                      size: 60,
                      color: Colors.white.withOpacity(0.9),
                    );
                  },
                ),
                const SizedBox(height: 15),
                Builder(
                  builder: (context) {
                    String buttonText;
                    if (_isAbsenToday) {
                      buttonText = _isAbsenPulangToday ? 'Absensi Hari Ini Selesai' : 'Absen Pulang';
                    } else {
                      buttonText = 'Absen Masuk';
                    }
                    
                    return Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: _isAbsenToday && _isAbsenPulangToday ? null : _doAbsen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    disabledBackgroundColor: Colors.white.withOpacity(0.7),
                    disabledForegroundColor: Colors.grey,
                    elevation: isActive ? 8 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    shadowColor: isActive ? primaryColor.withOpacity(0.5) : Colors.transparent,
                  ),
                  child: Builder(
                    builder: (context) {
                      // Pemilihan teks tombol absen berdasarkan status
                      String buttonText;
                      if (_isAbsenToday) {
                        // Sudah absen masuk
                        if (_isAbsenPulangToday) {
                          // Sudah absen masuk dan pulang
                          buttonText = 'SUDAH ABSEN';
                        } else {
                          // Sudah absen masuk tapi belum pulang
                          buttonText = 'ABSEN PULANG SEKARANG';
                        }
                      } else {
                        // Belum absen sama sekali
                        buttonText = 'ABSEN MASUK SEKARANG';
                      }
                      
                      // Debug teks yang ditampilkan untuk diagnosis - batasi output
                      if (kDebugMode) {
                        print('Button text: $buttonText (absen today: $_isAbsenToday, pulang: $_isAbsenPulangToday, id: $_todayAbsensiId)');
                      }
                      
                      return Text(
                        buttonText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isActive ? primaryColor : Colors.grey,
                          letterSpacing: 1,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Efek lingkaran di belakang (opsional untuk efek visual)
          if (isActive)
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          if (isActive)
            Positioned(
              bottom: -15,
              left: -15,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Extracted method untuk item absensi (mengurangi rebuilds)
  Widget _buildAbsensiItem(dynamic absensi, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 20, 
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, 
          vertical: 8,
        ),
        title: Text(
          _formatDate(absensi['tanggal']),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.login,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Masuk: ${_formatTime(absensi['jamMasuk'])}',
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.logout,
                  size: 16,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Pulang: ${_formatTime(absensi['jamKeluar'])}',
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: _getStatusColor(absensi['status']),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            absensi['status'] ?? 'HADIR',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }

  // Extracted method untuk error view
  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              _errorMessage,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
          ElevatedButton.icon(
            onPressed: _fetchAbsensiData,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Extracted method untuk empty view
  Widget _buildEmptyAbsensiView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(50.0),
        child: Column(
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada data absensi',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'HADIR':
        return Colors.green;
      case 'IZIN':
        return Colors.orange;
      case 'SAKIT':
        return Colors.blue;
      case 'ALPA':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
} 