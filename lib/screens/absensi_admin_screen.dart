import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/guru_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

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

  @override
  bool get wantKeepAlive => true; // Agar status tidak reset saat berpindah tab

  @override
  void initState() {
    super.initState();
    _fetchGuru();
    _fetchAbsensiHariIni();
  }

  // Fungsi untuk mengambil data absensi hari ini
  Future<void> _fetchAbsensiHariIni() async {
    try {
      final result = await _apiService.getAbsensiHariIni();
      if (result['success']) {
        final absensiList = result['data'] as List;
        
        // Update status absensi dari data yang ada
        Map<String, String?> absenStatus = {};
        
        for (var absensi in absensiList) {
          final guruId = absensi['guruId'].toString();
          final status = absensi['status'];
          absenStatus[guruId] = status;
        }
        
        setState(() {
          _absenStatus = absenStatus;
        });
      }
    } catch (e) {
      print('Error fetching absensi hari ini: $e');
    }
  }

  Future<void> _fetchGuru() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    final result = await _apiService.getGuruData();
    if (result['success']) {
      setState(() {
        _guruList = (result['data'] as List).map((e) => Guru.fromJson(e)).toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['message'] ?? 'Gagal memuat data guru';
        _isLoading = false;
      });
    }
  }

  Future<void> _absenGuru(String guruId, String status) async {
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      final result = await _apiService.updateAbsensiStatus(int.parse(guruId), status);
      
      if (result['success']) {
        setState(() {
          _absenStatus[guruId] = status;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Absen $status berhasil untuk guru dengan ID $guruId'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal absen: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Semua guru telah diubah status menjadi $status'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Diperlukan untuk AutomaticKeepAliveClientMixin
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Absensi Semua Guru'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchGuru();
              _fetchAbsensiHariIni();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isSubmitting ? null : () => _absenSemua('HADIR'),
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Hadir Semua'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _guruList.length,
                        itemBuilder: (context, i) {
                          final guru = _guruList[i];
                          final status = _absenStatus[guru.id];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              title: Text(guru.nama),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('NIP: ${guru.nip}'),
                                  if (status != null)
                                    Text(
                                      'Status hari ini: $status',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _getColorForStatus(status),
                                      ),
                                    ),
                                ],
                              ),
                              isThreeLine: status != null,
                              trailing: _isSubmitting
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator())
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _AbsenButton(
                                          label: 'Hadir',
                                          color: Colors.green,
                                          selected: status == 'HADIR',
                                          onTap: () => _absenGuru(guru.id, 'HADIR'),
                                        ),
                                        _AbsenButton(
                                          label: 'Izin',
                                          color: Colors.orange,
                                          selected: status == 'IZIN',
                                          onTap: () => _absenGuru(guru.id, 'IZIN'),
                                        ),
                                        _AbsenButton(
                                          label: 'Sakit',
                                          color: Colors.blue,
                                          selected: status == 'SAKIT',
                                          onTap: () => _absenGuru(guru.id, 'SAKIT'),
                                        ),
                                        _AbsenButton(
                                          label: 'Alpa',
                                          color: Colors.red,
                                          selected: status == 'ALPA',
                                          onTap: () => _absenGuru(guru.id, 'ALPA'),
                                        ),
                                      ],
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
  final VoidCallback onTap;
  const _AbsenButton({required this.label, required this.color, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ElevatedButton(
        onPressed: onTap, // Selalu bisa diklik untuk mengubah status
        style: ElevatedButton.styleFrom(
          backgroundColor: selected ? color : color.withOpacity(0.5),
          foregroundColor: Colors.white,
          minimumSize: const Size(40, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
} 