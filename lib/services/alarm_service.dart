import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // URL Alunan Azan Syeikh Naji Qazzaz (Masjidil Aqsa)
  // Termasuk fallback streaming online berkualiti tinggi
  static const String audioAzanBiasaUrl =
      'https://archive.org/download/AzanAlAqsaByNajiQazzaz/Azan_Al_Aqsa_Naji_Qazzaz.mp3';
  static const String audioAzanSubuhUrl =
      'https://archive.org/download/FajrAzanAlAqsaNajiQazzaz/Fajr_Azan_Naji_Qazzaz.mp3';

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(initSettings);

    // Konfigurasi audio stream khas kategori Alarm (kalis silent mode biasa)
    await _audioPlayer.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gainTransientExclusive,
        ),
      ),
    );
  }

  Future<void> requestPermissions() async {
    await Permission.notification.request();
    await Permission.scheduleExactAlarm.request();
  }

  /// Mainkan azan Syeikh Naji Qazzaz mengikut waktu solat
  /// Jika Subuh -> Mainkan versi Subuh (ada 'As-salatu khairum minan naum')
  /// Jika Zohor, Asar, Maghrib, Isyak -> Mainkan versi Biasa
  Future<void> playAzan({required String prayerName}) async {
    try {
      await stopAzan();
      final isSubuh = prayerName.trim().toLowerCase() == 'subuh';

      // Semak jika ada fail tempatan dalam assets/audio/ dahulu
      final assetPath = isSubuh ? 'audio/azan_subuh.mp3' : 'audio/azan_biasa.mp3';
      try {
        await _audioPlayer.play(AssetSource(assetPath));
        return;
      } catch (_) {
        // Jika fail asset belum diletak, main terus dari URL Naji Qazzaz secara streaming
        final targetUrl = isSubuh ? audioAzanSubuhUrl : audioAzanBiasaUrl;
        await _audioPlayer.play(UrlSource(targetUrl));
      }
    } catch (_) {}
  }

  Future<void> stopAzan() async {
    await _audioPlayer.stop();
  }
}
