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
      appBar: AppBar(
        title: const Text('Data Absensi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAbsensiData,
            tooltip: 'Refresh',
          ),
        ],
      ),
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
              : Column(
                  children: [
                    // Status absensi hari ini
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isAbsenPulangToday 
                            ? Colors.green.shade50 
                            : _isAbsenToday 
                                ? Colors.orange.shade50 
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isAbsenPulangToday 
                              ? Colors.green 
                              : _isAbsenToday 
                                  ? Colors.orange 
                                  : Colors.grey,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status Absensi Hari Ini:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                _isAbsenPulangToday 
                                    ? Icons.check_circle 
                                    : _isAbsenToday 
                                        ? Icons.access_time 
                                        : Icons.pending,
                                color: _isAbsenPulangToday 
                                    ? Colors.green 
                                    : _isAbsenToday 
                                        ? Colors.orange 
                                        : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isAbsenPulangToday 
                                    ? 'Absensi lengkap (masuk & pulang)' 
                                    : _isAbsenToday 
                                        ? 'Sudah absen masuk, belum absen pulang' 
                                        : 'Belum melakukan absensi',
                                style: TextStyle(
                                  color: _isAbsenPulangToday 
                                      ? Colors.green 
                                      : _isAbsenToday 
                                          ? Colors.orange 
                                          : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Daftar absensi
                    Expanded(
                      child: _absensiData.isEmpty
                          ? const Center(child: Text('Tidak ada data absensi'))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              absensi['namaGuru'] ?? 'Nama tidak tersedia',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: statusColor,
                                                borderRadius: BorderRadius.circular(4),
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
                                        const SizedBox(height: 8),
                                        Text('Tanggal: $tanggal'),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.login, size: 16),
                                            const SizedBox(width: 4),
                                            Text('Jam Masuk: $jamMasuk'),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.logout, size: 16),
                                            const SizedBox(width: 4),
                                            Text('Jam Keluar: $jamKeluar'),
                                          ],
                                        ),
                                        if (absensi['keterangan'] != null && absensi['keterangan'] != '')
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Text(
                                              'Keterangan: ${absensi['keterangan']}',
                                              style: const TextStyle(
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      // Tampilkan tombol hanya jika belum absen atau sudah absen masuk tapi belum absen pulang
      floatingActionButton: _isAbsenPulangToday 
          ? null // Tidak menampilkan tombol jika sudah absen pulang
          : FloatingActionButton.extended(
              onPressed: _doAbsen,
              icon: Icon(_isAbsenToday ? Icons.logout : Icons.login),
              label: Text(_isAbsenToday ? 'Absen Pulang' : 'Absen'),
              backgroundColor: _isAbsenToday ? Colors.orange : Colors.green,
            ),
    );
  }
} 