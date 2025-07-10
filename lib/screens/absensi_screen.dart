import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/absensi_model.dart';
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
      final result = await _apiService.getAbsensiData();
      
      if (result['success']) {
        setState(() {
          _absensiData = result['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Gagal memuat data absensi';
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

  Future<void> _showAbsensiForm(BuildContext context) async {
    // Mendapatkan data guru untuk dropdown
    final guruResult = await _apiService.getGuruData();
    if (!guruResult['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(guruResult['message'] ?? 'Gagal memuat data guru'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final guruList = guruResult['data'] as List<dynamic>;
    
    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => AbsensiFormWidget(
          guruList: guruList,
          onSubmit: (absensiData) async {
            Navigator.pop(context);
            
            setState(() {
              _isLoading = true;
            });
            
            final result = await _apiService.createAbsensi(absensiData);
            
            setState(() {
              _isLoading = false;
            });
            
            if (result['success']) {
              _fetchAbsensiData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Absensi berhasil ditambahkan'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message'] ?? 'Gagal menambahkan absensi'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
      );
    }
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
              : _absensiData.isEmpty
                  ? const Center(child: Text('Tidak ada data absensi'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAbsensiForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AbsensiFormWidget extends StatefulWidget {
  final List<dynamic> guruList;
  final Function(Map<String, dynamic>) onSubmit;

  const AbsensiFormWidget({
    super.key,
    required this.guruList,
    required this.onSubmit,
  });

  @override
  State<AbsensiFormWidget> createState() => _AbsensiFormWidgetState();
}

class _AbsensiFormWidgetState extends State<AbsensiFormWidget> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedGuruId;
  String? _selectedGuruNama;
  String _status = 'hadir';
  final _keteranganController = TextEditingController();

  final List<String> _statusOptions = ['hadir', 'izin', 'sakit', 'alpa'];

  @override
  void dispose() {
    _keteranganController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_selectedGuruId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan pilih guru terlebih dahulu'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Format tanggal dan waktu
      final now = DateTime.now();
      final tanggal = DateFormat('yyyy-MM-dd').format(now);
      final jamMasuk = DateFormat('HH:mm:ss').format(now);

      final absensiData = {
        'guruId': _selectedGuruId,
        'namaGuru': _selectedGuruNama,
        'tanggal': tanggal,
        'jamMasuk': jamMasuk,
        'status': _status,
        'keterangan': _keteranganController.text.trim(),
      };

      widget.onSubmit(absensiData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tambah Absensi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Dropdown guru
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Pilih Guru',
                border: OutlineInputBorder(),
              ),
              value: _selectedGuruId,
              items: widget.guruList.map((guru) {
                return DropdownMenuItem<String>(
                  value: guru['id'],
                  child: Text(guru['nama'] ?? 'Nama tidak tersedia'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedGuruId = value;
                  _selectedGuruNama = widget.guruList
                      .firstWhere((guru) => guru['id'] == value)['nama'];
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Silakan pilih guru';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Dropdown status
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              value: _status,
              items: _statusOptions.map((status) {
                return DropdownMenuItem<String>(
                  value: status,
                  child: Text(status.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _status = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Field keterangan
            TextFormField(
              controller: _keteranganController,
              decoration: const InputDecoration(
                labelText: 'Keterangan (opsional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            
            // Tombol submit
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'SIMPAN',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 