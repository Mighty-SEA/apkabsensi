import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/pengaturan_gaji_model.dart';
import '../models/guru_model.dart';
import '../services/api_service.dart';

class PengaturanGajiScreen extends StatefulWidget {
  const PengaturanGajiScreen({Key? key}) : super(key: key);

  @override
  State<PengaturanGajiScreen> createState() => _PengaturanGajiScreenState();
}

class _PengaturanGajiScreenState extends State<PengaturanGajiScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String _error = '';
  
  // Data
  PengaturanGaji? _pengaturanGajiGlobal;
  List<Guru> _guruList = [];
  Map<String, PengaturanGaji> _pengaturanPerGuru = {};
  
  // Controller untuk tab
  final _tabController = PageController();
  int _selectedTabIndex = 0;
  
  // Controller untuk form pengaturan global
  final _formKeyGlobal = GlobalKey<FormState>();
  final _gajiPokokController = TextEditingController();
  final _potonganIzinController = TextEditingController();
  final _potonganSakitController = TextEditingController();
  final _potonganAlpaController = TextEditingController();
  
  // Controller untuk form pengaturan per guru
  final _formKeyPerGuru = GlobalKey<FormState>();
  final _gajiPokokGuruController = TextEditingController();
  final _potonganIzinGuruController = TextEditingController();
  final _potonganSakitGuruController = TextEditingController();
  final _potonganAlpaGuruController = TextEditingController();
  String? _selectedGuruId;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _gajiPokokController.dispose();
    _potonganIzinController.dispose();
    _potonganSakitController.dispose();
    _potonganAlpaController.dispose();
    _gajiPokokGuruController.dispose();
    _potonganIzinGuruController.dispose();
    _potonganSakitGuruController.dispose();
    _potonganAlpaGuruController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    
    try {
      // Load pengaturan gaji global
      final resultGlobal = await _apiService.getPengaturanGajiGlobal();
      if (!resultGlobal['success']) {
        setState(() {
          _error = resultGlobal['message'] ?? 'Gagal memuat pengaturan gaji global';
          _isLoading = false;
        });
        return;
      }
      
      // Load daftar guru
      final resultGuru = await _apiService.getGuruData();
      if (!resultGuru['success']) {
        setState(() {
          _error = resultGuru['message'] ?? 'Gagal memuat data guru';
          _isLoading = false;
        });
        return;
      }
      
      // Parse data global
      PengaturanGaji pengaturanGlobal;
      if (resultGlobal['data'] != null) {
        pengaturanGlobal = PengaturanGaji.fromJson(resultGlobal['data']);
      } else {
        // Default values jika belum ada
        pengaturanGlobal = PengaturanGaji(
          id: '',
          gajiPokok: 3000000,
          potonganIzin: 150000,
          potonganSakit: 50000,
          potonganAlpa: 300000,
          isGlobal: true,
        );
      }
      
      // Parse data guru
      final guruList = (resultGuru['data'] as List).map((e) => Guru.fromJson(e)).toList();
      
      // Load pengaturan per guru untuk guru yang ada
      final pengaturanPerGuru = <String, PengaturanGaji>{};
      for (var guru in guruList) {
        final resultPerGuru = await _apiService.getPengaturanGajiGuru(guru.id);
        if (resultPerGuru['success'] && resultPerGuru['data'] != null) {
          final pengaturan = PengaturanGaji.fromJson(resultPerGuru['data']);
          if (!pengaturan.isGlobal) {
            pengaturanPerGuru[guru.id] = pengaturan;
          }
        }
      }
      
      // Update state
      setState(() {
        _pengaturanGajiGlobal = pengaturanGlobal;
        _guruList = guruList;
        _pengaturanPerGuru = pengaturanPerGuru;
        _isLoading = false;
        
        // Isi form pengaturan global
        _gajiPokokController.text = pengaturanGlobal.gajiPokok.toString();
        _potonganIzinController.text = pengaturanGlobal.potonganIzin.toString();
        _potonganSakitController.text = pengaturanGlobal.potonganSakit.toString();
        _potonganAlpaController.text = pengaturanGlobal.potonganAlpa.toString();
      });
    } catch (e) {
      setState(() {
        _error = 'Terjadi kesalahan: $e';
        _isLoading = false;
      });
    }
  }
  
  void _onGuruSelected(String? guruId) {
    setState(() {
      _selectedGuruId = guruId;
      
      if (guruId != null) {
        // Cek apakah guru ini punya pengaturan khusus
        if (_pengaturanPerGuru.containsKey(guruId)) {
          // Jika ada pengaturan khusus, gunakan nilai tersebut
          final pengaturan = _pengaturanPerGuru[guruId]!;
          _gajiPokokGuruController.text = pengaturan.gajiPokok.toString();
          _potonganIzinGuruController.text = pengaturan.potonganIzin.toString();
          _potonganSakitGuruController.text = pengaturan.potonganSakit.toString();
          _potonganAlpaGuruController.text = pengaturan.potonganAlpa.toString();
        } else {
          // Jika tidak ada, gunakan nilai global
          _gajiPokokGuruController.text = _pengaturanGajiGlobal!.gajiPokok.toString();
          _potonganIzinGuruController.text = _pengaturanGajiGlobal!.potonganIzin.toString();
          _potonganSakitGuruController.text = _pengaturanGajiGlobal!.potonganSakit.toString();
          _potonganAlpaGuruController.text = _pengaturanGajiGlobal!.potonganAlpa.toString();
        }
      } else {
        // Reset form jika tidak ada guru yang dipilih
        _gajiPokokGuruController.clear();
        _potonganIzinGuruController.clear();
        _potonganSakitGuruController.clear();
        _potonganAlpaGuruController.clear();
      }
    });
  }
  
  Future<void> _saveGlobalSettings() async {
    if (!_formKeyGlobal.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final data = {
        'gajiPokok': int.parse(_gajiPokokController.text),
        'potonganIzin': int.parse(_potonganIzinController.text),
        'potonganSakit': int.parse(_potonganSakitController.text),
        'potonganAlpa': int.parse(_potonganAlpaController.text),
        'isGlobal': true,
      };
      
      final result = await _apiService.simpanPengaturanGajiGlobal(data);
      
      setState(() {
        _isLoading = false;
      });
      
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengaturan gaji global berhasil disimpan'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload data
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal menyimpan pengaturan gaji global'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _savePerGuruSettings() async {
    if (_selectedGuruId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih guru terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (!_formKeyPerGuru.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final data = {
        'gajiPokok': int.parse(_gajiPokokGuruController.text),
        'potonganIzin': int.parse(_potonganIzinGuruController.text),
        'potonganSakit': int.parse(_potonganSakitGuruController.text),
        'potonganAlpa': int.parse(_potonganAlpaGuruController.text),
        'isGlobal': false,
        'guruId': _selectedGuruId,
      };
      
      final result = await _apiService.simpanPengaturanGajiGuru(_selectedGuruId!, data);
      
      setState(() {
        _isLoading = false;
      });
      
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengaturan gaji guru berhasil disimpan'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload data
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal menyimpan pengaturan gaji guru'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _resetPerGuruSettings() async {
    if (_selectedGuruId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih guru terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Konfirmasi reset
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Reset'),
        content: const Text('Pengaturan gaji guru ini akan dikembalikan ke pengaturan global. Lanjutkan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await _apiService.hapusPengaturanGajiGuru(_selectedGuruId!);
      
      setState(() {
        _isLoading = false;
      });
      
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengaturan gaji guru berhasil direset ke global'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reset form to global values
        _gajiPokokGuruController.text = _pengaturanGajiGlobal!.gajiPokok.toString();
        _potonganIzinGuruController.text = _pengaturanGajiGlobal!.potonganIzin.toString();
        _potonganSakitGuruController.text = _pengaturanGajiGlobal!.potonganSakit.toString();
        _potonganAlpaGuruController.text = _pengaturanGajiGlobal!.potonganAlpa.toString();
        
        // Remove from map
        setState(() {
          _pengaturanPerGuru.remove(_selectedGuruId);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal mereset pengaturan gaji guru'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Widget _buildGajiForm({
    required GlobalKey<FormState> formKey,
    required TextEditingController gajiPokokController,
    required TextEditingController potonganIzinController,
    required TextEditingController potonganSakitController,
    required TextEditingController potonganAlpaController,
    required Function() onSave,
    Function()? onReset,
  }) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );
    
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gaji Pokok
          TextFormField(
            controller: gajiPokokController,
            decoration: InputDecoration(
              labelText: 'Gaji Pokok',
              hintText: 'Contoh: 3000000',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.monetization_on),
              prefixText: 'Rp',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Gaji pokok tidak boleh kosong';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Potongan Izin
          TextFormField(
            controller: potonganIzinController,
            decoration: InputDecoration(
              labelText: 'Potongan Izin',
              hintText: 'Contoh: 150000',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.remove_circle_outline),
              prefixText: 'Rp',
              helperText: 'Potongan gaji jika izin (per hari)',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Potongan izin tidak boleh kosong';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Potongan Sakit
          TextFormField(
            controller: potonganSakitController,
            decoration: InputDecoration(
              labelText: 'Potongan Sakit',
              hintText: 'Contoh: 50000',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.medical_services_outlined),
              prefixText: 'Rp',
              helperText: 'Potongan gaji jika sakit (per hari)',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Potongan sakit tidak boleh kosong';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Potongan Alpa
          TextFormField(
            controller: potonganAlpaController,
            decoration: InputDecoration(
              labelText: 'Potongan Alpa (Tanpa Keterangan)',
              hintText: 'Contoh: 300000',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.cancel_outlined),
              prefixText: 'Rp',
              helperText: 'Potongan gaji jika tidak hadir tanpa keterangan (per hari)',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Potongan alpa tidak boleh kosong';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          
          // Tombol simpan dan reset
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onReset != null) ...[
                OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset ke Global'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(color: Theme.of(context).colorScheme.error),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              ElevatedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save),
                label: const Text('Simpan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Gaji'),
        elevation: 0,
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
                    // Tab menu
                    Container(
                      color: Theme.of(context).primaryColor,
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                _tabController.animateToPage(
                                  0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                                setState(() {
                                  _selectedTabIndex = 0;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _selectedTabIndex == 0
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Global',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: _selectedTabIndex == 0
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                _tabController.animateToPage(
                                  1,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                                setState(() {
                                  _selectedTabIndex = 1;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _selectedTabIndex == 1
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Per Guru',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: _selectedTabIndex == 1
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Tab content
                    Expanded(
                      child: PageView(
                        controller: _tabController,
                        onPageChanged: (index) {
                          setState(() {
                            _selectedTabIndex = index;
                          });
                        },
                        children: [
                          // Pengaturan Global
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title
                                const Text(
                                  'Pengaturan Gaji Global',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Pengaturan ini akan berlaku untuk semua guru kecuali yang memiliki pengaturan khusus.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // Form pengaturan global
                                _buildGajiForm(
                                  formKey: _formKeyGlobal,
                                  gajiPokokController: _gajiPokokController,
                                  potonganIzinController: _potonganIzinController,
                                  potonganSakitController: _potonganSakitController,
                                  potonganAlpaController: _potonganAlpaController,
                                  onSave: _saveGlobalSettings,
                                ),
                              ],
                            ),
                          ),
                          
                          // Pengaturan Per Guru
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title
                                const Text(
                                  'Pengaturan Gaji Per Guru',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Atur gaji khusus untuk guru tertentu. Jika tidak diatur, akan menggunakan pengaturan global.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // Dropdown pilih guru
                                DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: 'Pilih Guru',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: const Icon(Icons.person),
                                  ),
                                  value: _selectedGuruId,
                                  items: _guruList.map((guru) {
                                    return DropdownMenuItem<String>(
                                      value: guru.id,
                                      child: Text(guru.nama),
                                    );
                                  }).toList(),
                                  onChanged: _onGuruSelected,
                                  hint: const Text('Pilih guru yang ingin diatur gajinya'),
                                ),
                                const SizedBox(height: 24),
                                
                                if (_selectedGuruId != null) ...[
                                  // Status pengaturan
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _pengaturanPerGuru.containsKey(_selectedGuruId)
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _pengaturanPerGuru.containsKey(_selectedGuruId)
                                              ? Icons.check_circle
                                              : Icons.info,
                                          color: _pengaturanPerGuru.containsKey(_selectedGuruId)
                                              ? Colors.green
                                              : Colors.orange,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _pengaturanPerGuru.containsKey(_selectedGuruId)
                                                ? 'Guru ini memiliki pengaturan gaji khusus'
                                                : 'Guru ini menggunakan pengaturan gaji global',
                                            style: TextStyle(
                                              color: _pengaturanPerGuru.containsKey(_selectedGuruId)
                                                  ? Colors.green
                                                  : Colors.orange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // Form pengaturan per guru
                                  _buildGajiForm(
                                    formKey: _formKeyPerGuru,
                                    gajiPokokController: _gajiPokokGuruController,
                                    potonganIzinController: _potonganIzinGuruController,
                                    potonganSakitController: _potonganSakitGuruController,
                                    potonganAlpaController: _potonganAlpaGuruController,
                                    onSave: _savePerGuruSettings,
                                    onReset: _pengaturanPerGuru.containsKey(_selectedGuruId)
                                        ? _resetPerGuruSettings
                                        : null,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
} 