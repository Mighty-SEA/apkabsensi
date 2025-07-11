import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DashboardAdminScreen extends StatefulWidget {
  const DashboardAdminScreen({Key? key}) : super(key: key);
  @override
  State<DashboardAdminScreen> createState() => _DashboardAdminScreenState();
}

class _DashboardAdminScreenState extends State<DashboardAdminScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String _error = '';
  List<Map<String, dynamic>> _rekap = [];

  @override
  void initState() {
    super.initState();
    _fetchRekap();
  }

  Future<void> _fetchRekap() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    final result = await _apiService.getAbsensiRekapAllGuru();
    if (result['success']) {
      setState(() {
        _rekap = List<Map<String, dynamic>>.from(result['data']);
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['message'] ?? 'Gagal memuat rekap';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Rekap Bulanan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRekap,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Nama Guru')),
                      DataColumn(label: Text('Hadir')),
                      DataColumn(label: Text('Izin')),
                      DataColumn(label: Text('Sakit')),
                      DataColumn(label: Text('Alpa')),
                    ],
                    rows: _rekap.map((e) => DataRow(cells: [
                      DataCell(Text(e['namaGuru'] ?? '-')),
                      DataCell(Text('${e['totalHadir'] ?? 0}')),
                      DataCell(Text('${e['totalIzin'] ?? 0}')),
                      DataCell(Text('${e['totalSakit'] ?? 0}')),
                      DataCell(Text('${e['totalAlpa'] ?? 0}')),
                    ])).toList(),
                  ),
                ),
    );
  }
} 