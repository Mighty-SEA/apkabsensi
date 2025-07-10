import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  Map<String, dynamic> _rekapData = {};
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchRekapData();
  }

  Future<void> _fetchRekapData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await _apiService.getAbsensiMonthlyReport();
      
      if (result['success']) {
        setState(() {
          _rekapData = result['data'] ?? {};
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Gagal memuat data rekap';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan: $e';
        _isLoading = false;
      });
    }
  }

  String _getCurrentMonthYear() {
    final now = DateTime.now();
    final formatter = DateFormat('MMMM yyyy', 'id_ID');
    return formatter.format(now);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aplikasi Absensi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRekapData,
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
                        onPressed: _fetchRekapData,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Informasi pengguna
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selamat Datang, ${user?.name ?? user?.username ?? 'Pengguna'}!',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Role: ${user?.role ?? '-'}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Judul rekap bulanan
                      Text(
                        'Rekap Absensi Bulan ${_getCurrentMonthYear()}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Statistik absensi
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Hadir',
                              _rekapData['totalHadir']?.toString() ?? '0',
                              Colors.green,
                              Icons.check_circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              'Izin',
                              _rekapData['totalIzin']?.toString() ?? '0',
                              Colors.orange,
                              Icons.assignment_late,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Sakit',
                              _rekapData['totalSakit']?.toString() ?? '0',
                              Colors.blue,
                              Icons.healing,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              'Alpa',
                              _rekapData['totalAlpa']?.toString() ?? '0',
                              Colors.red,
                              Icons.cancel,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Rata-rata jam masuk dan keluar
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rata-rata Waktu Absensi',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      const Icon(Icons.login, color: Colors.green),
                                      const SizedBox(height: 8),
                                      const Text('Jam Masuk'),
                                      const SizedBox(height: 4),
                                      Text(
                                        _rekapData['avgJamMasuk'] ?? '00:00',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    height: 50,
                                    width: 1,
                                    color: Colors.grey[300],
                                  ),
                                  Column(
                                    children: [
                                      const Icon(Icons.logout, color: Colors.orange),
                                      const SizedBox(height: 8),
                                      const Text('Jam Keluar'),
                                      const SizedBox(height: 4),
                                      Text(
                                        _rekapData['avgJamKeluar'] ?? '00:00',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Ringkasan absensi bulan ini
                      const Text(
                        'Ringkasan Absensi Bulan Ini',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildAbsensiSummary(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbsensiSummary() {
    final absensiList = _rekapData['absensiPerTanggal'] as List? ?? [];
    
    if (absensiList.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'Belum ada data absensi bulan ini',
              style: TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      );
    }
    
    // Urutkan berdasarkan tanggal terbaru
    absensiList.sort((a, b) {
      final tanggalA = a['tanggal'] ?? '';
      final tanggalB = b['tanggal'] ?? '';
      return tanggalB.compareTo(tanggalA); // Descending (terbaru dulu)
    });
    
    // Batasi jumlah item yang ditampilkan untuk mencegah overflow
    final displayedList = absensiList.length > 5 
        ? absensiList.sublist(0, 5) 
        : absensiList;
    
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayedList.length,
          itemBuilder: (context, index) {
            final absensi = displayedList[index];
            final tanggal = absensi['tanggal'] ?? '-';
            final jamMasuk = absensi['jamMasuk'] ?? '-';
            final jamKeluar = absensi['jamKeluar'] ?? '-';
            final status = absensi['status'] ?? 'hadir';
            
            // Format tanggal menjadi lebih mudah dibaca
            String formattedDate = tanggal;
            try {
              final date = DateTime.parse(tanggal);
              formattedDate = DateFormat('EEEE, d MMM yyyy', 'id_ID').format(date);
            } catch (e) {
              // Gunakan format asli jika parsing gagal
            }
            
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
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  formattedDate,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.login, size: 14),
                        const SizedBox(width: 4),
                        Flexible(child: Text('Masuk: $jamMasuk')),
                        const SizedBox(width: 16),
                        const Icon(Icons.logout, size: 14),
                        const SizedBox(width: 4),
                        Flexible(child: Text('Keluar: $jamKeluar')),
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
              ),
            );
          },
        ),
        // Tampilkan tombol "Lihat Semua" jika ada lebih dari 5 item
        if (absensiList.length > 5)
          TextButton(
            onPressed: () {
              // Navigasi ke halaman detail absensi (bisa diimplementasikan nanti)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Menampilkan semua absensi')),
              );
            },
            child: const Text('Lihat Semua Absensi'),
          ),
      ],
    );
  }
} 