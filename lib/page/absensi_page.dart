import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'login_page.dart';

class AbsensiPage extends StatefulWidget {
  const AbsensiPage({super.key});

  @override
  State<AbsensiPage> createState() => _AbsensiPageState();
}

class _AbsensiPageState extends State<AbsensiPage> {
  bool sudahCheckInPagi = false;
  bool sudahCheckOutSore = false;
  bool diArea = false;
  bool loading = true;

  double jarak = 0;
  String status = 'Mengecek lokasi...';
  Color statusColor = Colors.white;
  IconData statusIcon = Icons.help_outline;

  String? currentUser;
  List<dynamic> riwayat = [];

  final double targetLat = -8.17889780785514;
  final double targetLng = 113.70893597791732;
  final double jarakMaks = 15; // meter

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _initUser();
  }

  Future<void> _initUser() async {
    final sp = await SharedPreferences.getInstance();
    currentUser = sp.getString('current_user');

    if (currentUser == null) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
      return;
    }

    final raw = sp.getString('absen_history_${currentUser!}') ?? '[]';
    riwayat = jsonDecode(raw);

    final now = DateTime.now();
    final tanggal =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    sudahCheckInPagi =
        sp.getBool('absen_in_${tanggal}_${currentUser!}') ?? false;
    sudahCheckOutSore =
        sp.getBool('absen_out_${tanggal}_${currentUser!}') ?? false;

    setState(() {});
    _startTracking();
  }

  void _updateStatus(String pesan, Color warna, IconData ikon) {
    setState(() {
      status = pesan;
      statusColor = warna;
      statusIcon = ikon;
    });
  }

  Future<void> _startTracking() async {
    try {
      await _getCurrentPosition();
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 1,
        ),
      ).listen((pos) {
        final d = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          targetLat,
          targetLng,
        );
        setState(() {
          jarak = d;
          diArea = d <= jarakMaks;
          loading = false;
          if (diArea) {
            _updateStatus(
                'Kamu berada di area absensi',
                const Color(0xFF4ADE80),
                Icons.location_on);
          } else {
            _updateStatus(
                'Di luar area absensi',
                const Color(0xFFEF4444),
                Icons.location_off);
          }
        });
      });
    } catch (e) {
      setState(() {
        loading = false;
        diArea = false;
        _updateStatus(
            'Gagal mendapatkan lokasi: $e',
            const Color(0xFFEF4444),
            Icons.error);
      });
    }
  }

  Future<Position> _getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('GPS tidak aktif');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Izin lokasi ditolak');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Izin lokasi ditolak permanen');
    }

    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best);
  }

  Future<void> _doAbsensi(String jenis) async {
    if (!diArea) {
      _updateStatus(
          'Kamu harus berada di area absensi',
          const Color(0xFFF59E0B),
          Icons.location_off);
      return;
    }

    final now = DateTime.now();
    final tanggal =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final sp = await SharedPreferences.getInstance();

    String key = 'absen_${jenis}_${tanggal}_${currentUser ?? "unknown"}';

    if (sp.getBool(key) == true) {
      _updateStatus(
        'Kamu sudah absen ${jenis == "in" ? "pagi" : "pulang"} hari ini',
        const Color(0xFFF59E0B),
        Icons.warning_amber_rounded,
      );
      return;
    }

    final jam = now.hour;
    final menit = now.minute;

    if (jenis == 'in') {
      if (!(jam >= 6 && (jam < 14 || (jam == 14 && menit == 0)))) {
        _updateStatus('Bukan jam absensi pagi', const Color(0xFFF59E0B),
            Icons.access_time_filled);
        return;
      }
      sudahCheckInPagi = true;
    } else {
      if (!(jam >= 9 && (jam < 18 || (jam == 18 && menit == 0)))) {
        _updateStatus('Bukan jam absensi pulang', const Color(0xFFF59E0B),
            Icons.access_time_filled);
        return;
      }
      sudahCheckOutSore = true;
    }

    await sp.setBool(key, true);

    final record = {
      'user': currentUser ?? 'unknown',
      'type': jenis,
      'time': now.toIso8601String(),
      'lat_target': targetLat,
      'lng_target': targetLng,
      'distance_m': jarak.toStringAsFixed(2),
    };
    riwayat.insert(0, record);
    await sp.setString('absen_history_${currentUser!}', jsonEncode(riwayat));

    _updateStatus(
      'Absensi ${jenis == 'in' ? 'pagi' : 'pulang'} berhasil ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      const Color(0xFF16A34A),
      Icons.check_circle_rounded,
    );
  }

  Future<void> _logout() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('current_user');

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> r) {
    final isIn = r['type'] == 'in';
    final t = DateTime.parse(r['time']);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white.withOpacity(0.05),
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isIn ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          child: Icon(isIn ? Icons.login : Icons.logout, color: Colors.white),
        ),
        title: Text(
          '${isIn ? 'Absensi Pagi' : 'Absensi Pulang'}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          'Jam ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} • Jarak ${r['distance_m']} m',
          style: TextStyle(
            color: isIn ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildHistorySectionList() {
    if (riwayat.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'Belum ada riwayat absensi',
            style: TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        )
      ];
    }

    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var r in riwayat) {
      final t = DateTime.parse(r['time']);
      final dateKey =
          "${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}";
      grouped.putIfAbsent(dateKey, () => []).add(Map<String, dynamic>.from(r));
    }

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return sortedKeys.map((dateKey) {
      final dateObj = DateTime.parse(dateKey);
      final dateFormatted =
          DateFormat("d MMMM yyyy", "id_ID").format(dateObj);
      final items = grouped[dateKey]!..sort((a, b) {
        if (a['type'] == b['type']) return 0;
        return a['type'] == 'in' ? -1 : 1; // 'in' di atas
      });

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            dateFormatted,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((r) => _buildHistoryCard(r)).toList(),
        ],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Hero(
                    tag: 'logo',
                    child: Icon(Icons.how_to_reg, size: 64, color: Colors.lightBlueAccent),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Absensi',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        currentUser ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Icon(statusIcon, size: 54, color: statusColor),
                    const SizedBox(height: 12),
                    Text(
                      status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                    if (!diArea && !loading) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Kurang ${(jarak - jarakMaks).abs().toStringAsFixed(1)} m untuk bisa absen',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (loading) ...[
                      const SizedBox(height: 8),
                      const CircularProgressIndicator(color: Colors.lightBlueAccent),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Tombol Absensi
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: sudahCheckInPagi ? null : () => _doAbsensi('in'),
                      icon: const Icon(Icons.login),
                      label: const Text('Absensi Pagi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: sudahCheckInPagi
                            ? Colors.grey.shade700
                            : const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: sudahCheckOutSore ? null : () => _doAbsensi('out'),
                      icon: const Icon(Icons.logout),
                      label: const Text('Absensi Pulang'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: sudahCheckOutSore
                            ? Colors.grey.shade700
                            : const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 3,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Logout
              OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, size: 14),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF87171),
                  side: const BorderSide(color: Color(0xFFF87171)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),

              const SizedBox(height: 20),

              // Riwayat
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: const [
                    Icon(Icons.history, color: Colors.white70, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Riwayat Terbaru',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Riwayat List
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: riwayat.isEmpty
                      ? const Center(
                          child: Text(
                            'Belum ada riwayat absensi',
                            style: TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                        )
                      : ListView(
                          children: _buildHistorySectionList(),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
