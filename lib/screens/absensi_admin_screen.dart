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
  Map<String, String?> _jamPulang = {}; // idGuru: jamKeluar
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
        Map<String, String?> jamPulang = {};
        
        for (var absensi in absensiList) {
          final guruId = absensi['guruId'].toString();
          final status = absensi['status'];
          absenStatus[guruId] = status;
          jamPulang[guruId] = absensi['jamKeluar'];
        }
        
        if (mounted) {
          setState(() {
            _absenStatus = absenStatus;
            _jamPulang = jamPulang;
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

  Future<void> _absenGuru(String guruId, String status, {bool showNotif = true, DateTime? customTime}) async {
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
          
          // Buat body request sesuai dengan parameter yang diberikan
          final Map<String, dynamic> updateBody = {'status': status};
          
          // Jika ada custom time, tambahkan ke body request untuk update jam masuk
          if (customTime != null) {
            updateBody['jamMasuk'] = customTime.toIso8601String();
          }
          
          final updateResponse = await http.put(
            Uri.parse(updateUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(updateBody),
          );
          
          print('PUT absensi: status= [32m [1m [4m [7m${updateResponse.statusCode} [0m, body=${updateResponse.body}');
          if (updateResponse.statusCode != 200) {
            throw Exception("Gagal mengupdate absensi:  [31m${updateResponse.statusCode} [0m");
          }
          
          // Jika berhasil update dengan custom time, update status jam masuk di state
          if (customTime != null) {
            // Update state untuk jam masuk jika diperlukan
            // Idealnya backend mengembalikan data yang sudah diupdate
          }
        } else {
          // Buat absensi baru dengan tanggal yang dipilih
          final createUrl = "${ApiService.baseUrl}${ApiService.absensiEndpoint}";
          
          final jamMasuk = customTime?.toIso8601String() ?? DateTime.now().toIso8601String();
          
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
              'jamMasuk': jamMasuk,
            }),
          );
          print('POST absensi: status= [32m [1m [4m [7m${createResponse.statusCode} [0m, body=${createResponse.body}');
          if (createResponse.statusCode != 201 && createResponse.statusCode != 200) {
            throw Exception("Gagal membuat absensi:  [31m${createResponse.statusCode} [0m");
          }
        }
        
        // Cari nama guru dari _guruList
        final guruNama = _guruList.firstWhere(
          (g) => g.id == guruId,
          orElse: () => Guru(id: guruId, nama: '', jenisKelamin: null, alamat: null, noTelp: null),
        ).nama;
        
        // Perbarui UI dengan data terbaru
        await _fetchAbsensiByDate();
        
        if (showNotif) {
          String message;
          if (customTime != null) {
            final timeStr = DateFormat('HH:mm').format(customTime);
            message = 'Absen $status berhasil untuk guru${guruNama.isNotEmpty ? ' $guruNama' : ' dengan ID $guruId'} pada jam $timeStr';
          } else {
            message = 'Absen $status berhasil untuk guru${guruNama.isNotEmpty ? ' $guruNama' : ' dengan ID $guruId'}';
          }
          
          Flushbar(
            message: message,
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
        }
        setState(() {
          _absenStatus[guruId] = status;
        });
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

  Future<void> _absenSemua(String status, {DateTime? customTime}) async {
    setState(() {
      _isSubmitting = true;
    });
    try {
      for (final guru in _guruList) {
        await _absenGuru(guru.id, status, showNotif: false, customTime: customTime);
      }
      
      // Perbarui UI dengan data terbaru
      await _fetchAbsensiByDate();
      
      String message;
      if (customTime != null) {
        final timeStr = DateFormat('HH:mm').format(customTime);
        message = 'Semua guru telah diubah status menjadi $status pada jam $timeStr';
      } else {
        message = 'Semua guru telah diubah status menjadi $status';
      }
      
      Flushbar(
        message: message,
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
  
  Future<void> _absenPulangGuru(String guruId, {bool showNotif = true, DateTime? customTime}) async {
    setState(() {
      _isSubmitting = true;
    });
    try {
      final token = await _apiService.getToken();
      if (token == null) {
        throw Exception("Token tidak tersedia");
      }
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
          final absensiId = absensiList[0]['id'];
          final updateUrl = "${ApiService.baseUrl}${ApiService.absensiEndpoint}/$absensiId";
          
          final jamKeluar = customTime?.toIso8601String() ?? DateTime.now().toIso8601String();
          
          final updateResponse = await http.put(
            Uri.parse(updateUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'jamKeluar': jamKeluar,
            }),
          );
          if (updateResponse.statusCode != 200) {
            throw Exception("Gagal update jam pulang: ${updateResponse.statusCode}");
          }
          
          // Perbarui UI dengan data terbaru
          await _fetchAbsensiByDate();
          
          if (showNotif) {
            String message;
            if (customTime != null) {
              final timeStr = DateFormat('HH:mm').format(customTime);
              message = 'Absen pulang berhasil pada jam $timeStr';
            } else {
              message = 'Absen pulang berhasil';
            }
            
            Flushbar(
              message: message,
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
          }
          setState(() {
            // Status tetap, hanya update jam pulang
            _jamPulang[guruId] = jamKeluar;
          });
        } else {
          throw Exception("Belum ada absensi masuk untuk guru ini");
        }
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

  Future<void> _absenPulangSemua({DateTime? customTime}) async {
    setState(() {
      _isSubmitting = true;
    });
    try {
      for (final guru in _guruList) {
        await _absenPulangGuru(guru.id, showNotif: false, customTime: customTime);
      }
      
      // Perbarui UI dengan data terbaru
      await _fetchAbsensiByDate();
      
      String message;
      if (customTime != null) {
        final timeStr = DateFormat('HH:mm').format(customTime);
        message = 'Semua guru telah absen pulang pada jam $timeStr';
      } else {
        message = 'Semua guru telah absen pulang';
      }
      
      Flushbar(
        message: message,
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

  // Fungsi untuk menampilkan dialog pemilihan waktu
  Future<DateTime?> _showTimePickerDialog(BuildContext context, {String title = 'Pilih Jam'}) async {
    // Tampilkan dialog konfirmasi terlebih dahulu
    bool? shouldShowTimePicker = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: const Text('Anda akan mengubah waktu pencatatan absensi. Lanjutkan?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('BATAL'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('LANJUTKAN'),
            ),
          ],
        );
      },
    );

    if (shouldShowTimePicker != true) {
      return null;
    }

    final TimeOfDay? timeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
            ),
            timePickerTheme: TimePickerThemeData(
              dialTextColor: Theme.of(context).colorScheme.onSurface,
              hourMinuteTextColor: Theme.of(context).colorScheme.primary,
              dayPeriodTextColor: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              alwaysUse24HourFormat: false,
            ),
            child: child!,
          ),
        );
      },
      helpText: title,
      cancelText: 'BATAL',
      confirmText: 'SIMPAN',
    );
    
    if (timeOfDay != null) {
      // Gabungkan tanggal yang dipilih dengan jam yang dipilih
      return DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );
    }
    
    return null;
  }
  
  // Fungsi untuk menangani long press pada tombol hadir
  Future<void> _handleHadirLongPress(String guruId) async {
    final customTime = await _showTimePickerDialog(
      context,
      title: 'Pilih Jam Masuk',
    );
    
    if (customTime != null && mounted) {
      await _absenGuru(guruId, 'HADIR', customTime: customTime);
    }
  }
  
  // Fungsi untuk menangani long press pada tombol hadir semua
  Future<void> _handleHadirSemuaLongPress() async {
    final customTime = await _showTimePickerDialog(
      context,
      title: 'Pilih Jam Masuk untuk Semua',
    );
    
    if (customTime != null && mounted) {
      await _absenSemua('HADIR', customTime: customTime);
    }
  }
  
  // Fungsi untuk menangani long press pada tombol pulang
  Future<void> _handlePulangLongPress(String guruId) async {
    final customTime = await _showTimePickerDialog(
      context,
      title: 'Pilih Jam Pulang',
    );
    
    if (customTime != null && mounted) {
      await _absenPulangGuru(guruId, customTime: customTime);
    }
  }
  
  // Fungsi untuk menangani long press pada tombol pulang semua
  Future<void> _handlePulangSemuaLongPress() async {
    final customTime = await _showTimePickerDialog(
      context,
      title: 'Pilih Jam Pulang untuk Semua',
    );
    
    if (customTime != null && mounted) {
      await _absenPulangSemua(customTime: customTime);
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
                      child: GestureDetector(
                        onLongPress: _isSubmitting ? null : _handleHadirSemuaLongPress,
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
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onLongPress: _isSubmitting ? null : _handlePulangSemuaLongPress,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _absenPulangSemua,
                          icon: const Icon(Icons.logout, size: 20),
                          label: const Text('Pulang Semua'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
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
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                guru.nama,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            // Tombol Pulang di ujung kanan sejajar nama
                                            GestureDetector(
                                              onLongPress: _isSubmitting ? null : () => _handlePulangLongPress(guru.id),
                                              child: _AbsenButton(
                                                label: 'Pulang',
                                                color: Colors.blue,
                                                selected: _jamPulang[guru.id] != null && _jamPulang[guru.id]!.isNotEmpty,
                                                onTap: _isSubmitting ? null : () => _absenPulangGuru(guru.id),
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Status dan jam pulang di bawah nama
                                        Row(
                                          children: [
                                            if (status != null)
                                              Container(
                                                margin: const EdgeInsets.only(top: 4, right: 8),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                                                margin: const EdgeInsets.only(top: 4, right: 8),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                                            // Jam pulang
                                            Container(
                                              margin: const EdgeInsets.only(top: 4),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: (_jamPulang[guru.id] != null && _jamPulang[guru.id]!.isNotEmpty)
                                                    ? Colors.blue.withOpacity(0.1)
                                                    : Colors.red.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                (_jamPulang[guru.id] != null && _jamPulang[guru.id]!.isNotEmpty)
                                                    ? 'Pulang: ' + DateFormat('HH:mm', 'id_ID').format(DateTime.tryParse(_jamPulang[guru.id]!) ?? DateTime(0))
                                                    : 'Belum Pulang',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: (_jamPulang[guru.id] != null && _jamPulang[guru.id]!.isNotEmpty)
                                                      ? Colors.blue
                                                      : Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
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
                                    child: GestureDetector(
                                      onLongPress: _isSubmitting ? null : () => _handleHadirLongPress(guru.id),
                                      child: _AbsenButton(
                                        label: 'Hadir',
                                        color: Colors.green,
                                        selected: status == 'HADIR',
                                        onTap: _isSubmitting ? null : () => _absenGuru(guru.id, 'HADIR'),
                                      ),
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
                                      selected: status == 'ALPHA',
                                      onTap: _isSubmitting ? null : () => _absenGuru(guru.id, 'ALPHA'),
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
        centerTitle: false,
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
      case 'ALPHA':
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