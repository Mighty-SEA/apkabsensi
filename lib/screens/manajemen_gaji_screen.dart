import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pengaturan_gaji_model.dart';
import '../models/guru_model.dart';
import '../services/api_service.dart';
import 'package:another_flushbar/flushbar.dart';

class ManajemenGajiScreen extends StatefulWidget {
  const ManajemenGajiScreen({Key? key}) : super(key: key);

  @override
  State<ManajemenGajiScreen> createState() => _ManajemenGajiScreenState();
}

class _ManajemenGajiScreenState extends State<ManajemenGajiScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String _error = '';
  
  // Data
  List<GajiGuru> _daftarGaji = [];
  List<Guru> _daftarGuru = [];
  String _selectedPeriode = '';
  
  @override
  void initState() {
    super.initState();
    // Set periode default ke bulan ini
    _selectedPeriode = DateFormat('yyyy-MM').format(DateTime.now());
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    
    try {
      // Load data guru
      final resultGuru = await _apiService.getGuruData();
      if (!resultGuru['success']) {
        setState(() {
          _error = resultGuru['message'] ?? 'Gagal memuat data guru';
          _isLoading = false;
        });
        return;
      }
      
      // Load data gaji untuk periode yang dipilih
      final resultGaji = await _apiService.getDaftarGajiGuru(periode: _selectedPeriode);
      if (!resultGaji['success']) {
        setState(() {
          _error = resultGaji['message'] ?? 'Gagal memuat data gaji';
          _isLoading = false;
        });
        return;
      }
      
      // Parse data
      final daftarGuru = (resultGuru['data'] as List).map((e) => Guru.fromJson(e)).toList();
      List<GajiGuru> daftarGaji = [];
      
      if (resultGaji['data'] != null && resultGaji['data'] is List) {
        daftarGaji = (resultGaji['data'] as List).map((e) => GajiGuru.fromJson(e)).toList();
      }
      
      setState(() {
        _daftarGuru = daftarGuru;
        _daftarGaji = daftarGaji;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Terjadi kesalahan: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _hitungGajiSemuaGuru() async {
    // Konfirmasi
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Hitung ulang gaji semua guru untuk periode ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hitung'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      print('Memulai proses perhitungan gaji untuk periode: $_selectedPeriode');
      final result = await _apiService.hitungSemuaGajiGuru(_selectedPeriode);
      print('Hasil perhitungan gaji: $result');
      
      setState(() {
        _isLoading = false;
      });
      
      if (result['success']) {
        Flushbar(
          message: result['message'] ?? 'Berhasil menghitung gaji semua guru',
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          flushbarPosition: FlushbarPosition.TOP,
          borderRadius: BorderRadius.circular(12),
          margin: const EdgeInsets.all(16),
          icon: const Icon(Icons.check_circle, color: Colors.white),
          shouldIconPulse: false,
          isDismissible: true,
          forwardAnimationCurve: Curves.easeOutBack,
          reverseAnimationCurve: Curves.easeInBack,
        )..show(context);
        
        // Reload data
        _loadData();
      } else {
        Flushbar(
          message: result['message'] ?? 'Gagal menghitung gaji guru',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          flushbarPosition: FlushbarPosition.TOP,
          borderRadius: BorderRadius.circular(12),
          margin: const EdgeInsets.all(16),
          icon: const Icon(Icons.error, color: Colors.white),
          shouldIconPulse: false,
          isDismissible: true,
          forwardAnimationCurve: Curves.easeOutBack,
          reverseAnimationCurve: Curves.easeInBack,
        )..show(context);
      }
    } catch (e) {
      print('Error saat menghitung gaji: $e');
      setState(() {
        _isLoading = false;
      });
      
      Flushbar(
        message: 'Terjadi kesalahan: $e',
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        flushbarPosition: FlushbarPosition.TOP,
        borderRadius: BorderRadius.circular(12),
        margin: const EdgeInsets.all(16),
        icon: const Icon(Icons.error, color: Colors.white),
        shouldIconPulse: false,
        isDismissible: true,
        forwardAnimationCurve: Curves.easeOutBack,
        reverseAnimationCurve: Curves.easeInBack,
      )..show(context);
    }
  }
  
  Future<void> _hitungGajiGuru(String guruId, String namaGuru) async {
    // Konfirmasi
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: Text('Hitung ulang gaji untuk $namaGuru?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hitung'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await _apiService.hitungGajiGuru(guruId, _selectedPeriode);
      
      setState(() {
        _isLoading = false;
      });
      
      if (result['success']) {
        Flushbar(
          message: 'Berhasil menghitung gaji untuk $namaGuru',
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          flushbarPosition: FlushbarPosition.TOP,
          borderRadius: BorderRadius.circular(12),
          margin: const EdgeInsets.all(16),
          icon: const Icon(Icons.check_circle, color: Colors.white),
          shouldIconPulse: false,
          isDismissible: true,
          forwardAnimationCurve: Curves.easeOutBack,
          reverseAnimationCurve: Curves.easeInBack,
        )..show(context);
        
        // Reload data
        _loadData();
      } else {
        Flushbar(
          message: result['message'] ?? 'Gagal menghitung gaji guru',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          flushbarPosition: FlushbarPosition.TOP,
          borderRadius: BorderRadius.circular(12),
          margin: const EdgeInsets.all(16),
          icon: const Icon(Icons.error, color: Colors.white),
          shouldIconPulse: false,
          isDismissible: true,
          forwardAnimationCurve: Curves.easeOutBack,
          reverseAnimationCurve: Curves.easeInBack,
        )..show(context);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      Flushbar(
        message: 'Terjadi kesalahan: $e',
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        flushbarPosition: FlushbarPosition.TOP,
        borderRadius: BorderRadius.circular(12),
        margin: const EdgeInsets.all(16),
        icon: const Icon(Icons.error, color: Colors.white),
        shouldIconPulse: false,
        isDismissible: true,
        forwardAnimationCurve: Curves.easeOutBack,
        reverseAnimationCurve: Curves.easeInBack,
      )..show(context);
    }
  }
  
  Future<void> _bayarGaji(GajiGuru gaji) async {
    // Konfirmasi
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Pembayaran'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tandai gaji ${gaji.namaGuru} sebagai sudah dibayar?'),
            const SizedBox(height: 16),
            Text('Total: ${gaji.totalGajiFormatted}'),
            Text('Periode: ${DateFormat('MMMM yyyy', 'id_ID').format(DateTime.parse(gaji.periode + '-01'))}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Bayar'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await _apiService.bayarGajiGuru(gaji.id);
      
      setState(() {
        _isLoading = false;
      });
      
      if (result['success']) {
        Flushbar(
          message: 'Gaji ${gaji.namaGuru} berhasil ditandai sebagai dibayar',
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          flushbarPosition: FlushbarPosition.TOP,
          borderRadius: BorderRadius.circular(12),
          margin: const EdgeInsets.all(16),
          icon: const Icon(Icons.check_circle, color: Colors.white),
          shouldIconPulse: false,
          isDismissible: true,
          forwardAnimationCurve: Curves.easeOutBack,
          reverseAnimationCurve: Curves.easeInBack,
        )..show(context);
        
        // Reload data
        _loadData();
      } else {
        Flushbar(
          message: result['message'] ?? 'Gagal menandai gaji sebagai dibayar',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          flushbarPosition: FlushbarPosition.TOP,
          borderRadius: BorderRadius.circular(12),
          margin: const EdgeInsets.all(16),
          icon: const Icon(Icons.error, color: Colors.white),
          shouldIconPulse: false,
          isDismissible: true,
          forwardAnimationCurve: Curves.easeOutBack,
          reverseAnimationCurve: Curves.easeInBack,
        )..show(context);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      Flushbar(
        message: 'Terjadi kesalahan: $e',
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        flushbarPosition: FlushbarPosition.TOP,
        borderRadius: BorderRadius.circular(12),
        margin: const EdgeInsets.all(16),
        icon: const Icon(Icons.error, color: Colors.white),
        shouldIconPulse: false,
        isDismissible: true,
        forwardAnimationCurve: Curves.easeOutBack,
        reverseAnimationCurve: Curves.easeInBack,
      )..show(context);
    }
  }
  
  Future<void> _pilihPeriode() async {
    final DateTime initialDate = _selectedPeriode.isNotEmpty
        ? DateTime.parse('${_selectedPeriode}-01')
        : DateTime.now();
    
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
      final newPeriode = DateFormat('yyyy-MM').format(picked);
      if (newPeriode != _selectedPeriode) {
        setState(() {
          _selectedPeriode = newPeriode;
        });
        _loadData();
      }
    }
  }
  
  void _showDetailGaji(GajiGuru gaji) {
    final formattedPeriode = DateFormat('MMMM yyyy', 'id_ID').format(DateTime.parse('${gaji.periode}-01'));
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.primaryColor.withOpacity(0.1),
                      child: Icon(
                        Icons.person,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gaji.namaGuru,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Periode: $formattedPeriode',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: gaji.sudahDibayar ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        gaji.sudahDibayar ? 'Sudah Dibayar' : 'Belum Dibayar',
                        style: TextStyle(
                          color: gaji.sudahDibayar ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Detail gaji
                _buildDetailItem('Gaji Pokok', gaji.gajiPokokFormatted),
                
                const Divider(),
                
                // Detail kehadiran
                _buildDetailItem('Jumlah Hadir', '${gaji.jumlahHadir} hari'),
                _buildDetailItem('Jumlah Izin', '${gaji.jumlahIzin} hari'),
                _buildDetailItem('Jumlah Sakit', '${gaji.jumlahSakit} hari'),
                _buildDetailItem('Jumlah Alpa', '${gaji.jumlahAlpa} hari'),
                
                const Divider(),
                
                // Detail potongan
                _buildDetailItem(
                  'Potongan Izin', 
                  '${gaji.jumlahIzin} × ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(gaji.potonganIzin)}'
                ),
                _buildDetailItem(
                  'Potongan Sakit', 
                  '${gaji.jumlahSakit} × ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(gaji.potonganSakit)}'
                ),
                _buildDetailItem(
                  'Potongan Alpa', 
                  '${gaji.jumlahAlpa} × ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(gaji.potonganAlpa)}'
                ),
                
                const Divider(),
                
                // Total
                _buildDetailItem('Total Potongan', gaji.totalPotonganFormatted, isTotal: true),
                _buildDetailItem('Total Gaji', gaji.totalGajiFormatted, isTotal: true, highlight: true),
                
                const SizedBox(height: 24),
                
                // Tombol
                if (!gaji.sudahDibayar)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _bayarGaji(gaji);
                      },
                      icon: const Icon(Icons.payment),
                      label: const Text('Tandai Sudah Dibayar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildDetailItem(String label, String value, {bool isTotal = false, bool highlight = false}) {
    final textColor = highlight ? Theme.of(context).primaryColor : null;
    final fontWeight = isTotal || highlight ? FontWeight.bold : null;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: fontWeight,
              color: textColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: fontWeight,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.money_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada data gaji untuk periode ini',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _hitungGajiSemuaGuru,
            icon: const Icon(Icons.calculate),
            label: const Text('Hitung Gaji Semua Guru'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedPeriode = _selectedPeriode.isNotEmpty
        ? DateFormat('MMMM yyyy', 'id_ID').format(DateTime.parse('${_selectedPeriode}-01'))
        : '';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Gaji Guru'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _pilihPeriode,
            tooltip: 'Pilih Periode',
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
                    // Header periode
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
                            'Periode: $formattedPeriode',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _hitungGajiSemuaGuru,
                            icon: const Icon(Icons.calculate, color: Colors.white),
                            label: const Text(
                              'Hitung Ulang',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Daftar gaji
                    Expanded(
                      child: _daftarGaji.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              itemCount: _daftarGaji.length,
                              padding: const EdgeInsets.all(12),
                              itemBuilder: (context, index) {
                                final gaji = _daftarGaji[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: InkWell(
                                    onTap: () => _showDetailGaji(gaji),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: _getAvatarColor(gaji.namaGuru),
                                                radius: 24,
                                                child: Text(
                                                  gaji.namaGuru.isNotEmpty ? gaji.namaGuru[0].toUpperCase() : '?',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      gaji.namaGuru,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.event,
                                                          size: 14,
                                                          color: Colors.grey[600],
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          DateFormat('MMMM yyyy', 'id_ID').format(DateTime.parse('${gaji.periode}-01')),
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color: Colors.grey[600],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    gaji.totalGajiFormatted,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Theme.of(context).primaryColor,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: gaji.sudahDibayar ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Text(
                                                      gaji.sudahDibayar ? 'Sudah Dibayar' : 'Belum Dibayar',
                                                      style: TextStyle(
                                                        color: gaji.sudahDibayar ? Colors.green : Colors.orange,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          const Divider(height: 1),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              _buildStatChip(
                                                Icons.check_circle,
                                                Colors.green,
                                                'Hadir',
                                                gaji.jumlahHadir.toString(),
                                              ),
                                              _buildStatChip(
                                                Icons.pending_actions,
                                                Colors.orange,
                                                'Izin',
                                                gaji.jumlahIzin.toString(),
                                              ),
                                              _buildStatChip(
                                                Icons.medical_services,
                                                Colors.blue,
                                                'Sakit',
                                                gaji.jumlahSakit.toString(),
                                              ),
                                              _buildStatChip(
                                                Icons.cancel,
                                                Colors.red,
                                                'Alpa',
                                                gaji.jumlahAlpa.toString(),
                                              ),
                                            ],
                                          ),
                                          if (!gaji.sudahDibayar) ...[
                                            const SizedBox(height: 16),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                OutlinedButton.icon(
                                                  onPressed: () => _hitungGajiGuru(gaji.guruId, gaji.namaGuru),
                                                  icon: const Icon(Icons.refresh, size: 16),
                                                  label: const Text('Hitung Ulang'),
                                                  style: OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                ),
                                                ElevatedButton.icon(
                                                  onPressed: () => _bayarGaji(gaji),
                                                  icon: const Icon(Icons.payment, size: 16),
                                                  label: const Text('Bayar'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
  
  Widget _buildStatChip(IconData icon, Color color, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  // Metode untuk mendapatkan warna avatar berdasarkan nama
  Color _getAvatarColor(String name) {
    if (name.isEmpty) return Colors.blue;
    
    // Gunakan hashCode untuk mendapatkan warna yang konsisten untuk nama yang sama
    final colorIndex = name.hashCode % _avatarColors.length;
    return _avatarColors[colorIndex];
  }
  
  // Daftar warna untuk avatar
  final List<Color> _avatarColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pinkAccent,
    Colors.indigo,
    Colors.brown,
    Colors.deepOrange,
    Colors.cyan,
  ];
} 