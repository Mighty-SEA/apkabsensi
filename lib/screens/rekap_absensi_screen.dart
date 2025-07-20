import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/absensi_model.dart';
import '../models/guru_model.dart';
import '../services/api_service.dart';
import 'dart:math' as math;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekap Absensi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _selectMonth,
            tooltip: 'Pilih Periode',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
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