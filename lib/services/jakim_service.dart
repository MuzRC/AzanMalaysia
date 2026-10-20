import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_time.dart';

class JakimService {
  static const String _storageKeyPrefix = 'waktu_solat_';

  Future<List<PrayerTime>> getMonthlyPrayerTimes({String zone = 'SBH07'}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_storageKeyPrefix$zone';

    // 1. Ambil dari cache tempatan dahulu
    final cachedData = prefs.getString(cacheKey);
    if (cachedData != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(cachedData);
        final list = jsonList.map((item) => PrayerTime.fromJson(item)).toList();
        if (list.isNotEmpty) {
          _syncFromApi(zone, prefs, cacheKey);
          return list;
        }
      } catch (_) {}
    }

    // 2. Jika tiada, sedut dari API JAKIM
    return await _syncFromApi(zone, prefs, cacheKey);
  }

  Future<List<PrayerTime>> _syncFromApi(String zone, SharedPreferences prefs, String cacheKey) async {
    final url = Uri.parse(
      'https://www.e-solat.gov.my/index.php?r=esolatApi/takwimsolat&period=month&zone=$zone',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK!' && data['prayerTime'] is List) {
          final List<dynamic> prayerList = data['prayerTime'];
          final parsed = prayerList.map((item) => PrayerTime.fromJson(item)).toList();
          await prefs.setString(cacheKey, jsonEncode(parsed));
          return parsed;
        }
      }
    } catch (_) {
      try {
        final fallbackUrl = Uri.parse('https://api.waktusolat.app/v2/solat/$zone');
        final fbResponse = await http.get(fallbackUrl).timeout(const Duration(seconds: 10));
        if (fbResponse.statusCode == 200) {
          final fbData = jsonDecode(fbResponse.body);
          if (fbData['prayers'] is List) {
            final List<dynamic> pList = fbData['prayers'];
            final parsed = pList.map((item) => PrayerTime.fromJson(item)).toList();
            await prefs.setString(cacheKey, jsonEncode(parsed));
            return parsed;
          }
        }
      } catch (_) {}
    }

    return [];
  }
}
