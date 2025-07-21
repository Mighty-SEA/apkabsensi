import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pengaturan_libur_model.dart';
import '../services/api_service.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:uuid/uuid.dart';
import '../utils/libur_helper.dart';

class PengaturanLiburScreen extends StatefulWidget {
  final int initialTabIndex;
  
  const PengaturanLiburScreen({
    Key? key, 
    this.initialTabIndex = 0,
  }) : super(key: key);

  @override
  State<PengaturanLiburScreen> createState() => _PengaturanLiburScreenState();
}

class _PengaturanLiburScreenState extends State<PengaturanLiburScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  bool _isLoading = false;
  String _error = '';

  // Data
  PengaturanLiburAkhirPekan _akhirPekan = PengaturanLiburAkhirPekan();
  List<LiburNasional> _liburNasional = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _loadData();
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
      // Ambil pengaturan akhir pekan
      final akhirPekanResult = await _apiService.getAkhirPekanSettings();
      if (akhirPekanResult['success']) {
        setState(() {
          _akhirPekan = PengaturanLiburAkhirPekan.fromJson(akhirPekanResult['data']);
        });
      } else {
        setState(() {
          _error = akhirPekanResult['message'] ?? 'Gagal memuat pengaturan akhir pekan';
        });
      }
      
      // Ambil data libur nasional
      final liburNasionalResult = await _apiService.getLiburNasional();
      if (liburNasionalResult['success']) {
        final liburList = (liburNasionalResult['data'] as List)
          .map((item) => LiburNasional.fromJson(item))
          .toList();
        
        setState(() {
          _liburNasional = liburList;
        });
      } else {
        setState(() {
          _error = liburNasionalResult['message'] ?? 'Gagal memuat data libur nasional';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Terjadi kesalahan: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Simpan pengaturan akhir pekan
  Future<void> _saveAkhirPekanSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await _apiService.saveAkhirPekanSettings(_akhirPekan.toJson());
      
      if (result['success']) {
        Flushbar(
          message: 'Pengaturan akhir pekan berhasil disimpan',
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      } else {
        Flushbar(
          message: result['message'] ?? 'Gagal menyimpan pengaturan',
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      }
    } catch (e) {
      Flushbar(
        message: 'Terjadi kesalahan: $e',
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Tambah libur nasional baru
  Future<void> _addLiburNasional(LiburNasional libur) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await _apiService.addLiburNasional(libur.toJson());
      
      if (result['success']) {
        setState(() {
          _liburNasional.add(LiburNasional.fromJson(result['data']));
        });
        
        Flushbar(
          message: 'Libur nasional berhasil ditambahkan',
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      } else {
        Flushbar(
          message: result['message'] ?? 'Gagal menambahkan libur nasional',
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      }
    } catch (e) {
      Flushbar(
        message: 'Terjadi kesalahan: $e',
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Update libur nasional
  Future<void> _updateLiburNasional(LiburNasional libur) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await _apiService.updateLiburNasional(libur.id, libur.toJson());
      
      if (result['success']) {
        setState(() {
          final index = _liburNasional.indexWhere((item) => item.id == libur.id);
          if (index >= 0) {
            _liburNasional[index] = LiburNasional.fromJson(result['data']);
          }
        });
        
        Flushbar(
          message: 'Libur nasional berhasil diupdate',
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      } else {
        Flushbar(
          message: result['message'] ?? 'Gagal mengupdate libur nasional',
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      }
    } catch (e) {
      Flushbar(
        message: 'Terjadi kesalahan: $e',
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Hapus libur nasional
  Future<void> _deleteLiburNasional(String id) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await _apiService.deleteLiburNasional(id);
      
      if (result['success']) {
        setState(() {
          _liburNasional.removeWhere((libur) => libur.id == id);
        });
        
        Flushbar(
          message: 'Libur nasional berhasil dihapus',
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      } else {
        Flushbar(
          message: result['message'] ?? 'Gagal menghapus libur nasional',
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      }
    } catch (e) {
      Flushbar(
        message: 'Terjadi kesalahan: $e',
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Dialog tambah/edit libur nasional
  Future<void> _showLiburNasionalDialog({LiburNasional? libur}) async {
    final isEditing = libur != null;
    
    final TextEditingController namaController = TextEditingController(
      text: isEditing ? libur.nama : '',
    );
    final TextEditingController keteranganController = TextEditingController(
      text: isEditing ? libur.keterangan ?? '' : '',
    );
    
    DateTime tanggalMulai = isEditing 
        ? libur.tanggalMulai 
        : DateTime.now();
    DateTime tanggalSelesai = isEditing 
        ? libur.tanggalSelesai 
        : DateTime.now();
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isEditing ? 'Edit Libur Nasional' : 'Tambah Libur Nasional'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama Libur
                  TextField(
                    controller: namaController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Libur *',
                      hintText: 'Contoh: Hari Kemerdekaan',
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Tanggal Mulai
                  Row(
                    children: [
                      const Text('Tanggal Mulai:'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            DateFormat('dd MMM yyyy').format(tanggalMulai),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: tanggalMulai,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2050),
                            );
                            
                            if (picked != null) {
                              setState(() {
                                tanggalMulai = picked;
                                // Jika tanggal mulai > tanggal selesai, sesuaikan tanggal selesai
                                if (tanggalMulai.isAfter(tanggalSelesai)) {
                                  tanggalSelesai = tanggalMulai;
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Tanggal Selesai
                  Row(
                    children: [
                      const Text('Tanggal Selesai:'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            DateFormat('dd MMM yyyy').format(tanggalSelesai),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: tanggalSelesai,
                              firstDate: tanggalMulai, // Minimal tanggal mulai
                              lastDate: DateTime(2050),
                            );
                            
                            if (picked != null) {
                              setState(() {
                                tanggalSelesai = picked;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Keterangan
                  TextField(
                    controller: keteranganController,
                    decoration: const InputDecoration(
                      labelText: 'Keterangan (Opsional)',
                      hintText: 'Tambahan informasi',
                    ),
                    maxLines: 2,
                  ),
                  
                  if (tanggalMulai != tanggalSelesai)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Periode: ${DateFormat('d').format(tanggalMulai)} - ${DateFormat('d MMM yyyy').format(tanggalSelesai)}',
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (namaController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nama libur tidak boleh kosong')),
                    );
                    return;
                  }
                  
                  final newLibur = LiburNasional(
                    id: isEditing ? libur.id : const Uuid().v4(),
                    nama: namaController.text.trim(),
                    tanggalMulai: tanggalMulai,
                    tanggalSelesai: tanggalSelesai,
                    keterangan: keteranganController.text.trim().isNotEmpty 
                        ? keteranganController.text.trim() 
                        : null,
                  );
                  
                  Navigator.of(context).pop(newLibur);
                },
                child: Text(isEditing ? 'Simpan' : 'Tambah'),
              ),
            ],
          );
        },
      ),
    ).then((value) {
      if (value != null) {
        if (isEditing) {
          _updateLiburNasional(value);
        } else {
          _addLiburNasional(value);
        }
      }
    });
  }
  
  // Tab Pengaturan Akhir Pekan
  Widget _buildAkhirPekanTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Hari Libur Akhir Pekan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pada hari yang dipilih, guru tidak dapat melakukan absensi',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          // Daftar hari
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildDayCheckbox('Senin', _akhirPekan.senin, (value) {
                  setState(() {
                    _akhirPekan = PengaturanLiburAkhirPekan(
                      senin: value ?? false,
                      selasa: _akhirPekan.selasa,
                      rabu: _akhirPekan.rabu,
                      kamis: _akhirPekan.kamis,
                      jumat: _akhirPekan.jumat,
                      sabtu: _akhirPekan.sabtu,
                      minggu: _akhirPekan.minggu,
                    );
                  });
                }),
                _buildDivider(),
                _buildDayCheckbox('Selasa', _akhirPekan.selasa, (value) {
                  setState(() {
                    _akhirPekan = PengaturanLiburAkhirPekan(
                      senin: _akhirPekan.senin,
                      selasa: value ?? false,
                      rabu: _akhirPekan.rabu,
                      kamis: _akhirPekan.kamis,
                      jumat: _akhirPekan.jumat,
                      sabtu: _akhirPekan.sabtu,
                      minggu: _akhirPekan.minggu,
                    );
                  });
                }),
                _buildDivider(),
                _buildDayCheckbox('Rabu', _akhirPekan.rabu, (value) {
                  setState(() {
                    _akhirPekan = PengaturanLiburAkhirPekan(
                      senin: _akhirPekan.senin,
                      selasa: _akhirPekan.selasa,
                      rabu: value ?? false,
                      kamis: _akhirPekan.kamis,
                      jumat: _akhirPekan.jumat,
                      sabtu: _akhirPekan.sabtu,
                      minggu: _akhirPekan.minggu,
                    );
                  });
                }),
                _buildDivider(),
                _buildDayCheckbox('Kamis', _akhirPekan.kamis, (value) {
                  setState(() {
                    _akhirPekan = PengaturanLiburAkhirPekan(
                      senin: _akhirPekan.senin,
                      selasa: _akhirPekan.selasa,
                      rabu: _akhirPekan.rabu,
                      kamis: value ?? false,
                      jumat: _akhirPekan.jumat,
                      sabtu: _akhirPekan.sabtu,
                      minggu: _akhirPekan.minggu,
                    );
                  });
                }),
                _buildDivider(),
                _buildDayCheckbox('Jumat', _akhirPekan.jumat, (value) {
                  setState(() {
                    _akhirPekan = PengaturanLiburAkhirPekan(
                      senin: _akhirPekan.senin,
                      selasa: _akhirPekan.selasa,
                      rabu: _akhirPekan.rabu,
                      kamis: _akhirPekan.kamis,
                      jumat: value ?? false,
                      sabtu: _akhirPekan.sabtu,
                      minggu: _akhirPekan.minggu,
                    );
                  });
                }),
                _buildDivider(),
                _buildDayCheckbox('Sabtu', _akhirPekan.sabtu, (value) {
                  setState(() {
                    _akhirPekan = PengaturanLiburAkhirPekan(
                      senin: _akhirPekan.senin,
                      selasa: _akhirPekan.selasa,
                      rabu: _akhirPekan.rabu,
                      kamis: _akhirPekan.kamis,
                      jumat: _akhirPekan.jumat,
                      sabtu: value ?? false,
                      minggu: _akhirPekan.minggu,
                    );
                  });
                }),
                _buildDivider(),
                _buildDayCheckbox('Minggu', _akhirPekan.minggu, (value) {
                  setState(() {
                    _akhirPekan = PengaturanLiburAkhirPekan(
                      senin: _akhirPekan.senin,
                      selasa: _akhirPekan.selasa,
                      rabu: _akhirPekan.rabu,
                      kamis: _akhirPekan.kamis,
                      jumat: _akhirPekan.jumat,
                      sabtu: _akhirPekan.sabtu,
                      minggu: value ?? false,
                    );
                  });
                }),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // Tombol simpan
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveAkhirPekanSettings,
              icon: _isLoading 
                  ? const SizedBox(
                      width: 16, 
                      height: 16, 
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Simpan Pengaturan'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Tab Libur Nasional
  Widget _buildLiburNasionalTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daftar Libur Nasional',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _showLiburNasionalDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Tambah'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Pada hari libur nasional, guru tidak dapat melakukan absensi',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _liburNasional.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy, 
                                size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Belum ada data libur nasional',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _liburNasional.length,
                        itemBuilder: (context, index) {
                          final libur = _liburNasional[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              title: Text(
                                libur.nama,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  // Jika tanggal mulai dan selesai sama
                                  if (libur.tanggalMulai.year == libur.tanggalSelesai.year &&
                                      libur.tanggalMulai.month == libur.tanggalSelesai.month &&
                                      libur.tanggalMulai.day == libur.tanggalSelesai.day)
                                    Row(
                                      children: [
                                        const Icon(Icons.event, size: 14, color: Colors.blue),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateFormat('dd MMM yyyy').format(libur.tanggalMulai),
                                          style: const TextStyle(color: Colors.blue),
                                        ),
                                      ],
                                    )
                                  // Jika periode
                                  else
                                    Row(
                                      children: [
                                        const Icon(Icons.date_range, size: 14, color: Colors.blue),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${DateFormat('dd MMM').format(libur.tanggalMulai)} - ${DateFormat('dd MMM yyyy').format(libur.tanggalSelesai)}',
                                          style: const TextStyle(color: Colors.blue),
                                        ),
                                      ],
                                    ),
                                  
                                  if (libur.keterangan != null && libur.keterangan!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        libur.keterangan!,
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.orange),
                                    onPressed: () => _showLiburNasionalDialog(libur: libur),
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _confirmDeleteLibur(libur),
                                    tooltip: 'Hapus',
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
  
  // Konfirmasi hapus libur nasional
  Future<void> _confirmDeleteLibur(LiburNasional libur) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Libur Nasional'),
        content: Text('Apakah Anda yakin ingin menghapus "${libur.nama}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteLiburNasional(libur.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDayCheckbox(String day, bool isChecked, Function(bool?) onChanged) {
    return CheckboxListTile(
      title: Text(day),
      value: isChecked,
      onChanged: onChanged as void Function(bool?),
      controlAffinity: ListTileControlAffinity.trailing,
      activeColor: Theme.of(context).primaryColor,
    );
  }
  
  Widget _buildDivider() {
    return const Divider(height: 1, indent: 16, endIndent: 16);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Hari Libur'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Akhir Pekan'),
            Tab(text: 'Libur Nasional'),
          ],
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          indicatorWeight: 3,
        ),
      ),
      body: _error.isNotEmpty
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
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAkhirPekanTab(),
                _buildLiburNasionalTab(),
              ],
            ),
    );
  }
} 