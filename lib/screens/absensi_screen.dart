import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../models/absensi_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

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
      final result = await _apiService.getAbsensiData(useCache: !_isRefreshing);
      
      if (result['success']) {
        final data = result['data'];
        
        // Gunakan setState yang efisien dengan memeriksa perubahan data
        if (mounted) {
          setState(() {
            _absensiData = data;
            _isLoading = false;
          });
        }
        
        // Cek apakah user sudah absen hari ini
        _checkTodayAbsensi();
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
    return;
  }

  // Memeriksa apakah user sudah absen hari ini
  void _checkTodayAbsensi() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    
    if (user != null && user.guruId != null && _absensiData.isNotEmpty) {
      // Mencari absensi hari ini menggunakan metode yang lebih efisien
      try {
        var todayAbsensi = _absensiData.firstWhere(
          (absensi) => absensi['tanggal'] != null && 
                       absensi['tanggal'].toString().substring(0, 10) == today &&
                       absensi['guruId'].toString() == user.guruId.toString(),
          orElse: () => null,
        );
        
        if (mounted) {
          setState(() {
            _isAbsenToday = todayAbsensi != null;
            
            if (_isAbsenToday) {
              _todayAbsensiId = todayAbsensi['id'].toString();
              // Cek apakah sudah absen pulang (jamKeluar sudah ada)
              _isAbsenPulangToday = todayAbsensi['jamKeluar'] != null && 
                                  todayAbsensi['jamKeluar'] != '' && 
                                  todayAbsensi['jamKeluar'] != '-';
            } else {
              _todayAbsensiId = null;
              _isAbsenPulangToday = false;
            }
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isAbsenToday = false;
            _isAbsenPulangToday = false;
            _todayAbsensiId = null;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isAbsenToday = false;
          _isAbsenPulangToday = false;
          _todayAbsensiId = null;
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
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      if (_isAbsenToday && !_isAbsenPulangToday) {
        // Absen pulang (update)
        final now = DateTime.now();
        
        final updateData = {
          'jamKeluar': now.toIso8601String(),
        };
        
        final result = await _apiService.updateAbsensi(_todayAbsensiId!, updateData);
        
        if (result['success']) {
          _showMessage('Absen pulang berhasil', isError: false);
          _fetchAbsensiData();
        } else {
          _showMessage(result['message'] ?? 'Gagal melakukan absen pulang', isError: true);
        }
      } else {
        // Absen masuk (create)
        final now = DateTime.now();
        
        // Convert guruId to integer
        int? guruIdInt;
        try {
          if (user.guruId == null) {
            throw 'GuruId tidak tersedia';
          }
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
          'jamMasuk': now.toIso8601String(),
          'keterangan': '',
          'longitude': 0.0,
          'latitude': 0.0,
        };
        
        final result = await _apiService.createAbsensi(absensiData);
        
        if (result['success']) {
          _showMessage('Absen masuk berhasil', isError: false);
          _fetchAbsensiData();
        } else {
          _showMessage(result['message'] ?? 'Gagal melakukan absen masuk', isError: true);
          
          // Coba periksa apakah koneksi ke server bermasalah
          if (result['message'] != null && result['message'].toString().contains('Terjadi kesalahan')) {
            final connectionCheck = await _apiService.checkServerConnection();
            if (!connectionCheck['success']) {
              _showMessage('Masalah koneksi server: ${connectionCheck['message']}', isError: true, backgroundColor: Colors.orange);
            }
          }
        }
      }
    } catch (e) {
      _showMessage('Error: $e', isError: true);
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
  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
    } catch (e) {
      return dateStr;
    }
  }
  
  // Format jam untuk display
  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty || timeStr == '-') {
      return '-';
    }
    
    try {
      final dateTime = DateTime.parse(timeStr);
      return DateFormat('HH:mm', 'id_ID').format(dateTime);
    } catch (e) {
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
                        _absensiData.isEmpty
                            ? SliverToBoxAdapter(
                                child: _buildEmptyAbsensiView(),
                              )
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    // Hanya tampilkan absensi untuk guru yang login
                                    if (user?.guruId == null || 
                                        _absensiData[index]['guruId'].toString() != user!.guruId.toString()) {
                                      return null; // Skip item ini
                                    }
                                    
                                    final absensi = _absensiData[index];
                                    
                                    return RepaintBoundary(
                                      child: _buildAbsensiItem(absensi, theme),
                                    );
                                  },
                                  childCount: _absensiData.length,
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
    // Status warna dan animasi
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
                Icon(
                  _isAbsenToday
                      ? _isAbsenPulangToday
                          ? Icons.check_circle_outline
                          : Icons.logout
                      : Icons.login,
                  size: 60,
                  color: Colors.white.withOpacity(0.9),
                ),
                const SizedBox(height: 15),
                Text(
                  _isAbsenToday
                      ? _isAbsenPulangToday
                          ? 'Absensi Hari Ini Selesai'
                          : 'Absen Pulang'
                      : 'Absen Masuk',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
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
                  child: Text(
                    _isAbsenToday
                        ? _isAbsenPulangToday
                            ? 'SUDAH ABSEN'
                            : 'ABSEN PULANG SEKARANG'
                        : 'ABSEN MASUK SEKARANG',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isActive ? primaryColor : Colors.grey,
                      letterSpacing: 1,
                    ),
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