class Absensi {
  final String id;
  final String guruId;
  final String namaGuru;
  final String tanggal;
  final String jamMasuk;
  final String? jamKeluar;
  final String status;
  final String? keterangan;

  Absensi({
    required this.id,
    required this.guruId,
    required this.namaGuru,
    required this.tanggal,
    required this.jamMasuk,
    this.jamKeluar,
    required this.status,
    this.keterangan,
  });

  factory Absensi.fromJson(Map<String, dynamic> json) {
    return Absensi(
      id: json['id'] ?? '',
      guruId: json['guruId'] ?? '',
      namaGuru: json['namaGuru'] ?? '',
      tanggal: json['tanggal'] ?? '',
      jamMasuk: json['jamMasuk'] ?? '',
      jamKeluar: json['jamKeluar'],
      status: json['status'] ?? 'hadir',
      keterangan: json['keterangan'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'guruId': guruId,
      'namaGuru': namaGuru,
      'tanggal': tanggal,
      'jamMasuk': jamMasuk,
      'jamKeluar': jamKeluar,
      'status': status,
      'keterangan': keterangan,
    };
  }
} 