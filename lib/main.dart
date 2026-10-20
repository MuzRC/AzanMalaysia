import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/prayer_time.dart';
import 'services/jakim_service.dart';
import 'services/alarm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlarmService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waktu Solat JAKIM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0D5C3A), // Emerald Green Islami
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0D5C3A),
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const PrayerScreen(),
    );
  }
}

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  final JakimService _jakimService = JakimService();
  final AlarmService _alarmService = AlarmService();

  // Senarai zon Sabah & Wilayah
  final Map<String, String> _zones = {
    'SBH07': 'Beaufort, K. Penyu, Sipitang, Membakut, Tenom',
    'SBH08': 'Keningau, Tambunan, Nabawan',
    'SBH09': 'Kota Kinabalu, Penampang, Ranau, Tuaran',
    'SBH06': 'Sandakan Timur, Bukit Garam, Semawang',
    'SBH04': 'Tawau, Lahad Datu, Kunak, Semporna',
    'WLY02': 'Labuan',
    'WLY01': 'Kuala Lumpur, Putrajaya',
  };

  String _selectedZone = 'SBH07';
  List<PrayerTime> _monthlyList = [];
  PrayerTime? _todayPrayer;
  bool _isLoading = true;
  String _currentTime = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _alarmService.requestPermissions();
    _loadPrayerTimes();
    _startClock();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startClock() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateFormat('hh:mm:ss a').format(DateTime.now());
        });
      }
    });
  }

  Future<void> _loadPrayerTimes() async {
    setState(() => _isLoading = true);
    final list = await _jakimService.getMonthlyPrayerTimes(zone: _selectedZone);

    final nowStr = DateFormat('dd-MMM-yyyy').format(DateTime.now()).toUpperCase();
    final today = list.firstWhere(
      (element) => element.date.toUpperCase().contains(nowStr.substring(0, 6)),
      orElse: () => list.isNotEmpty ? list.first : PrayerTime(
        date: '', hijri: '', day: '', imsak: '', fajr: '', syuruk: '', dhuhr: '', asr: '', maghrib: '', isha: '',
      ),
    );

    setState(() {
      _monthlyList = list;
      _todayPrayer = today;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Waktu Solat & Azan', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPrayerTimes,
            tooltip: 'Sync Data JAKIM',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPrayerTimes,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Kad Pilih Zon
                  Card(
                    elevation: 0,
                    color: colorScheme.surfaceVariant.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedZone,
                                isExpanded: true,
                                items: _zones.entries.map((entry) {
                                  return DropdownMenuItem<String>(
                                    value: entry.key,
                                    child: Text(
                                      '${entry.key} - ${entry.value}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (newZone) {
                                  if (newZone != null) {
                                    setState(() => _selectedZone = newZone);
                                    _loadPrayerTimes();
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Kad Header Jam & Tarikh Hijri
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _todayPrayer?.hijri.isNotEmpty == true ? _todayPrayer!.hijri : '1448 Hijrah',
                            style: TextStyle(color: colorScheme.onPrimary.withOpacity(0.9), fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _currentTime.isEmpty ? '00:00:00' : _currentTime,
                            style: TextStyle(
                              color: colorScheme.onPrimary,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                            style: TextStyle(color: colorScheme.onPrimary.withOpacity(0.9), fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Senarai 6 Waktu Solat
                  _buildPrayerCard('Subuh', _todayPrayer?.fajr ?? '--:--', Icons.wb_twilight, colorScheme),
                  _buildPrayerCard('Syuruk', _todayPrayer?.syuruk ?? '--:--', Icons.wb_sunny_outlined, colorScheme),
                  _buildPrayerCard('Zohor', _todayPrayer?.dhuhr ?? '--:--', Icons.wb_sunny, colorScheme),
                  _buildPrayerCard('Asar', _todayPrayer?.asr ?? '--:--', Icons.wb_cloudy_outlined, colorScheme),
                  _buildPrayerCard('Maghrib', _todayPrayer?.maghrib ?? '--:--', Icons.nights_stay_outlined, colorScheme),
                  _buildPrayerCard('Isyak', _todayPrayer?.isha ?? '--:--', Icons.nights_stay, colorScheme),

                  const SizedBox(height: 20),

                  // Butang Uji Suara Azan
                  ElevatedButton.icon(
                    onPressed: () {
                      _alarmService.playAzan();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Memainkan audio azan...'),
                          action: SnackBarAction(
                            label: 'Berhenti',
                            onPressed: () => _alarmService.stopAzan(),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Uji Bunyi Audio Azan'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPrayerCard(String name, String time, IconData icon, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: colorScheme.surfaceVariant.withOpacity(0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary, size: 24),
            const SizedBox(width: 16),
            Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              time,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
