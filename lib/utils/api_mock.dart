class ApiMock {
  // Mock untuk respons login
  static Map<String, dynamic> mockLoginResponse({
    required String username, 
    required String password
  }) {
    if (username == 'testuser' && password == 'password123') {
      return {
        'success': true,
        'data': {
          'id': 'user123',
          'username': username,
          'name': 'Test User',
          'role': 'guru',
          'token': 'mock-jwt-token-12345',
          'guruId': 'guru1', // ID guru untuk keperluan absensi
        }
      };
    } else {
      return {
        'success': false,
        'message': 'Username atau password salah',
      };
    }
  }

  // Mock untuk data guru
  static Map<String, dynamic> mockGuruData() {
    return {
      'success': true,
      'data': [
        {
          'id': 'guru1',
          'nama': 'Ahmad Setiawan',
          'nip': '19850512200901',
          'jenisKelamin': 'L',
          'alamat': 'Jl. Pendidikan No. 123',
          'noTelp': '08123456789',
          'email': 'ahmad@sekolah.ac.id',
          'mapel': 'Matematika'
        },
        {
          'id': 'guru2',
          'nama': 'Siti Rahayu',
          'nip': '19871025201001',
          'jenisKelamin': 'P',
          'alamat': 'Jl. Guru No. 45',
          'noTelp': '08234567890',
          'email': 'siti@sekolah.ac.id',
          'mapel': 'Bahasa Indonesia'
        },
        {
          'id': 'guru3',
          'nama': 'Budi Santoso',
          'nip': '19800330200501',
          'jenisKelamin': 'L',
          'alamat': 'Jl. Pendidik No. 67',
          'noTelp': '08345678901',
          'email': 'budi@sekolah.ac.id',
          'mapel': 'IPA'
        }
      ]
    };
  }

  // Mock untuk data absensi
  static Map<String, dynamic> mockAbsensiData() {
    return {
      'success': true,
      'data': [
        {
          'id': 'absensi1',
          'guruId': 'guru1',
          'namaGuru': 'Ahmad Setiawan',
          'tanggal': '2023-06-10',
          'jamMasuk': '07:30:00',
          'jamKeluar': '15:00:00',
          'status': 'hadir',
          'keterangan': ''
        },
        {
          'id': 'absensi2',
          'guruId': 'guru2',
          'namaGuru': 'Siti Rahayu',
          'tanggal': '2023-06-10',
          'jamMasuk': '07:45:00',
          'jamKeluar': '15:15:00',
          'status': 'hadir',
          'keterangan': ''
        },
        {
          'id': 'absensi3',
          'guruId': 'guru3',
          'namaGuru': 'Budi Santoso',
          'tanggal': '2023-06-10',
          'jamMasuk': '',
          'jamKeluar': '',
          'status': 'izin',
          'keterangan': 'Sakit demam'
        }
      ]
    };
  }

  // Mock untuk membuat absensi baru
  static Map<String, dynamic> mockCreateAbsensi(Map<String, dynamic> absensiData) {
    return {
      'success': true,
      'data': {
        'id': 'absensi${DateTime.now().millisecondsSinceEpoch}',
        ...absensiData
      }
    };
  }

  // Mock untuk verifikasi token
  static Map<String, dynamic> mockTestToken() {
    return {
      'success': true,
      'data': {
        'valid': true,
        'userId': 'user123',
        'username': 'testuser'
      }
    };
  }
} 