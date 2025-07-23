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
      // Ambil pengaturan hari libur
      final akhirPekanResult = await _apiService.getAkhirPekanSettings();
      if (akhirPekanResult['success']) {
        setState(() {
          _akhirPekan = PengaturanLiburAkhirPekan.fromJson(akhirPekanResult['data']);
        });
      } else {
        setState(() {
          _error = akhirPekanResult['message'] ?? 'Gagal memuat pengaturan hari libur';
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
  
  // Simpan pengaturan hari libur
  Future<void> _saveAkhirPekanSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await _apiService.saveAkhirPekanSettings(_akhirPekan.toJson());
      
      if (result['success']) {
        Flushbar(
          message: 'Pengaturan hari libur berhasil disimpan',
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
    final theme = Theme.of(context);
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
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        isEditing ? Icons.edit_calendar : Icons.add_circle,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isEditing ? 'Edit Libur Nasional' : 'Tambah Libur Nasional',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Nama Libur
                  TextField(
                    controller: namaController,
                    decoration: InputDecoration(
                      labelText: 'Nama Libur *',
                      hintText: 'Contoh: Hari Kemerdekaan',
                      prefixIcon: const Icon(Icons.label_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.colorScheme.primary),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Tanggal Mulai
                  Text(
                    'Tanggal Mulai',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: tanggalMulai,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2050),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: theme.colorScheme.primary,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: theme.colorScheme.onSurface,
                              ),
                            ),
                            child: child!,
                          );
                        },
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
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('dd MMMM yyyy').format(tanggalMulai),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_drop_down,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Tanggal Selesai
                  Text(
                    'Tanggal Selesai',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: tanggalSelesai,
                        firstDate: tanggalMulai,
                        lastDate: DateTime(2050),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: theme.colorScheme.primary,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: theme.colorScheme.onSurface,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      
                      if (picked != null) {
                        setState(() {
                          tanggalSelesai = picked;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('dd MMMM yyyy').format(tanggalSelesai),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_drop_down,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Keterangan
                  TextField(
                    controller: keteranganController,
                    decoration: InputDecoration(
                      labelText: 'Keterangan (Opsional)',
                      hintText: 'Tambahan informasi',
                      prefixIcon: const Icon(Icons.description_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    maxLines: 2,
                  ),
                  
                  // Periode info
                  if (tanggalMulai != tanggalSelesai)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Periode: ${DateFormat('d').format(tanggalMulai)} - ${DateFormat('d MMM yyyy').format(tanggalSelesai)}',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Batal',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          isEditing ? 'Simpan' : 'Tambah',
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
  
  // Tab Pengaturan Hari Libur
  Widget _buildAkhirPekanTab() {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Pilih Hari Libur',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pada hari yang dipilih, guru tidak dapat melakukan absensi',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Daftar hari
          Card(
            elevation: 3,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: const Text(
                'Simpan Pengaturan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Tab Libur Nasional
  Widget _buildLiburNasionalTab() {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.event_note, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'Daftar Libur Nasional',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Pada hari libur nasional, guru tidak dapat melakukan absensi',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _showLiburNasionalDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                    ),
                  )
                : _liburNasional.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy, 
                                size: 100, color: Colors.grey[300]),
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
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shadowColor: Colors.black26,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.event,
                                      color: theme.colorScheme.primary,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          libur.nama,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // Jika tanggal mulai dan selesai sama
                                        if (libur.tanggalMulai.year == libur.tanggalSelesai.year &&
                                            libur.tanggalMulai.month == libur.tanggalSelesai.month &&
                                            libur.tanggalMulai.day == libur.tanggalSelesai.day)
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today, 
                                                size: 14, 
                                                color: theme.colorScheme.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                DateFormat('dd MMM yyyy').format(libur.tanggalMulai),
                                                style: TextStyle(
                                                  color: theme.colorScheme.primary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          )
                                        // Jika periode
                                        else
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.date_range, 
                                                size: 14, 
                                                color: theme.colorScheme.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${DateFormat('dd MMM').format(libur.tanggalMulai)} - ${DateFormat('dd MMM yyyy').format(libur.tanggalSelesai)}',
                                                style: TextStyle(
                                                  color: theme.colorScheme.primary,
                                                  fontWeight: FontWeight.w500,
                                                ),
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
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit_outlined,
                                          color: theme.colorScheme.secondary,
                                        ),
                                        onPressed: () => _showLiburNasionalDialog(libur: libur),
                                        tooltip: 'Edit',
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete_outline,
                                          color: theme.colorScheme.error,
                                        ),
                                        onPressed: () => _confirmDeleteLibur(libur),
                                        tooltip: 'Hapus',
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
      ),
    );
  }
  
  Widget _buildDayCheckbox(String day, bool isChecked, Function(bool?) onChanged) {
    return CheckboxListTile(
      title: Text(
        day, 
        style: TextStyle(
          fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      value: isChecked,
      onChanged: onChanged as void Function(bool?),
      controlAffinity: ListTileControlAffinity.trailing,
      activeColor: Theme.of(context).colorScheme.primary,
      checkColor: Colors.white,
      dense: true,
      secondary: Icon(
        isChecked ? Icons.event_busy : Icons.event_available,
        color: isChecked ? Theme.of(context).colorScheme.primary : Colors.grey,
      ),
    );
  }
  
  Widget _buildDivider() {
    return const Divider(height: 1, indent: 16, endIndent: 16);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Hari Libur'),
        elevation: 0,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Hari Libur'),
            Tab(text: 'Libur Nasional'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
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
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba Lagi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
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
  
  // Konfirmasi hapus libur nasional
  Future<void> _confirmDeleteLibur(LiburNasional libur) async {
    final theme = Theme.of(context);
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Hapus Libur Nasional',
          style: TextStyle(color: theme.colorScheme.error),
        ),
        content: Text('Apakah Anda yakin ingin menghapus "${libur.nama}"?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteLiburNasional(libur.id);
            },
            icon: const Icon(Icons.delete),
            label: const Text('Hapus'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
} 