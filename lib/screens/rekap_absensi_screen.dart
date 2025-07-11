import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/absensi_model.dart';
import '../models/guru_model.dart';
import '../services/api_service.dart';

class RekapAbsensiScreen extends StatefulWidget {
  const RekapAbsensiScreen({Key? key}) : super(key: key);

  @override
  State<RekapAbsensiScreen> createState() => _RekapAbsensiScreenState();
}

class _RekapAbsensiScreenState extends State<RekapAbsensiScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String _error = '';
  
  // Data rekap
  List<dynamic> _allAbsensiData = [];
  List<Guru> _allGuruData = [];
  
  // Data filter
  DateTime _selectedDate = DateTime.now();
  String? _selectedGuruId;
  String _searchQuery = '';
  
  // Controller untuk pencarian
  final TextEditingController _searchController = TextEditingController();
  
  // Data statistik
  int _totalHadir = 0;
  int _totalIzin = 0;
  int _totalSakit = 0;
  int _totalAlpa = 0;
  int _totalGuru = 0;
  
  @override
  void initState() {
    super.initState();
    _loadData();
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
      
      setState(() {
        _allGuruData = (guruResult['data'] as List).map((e) => Guru.fromJson(e)).toList();
        _allAbsensiData = filteredAbsensi;
        _totalGuru = _allGuruData.length;
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
    if (_selectedGuruId == null && _searchQuery.isEmpty) {
      return _allAbsensiData;
    }
    
    return _allAbsensiData.where((absen) {
      bool matchesGuru = _selectedGuruId == null || absen['guruId'].toString() == _selectedGuruId;
      bool matchesSearch = _searchQuery.isEmpty || 
                          absen['namaGuru'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      
      return matchesGuru && matchesSearch;
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
  
  // Dapatkan nama guru berdasarkan ID
  String _getGuruName(String? guruId) {
    if (guruId == null) return 'Tidak diketahui';
    
    final guru = _allGuruData.firstWhere(
      (guru) => guru.id == guruId,
      orElse: () => Guru(id: '', nama: 'Tidak diketahui', nip: ''),
    );
    
    return guru.nama;
  }
  
  // Tampilkan dialog pilih bulan
  Future<void> _selectMonth() async {
    final DateTime initialDate = _selectedDate;
    
    // Gunakan year picker terlebih dahulu
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        int selectedYear = initialDate.year;
        int selectedMonth = initialDate.month;
        final currentYear = DateTime.now().year;
        
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
  
  // Widget untuk tampilan statistik
  Widget _buildStatisticsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insert_chart,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Statistik Absensi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    Icons.check_circle,
                    Colors.green,
                    'Hadir',
                    _totalHadir.toString(),
                  ),
                ),
                Expanded(
                  child: _buildStatCard(
                    Icons.pending_actions,
                    Colors.orange,
                    'Izin',
                    _totalIzin.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    Icons.medical_services,
                    Colors.blue,
                    'Sakit',
                    _totalSakit.toString(),
                  ),
                ),
                Expanded(
                  child: _buildStatCard(
                    Icons.cancel,
                    Colors.red,
                    'Alpa',
                    _totalAlpa.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_totalHadir + _totalIzin + _totalSakit + _totalAlpa > 0)
              SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: [
                      PieChartSectionData(
                        color: Colors.green,
                        value: _totalHadir.toDouble(),
                        title: '${(_totalHadir / (_totalHadir + _totalIzin + _totalSakit + _totalAlpa) * 100).toStringAsFixed(1)}%',
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        color: Colors.orange,
                        value: _totalIzin.toDouble(),
                        title: '${(_totalIzin / (_totalHadir + _totalIzin + _totalSakit + _totalAlpa) * 100).toStringAsFixed(1)}%',
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        color: Colors.blue,
                        value: _totalSakit.toDouble(),
                        title: '${(_totalSakit / (_totalHadir + _totalIzin + _totalSakit + _totalAlpa) * 100).toStringAsFixed(1)}%',
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        color: Colors.red,
                        value: _totalAlpa.toDouble(),
                        title: '${(_totalAlpa / (_totalHadir + _totalIzin + _totalSakit + _totalAlpa) * 100).toStringAsFixed(1)}%',
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(Colors.green, 'Hadir'),
                const SizedBox(width: 16),
                _buildLegendItem(Colors.orange, 'Izin'),
                const SizedBox(width: 16),
                _buildLegendItem(Colors.blue, 'Sakit'),
                const SizedBox(width: 16),
                _buildLegendItem(Colors.red, 'Alpa'),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard(IconData icon, Color color, String label, String value) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
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
    
    return ListView.builder(
      itemCount: _filteredAbsensiData.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final absensi = _filteredAbsensiData[index];
        final status = absensi['status']?.toString().toLowerCase() ?? 'hadir';
        final tanggal = absensi['tanggal'] != null
            ? DateFormat('dd MMMM yyyy').format(DateTime.parse(absensi['tanggal']))
            : 'Tanggal tidak diketahui';
            
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
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.2),
              foregroundColor: statusColor,
              radius: 20,
              child: Icon(statusIcon),
            ),
            title: Text(
              _getGuruName(absensi['guruId']?.toString()),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(tanggal),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Masuk: ${absensi['jamMasuk'] ?? '-'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.logout,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Keluar: ${absensi['jamKeluar'] ?? '-'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Container(
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
            onTap: () => _showAbsensiDetail(absensi),
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
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detail Absensi - $guruName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tanggal: $tanggal'),
            const SizedBox(height: 8),
            Text('Status: ${status.toUpperCase()}'),
            const SizedBox(height: 8),
            Text('Jam Masuk: ${absensi['jamMasuk'] ?? '-'}'),
            const SizedBox(height: 8),
            Text('Jam Keluar: ${absensi['jamKeluar'] ?? '-'}'),
            if (absensi['keterangan'] != null && absensi['keterangan'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Keterangan: ${absensi['keterangan']}'),
            ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekap Absensi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _selectMonth,
            tooltip: 'Pilih Bulan',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh Data',
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
                    // Bulan yang dipilih
                    Container(
                      color: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Periode: ${DateFormat('MMMM yyyy').format(_selectedDate)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Total Guru: $_totalGuru',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Konten dengan scroll
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            // Filter dan pencarian
                            Container(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  // Filter guru
                                  DropdownButtonFormField<String?>(
                                    decoration: InputDecoration(
                                      labelText: 'Filter Guru',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      prefixIcon: const Icon(Icons.person),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
                                  
                                  const SizedBox(height: 12),
                                  
                                  // Pencarian
                                  TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      labelText: 'Cari Guru',
                                      hintText: 'Masukkan nama guru',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      prefixIcon: const Icon(Icons.search),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear),
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(() {
                                                  _searchQuery = '';
                                                });
                                              },
                                            )
                                          : null,
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            
                            // Statistik
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: _buildStatisticsCard(),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Label untuk daftar absensi
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.list_alt,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Daftar Absensi',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_filteredAbsensiData.length} data',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Daftar absensi
                            ListView.builder(
                              itemCount: _filteredAbsensiData.length,
                              padding: const EdgeInsets.all(8),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemBuilder: (context, index) {
                                final absensi = _filteredAbsensiData[index];
                                final status = absensi['status']?.toString().toLowerCase() ?? 'hadir';
                                final tanggal = absensi['tanggal'] != null
                                    ? DateFormat('dd MMMM yyyy').format(DateTime.parse(absensi['tanggal']))
                                    : 'Tanggal tidak diketahui';
                                    
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
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      backgroundColor: statusColor.withOpacity(0.2),
                                      foregroundColor: statusColor,
                                      radius: 20,
                                      child: Icon(statusIcon),
                                    ),
                                    title: Text(
                                      _getGuruName(absensi['guruId']?.toString()),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(tanggal),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.access_time,
                                              size: 14,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Masuk: ${absensi['jamMasuk'] ?? '-'}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                            const SizedBox(width: 12),
                                            const Icon(
                                              Icons.logout,
                                              size: 14,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Keluar: ${absensi['jamKeluar'] ?? '-'}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: Container(
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
                                    onTap: () => _showAbsensiDetail(absensi),
                                  ),
                                );
                              },
                            ),
                            // Tambahkan padding di bagian bawah untuk memastikan konten terakhir terlihat
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
} 