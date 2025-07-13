class Guru {
  final String id;
  final String nama;
  final String? jenisKelamin;
  final String? alamat;
  final String? noTelp;

  Guru({
    required this.id,
    required this.nama,
    this.jenisKelamin,
    this.alamat,
    this.noTelp,
  });

  factory Guru.fromJson(Map<String, dynamic> json) {
    return Guru(
      id: json['id']?.toString() ?? '',
      nama: json['nama'] ?? '',
      jenisKelamin: json['jenisKelamin'],
      alamat: json['alamat'],
      noTelp: json['noTelp'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama': nama,
      'jenisKelamin': jenisKelamin,
      'alamat': alamat,
      'noTelp': noTelp,
    };
  }
} 