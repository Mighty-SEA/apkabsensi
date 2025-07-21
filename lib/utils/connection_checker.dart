import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ConnectionChecker {
  static Future<Map<String, dynamic>> checkAllConnections() async {
    final ApiService apiService = ApiService();
    final result = <String, dynamic>{};
    
    // 1. Cek koneksi internet
    final hasInternet = await apiService.hasInternetConnection();
    result['internetConnected'] = hasInternet;
    
    if (!hasInternet) {
      result['error'] = 'Tidak ada koneksi internet';
      return result;
    }
    
    // 2. Cek koneksi ke server backend
    final serverCheck = await apiService.checkServerConnection();
    result['serverConnected'] = serverCheck['success'];
    result['serverMessage'] = serverCheck['message'];
    
    if (!serverCheck['success']) {
      result['error'] = 'Tidak dapat terhubung ke server: ${serverCheck['message']}';
      return result;
    }
    
    // 3. Cek status API (dapat diakses atau tidak)
    try {
      final apiStatusCheck = await apiService.checkApiStatus();
      result['apiConnected'] = apiStatusCheck['success'];
      result['apiMessage'] = apiStatusCheck['message'] ?? apiStatusCheck['data']?['message'];
      
      if (!apiStatusCheck['success']) {
        result['error'] = 'API tidak dapat diakses: ${apiStatusCheck['message']}';
      }
    } catch (e) {
      result['apiConnected'] = false;
      result['error'] = 'Gagal memeriksa status API: $e';
    }
    
    // 4. Cek endpoint spesifik untuk fitur libur
    try {
      // Cek endpoint akhir pekan
      final akhirPekanCheck = await apiService.getAkhirPekanSettings();
      result['akhirPekanEndpointConnected'] = akhirPekanCheck['success'];
      
      if (!akhirPekanCheck['success']) {
        result['akhirPekanEndpointError'] = akhirPekanCheck['message'];
      }
      
      // Cek endpoint libur nasional
      final liburNasionalCheck = await apiService.getLiburNasional();
      result['liburNasionalEndpointConnected'] = liburNasionalCheck['success'];
      
      if (!liburNasionalCheck['success']) {
        result['liburNasionalEndpointError'] = liburNasionalCheck['message'];
      }
    } catch (e) {
      result['libusEndpointsError'] = 'Gagal memeriksa endpoint libur: $e';
    }
    
    return result;
  }
  
  // Tampilkan dialog hasil pengecekan
  static Future<void> showConnectionCheckDialog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Memeriksa Koneksi...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Sedang memeriksa koneksi ke server...')
          ],
        ),
      ),
    );
    
    // Lakukan pengecekan
    final result = await checkAllConnections();
    
    // Tutup dialog loading
    Navigator.pop(context);
    
    // Tampilkan hasil
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          result['error'] != null ? 'Masalah Koneksi' : 'Status Koneksi',
          style: TextStyle(
            color: result['error'] != null ? Colors.red : Colors.green,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusItem(
                'Koneksi Internet', 
                result['internetConnected'] == true,
                errorMessage: !result['internetConnected'] ? 'Tidak terhubung ke internet' : null,
              ),
              const Divider(),
              _buildStatusItem(
                'Koneksi Server', 
                result['serverConnected'] == true,
                message: result['serverMessage'],
              ),
              const Divider(),
              _buildStatusItem(
                'Status API', 
                result['apiConnected'] == true,
                message: result['apiMessage'],
              ),
              const Divider(),
              _buildStatusItem(
                'Endpoint Akhir Pekan', 
                result['akhirPekanEndpointConnected'] == true,
                errorMessage: result['akhirPekanEndpointError'],
              ),
              const Divider(),
              _buildStatusItem(
                'Endpoint Libur Nasional', 
                result['liburNasionalEndpointConnected'] == true,
                errorMessage: result['liburNasionalEndpointError'],
              ),
              
              if (result['error'] != null) ...[
                const Divider(),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Error Detail:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(result['error'], style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              showConnectionCheckDialog(context);
            },
            child: const Text('Cek Ulang'),
          ),
        ],
      ),
    );
  }
  
  // Widget untuk menampilkan item status
  static Widget _buildStatusItem(String title, bool isSuccess, {String? message, String? errorMessage}) {
    return Row(
      children: [
        Icon(
          isSuccess ? Icons.check_circle : Icons.error_outline,
          color: isSuccess ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (message != null || errorMessage != null)
                Text(
                  message ?? errorMessage ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSuccess ? Colors.grey[600] : Colors.red,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
} 