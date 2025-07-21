import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/absensi_model.dart';
import '../models/guru_model.dart';
import '../services/api_service.dart';
import 'dart:math' as math;
import 'package:excel/excel.dart' hide Border, BorderStyle;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:another_flushbar/flushbar.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:file_saver/file_saver.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../utils/saf_helper.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

class RekapAbsensiScreen extends StatefulWidget {
  const RekapAbsensiScreen({Key? key}) : super(key: key);

  @override
  State<RekapAbsensiScreen> createState() => _RekapAbsensiScreenState();
}

class _RekapAbsensiScreenState extends State<RekapAbsensiScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String _error = '';
  
  // Tab controller
  late TabController _tabController;
  
  // Data rekap
  List<dynamic> _allAbsensiData = [];
  List<Guru> _allGuruData = [];
  
  // Data filter
  DateTime _selectedDate = DateTime.now();
  String? _selectedGuruId;
  
  // Data statistik
  int _totalHadir = 0;
  int _totalIzin = 0;
  int _totalSakit = 0;
  int _totalAlpa = 0;
  int _totalGuru = 0;
  
  // Data kehadiran per guru
  Map<String, Map<String, int>> _kehadiranPerGuru = {};
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Pastikan data dimuat segera setelah widget dibuat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    
    try {
      // Ambil data guru
      final guruResult = await _apiService.getGuruData();
      if (!guruResult['success']) {
        setState(() {
          _error = guruResult['message'] ?? 'Gagal memuat data guru';
          _isLoading = false;
        });
        return;
      }
      
      // Set data guru terlebih dahulu
      setState(() {
        _allGuruData = (guruResult['data'] as List).map((e) => Guru.fromJson(e)).toList();
        _totalGuru = _allGuruData.length;
      });
      
      // Ambil data absensi
      final result = await _apiService.getAbsensiData();
      if (!result['success']) {
        setState(() {
          _error = result['message'] ?? 'Gagal memuat data absensi';
          _isLoading = false;
        });
        return;
      }
      
      // Filter absensi berdasarkan bulan yang dipilih
      final filteredAbsensi = _filterAbsensiByMonth(result['data'] as List);
      
      // Hitung statistik
      _calculateStatistics(filteredAbsensi);
      
      // Hitung kehadiran per guru
      _hitungKehadiranPerGuru(filteredAbsensi);
      
      setState(() {
        _allAbsensiData = filteredAbsensi;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Terjadi kesalahan: $e';
        _isLoading = false;
      });
    }
  }
  
  // Filter absensi berdasarkan bulan yang dipilih
  List<dynamic> _filterAbsensiByMonth(List<dynamic> data) {
    final yearMonth = DateFormat('yyyy-MM').format(_selectedDate);
    
    return data.where((absen) {
      if (absen['tanggal'] == null) return false;
      return absen['tanggal'].startsWith(yearMonth);
    }).toList();
  }
  
  // Filter absensi berdasarkan guru yang dipilih
  List<dynamic> get _filteredAbsensiData {
    if (_selectedGuruId == null) {
      return _allAbsensiData;
    }
    
    return _allAbsensiData.where((absen) {
      return absen['guruId'].toString() == _selectedGuruId;
    }).toList();
  }
  
  // Hitung statistik absensi
  void _calculateStatistics(List<dynamic> data) {
    _totalHadir = 0;
    _totalIzin = 0;
    _totalSakit = 0;
    _totalAlpa = 0;
    
    for (var absen in data) {
      final status = absen['status']?.toString().toLowerCase() ?? '';
      
      if (status == 'hadir') {
        _totalHadir++;
      } else if (status == 'izin') {
        _totalIzin++;
      } else if (status == 'sakit') {
        _totalSakit++;
      } else if (status == 'alpa') {
        _totalAlpa++;
      }
    }
  }

  // Hitung kehadiran per guru
  void _hitungKehadiranPerGuru(List<dynamic> data) {
    _kehadiranPerGuru = {};
    
    // Inisialisasi data untuk semua guru
    for (var guru in _allGuruData) {
      _kehadiranPerGuru[guru.id] = {
        'hadir': 0,
        'izin': 0,
        'sakit': 0,
        'alpa': 0,
        'total': 0,
      };
    }
    
    // Hitung kehadiran dari data absensi
    for (var absen in data) {
      final guruId = absen['guruId']?.toString();
      final status = absen['status']?.toString().toLowerCase() ?? 'hadir';
      
      if (guruId != null && _kehadiranPerGuru.containsKey(guruId)) {
        _kehadiranPerGuru[guruId]![status] = (_kehadiranPerGuru[guruId]![status] ?? 0) + 1;
        _kehadiranPerGuru[guruId]!['total'] = (_kehadiranPerGuru[guruId]!['total'] ?? 0) + 1;
      }
    }
  }
  
  // Dapatkan nama guru berdasarkan ID
  String _getGuruName(String? guruId) {
    if (guruId == null) return 'Tidak diketahui';
    
    final guru = _allGuruData.firstWhere(
      (guru) => guru.id == guruId,
      orElse: () => Guru(id: '', nama: 'Tidak diketahui'),
    );
    
    return guru.nama;
  }
  
  // Tampilkan dialog pilih bulan
  Future<void> _selectMonth() async {
    final DateTime initialDate = _selectedDate;
    
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        int selectedYear = initialDate.year;
        int selectedMonth = initialDate.month;
        
        return AlertDialog(
          title: const Text('Pilih Periode'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SizedBox(
                height: 300,
                width: 300,
                child: Column(
                  children: [
                    // Pilihan tahun
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios),
                          onPressed: () {
                            setState(() {
                              selectedYear = selectedYear > 2020 ? selectedYear - 1 : selectedYear;
                            });
                          },
                        ),
                        Text(
                          selectedYear.toString(),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios),
                          onPressed: () {
                            setState(() {
                              selectedYear = selectedYear < 2030 ? selectedYear + 1 : selectedYear;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Grid bulan
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 3,
                        children: List.generate(12, (index) {
                          final month = index + 1;
                          final isSelected = month == selectedMonth;
                          final monthName = DateFormat('MMM', 'id_ID').format(DateTime(selectedYear, month));
                          
                          return InkWell(
                            onTap: () {
                              setState(() {
                                selectedMonth = month;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade400,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  monthName,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.black,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(DateTime(selectedYear, selectedMonth));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Pilih'),
            ),
          ],
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }
  
  // Widget untuk ringkasan statistik
  Widget _buildRingkasanStatistik() {
    final totalAbsensi = _totalHadir + _totalIzin + _totalSakit + _totalAlpa;
    
    // Hitung persentase kehadiran
    final double persentaseKehadiran = totalAbsensi > 0 
        ? (_totalHadir / totalAbsensi) * 100 
        : 0;
        
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Rekap Periode: ${DateFormat('MMMM yyyy').format(_selectedDate)}",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Ringkasan Utama
            Row(
              children: [
                // Persentase Kehadiran
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 120,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: CircularProgressIndicator(
                                value: persentaseKehadiran / 100,
                                strokeWidth: 10,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  persentaseKehadiran > 80 
                                      ? Colors.green 
                                      : persentaseKehadiran > 60 
                                          ? Colors.orange 
                                          : Colors.red
                                ),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "${persentaseKehadiran.toStringAsFixed(1)}%",
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text("Kehadiran")
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text("Total Guru: $_totalGuru"),
                    ],
                  ),
                ),
                
                // Detail Status
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusBar("Hadir", _totalHadir, totalAbsensi, Colors.green),
                      const SizedBox(height: 8),
                      _buildStatusBar("Izin", _totalIzin, totalAbsensi, Colors.orange),
                      const SizedBox(height: 8),
                      _buildStatusBar("Sakit", _totalSakit, totalAbsensi, Colors.blue),
                      const SizedBox(height: 8),
                      _buildStatusBar("Alpa", _totalAlpa, totalAbsensi, Colors.red),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusBar(String label, int value, int total, Color color) {
    final double percentage = total > 0 ? (value / total) * 100 : 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "$label: $value",
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
            const Spacer(),
            Text(
              "${percentage.toStringAsFixed(1)}%",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }
  
  // Widget untuk top kehadiran guru
  Widget _buildTopKehadiranGuru() {
    // Ambil 5 guru dengan kehadiran tertinggi
    final sortedGuru = _kehadiranPerGuru.entries.toList()
      ..sort((a, b) => (b.value['hadir'] ?? 0).compareTo(a.value['hadir'] ?? 0));
    
    final top5Guru = sortedGuru.take(5).toList();
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Guru dengan Kehadiran Tertinggi",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : top5Guru.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text("Belum ada data kehadiran"),
                        ),
                      )
                    : Column(
                        children: top5Guru.map((entry) {
                          final guru = _allGuruData.firstWhere(
                            (g) => g.id == entry.key,
                            orElse: () => Guru(id: '', nama: 'Unknown'),
                          );
                          
                          final hadirCount = entry.value['hadir'] ?? 0;
                          final totalCount = entry.value['total'] ?? 0;
                          final percentage = totalCount > 0 ? (hadirCount / totalCount) * 100 : 0;
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.green.withOpacity(0.2),
                                  child: Text(
                                    guru.nama.isNotEmpty ? guru.nama[0] : "?",
                                    style: const TextStyle(color: Colors.green),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        guru.nama,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: LinearProgressIndicator(
                                              value: percentage / 100,
                                              backgroundColor: Colors.grey[200],
                                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                                              minHeight: 6,
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "$hadirCount/$totalCount (${percentage.toStringAsFixed(0)}%)",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
          ],
        ),
      ),
    );
  }

  // Widget untuk daftar absensi
  Widget _buildAbsensiList() {
    if (_filteredAbsensiData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak ada data absensi untuk periode ini',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    // Kelompokkan absensi berdasarkan tanggal
    Map<String, List<dynamic>> groupedAbsensi = {};
    for (var absensi in _filteredAbsensiData) {
      final tanggal = absensi['tanggal'] ?? '';
      if (!groupedAbsensi.containsKey(tanggal)) {
        groupedAbsensi[tanggal] = [];
      }
      groupedAbsensi[tanggal]!.add(absensi);
    }
    
    // Urutkan tanggal dari terbaru
    final sortedDates = groupedAbsensi.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    
    return ListView.builder(
      itemCount: sortedDates.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final tanggal = sortedDates[index];
        final absensiList = groupedAbsensi[tanggal]!;
        final formattedDate = DateFormat('EEEE, dd MMMM yyyy', 'id_ID')
          .format(DateTime.parse(tanggal));
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header tanggal
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "${absensiList.length} guru",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Daftar absensi pada tanggal tersebut
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: absensiList.length,
                itemBuilder: (context, idx) {
                  final absensi = absensiList[idx];
                  final status = absensi['status']?.toString().toLowerCase() ?? 'hadir';
                  
                  Color statusColor;
                  IconData statusIcon;
                  
                  switch (status) {
                    case 'hadir':
                      statusColor = Colors.green;
                      statusIcon = Icons.check_circle;
                      break;
                    case 'izin':
                      statusColor = Colors.orange;
                      statusIcon = Icons.pending_actions;
                      break;
                    case 'sakit':
                      statusColor = Colors.blue;
                      statusIcon = Icons.medical_services;
                      break;
                    case 'alpa':
                      statusColor = Colors.red;
                      statusIcon = Icons.cancel;
                      break;
                    default:
                      statusColor = Colors.grey;
                      statusIcon = Icons.help;
                  }
                  
                  return InkWell(
                    onTap: () => _showAbsensiDetail(absensi),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: statusColor.withOpacity(0.2),
                            foregroundColor: statusColor,
                            radius: 18,
                            child: Icon(statusIcon, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getGuruName(absensi['guruId']?.toString()),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Masuk: ${absensi['jamMasuk'] ?? '-'}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.logout,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Keluar: ${absensi['jamKeluar'] ?? '-'}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Tampilkan detail absensi
  void _showAbsensiDetail(dynamic absensi) {
    final guruName = _getGuruName(absensi['guruId']?.toString());
    final tanggal = absensi['tanggal'] != null
        ? DateFormat('dd MMMM yyyy').format(DateTime.parse(absensi['tanggal']))
        : 'Tanggal tidak diketahui';
    final status = absensi['status']?.toString().toLowerCase() ?? 'hadir';
    
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'hadir':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'izin':
        statusColor = Colors.orange;
        statusIcon = Icons.pending_actions;
        break;
      case 'sakit':
        statusColor = Colors.blue;
        statusIcon = Icons.medical_services;
        break;
      case 'alpa':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(statusIcon, color: statusColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Detail Absensi',
                style: TextStyle(color: statusColor),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Nama Guru', guruName),
            _buildDetailRow('Tanggal', tanggal),
            _buildDetailRow('Status', status.toUpperCase()),
            _buildDetailRow('Jam Masuk', absensi['jamMasuk'] ?? '-'),
            _buildDetailRow('Jam Keluar', absensi['jamKeluar'] ?? '-'),
            if (absensi['keterangan'] != null && absensi['keterangan'].toString().isNotEmpty)
              _buildDetailRow('Keterangan', absensi['keterangan']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Tampilkan dialog filter
  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.filter_list),
                      SizedBox(width: 8),
                      Text(
                        'Filter Data',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String?>(
                    decoration: InputDecoration(
                      labelText: 'Guru',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    value: _selectedGuruId,
                    hint: const Text('Semua Guru'),
                    onChanged: (value) {
                      setState(() {
                        _selectedGuruId = value;
                      });
                    },
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Semua Guru'),
                      ),
                      ..._allGuruData.map((guru) {
                        return DropdownMenuItem<String>(
                          value: guru.id,
                          child: Text(guru.nama),
                        );
                      }).toList(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedGuruId = null;
                            });
                            Navigator.pop(context);
                            this.setState(() {});
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            this.setState(() {});
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Terapkan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Implementasi fungsi export ke Excel dengan support untuk Android 15
  Future<bool> requestStoragePermission() async {
    try {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

      // Untuk Android 13 (API level 33) dan diatas, kita tidak perlu izin storage
      // karena menggunakan SAF (Storage Access Framework)
      if (sdkInt >= 33) {
        return true; // Langsung return true karena menggunakan SAF
      } 
      // Untuk Android 10-12
      else if (sdkInt >= 29) {
      final status = await Permission.storage.request();
      return status.isGranted;
      } 
      // Untuk Android 9 dan di bawahnya
      else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  // Ganti _exportData dengan SAF yang lebih robust
  Future<void> _exportData() async {
    try {
      // Tampilkan dialog loading
      final loadingDialog = _showLoadingDialog('Mempersiapkan data...');

      // Buat Excel dengan Sheet1 default
    final excel = Excel.createExcel();
      print('📊 Sheet default yang dibuat: ${excel.sheets.keys.toList()}');
      
      // Dapatkan referensi ke Sheet1 dan rename menjadi "Rekap Absensi"
      if (excel.sheets.containsKey('Sheet1')) {
        excel.rename('Sheet1', 'Rekap Absensi');
        print('🔄 Sheet1 direname menjadi "Rekap Absensi"');
      }
      
      // Gunakan sheet "Rekap Absensi"
    final sheet = excel['Rekap Absensi'];
    
      // Jumlah hari dalam bulan yang dipilih
      final daysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
      
      // Tambahkan header
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = TextCellValue('NO');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value = TextCellValue('NAMA');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value = TextCellValue('');
      
      // Merge cell untuk header "TANGGAL"
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0), 
                 CellIndex.indexByColumnRow(columnIndex: 3 + daysInMonth - 1, rowIndex: 0));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0)).value = TextCellValue('TANGGAL');
      
      // Format header dengan style
      for (int i = 0; i <= 3 + daysInMonth - 1; i++) {
        final headerCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        headerCell.cellStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }
      
      // Tambahkan nomor tanggal sebagai header kolom
      for (int day = 1; day <= daysInMonth; day++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + day, rowIndex: 1)).value = TextCellValue('$day');
        final dayCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + day, rowIndex: 1));
        dayCell.cellStyle = CellStyle(
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }

      // Dapatkan data guru unik dari data absensi
      final List<Guru> guruList = _allGuruData.toList();
      
      // Mulai dari baris 2 untuk data guru
      int rowIndex = 2;
      for (int i = 0; i < guruList.length; i++) {
        final guru = guruList[i];
        
        // Set nomor urut dan nama guru (merge 3 baris untuk setiap guru)
        sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex), 
                   CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex + 2));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue('${i + 1}');
        
        sheet.merge(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex), 
                   CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex + 2));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue('${guru.nama}');
        
        // Tambahkan label "Datang" dan "Pulang" di kolom 3
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue('Datang');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex + 1)).value = TextCellValue('Pulang');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex + 2)).value = TextCellValue('TTD');
        
        // Style untuk cell guru
        for (int col = 0; col < 3; col++) {
          for (int r = 0; r < 3; r++) {
            final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex + r));
      cell.cellStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
          }
        }
        
        // Isi data absensi untuk setiap tanggal
        for (int day = 1; day <= daysInMonth; day++) {
          // Buat tanggal untuk pencarian data
          final date = DateTime(_selectedDate.year, _selectedDate.month, day);
          final formattedDate = DateFormat('yyyy-MM-dd').format(date);
          
          // Cari data absensi untuk guru dan tanggal ini
          final absensiData = _filteredAbsensiData.where((absensi) => 
            absensi['guruId']?.toString() == guru.id.toString() && 
            absensi['tanggal']?.startsWith(formattedDate) == true
          ).toList();
          
          if (absensiData.isNotEmpty) {
            final absensi = absensiData.first;
            String jamMasuk = '';
            String jamKeluar = '';
            
            // Format jam masuk
      if (absensi['jamMasuk'] != null) {
        try {
          final jamMasukDate = DateTime.parse(absensi['jamMasuk']);
                jamMasuk = DateFormat('HH:mm').format(jamMasukDate);
        } catch (e) {
                jamMasuk = '08:00';  // Default jika format tidak valid
        }
            } else {
              jamMasuk = '08:00';  // Default jika tidak ada data
      }
      
            // Format jam keluar
      if (absensi['jamKeluar'] != null) {
        try {
          final jamKeluarDate = DateTime.parse(absensi['jamKeluar']);
                jamKeluar = DateFormat('HH:mm').format(jamKeluarDate);
        } catch (e) {
                jamKeluar = '10:00';  // Default jika format tidak valid
              }
            } else {
              jamKeluar = '10:00';  // Default jika tidak ada data
            }
            
            // Isi jam masuk dan keluar
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + day, rowIndex: rowIndex)).value = TextCellValue(jamMasuk);
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + day, rowIndex: rowIndex + 1)).value = TextCellValue(jamKeluar);
          } else {
            // Default jika tidak ada data
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + day, rowIndex: rowIndex)).value = TextCellValue('');
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + day, rowIndex: rowIndex + 1)).value = TextCellValue('');
          }
          
          // Style untuk cell absensi
          for (int r = 0; r < 3; r++) {
            final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + day, rowIndex: rowIndex + r));
            cell.cellStyle = CellStyle(
              horizontalAlign: HorizontalAlign.Center,
              verticalAlign: VerticalAlign.Center,
            );
          }
        }
        
        // Pindah ke guru berikutnya (3 baris per guru)
        rowIndex += 3;
      }
      
      // Atur lebar kolom
      sheet.setColumnWidth(0, 5);  // NO
      sheet.setColumnWidth(1, 30); // NAMA
      sheet.setColumnWidth(2, 10); // Datang/Pulang
      
      // Atur lebar kolom tanggal
      for (int day = 1; day <= daysInMonth; day++) {
        sheet.setColumnWidth(2 + day, 6);  // Lebar untuk tanggal
      }
      
      // Hapus semua sheet lain selain "Rekap Absensi"
      final sheetNames = List<String>.from(excel.sheets.keys);
      print('🔍 Sheet sebelum pembersihan: $sheetNames');
      
      for (final name in sheetNames) {
        if (name != 'Rekap Absensi') {
          excel.delete(name);
          print('🗑️ Menghapus sheet: $name');
        }
      }
      
      // Verifikasi setelah pembersihan
      print('✅ Sheet setelah pembersihan: ${excel.sheets.keys.toList()}');
      
      // Generate file Excel
    final excelData = excel.encode();
    if (excelData == null) {
        Navigator.pop(context); // Tutup dialog loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghasilkan data Excel')),
      );
      return;
    }
    
    final monthYear = DateFormat('MMMM-yyyy', 'id_ID').format(_selectedDate);
      final fileName = 'rekap-absensi-$monthYear.xlsx';
      
      // Tutup dialog loading sebelum pengguna memilih folder
      Navigator.pop(context);

      // Fungsi untuk minta pengguna pilih folder
      Future<String?> _selectFolder({bool forceNew = false}) async {
        if (forceNew) {
          // Jika dipaksa pilih folder baru, hapus URI yang tersimpan
          await SAFHelper.clearSavedUri();
          
          // Tampilkan dialog petunjuk
          await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(
                  'Pilih Folder Baru',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anda akan diminta memilih folder untuk menyimpan file Excel.',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Pada Android 13 ke atas, silakan pilih folder Documents.',
                              style: TextStyle(color: Colors.blue.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                actions: <Widget>[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('OK'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        }
        
        // Cek apakah sudah pernah memilih folder
        String? uri = forceNew ? null : await SAFHelper.getSavedDocumentTreeUri();
        
        // Jika belum ada URI tersimpan, minta pengguna memilih folder
        if (uri == null) {
          // Tampilkan dialog petunjuk jika pertama kali
          if (!forceNew) {
            await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text(
                    'Pilih Folder Documents',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Anda akan diminta memilih folder untuk menyimpan file Excel.',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Pada Android 13 ke atas, silakan pilih folder Documents.',
                                style: TextStyle(color: Colors.blue.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  actions: <Widget>[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('OK'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              },
            );
          }

          // Minta pengguna memilih folder
          uri = await SAFHelper.openDocumentTree();
        }
        
        return uri;
      }
      
      // Pilih folder untuk menyimpan file
      String? uri = await _selectFolder();
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Export dibatalkan', style: TextStyle(fontSize: 16)),
              ],
            ),
            backgroundColor: Colors.blue.shade700,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
      );
      return;
    }

      // Tampilkan dialog loading kembali untuk proses ekspor
      final savingDialog = _showLoadingDialog('Menyimpan file...');

      // Convert ke Uint8List dan tulis file
    final Uint8List bytes = Uint8List.fromList(excelData);
      bool success = await SAFHelper.writeFileToUri(
      uri: uri,
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
      
      // Jika gagal, coba minta folder baru
      if (!success) {
        // Tutup dialog loading
        Navigator.pop(context);
        
        // Tanya pengguna apakah mau pilih folder baru
        final shouldSelectNewFolder = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 10),
                  Text(
                    'Gagal Menyimpan File',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gagal menyimpan file ke folder yang dipilih. Hal ini mungkin karena:',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('•', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text('Izin akses folder sudah tidak valid', 
                                style: TextStyle(color: Colors.red.shade900),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('•', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text('Folder yang dipilih tidak dapat ditulis', 
                                style: TextStyle(color: Colors.red.shade900),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Apakah anda ingin memilih folder lain?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              actions: <Widget>[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Batal'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Pilih Folder Baru'),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        ) ?? false;
        
        if (shouldSelectNewFolder) {
          // Pilih folder baru
          uri = await _selectFolder(forceNew: true);
          if (uri == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Export dibatalkan', style: TextStyle(fontSize: 16)),
                  ],
                ),
                backgroundColor: Colors.blue.shade700,
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.all(8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
            return;
          }
          
          // Tampilkan dialog loading kembali
          final retryDialog = _showLoadingDialog('Mencoba menyimpan ulang...');
          
          // Coba simpan file lagi
          success = await SAFHelper.writeFileToUri(
            uri: uri,
            fileName: fileName,
            bytes: bytes,
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          );
          
          // Tutup dialog loading
          Navigator.pop(context);
        } else {
          return;
        }
      } else {
        // Tutup dialog loading jika berhasil di percobaan pertama
        Navigator.pop(context);
      }
      
    if (success) {
        // Simpan file ke lokasi sementara untuk fitur buka dan bagikan
        final tempFilePath = await _getExternalFilePath(uri, fileName);
        
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'File berhasil disimpan',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: Duration(seconds: 10),
            // Menggunakan actionOverflowThreshold untuk menampilkan semua tombol
            actionOverflowThreshold: 1,
            action: SnackBarAction(
              label: 'PILIH FOLDER LAIN',
              textColor: Colors.white,
              onPressed: () async {
                final newUri = await _selectFolder(forceNew: true);
                if (newUri != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Folder baru dipilih untuk ekspor berikutnya'),
                      backgroundColor: Colors.blue.shade700,
                      behavior: SnackBarBehavior.floating,
                      margin: EdgeInsets.all(8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                }
              },
            ),
          ),
        );
        
        // Tampilkan dialog dengan tombol Bagikan dan Buka
        if (tempFilePath != null) {
          showDialog(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 10),
                  Text(
                    'File Excel Berhasil Disimpan',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'File rekap absensi telah berhasil disimpan ke folder Documents. Anda dapat:',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.folder_open),
                          label: Text('BUKA'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _openFile(tempFilePath);
                          },
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.share),
                          label: Text('BAGIKAN'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _shareFile(tempFilePath);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              actions: <Widget>[
                TextButton(
                  child: Text('TUTUP'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Gagal export file setelah beberapa percobaan',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      // Pastikan dialog loading ditutup jika terjadi error
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Error: ${e.toString()}',
                  style: TextStyle(fontSize: 16),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: Duration(seconds: 10),
        ),
      );
    }
  }
  
  // Dialog loading
  dynamic _showLoadingDialog(String message) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // Fungsi untuk membuka file Excel
  Future<void> _openFile(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Gagal membuka file: ${result.message}')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Error: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  // Fungsi untuk membagikan file Excel
  Future<void> _shareFile(String filePath) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Rekap Absensi ${DateFormat('MMMM yyyy', 'id_ID').format(_selectedDate)}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Gagal membagikan file: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }
  
  // Fungsi untuk mendapatkan path file dari storage Android
  Future<String?> _getExternalFilePath(String uri, String fileName) async {
    try {
      // Untuk Android 10 ke atas, kita perlu tempat sementara untuk membuka/bagikan file
      final tempFile = await SAFHelper.getTempFile(fileName);
      if (tempFile != null) {
        return tempFile.path;
      }
      
      // Jika tidak ada file sementara, buat file dari data yang sama
      final tempDir = await getTemporaryDirectory();
      final tempFilePath = '${tempDir.path}/$fileName';
      
      // Buat file Excel dari data
      final excel = await _createExcelFile();
      if (excel != null) {
        final file = File(tempFilePath);
        await file.writeAsBytes(excel);
        return tempFilePath;
      }
      
      return null;
    } catch (e) {
      print('Error getting file path: $e');
      return null;
    }
  }
  
  // Fungsi untuk membuat file Excel
  Future<Uint8List?> _createExcelFile() async {
    try {
      // Buat Excel dengan Sheet1 default
      final excel = Excel.createExcel();
      print('📊 Sheet default yang dibuat: ${excel.sheets.keys.toList()}');
      
      // Dapatkan referensi ke Sheet1 dan rename menjadi "Rekap Absensi"
      if (excel.sheets.containsKey('Sheet1')) {
        excel.rename('Sheet1', 'Rekap Absensi');
        print('🔄 Sheet1 direname menjadi "Rekap Absensi"');
      }
      
      // Gunakan sheet "Rekap Absensi"
      final sheet = excel['Rekap Absensi'];

      // Jumlah hari dalam bulan yang dipilih
      final daysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
      
      // Tambahkan header
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = TextCellValue('NO');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value = TextCellValue('NAMA');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value = TextCellValue('');
      
      // Merge cell untuk header "TANGGAL"
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0), 
                 CellIndex.indexByColumnRow(columnIndex: 3 + daysInMonth - 1, rowIndex: 0));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0)).value = TextCellValue('TANGGAL');
      
      // Format header dengan style
      for (int i = 0; i <= 3 + daysInMonth - 1; i++) {
        final headerCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        headerCell.cellStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }
      
      // Tambahkan nomor tanggal sebagai header kolom
      for (int day = 1; day <= daysInMonth; day++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + day, rowIndex: 1)).value = TextCellValue('$day');
        final dayCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + day, rowIndex: 1));
        dayCell.cellStyle = CellStyle(
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }

      // Dapatkan data guru unik dari data absensi
      final List<Guru> guruList = _allGuruData.toList();
      
      // Mulai dari baris 2 untuk data guru
      int rowIndex = 2;
      for (int i = 0; i < guruList.length; i++) {
        final guru = guruList[i];
        
        // Set nomor urut dan nama guru (merge 3 baris untuk setiap guru)
        sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex), 
                   CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex + 2));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue('${i + 1}');
        
        sheet.merge(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex), 
                   CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex + 2));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue('${guru.nama}');
        
        // Tambahkan label "Datang" dan "Pulang" di kolom 3
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue('Datang');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex + 1)).value = TextCellValue('Pulang');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex + 2)).value = TextCellValue('TTD');
        
        // Style untuk cell guru
        for (int col = 0; col < 3; col++) {
          for (int r = 0; r < 3; r++) {
            final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex + r));
            cell.cellStyle = CellStyle(
              horizontalAlign: HorizontalAlign.Center,
              verticalAlign: VerticalAlign.Center,
            );
          }
        }
        
        // Isi data absensi untuk setiap tanggal
        for (int day = 1; day <= daysInMonth; day++) {
          // Buat tanggal untuk pencarian data
          final date = DateTime(_selectedDate.year, _selectedDate.month, day);
          final formattedDate = DateFormat('yyyy-MM-dd').format(date);
          
          // Cari data absensi untuk guru dan tanggal ini
          final absensiData = _filteredAbsensiData.where((absensi) => 
            absensi['guruId']?.toString() == guru.id.toString() && 
            absensi['tanggal']?.startsWith(formattedDate) == true
          ).toList();
          
          if (absensiData.isNotEmpty) {
            final absensi = absensiData.first;
            String jamMasuk = '';
            String jamKeluar = '';
            
            // Format jam masuk
            if (absensi['jamMasuk'] != null) {
              try {
                final jamMasukDate = DateTime.parse(absensi['jamMasuk']);
                jamMasuk = DateFormat('HH:mm').format(jamMasukDate);
              } catch (e) {
                jamMasuk = '08:00';  // Default jika format tidak valid
              }
            } else {
              jamMasuk = '08:00';  // Default jika tidak ada data
            }
            
            // Format jam keluar
            if (absensi['jamKeluar'] != null) {
              try {
                final jamKeluarDate = DateTime.parse(absensi['jamKeluar']);
                jamKeluar = DateFormat('HH:mm').format(jamKeluarDate);
              } catch (e) {
                jamKeluar = '10:00';  // Default jika format tidak valid
              }
            } else {
              jamKeluar = '10:00';  // Default jika tidak ada data
            }
            
            // Isi jam masuk dan keluar
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + day, rowIndex: rowIndex)).value = TextCellValue(jamMasuk);
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + day, rowIndex: rowIndex + 1)).value = TextCellValue(jamKeluar);
          } else {
            // Default jika tidak ada data
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + day, rowIndex: rowIndex)).value = TextCellValue('');
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + day, rowIndex: rowIndex + 1)).value = TextCellValue('');
          }
          
          // Style untuk cell absensi
          for (int r = 0; r < 3; r++) {
            final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + day, rowIndex: rowIndex + r));
            cell.cellStyle = CellStyle(
              horizontalAlign: HorizontalAlign.Center,
              verticalAlign: VerticalAlign.Center,
            );
          }
        }
        
        // Pindah ke guru berikutnya (3 baris per guru)
        rowIndex += 3;
      }
      
      // Atur lebar kolom
      sheet.setColumnWidth(0, 5);  // NO
      sheet.setColumnWidth(1, 30); // NAMA
      sheet.setColumnWidth(2, 10); // Datang/Pulang
      
      // Atur lebar kolom tanggal
      for (int day = 1; day <= daysInMonth; day++) {
        sheet.setColumnWidth(2 + day, 6);  // Lebar untuk tanggal
      }
      
      // Hapus semua sheet lain selain "Rekap Absensi"
      final sheetNames = List<String>.from(excel.sheets.keys);
      print('🔍 Sheet sebelum pembersihan (createExcel): $sheetNames');
      
      for (final name in sheetNames) {
        if (name != 'Rekap Absensi') {
          excel.delete(name);
          print('🗑️ Menghapus sheet: $name');
        }
      }
      
      // Verifikasi setelah pembersihan
      print('✅ Sheet setelah pembersihan (createExcel): ${excel.sheets.keys.toList()}');
      
      // Generate file Excel
      final excelBytes = excel.encode();
      if (excelBytes == null) {
        return null;
      }
      
      return Uint8List.fromList(excelBytes);
    } catch (e) {
      print('Error creating Excel file: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekap Absensi'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _selectMonth,
            tooltip: 'Pilih Periode',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportData,
            tooltip: 'Export',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Header dengan periode yang dipilih
                    Container(
                      color: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('MMMM yyyy').format(_selectedDate),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${_filteredAbsensiData.length} absensi",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Tab bar
                    TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Statistik'),
                        Tab(text: 'Daftar Absensi'),
                      ],
                      labelColor: Theme.of(context).primaryColor,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Theme.of(context).primaryColor,
                      indicatorWeight: 3,
                    ),
                    
                    // Tab content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Tab Statistik
                          RefreshIndicator(
                            onRefresh: _loadData,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  _buildRingkasanStatistik(),
                                  const SizedBox(height: 16),
                                  _buildTopKehadiranGuru(),
                                ],
                              ),
                            ),
                          ),
                          
                          // Tab Daftar Absensi
                          RefreshIndicator(
                            onRefresh: _loadData,
                            child: _buildAbsensiList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
} 