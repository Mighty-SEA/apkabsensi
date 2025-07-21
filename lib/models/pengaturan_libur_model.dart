// Model untuk pengaturan hari libur akhir pekan dan libur nasional

class PengaturanLiburAkhirPekan {
  final bool senin;
  final bool selasa;
  final bool rabu;
  final bool kamis;
  final bool jumat;
  final bool sabtu;
  final bool minggu;

  PengaturanLiburAkhirPekan({
    this.senin = false,
    this.selasa = false,
    this.rabu = false,
    this.kamis = false,
    this.jumat = false,
    this.sabtu = true, // Default Sabtu libur
    this.minggu = true, // Default Minggu libur
  });

  factory PengaturanLiburAkhirPekan.fromJson(Map<String, dynamic> json) {
    return PengaturanLiburAkhirPekan(
      senin: json['senin'] ?? false,
      selasa: json['selasa'] ?? false,
      rabu: json['rabu'] ?? false,
      kamis: json['kamis'] ?? false,
      jumat: json['jumat'] ?? false,
      sabtu: json['sabtu'] ?? true,
      minggu: json['minggu'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senin': senin,
      'selasa': selasa,
      'rabu': rabu,
      'kamis': kamis,
      'jumat': jumat,
      'sabtu': sabtu,
      'minggu': minggu,
    };
  }

  // Check apakah hari tertentu adalah libur akhir pekan
  bool isLibur(DateTime date) {
    int weekday = date.weekday; // 1 = Senin, 7 = Minggu
    switch (weekday) {
      case 1: return senin;
      case 2: return selasa;
      case 3: return rabu;
      case 4: return kamis;
      case 5: return jumat;
      case 6: return sabtu;
      case 7: return minggu;
      default: return false;
    }
  }
}

class LiburNasional {
  final String id;
  final String nama;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final String? keterangan;

  LiburNasional({
    required this.id,
    required this.nama,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    this.keterangan,
  });

  factory LiburNasional.fromJson(Map<String, dynamic> json) {
    return LiburNasional(
      id: json['id']?.toString() ?? '',
      nama: json['nama'] != null ? json['nama'].toString() : '',
      tanggalMulai: json['tanggalMulai'] != null 
          ? DateTime.parse(json['tanggalMulai']) 
          : DateTime.now(),
      tanggalSelesai: json['tanggalSelesai'] != null 
          ? DateTime.parse(json['tanggalSelesai']) 
          : DateTime.now(),
      keterangan: json['keterangan'] != null ? json['keterangan'].toString() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama': nama,
      'tanggalMulai': tanggalMulai.toIso8601String(),
      'tanggalSelesai': tanggalSelesai.toIso8601String(),
      'keterangan': keterangan,
    };
  }

  // Check apakah tanggal tertentu masuk dalam libur nasional ini
  bool isInLiburPeriod(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final startOnly = DateTime(tanggalMulai.year, tanggalMulai.month, tanggalMulai.day);
    final endOnly = DateTime(tanggalSelesai.year, tanggalSelesai.month, tanggalSelesai.day);
    
    return dateOnly.compareTo(startOnly) >= 0 && dateOnly.compareTo(endOnly) <= 0;
  }
} 