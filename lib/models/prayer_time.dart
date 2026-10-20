class PrayerTime {
  final String date;
  final String hijri;
  final String day;
  final String imsak;
  final String fajr;
  final String syuruk;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;

  PrayerTime({
    required this.date,
    required this.hijri,
    required this.day,
    required this.imsak,
    required this.fajr,
    required this.syuruk,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  factory PrayerTime.fromJson(Map<String, dynamic> json) {
    return PrayerTime(
      date: json['date'] ?? '',
      hijri: json['hijri'] ?? '',
      day: json['day'] ?? '',
      imsak: json['imsak'] ?? '',
      fajr: json['fajr'] ?? '',
      syuruk: json['syuruk'] ?? '',
      dhuhr: json['dhuhr'] ?? '',
      asr: json['asr'] ?? '',
      maghrib: json['maghrib'] ?? '',
      isha: json['isha'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'hijri': hijri,
    'day': day,
    'imsak': imsak,
    'fajr': fajr,
    'syuruk': syuruk,
    'dhuhr': dhuhr,
    'asr': asr,
    'maghrib': maghrib,
    'isha': isha,
  };
}
