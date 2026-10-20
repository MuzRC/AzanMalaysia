import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      title: 'Waktu Solat & Azan JAKIM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF004D40), // Deep Islamic Emerald Green
          brightness: Brightness.light,
          primary: const Color(0xFF0D5C3A),
          secondary: const Color(0xFFC59B27), // Warm Gold
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF004D40),
          brightness: Brightness.dark,
          primary: const Color(0xFF10B981),
          secondary: const Color(0xFFFBBF24), // Vibrant Gold
        ),
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
  String _nextPrayerName = 'Subuh';
  String _nextPrayerTimeStr = '--:--';
  String _countdownStr = '00:00:00';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _alarmService.requestPermissions();
    _loadPrayerTimes();
    _startClockAndCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startClockAndCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _currentTime = DateFormat('hh:mm:ss a').format(now);
        _calculateNextPrayer(now);
      });
    });
  }

  Future<void> _loadPrayerTimes() async {
    setState(() => _isLoading = true);
    final list = await _jakimService.getMonthlyPrayerTimes(zone: _selectedZone);

    final nowStr = DateFormat('dd-MMM-yyyy').format(DateTime.now()).toUpperCase();
    final today = list.firstWhere(
      (item) => item.date.toUpperCase().contains(nowStr.substring(0, 6)),
      orElse: () => list.isNotEmpty
          ? list.first
          : PrayerTime(
              date: '', hijri: '', day: '', imsak: '', fajr: '', syuruk: '', dhuhr: '', asr: '', maghrib: '', isha: '',
            ),
    );

    setState(() {
      _monthlyList = list;
      _todayPrayer = today;
      _isLoading = false;
      _calculateNextPrayer(DateTime.now());
    });
  }

  void _calculateNextPrayer(DateTime now) {
    if (_todayPrayer == null) return;

    final prayers = [
      {'name': 'Subuh', 'time': _todayPrayer!.fajr},
      {'name': 'Syuruk', 'time': _todayPrayer!.syuruk},
      {'name': 'Zohor', 'time': _todayPrayer!.dhuhr},
      {'name': 'Asar', 'time': _todayPrayer!.asr},
      {'name': 'Maghrib', 'time': _todayPrayer!.maghrib},
      {'name': 'Isyak', 'time': _todayPrayer!.isha},
    ];

    DateTime? nextDateTime;
    String name = 'Subuh';
    String timeStr = _todayPrayer!.fajr;

    for (var p in prayers) {
      final t = p['time']!;
      if (t.contains(':')) {
        final parts = t.split(':');
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        final pDateTime = DateTime(now.year, now.month, now.day, hour, minute);

        if (pDateTime.isAfter(now)) {
          nextDateTime = pDateTime;
          name = p['name']!;
          timeStr = t;
          break;
        }
      }
    }

    // Jika semua waktu solat hari ini sudah lepas, seterusnya adalah Subuh esok
    if (nextDateTime == null && prayers[0]['time']!.contains(':')) {
      final parts = prayers[0]['time']!.split(':');
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      nextDateTime = DateTime(now.year, now.month, now.day + 1, hour, minute);
      name = 'Subuh';
      timeStr = prayers[0]['time']!;
    }

    if (nextDateTime != null) {
      final diff = nextDateTime.difference(now);
      final h = diff.inHours.toString().padLeft(2, '0');
      final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
      final s = (diff.inSeconds % 60).toString().padLeft(2, '0');

      _nextPrayerName = name;
      _nextPrayerTimeStr = timeStr;
      _countdownStr = '-\$h:\$m:\$s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Waktu Solat & Azan',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            onPressed: _loadPrayerTimes,
            tooltip: 'Sync e-Solat JAKIM',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPrayerTimes,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                children: [
                  // 1. Kad Pemilih Zon Cantik
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
                    ),
                    color: isDark ? colorScheme.surfaceVariant.withOpacity(0.3) : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_rounded, color: colorScheme.primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedZone,
                                isExpanded: true,
                                icon: Icon(Icons.keyboard_arrow_down_rounded, color: colorScheme.primary),
                                items: _zones.entries.map((entry) {
                                  return DropdownMenuItem<String>(
                                    value: entry.key,
                                    child: Text(
                                      '\${entry.key} • \${entry.value}',
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
                  const SizedBox(height: 14),

                  // 2. Kad Menyerlah: Hero Card Solat Seterusnya & Countdown Live
                  Card(
                    elevation: 4,
                    shadowColor: colorScheme.primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.primary.withRed(20).withGreen(120),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _todayPrayer?.hijri.isNotEmpty == true ? _todayPrayer!.hijri : '1448 Hijrah',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Text(
                                _currentTime.isEmpty ? '--:--:--' : _currentTime,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'SOLAT SETERUSNYA',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                              letterSpacing: 2.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _nextPrayerName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _nextPrayerTimeStr,
                            style: const TextStyle(
                              color: Color(0xFFFBBF24), // Gold Accent
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer_outlined, color: Colors.white, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Masuk dalam $_countdownStr',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Senarai Jadual Waktu Solat
                  _buildPrayerTile('Subuh', _todayPrayer?.fajr ?? '--:--', Icons.wb_twilight_rounded, colorScheme),
                  _buildPrayerTile('Syuruk', _todayPrayer?.syuruk ?? '--:--', Icons.wb_sunny_outlined, colorScheme),
                  _buildPrayerTile('Zohor', _todayPrayer?.dhuhr ?? '--:--', Icons.wb_sunny_rounded, colorScheme),
                  _buildPrayerTile('Asar', _todayPrayer?.asr ?? '--:--', Icons.wb_cloudy_outlined, colorScheme),
                  _buildPrayerTile('Maghrib', _todayPrayer?.maghrib ?? '--:--', Icons.nights_stay_outlined, colorScheme),
                  _buildPrayerTile('Isyak', _todayPrayer?.isha ?? '--:--', Icons.nights_stay_rounded, colorScheme),

                  const SizedBox(height: 20),

                  // 4. Kad Butang Audio Azan Syeikh Naji Qazzaz
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.6)),
                    ),
                    color: isDark ? colorScheme.surfaceVariant.withOpacity(0.2) : Colors.grey.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.volume_up_rounded, color: colorScheme.primary, size: 22),
                              const SizedBox(width: 10),
                              const Text(
                                'Alunan Azan Syeikh Naji Qazzaz',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Muazin Masjid Al-Aqsa. Azan Subuh dilengkapi alunan "As-salatu khairum minan naum".',
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.7)),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    _alarmService.playAzan(prayerName: 'Subuh');
                                    _showAudioSnackbar('Memainkan Azan Subuh (Syeikh Naji Qazzaz)...');
                                  },
                                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                  label: const Text('Uji Subuh'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _alarmService.playAzan(prayerName: 'Zohor');
                                    _showAudioSnackbar('Memainkan Azan Biasa (Syeikh Naji Qazzaz)...');
                                  },
                                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                  label: const Text('Uji Biasa'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 5. Kad Doa Selepas Azan (Lengkap Arab, Rumi & Maksud)
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: const Color(0xFFC59B27).withOpacity(0.4)),
                    ),
                    color: isDark ? const Color(0xFF1E2320) : const Color(0xFFFBF8F0),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC59B27).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.menu_book_rounded, color: Color(0xFFC59B27), size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Doa Selepas Azan',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFFC59B27),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                color: colorScheme.onSurface.withOpacity(0.6),
                                onPressed: () {
                                  Clipboard.setData(const ClipboardData(
                                    text: 'اللَّهُمَّ رَبَّ هَذِهِ الدَّعْوَةِ التَّامَّةِ، وَالصَّلَاةِ الْقَائِمَةِ، آتِ مُحَمَّدًا الْوَسِيلَةَ وَالْفَضِيلَةَ، وَابْعَثْهُ مَقَامًا مَحْمُودًا الَّذِي وَعَدْتَهُ، إِنَّكَ لَا تُخْلِفُ الْمِيعَادَ',
                                  ));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Doa selepas azan disalin ke papan klip!')),
                                  );
                                },
                                tooltip: 'Salin Doa',
                              ),
                            ],
                          ),
                          const Divider(height: 24),

                          // Teks Arab
                          const Text(
                            'اللَّهُمَّ رَبَّ هَذِهِ الدَّعْوَةِ التَّامَّةِ، وَالصَّلَاةِ الْقَائِمَةِ، آتِ مُحَمَّدًا الْوَسِيلَةَ وَالْفَضِيلَةَ، وَابْعَثْهُ مَقَامًا مَحْمُودًا الَّذِي وَعَدْتَهُ، إِنَّكَ لَا تُخْلِفُ الْمِيعَادَ',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 21,
                              height: 2.0,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'serif',
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Sebutan Rumi
                          Text(
                            'Allahumma rabba hazihid-da’watit-tammah, was-salatil-qa’imah, ati Muhammadanil-wasilata wal-fadilah, wab’athhu maqamam-mahmudal-lazi wa’adtah, innaka la tukhliful-mi’ad.',
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: colorScheme.onSurface.withOpacity(0.85),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Terjemahan Bahasa Melayu
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black26 : Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '"Ya Allah, Tuhan yang memiliki seruan yang sempurna ini dan solat yang didirikan, berikanlah kepada Nabi Muhammad wasilah dan keutamaan, serta tempatkanlah Baginda di tempat yang terpuji sebagaimana yang telah Engkau janjikan. Sesungguhnya Engkau tidak memungkiri janji."',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: colorScheme.onSurface.withOpacity(0.8),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  void _showAudioSnackbar(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Henti',
          textColor: const Color(0xFFFBBF24),
          onPressed: () => _alarmService.stopAzan(),
        ),
      ),
    );
  }

  Widget _buildPrayerTile(String name, String time, IconData icon, ColorScheme colorScheme) {
    final isNext = _nextPrayerName.toLowerCase() == name.toLowerCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isNext
            ? colorScheme.primary.withOpacity(0.12)
            : colorScheme.surfaceVariant.withOpacity(0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNext ? colorScheme.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isNext ? colorScheme.primary : colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isNext ? Colors.white : colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isNext ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
                if (isNext)
                  Text(
                    'Solat Seterusnya',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              time,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isNext ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
