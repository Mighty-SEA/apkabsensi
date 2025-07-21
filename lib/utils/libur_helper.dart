import '../models/pengaturan_libur_model.dart';
import 'package:intl/intl.dart';

class LiburHelper {
  // Pengecekan apakah suatu hari adalah libur
  static bool isHariLibur(
    DateTime date,
    PengaturanLiburAkhirPekan? akhirPekan,
    List<LiburNasional> liburNasional,
  ) {
    // Default untuk Sabtu dan Minggu jika tidak ada pengaturan
    if (akhirPekan == null) {
      int weekday = date.weekday;
      return weekday == 6 || weekday == 7; // 6 = Sabtu, 7 = Minggu
    }
    
    // Cek hari libur akhir pekan
    if (akhirPekan.isLibur(date)) {
      return true;
    }
    
    // Cek libur nasional
    for (final libur in liburNasional) {
      if (libur.isInLiburPeriod(date)) {
        return true;
      }
    }
    
    return false;
  }
  
  // Mendapatkan alasan libur
  static String? getAlasanLibur(
    DateTime date,
    PengaturanLiburAkhirPekan? akhirPekan,
    List<LiburNasional> liburNasional,
  ) {
    // Cek libur nasional terlebih dahulu (prioritas)
    for (final libur in liburNasional) {
      if (libur.isInLiburPeriod(date)) {
        return 'Libur Nasional: ${libur.nama}';
      }
    }
    
    // Cek hari libur akhir pekan
    if (akhirPekan != null && akhirPekan.isLibur(date)) {
      return 'Libur Akhir Pekan';
    }
    
    return null;
  }
  
  // Mendapatkan nama hari dalam Bahasa Indonesia
  static String getNamaHari(DateTime date) {
    return DateFormat('EEEE', 'id_ID').format(date);
  }
  
  // Mendapatkan tanggal dalam format Indonesia
  static String getTanggalLengkap(DateTime date) {
    return DateFormat('d MMMM yyyy', 'id_ID').format(date);
  }
} 