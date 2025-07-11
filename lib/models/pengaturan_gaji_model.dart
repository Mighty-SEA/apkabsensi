class PengaturanGaji {
  final String id;
  final int gajiPokok;
  final int potonganIzin;
  final int potonganSakit;
  final int potonganAlpa;
  final bool isGlobal;
  final String? guruId;
  
  PengaturanGaji({
    required this.id,
    required this.gajiPokok,
    required this.potonganIzin,
    required this.potonganSakit,
    required this.potonganAlpa,
    required this.isGlobal,
    this.guruId,
  });
  
  factory PengaturanGaji.fromJson(Map<String, dynamic> json) {
    return PengaturanGaji(
      id: json['id']?.toString() ?? '',
      gajiPokok: json['gajiPokok'] is int ? json['gajiPokok'] : int.tryParse(json['gajiPokok']?.toString() ?? '0') ?? 0,
      potonganIzin: json['potonganIzin'] is int ? json['potonganIzin'] : int.tryParse(json['potonganIzin']?.toString() ?? '0') ?? 0,
      potonganSakit: json['potonganSakit'] is int ? json['potonganSakit'] : int.tryParse(json['potonganSakit']?.toString() ?? '0') ?? 0,
      potonganAlpa: json['potonganAlpa'] is int ? json['potonganAlpa'] : int.tryParse(json['potonganAlpa']?.toString() ?? '0') ?? 0,
      isGlobal: json['isGlobal'] ?? true,
      guruId: json['guruId']?.toString(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gajiPokok': gajiPokok,
      'potonganIzin': potonganIzin,
      'potonganSakit': potonganSakit,
      'potonganAlpa': potonganAlpa,
      'isGlobal': isGlobal,
      'guruId': guruId,
    };
  }
  
  // Untuk menampilkan format rupiah
  String formatRupiah(int nominal) {
    return 'Rp${nominal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }
  
  String get gajiPokokFormatted => formatRupiah(gajiPokok);
  String get potonganIzinFormatted => formatRupiah(potonganIzin);
  String get potonganSakitFormatted => formatRupiah(potonganSakit);
  String get potonganAlpaFormatted => formatRupiah(potonganAlpa);
}

class GajiGuru {
  final String id;
  final String guruId;
  final String namaGuru;
  final String periode; // Format: YYYY-MM
  final int gajiPokok;
  final int potonganIzin;
  final int potonganSakit;
  final int potonganAlpa;
  final int jumlahHadir;
  final int jumlahIzin;
  final int jumlahSakit;
  final int jumlahAlpa;
  final int totalPotongan;
  final int totalGaji;
  final bool sudahDibayar;
  final String? tanggalPembayaran;
  
  GajiGuru({
    required this.id,
    required this.guruId,
    required this.namaGuru,
    required this.periode,
    required this.gajiPokok,
    required this.potonganIzin,
    required this.potonganSakit,
    required this.potonganAlpa,
    required this.jumlahHadir,
    required this.jumlahIzin,
    required this.jumlahSakit,
    required this.jumlahAlpa,
    required this.totalPotongan,
    required this.totalGaji,
    required this.sudahDibayar,
    this.tanggalPembayaran,
  });
  
  factory GajiGuru.fromJson(Map<String, dynamic> json) {
    return GajiGuru(
      id: json['id']?.toString() ?? '',
      guruId: json['guruId']?.toString() ?? '',
      namaGuru: json['namaGuru'] ?? json['guru']?['nama'] ?? '',
      periode: json['periode'] ?? '',
      gajiPokok: json['gajiPokok'] is int ? json['gajiPokok'] : int.tryParse(json['gajiPokok']?.toString() ?? '0') ?? 0,
      potonganIzin: json['potonganIzin'] is int ? json['potonganIzin'] : int.tryParse(json['potonganIzin']?.toString() ?? '0') ?? 0,
      potonganSakit: json['potonganSakit'] is int ? json['potonganSakit'] : int.tryParse(json['potonganSakit']?.toString() ?? '0') ?? 0,
      potonganAlpa: json['potonganAlpa'] is int ? json['potonganAlpa'] : int.tryParse(json['potonganAlpa']?.toString() ?? '0') ?? 0,
      jumlahHadir: json['jumlahHadir'] is int ? json['jumlahHadir'] : int.tryParse(json['jumlahHadir']?.toString() ?? '0') ?? 0,
      jumlahIzin: json['jumlahIzin'] is int ? json['jumlahIzin'] : int.tryParse(json['jumlahIzin']?.toString() ?? '0') ?? 0,
      jumlahSakit: json['jumlahSakit'] is int ? json['jumlahSakit'] : int.tryParse(json['jumlahSakit']?.toString() ?? '0') ?? 0,
      jumlahAlpa: json['jumlahAlpa'] is int ? json['jumlahAlpa'] : int.tryParse(json['jumlahAlpa']?.toString() ?? '0') ?? 0,
      totalPotongan: json['totalPotongan'] is int ? json['totalPotongan'] : int.tryParse(json['totalPotongan']?.toString() ?? '0') ?? 0,
      totalGaji: json['totalGaji'] is int ? json['totalGaji'] : int.tryParse(json['totalGaji']?.toString() ?? '0') ?? 0,
      sudahDibayar: json['sudahDibayar'] ?? false,
      tanggalPembayaran: json['tanggalPembayaran']?.toString(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'guruId': guruId,
      'namaGuru': namaGuru,
      'periode': periode,
      'gajiPokok': gajiPokok,
      'potonganIzin': potonganIzin,
      'potonganSakit': potonganSakit,
      'potonganAlpa': potonganAlpa,
      'jumlahHadir': jumlahHadir,
      'jumlahIzin': jumlahIzin,
      'jumlahSakit': jumlahSakit,
      'jumlahAlpa': jumlahAlpa,
      'totalPotongan': totalPotongan,
      'totalGaji': totalGaji,
      'sudahDibayar': sudahDibayar,
      'tanggalPembayaran': tanggalPembayaran,
    };
  }
  
  // Untuk menampilkan format rupiah
  String formatRupiah(int nominal) {
    return 'Rp${nominal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }
  
  String get gajiPokokFormatted => formatRupiah(gajiPokok);
  String get totalPotonganFormatted => formatRupiah(totalPotongan);
  String get totalGajiFormatted => formatRupiah(totalGaji);
} 