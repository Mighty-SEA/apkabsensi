import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/guru_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'package:another_flushbar/flushbar.dart';

class AbsensiAdminScreen extends StatefulWidget {
  const AbsensiAdminScreen({Key? key}) : super(key: key);

  @override
  State<AbsensiAdminScreen> createState() => _AbsensiAdminScreenState();
}

class _AbsensiAdminScreenState extends State<AbsensiAdminScreen> with AutomaticKeepAliveClientMixin {
  final ApiService _apiService = ApiService();
  List<Guru> _guruList = [];
  bool _isLoading = true;
  String _error = '';
  Map<String, String?> _absenStatus = {}; // idGuru: status
  bool _isSubmitting = false;
  
  // Tambahkan tanggal yang dipilih
  DateTime _selectedDate = DateTime.now();
  String get _formattedDate => DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_selectedDate);
  String get _apiFormattedDate => DateFormat('yyyy-MM-dd').format(_selectedDate);

  @override
  bool get wantKeepAlive => true; // Agar status tidak reset saat berpindah tab

  @override
  void initState() {
    super.initState();
    // Panggil fungsi untuk load data guru terlebih dahulu, kemudian load data absensi
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    
    try {
      // Ambil data guru terlebih dahulu
      final resultGuru = await _apiService.getGuruData();
      
      if (resultGuru['success']) {
        if (mounted) {
          setState(() {
            _guruList = (resultGuru['data'] as List).map((e) => Guru.fromJson(e)).toList();
          });
        }
        
        // Setelah berhasil mendapatkan data guru, ambil data absensi
        await _fetchAbsensiByDate();
      } else {
        if (mounted) {
          setState(() {
            _error = resultGuru['message'] ?? 'Gagal memuat data guru';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Terjadi kesalahan saat memuat data: $e";
          _isLoading = false;
        });
      }
    }
  }

  // Fungsi untuk mengambil data absensi berdasarkan tanggal
  Future<void> _fetchAbsensiByDate() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final token = await _apiService.getToken();
      if (token == null) {
        setState(() {
          _error = "Token tidak tersedia";
          _isLoading = false;
        });
        return;
      }
      
      final date = _apiFormattedDate;
      
      // Buat URL dengan tanggal tertentu
      final String url = "${ApiService.baseUrl}${ApiService.absensiEndpoint}?tanggal=$date";
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final absensiList = data['absensi'] ?? [];
        
        // Update status absensi dari data yang ada
        Map<String, String?> absenStatus = {};
        
        for (var absensi in absensiList) {
          final guruId = absensi['guruId'].toString();
          final status = absensi['status'];
          absenStatus[guruId] = status;
        }
        
        if (mounted) {
          setState(() {
            _absenStatus = absenStatus;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = "Gagal mengambil data absensi: ${response.statusCode}";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Terjadi kesalahan: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchGuru() async {
    // Hapus kondisi yang mencegah fetch jika sedang loading
    setState(() {
      _error = '';
    });
    
    final result = await _apiService.getGuruData();
    if (result['success']) {
      if (mounted) {
        setState(() {
          _guruList = (result['data'] as List).map((e) => Guru.fromJson(e)).toList();
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _error = result['message'] ?? 'Gagal memuat data guru';
        });
      }
    }
  }

  Future<void> _absenGuru(String guruId, String status) async {
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      // Kirim permintaan ke backend dengan tanggal yang dipilih
      final token = await _apiService.getToken();
      if (token == null) {
        throw Exception("Token tidak tersedia");
      }
      
      // Cek apakah sudah ada absensi pada tanggal yang dipilih
      final url = "${ApiService.baseUrl}${ApiService.absensiEndpoint}?tanggal=${_apiFormattedDate}&guruId=$guruId";
      
      final checkResponse = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (checkResponse.statusCode == 200) {
        final data = jsonDecode(checkResponse.body);
        final absensiList = data['absensi'] ?? [];
        
        if (absensiList.isNotEmpty) {
          // Update absensi yang sudah ada
          final absensiId = absensiList[0]['id'];
          final updateUrl = "${ApiService.baseUrl}${ApiService.absensiEndpoint}/$absensiId";
          
          final updateResponse = await http.put(
            Uri.parse(updateUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'status': status,
            }),
          );
          
          if (updateResponse.statusCode != 200) {
            throw Exception("Gagal mengupdate absensi: ${updateResponse.statusCode}");
          }
        } else {
          // Buat absensi baru dengan tanggal yang dipilih
          final createUrl = "${ApiService.baseUrl}${ApiService.absensiEndpoint}";
          
          final createResponse = await http.post(
            Uri.parse(createUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'guruId': int.parse(guruId),
              'status': status,
              'tanggal': "${_apiFormattedDate}T00:00:00.000Z",
              'jamMasuk': DateTime.now().toIso8601String(),
            }),
          );
          
          if (createResponse.statusCode != 201 && createResponse.statusCode != 200) {
            throw Exception("Gagal membuat absensi: ${createResponse.statusCode}");
          }
        }
        
        // Update UI setelah berhasil
        setState(() {
          _absenStatus[guruId] = status;
        });
        
        Flushbar(
          message: 'Absen $status berhasil untuk guru dengan ID $guruId',
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
      } else {
        throw Exception("Gagal memeriksa absensi: ${checkResponse.statusCode}");
      }
    } catch (e) {
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
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _absenSemua(String status) async {
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      for (final guru in _guruList) {
        await _absenGuru(guru.id, status);
      }
      
      Flushbar(
        message: 'Semua guru telah diubah status menjadi $status',
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
    } catch (e) {
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
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('id', 'ID'),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Theme.of(context).colorScheme.primary,
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
            ),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchAbsensiByDate();
    }
  }
  


  @override
  Widget build(BuildContext context) {
    super.build(context); // Diperlukan untuk AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    
    Widget content;
    
    if (_isLoading) {
      content = _buildShimmerLoading();
    } else if (_error.isNotEmpty) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error,
              style: TextStyle(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    } else {
      content = Column(
        children: [
          // Date picker dan status cards
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              onTap: () => _selectDate(context),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tanggal Absensi',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            _formattedDate,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
          ),
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : () => _absenSemua('HADIR'),
                        icon: const Icon(Icons.check_circle, size: 20),
                        label: const Text('Hadir Semua'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : () => _absenSemua('IZIN'),
                        icon: const Icon(Icons.assignment_late, size: 20),
                        label: const Text('Izin Semua'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Guru list
          Expanded(
            child: _guruList.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada data guru',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _guruList.length,
                    itemBuilder: (context, i) {
                      final guru = _guruList[i];
                      final status = _absenStatus[guru.id];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: status != null
                                        ? _getColorForStatus(status).withOpacity(0.2)
                                        : Colors.grey.withOpacity(0.2),
                                    child: Text(
                                      guru.nama.isNotEmpty ? guru.nama[0] : '?',
                                      style: TextStyle(
                                        color: status != null
                                            ? _getColorForStatus(status)
                                            : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (status != null)
                                          Container(
                                            margin: const EdgeInsets.only(top: 4),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getColorForStatus(status).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _getColorForStatus(status),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          )
                                        else
                                          Container(
                                            margin: const EdgeInsets.only(top: 4),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: const Text(
                                              'BELUM ABSEN',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: _AbsenButton(
                                      label: 'Hadir',
                                      color: Colors.green,
                                      selected: status == 'HADIR',
                                      onTap: _isSubmitting ? null : () => _absenGuru(guru.id, 'HADIR'),
                                    ),
                                  ),
                                  Expanded(
                                    child: _AbsenButton(
                                      label: 'Izin',
                                      color: Colors.orange,
                                      selected: status == 'IZIN',
                                      onTap: _isSubmitting ? null : () => _absenGuru(guru.id, 'IZIN'),
                                    ),
                                  ),
                                  Expanded(
                                    child: _AbsenButton(
                                      label: 'Sakit',
                                      color: Colors.blue,
                                      selected: status == 'SAKIT',
                                      onTap: _isSubmitting ? null : () => _absenGuru(guru.id, 'SAKIT'),
                                    ),
                                  ),
                                  Expanded(
                                    child: _AbsenButton(
                                      label: 'Alpa',
                                      color: Colors.red,
                                      selected: status == 'ALPA',
                                      onTap: _isSubmitting ? null : () => _absenGuru(guru.id, 'ALPA'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Absensi Guru'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: content,
    );
  }
  
  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(16),
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            for (int i = 0; i < 5; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Color _getColorForStatus(String status) {
    switch (status) {
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

class _AbsenButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;
  
  const _AbsenButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: selected ? color : color.withOpacity(0.1),
          foregroundColor: selected ? Colors.white : color,
          elevation: selected ? 2 : 0,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          minimumSize: const Size(0, 36),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
} 