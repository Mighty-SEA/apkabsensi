import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/guru_model.dart';
import '../services/api_service.dart';

class ManajemenGuruScreen extends StatefulWidget {
  const ManajemenGuruScreen({Key? key}) : super(key: key);
  @override
  State<ManajemenGuruScreen> createState() => _ManajemenGuruScreenState();
}

class _ManajemenGuruScreenState extends State<ManajemenGuruScreen> {
  final ApiService _apiService = ApiService();
  List<Guru> _guruList = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _error = '';
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false; // Untuk toggle visibility password
  
  // Filter pencarian
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Guru> get _filteredGuruList => _guruList
      .where((guru) => 
          guru.nama.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          guru.nip.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (guru.mapel != null && guru.mapel!.toLowerCase().contains(_searchQuery.toLowerCase())))
      .toList();

  // Untuk validasi email
  final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
  );

  @override
  void initState() {
    super.initState();
    _fetchGuru();
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

  void _showGuruDialog({Guru? guru}) {
    // Controller untuk form fields
    final namaController = TextEditingController(text: guru?.nama ?? '');
    final nipController = TextEditingController(text: guru?.nip ?? '');
    final jenisKelaminController = TextEditingController(text: guru?.jenisKelamin ?? 'Laki-laki');
    final alamatController = TextEditingController(text: guru?.alamat ?? '');
    final noTelpController = TextEditingController(text: guru?.noTelp ?? '');
    final emailController = TextEditingController(text: guru?.email ?? '');
    final mapelController = TextEditingController(text: guru?.mapel ?? '');
    
    // Khusus untuk tambah guru baru
    final usernameController = TextEditingController();
    final passwordController = TextEditingController(text: 'password');
    
    // Pilihan jenis kelamin
    final jenisKelaminOptions = ['Laki-laki', 'Perempuan'];
    String selectedJenisKelamin = guru?.jenisKelamin ?? 'Laki-laki';
    
    // Fungsi untuk generate username dari nama
    void updateUsername() {
      if (namaController.text.isNotEmpty && guru == null) {
        // Ambil kata pertama dari nama (sebelum spasi pertama)
        final firstName = namaController.text.split(' ').first.toLowerCase();
        usernameController.text = firstName;
      }
    }
    
    // Set username dari nama saat dialog pertama kali dibuka
    updateUsername();
    
    // Reset state submission
    _isSubmitting = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 10,
              backgroundColor: Colors.white,
              child: Container(
                padding: const EdgeInsets.all(24),
                width: MediaQuery.of(context).size.width * 0.8,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                              radius: 25,
                              child: Icon(
                                guru == null ? Icons.person_add : Icons.edit_note,
                                color: Theme.of(context).primaryColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    guru == null ? 'Tambah Guru Baru' : 'Edit Data Guru',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    guru == null 
                                      ? 'Masukkan informasi guru dan data akun'
                                      : 'Perbarui informasi data guru',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                              splashRadius: 20,
                            ),
                          ],
                        ),
                        
                        const Divider(height: 32),
                        
                        // Section title: Data Guru
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.badge,
                                color: Theme.of(context).primaryColor,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Data Guru',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Nama field dengan auto-generate username
                        TextFormField(
                          controller: namaController,
                          decoration: InputDecoration(
                            labelText: 'Nama Lengkap *',
                            hintText: 'Masukkan nama lengkap',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.person),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Nama tidak boleh kosong';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            // Update username secara live saat nama diketik (jika tambah baru)
                            updateUsername();
                            setState(() {}); // Refresh UI untuk menampilkan perubahan username
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // NIP field
                        TextFormField(
                          controller: nipController,
                          decoration: InputDecoration(
                            labelText: 'NIP *',
                            hintText: 'Masukkan NIP',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.credit_card),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'NIP tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Jenis Kelamin dropdown
                        DropdownButtonFormField<String>(
                          value: selectedJenisKelamin,
                          decoration: InputDecoration(
                            labelText: 'Jenis Kelamin',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.wc),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          items: jenisKelaminOptions.map((option) {
                            return DropdownMenuItem(
                              value: option,
                              child: Text(option),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedJenisKelamin = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Alamat field
                        TextFormField(
                          controller: alamatController,
                          decoration: InputDecoration(
                            labelText: 'Alamat',
                            hintText: 'Masukkan alamat',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.home),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        
                        // Row untuk no telp dan email
                        Row(
                          children: [
                            // No Telp field
                            Expanded(
                              child: TextFormField(
                                controller: noTelpController,
                                decoration: InputDecoration(
                                  labelText: 'Nomor Telepon',
                                  hintText: 'Nomor telepon',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.phone),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  prefixText: '+62 ',
                                ),
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            
                            // Email field
                            Expanded(
                              child: TextFormField(
                                controller: emailController,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'Email',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.email),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value != null && value.isNotEmpty && !_emailRegex.hasMatch(value)) {
                                    return 'Format email tidak valid';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Mata Pelajaran field
                        TextFormField(
                          controller: mapelController,
                          decoration: InputDecoration(
                            labelText: 'Mata Pelajaran',
                            hintText: 'Mata pelajaran yang diampu',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.book),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                        
                        // Tambahan form untuk user baru
                        if (guru == null) ...[
                          const Divider(height: 32),
                          
                          // Section title: Data Akun
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.account_circle,
                                  color: Theme.of(context).primaryColor,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Data Akun',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Username field (auto-generated)
                          TextFormField(
                            controller: usernameController,
                            decoration: InputDecoration(
                              labelText: 'Username *',
                              hintText: 'Username untuk login',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.alternate_email),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              helperText: 'Username otomatis dari nama depan',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Username tidak boleh kosong';
                              }
                              if (value.contains(' ')) {
                                return 'Username tidak boleh mengandung spasi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Password field (default: 'password')
                          TextFormField(
                            controller: passwordController,
                            decoration: InputDecoration(
                              labelText: 'Password *',
                              hintText: 'Password untuk login',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.lock),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              helperText: 'Default: "password"',
                              suffixIcon: IconButton(
                                icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                            ),
                            obscureText: !_isPasswordVisible,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password tidak boleh kosong';
                              }
                              if (value.length < 6) {
                                return 'Password minimal 6 karakter';
                              }
                              return null;
                            },
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        
                        // Action buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _isSubmitting 
                                ? null 
                                : () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              child: const Text('Batal'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _isSubmitting 
                                ? null 
                                : () async {
                                    if (_formKey.currentState!.validate()) {
                                      setState(() {
                                        _isSubmitting = true;
                                      });
                                      
                                      try {
                                        final guruData = {
                                          'nama': namaController.text,
                                          'nip': nipController.text,
                                          'jenisKelamin': selectedJenisKelamin,
                                          'alamat': alamatController.text,
                                          'noTelp': noTelpController.text,
                                          'email': emailController.text,
                                          'mataPelajaran': mapelController.text,
                                        };
                                        
                                        // Tambahkan data user jika tambah guru baru
                                        if (guru == null) {
                                          guruData['username'] = usernameController.text;
                                          guruData['password'] = passwordController.text;
                                        }
                                        
                                        final result = guru == null
                                            ? await _apiService.createGuru(guruData)
                                            : await _apiService.updateGuru(guru.id, guruData);
                                        
                                        setState(() {
                                          _isSubmitting = false;
                                        });
                                        
                                        Navigator.pop(context);
                                        
                                        if (result['success']) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(result['message'] ?? (guru == null ? 'Guru berhasil ditambahkan' : 'Guru berhasil diupdate')),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                          _fetchGuru();
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(result['message'] ?? 'Terjadi kesalahan'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setState(() {
                                          _isSubmitting = false;
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Terjadi kesalahan: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      guru == null ? 'Tambah Guru' : 'Simpan Perubahan',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }

  void _showDetail(Guru guru) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detail Guru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nama: ${guru.nama}'),
            Text('NIP: ${guru.nip}'),
            if (guru.jenisKelamin != null) Text('Jenis Kelamin: ${guru.jenisKelamin}'),
            if (guru.alamat != null && guru.alamat!.isNotEmpty) Text('Alamat: ${guru.alamat}'),
            if (guru.noTelp != null && guru.noTelp!.isNotEmpty) Text('No. Telp: ${guru.noTelp}'),
            if (guru.email != null && guru.email!.isNotEmpty) Text('Email: ${guru.email}'),
            if (guru.mapel != null && guru.mapel!.isNotEmpty) Text('Mata Pelajaran: ${guru.mapel}'),
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

  void _showDeleteConfirmation(Guru guru) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Apakah Anda yakin ingin menghapus guru ini?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Nama: ${guru.nama}'),
            Text('NIP: ${guru.nip}'),
            const SizedBox(height: 16),
            const Text(
              'Perhatian: Tindakan ini akan menghapus data guru dan akun user terkait!',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteGuru(guru);
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

  Future<void> _deleteGuru(Guru guru) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await _apiService.deleteGuru(guru.id);
      
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Guru berhasil dihapus'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchGuru();
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal menghapus guru'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Guru'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchGuru,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showGuruDialog(),
            tooltip: 'Tambah Guru',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            color: theme.primaryColor,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Cari nama, NIP, atau mata pelajaran...',
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
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
              ),
            ),
          ),
          
          // List atau loading
          Expanded(
            child: _isLoading
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
                              onPressed: _fetchGuru,
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      )
                    : _filteredGuruList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_search,
                                  size: 80,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty 
                                      ? 'Tidak ada guru yang sesuai dengan pencarian.'
                                      : 'Belum ada data guru. Silakan tambahkan guru baru.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (_searchQuery.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('Reset Pencarian'),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredGuruList.length,
                            padding: const EdgeInsets.all(12),
                            itemBuilder: (context, i) {
                              final guru = _filteredGuruList[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _showDetail(guru),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: _getAvatarColor(guru.nama),
                                          radius: 28,
                                          child: Text(
                                            guru.nama.isNotEmpty ? guru.nama[0].toUpperCase() : '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                guru.nama,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'NIP: ${guru.nip}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                              if (guru.mapel != null && guru.mapel!.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.book,
                                                      size: 14,
                                                      color: theme.primaryColor,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        guru.mapel!,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: theme.primaryColor,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Column(
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons.edit,
                                                color: theme.primaryColor,
                                              ),
                                              onPressed: () => _showGuruDialog(guru: guru),
                                              tooltip: 'Edit',
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              onPressed: () => _showDeleteConfirmation(guru),
                                              tooltip: 'Hapus',
                                            ),
                                          ],
                                        ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGuruDialog(),
        backgroundColor: theme.primaryColor,
        icon: const Icon(Icons.person_add),
        label: const Text('Tambah Guru'),
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