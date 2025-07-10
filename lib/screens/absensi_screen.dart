import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/absensi_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class AbsensiScreen extends StatefulWidget {
  const AbsensiScreen({super.key});

  @override
  State<AbsensiScreen> createState() => _AbsensiScreenState();
}

class _AbsensiScreenState extends State<AbsensiScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  List<dynamic> _absensiData = [];
  String _errorMessage = '';
  bool _isAbsenToday = false;
  bool _isAbsenPulangToday = false; // Tambahkan variabel untuk melacak absen pulang
  String? _todayAbsensiId;

  @override
  void initState() {
    super.initState();
    _fetchAbsensiData();
  }

  Future<void> _fetchAbsensiData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      print('Mengambil data absensi...');
      final result = await _apiService.getAbsensiData();
      print('Hasil respons: $result');
      
      if (result['success']) {
        final data = result['data'];
        print('Data absensi: ${data.length} item');
        
        setState(() {
          _absensiData = data;
          _isLoading = false;
        });
        
        // Cek apakah user sudah absen hari ini
        _checkTodayAbsensi();
      } else {
        print('Error: ${result['message']}');
        setState(() {
          _errorMessage = result['message'] ?? 'Gagal memuat data absensi';
          _isLoading = false;
        });

        // Memeriksa koneksi server jika ada masalah
        final connectionCheck = await _apiService.checkServerConnection();
        if (!connectionCheck['success']) {
          setState(() {
            _errorMessage += '\n\nStatus server: ${connectionCheck['message']}';
          });
        }
      }
    } catch (e) {
      print('Exception saat mengambil data absensi: $e');
      setState(() {
        _errorMessage = 'Terjadi kesalahan: $e';
        _isLoading = false;
      });
    }
  }

  // Memeriksa apakah user sudah absen hari ini
  void _checkTodayAbsensi() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    
    print('Memeriksa absensi hari ini: $today untuk user: ${user?.guruId}');
    print('Data absensi tersedia: ${_absensiData.length} item');
    
    if (user != null && user.guruId != null && _absensiData.isNotEmpty) {
      // Mencari absensi hari ini
      try {
        var todayAbsensi;
        
        for (var absensi in _absensiData) {
          print('Memeriksa absensi: ${absensi['tanggal']} - GuruId: ${absensi['guruId']} - UserId: ${user.guruId}');
          
          if (absensi['tanggal'] != null && 
              absensi['tanggal'].toString().substring(0, 10) == today &&
              absensi['guruId'].toString() == user.guruId.toString()) {
            todayAbsensi = absensi;
            break;
          }
        }
        
        setState(() {
          _isAbsenToday = todayAbsensi != null;
          
          if (_isAbsenToday) {
            _todayAbsensiId = todayAbsensi['id'].toString();
            // Cek apakah sudah absen pulang (jamKeluar sudah ada)
            _isAbsenPulangToday = todayAbsensi['jamKeluar'] != null && 
                                 todayAbsensi['jamKeluar'] != '' && 
                                 todayAbsensi['jamKeluar'] != '-';
            print('User sudah absen hari ini dengan ID: $_todayAbsensiId');
            print('Status absen pulang: ${_isAbsenPulangToday ? "Sudah" : "Belum"}');
          } else {
            _todayAbsensiId = null;
            _isAbsenPulangToday = false;
            print('User belum absen hari ini');
          }
        });
      } catch (e) {
        print('Error saat memeriksa absensi hari ini: $e');
        setState(() {
          _isAbsenToday = false;
          _isAbsenPulangToday = false;
          _todayAbsensiId = null;
        });
      }
    } else {
      print('Tidak dapat memeriksa absensi: user=${user != null}, guruId=${user?.guruId}, dataAbsensi=${_absensiData.isNotEmpty}');
      setState(() {
        _isAbsenToday = false;
        _isAbsenPulangToday = false;
        _todayAbsensiId = null;
      });
    }
  }

  // Fungsi untuk melakukan absen (masuk atau pulang)
  Future<void> _doAbsen() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda harus login terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    print('Melakukan absensi untuk user: ${user.username}, guruId: ${user.guruId}');
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      if (_isAbsenToday) {
        // Absen pulang (update)
        print('Melakukan absen pulang dengan ID: $_todayAbsensiId');
        final now = DateTime.now();
        
        final updateData = {
          'jamKeluar': now.toIso8601String(),
        };
        
        print('Data update: $updateData');
        final result = await _apiService.updateAbsensi(_todayAbsensiId!, updateData);
        print('Hasil update absensi: $result');
        
        if (result['success']) {
          _fetchAbsensiData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Absen pulang berhasil'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal melakukan absen pulang'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Absen masuk (create)
        print('Melakukan absen masuk');
        final now = DateTime.now();
        
        // Convert guruId to integer
        int? guruIdInt;
        try {
          if (user.guruId == null) {
            throw 'GuruId tidak tersedia';
          }
          guruIdInt = int.parse(user.guruId!);
          print('GuruId dalam bentuk integer: $guruIdInt');
        } catch (e) {
          print('Error parsing guruId: ${user.guruId} - $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ID guru tidak valid: ${user.guruId} - $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
        
        final absensiData = {
          'guruId': guruIdInt,
          'status': 'HADIR',  // Capital letters as expected by backend
          'jamMasuk': now.toIso8601String(),
          'keterangan': '',
          'longitude': 0.0, // Optional: Get actual GPS coordinates
          'latitude': 0.0,   // Optional: Get actual GPS coordinates
        };
        
        print('Data absensi: $absensiData');
        final result = await _apiService.createAbsensi(absensiData);
        print('Hasil create absensi: $result');
        
        if (result['success']) {
          _fetchAbsensiData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Absen masuk berhasil'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal melakukan absen masuk'),
              backgroundColor: Colors.red,
            ),
          );
          
          // Coba periksa apakah koneksi ke server bermasalah
          if (result['message'] != null && result['message'].toString().contains('Terjadi kesalahan')) {
            final connectionCheck = await _apiService.checkServerConnection();
            if (!connectionCheck['success']) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Masalah koneksi server: ${connectionCheck['message']}'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      print('Error saat melakukan absensi: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchAbsensiData,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  child: Column(
                    children: [
                      // Header dengan refresh action
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Absensi',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: _fetchAbsensiData,
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Refresh',
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                foregroundColor: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Status absensi hari ini
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _isAbsenPulangToday 
                                  ? Colors.green 
                                  : _isAbsenToday 
                                      ? Colors.orange 
                                      : Theme.of(context).colorScheme.primary,
                              _isAbsenPulangToday 
                                  ? Colors.green.shade700 
                                  : _isAbsenToday 
                                      ? Colors.deepOrange 
                                      : Theme.of(context).colorScheme.secondary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Status Absensi Hari Ini',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _isAbsenPulangToday 
                                        ? Icons.check_circle 
                                        : _isAbsenToday 
                                            ? Icons.access_time 
                                            : Icons.pending,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isAbsenPulangToday 
                                            ? 'Absensi Selesai' 
                                            : _isAbsenToday 
                                                ? 'Sudah Absen Masuk' 
                                                : 'Belum Absen',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _isAbsenPulangToday 
                                            ? 'Anda telah melakukan absen masuk dan pulang' 
                                            : _isAbsenToday 
                                                ? 'Silakan lakukan absen pulang setelah selesai' 
                                                : 'Silakan lakukan absen masuk untuk memulai',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _isAbsenPulangToday ? null : _doAbsen,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: _isAbsenPulangToday 
                                    ? Colors.grey 
                                    : _isAbsenToday 
                                        ? Colors.orange 
                                        : Theme.of(context).colorScheme.primary,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _isAbsenPulangToday 
                                    ? 'Absensi Selesai' 
                                    : _isAbsenToday 
                                        ? 'Absen Pulang' 
                                        : 'Absen Masuk',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Label riwayat absensi
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
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
                            Flexible(
                              child: Text(
                                DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now()),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Daftar absensi
                      Expanded(
                        child: _absensiData.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 80,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Tidak ada data absensi',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: _absensiData.length,
                                itemBuilder: (context, index) {
                                  final absensi = _absensiData[index];
                                  final tanggal = absensi['tanggal'] ?? '-';
                                  final jamMasuk = absensi['jamMasuk'] ?? '-';
                                  final jamKeluar = absensi['jamKeluar'] ?? '-';
                                  final status = absensi['status'] ?? 'hadir';
                                  
                                  Color statusColor;
                                  switch (status.toLowerCase()) {
                                    case 'hadir':
                                      statusColor = Colors.green;
                                      break;
                                    case 'izin':
                                      statusColor = Colors.orange;
                                      break;
                                    case 'sakit':
                                      statusColor = Colors.blue;
                                      break;
                                    case 'alpa':
                                      statusColor = Colors.red;
                                      break;
                                    default:
                                      statusColor = Colors.grey;
                                  }
                                  
                                  // Format tanggal menjadi lebih mudah dibaca
                                  String formattedDate = tanggal;
                                  try {
                                    final date = DateTime.parse(tanggal);
                                    formattedDate = DateFormat('EEEE, d MMM yyyy', 'id_ID').format(date);
                                  } catch (e) {
                                    // Gunakan format asli jika parsing gagal
                                  }
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        // Header dengan status
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.1),
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(16),
                                              topRight: Radius.circular(16),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  formattedDate,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: statusColor,
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  status.toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Informasi jam masuk dan keluar
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                                            children: [
                                              _buildTimeInfo(Icons.login, 'Masuk', jamMasuk, Colors.green),
                                              Container(
                                                height: 40,
                                                width: 1,
                                                color: Colors.grey[300],
                                              ),
                                              _buildTimeInfo(Icons.logout, 'Keluar', jamKeluar, Colors.orange),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
  
  Widget _buildTimeInfo(IconData icon, String label, String time, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
} 