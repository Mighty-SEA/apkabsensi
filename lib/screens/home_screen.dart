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
    final theme = Theme.of(context);

    return Scaffold(
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
              : SafeArea(
                  child: CustomScrollView(
                    slivers: [
                      // Header dengan refresh action
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Selamat Datang,',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    '${user?.name ?? user?.username ?? 'Pengguna'}',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                onPressed: _fetchRekapData,
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

                      // Statistik absensi
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.secondary,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rekap Bulan ${_getCurrentMonthYear()}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatItem('Hadir', _rekapData['totalHadir']?.toString() ?? '0', Icons.check_circle),
                                  ),
                                  Expanded(
                                    child: _buildStatItem('Izin', _rekapData['totalIzin']?.toString() ?? '0', Icons.assignment_late),
                                  ),
                                  Expanded(
                                    child: _buildStatItem('Sakit', _rekapData['totalSakit']?.toString() ?? '0', Icons.healing),
                                  ),
                                  Expanded(
                                    child: _buildStatItem('Alpa', _rekapData['totalAlpa']?.toString() ?? '0', Icons.cancel),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Rata-rata waktu absensi
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
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
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.login, color: Colors.green),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Jam Masuk',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
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
                                    height: 60,
                                    width: 1,
                                    color: Colors.grey[300],
                                  ),
                                  Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.logout, color: Colors.orange),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Jam Keluar',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
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

                      // Riwayat absensi terakhir
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Riwayat Absensi',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      // Navigasi ke halaman detail absensi (bisa diimplementasikan nanti)
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Menampilkan semua absensi')),
                                      );
                                    },
                                    child: Text(
                                      'Lihat Semua',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _buildAbsensiSummary(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
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
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      status.toLowerCase() == 'hadir' ? Icons.check_circle : 
                      status.toLowerCase() == 'izin' ? Icons.assignment_late :
                      status.toLowerCase() == 'sakit' ? Icons.healing : Icons.cancel,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formattedDate,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 16,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.login, size: 14),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Masuk: $jamMasuk',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.logout, size: 14),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Keluar: $jamKeluar',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
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
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
} 