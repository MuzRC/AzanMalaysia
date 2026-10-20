import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(initSettings);

    // Konfigurasi audio stream khas untuk kategori Alarm
    await _audioPlayer.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm, // Pastikan stream Alarm aktif
          audioFocus: AndroidAudioFocus.gainTransientExclusive,
        ),
      ),
    );
  }

  /// Minta kebenaran Notification & Exact Alarm untuk Android 13/14+
  Future<void> requestPermissions() async {
    await Permission.notification.request();
    await Permission.scheduleExactAlarm.request();
  }

  /// Mainkan bunyi azan (Contoh dari asset atau URL azan berkualiti)
  Future<void> playAzan() async {
    try {
      // Mainkan azan Makkah / Madinah online streaming atau letak dalam assets/audio/azan.mp3
      await _audioPlayer.play(
        UrlSource('https://www.islamcan.com/audio/adhan/azan1.mp3'),
      );
    } catch (_) {
      // fallback
    }
  }

  Future<void> stopAzan() async {
    await _audioPlayer.stop();
  }
}
