class Guru {
  final String id;
  final String nama;
  final String nip;
  final String? jenisKelamin;
  final String? alamat;
  final String? noTelp;
  final String? email;
  final String? mapel;

  Guru({
    required this.id,
    required this.nama,
    required this.nip,
    this.jenisKelamin,
    this.alamat,
    this.noTelp,
    this.email,
    this.mapel,
  });

  factory Guru.fromJson(Map<String, dynamic> json) {
    return Guru(
      id: json['id'] ?? '',
      nama: json['nama'] ?? '',
      nip: json['nip'] ?? '',
      jenisKelamin: json['jenisKelamin'],
      alamat: json['alamat'],
      noTelp: json['noTelp'],
      email: json['email'],
      mapel: json['mapel'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama': nama,
      'nip': nip,
      'jenisKelamin': jenisKelamin,
      'alamat': alamat,
      'noTelp': noTelp,
      'email': email,
      'mapel': mapel,
    };
  }
} 