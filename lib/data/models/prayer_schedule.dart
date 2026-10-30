/// Model for a single daily Salah schedule stored in SQLite.
class PrayerSchedule {
  final int? id;
  final String prayerName;
  final int hour; // 0–23
  final int minute; // 0–59
  final bool enabled;
  final int durationMinutes;
  final int updatedAt; // epoch millis

  const PrayerSchedule({
    this.id,
    required this.prayerName,
    required this.hour,
    required this.minute,
    required this.enabled,
    required this.durationMinutes,
    required this.updatedAt,
  });

  static const List<String> orderedNames = [
    'Fajr',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  /// Example default times (not real local prayer times).
  static Map<String, (int hour, int minute)> get exampleDefaults => {
        'Fajr': (5, 15),
        'Dhuhr': (12, 30),
        'Asr': (15, 45),
        'Maghrib': (18, 10),
        'Isha': (19, 45),
      };

  TimeOfDayCompat get timeOfDay => TimeOfDayCompat(hour: hour, minute: minute);

  String get formattedTime {
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour < 12 ? 'AM' : 'PM';
    final m = minute.toString().padLeft(2, '0');
    return '$h12:$m $period';
  }

  String get durationLabel {
    if (durationMinutes < 60) return '$durationMinutes min';
    if (durationMinutes == 60) return '1 hour';
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (m == 0) return '$h hour${h > 1 ? 's' : ''}';
    return '${h}h ${m}m';
  }

  PrayerSchedule copyWith({
    int? id,
    String? prayerName,
    int? hour,
    int? minute,
    bool? enabled,
    int? durationMinutes,
    int? updatedAt,
  }) {
    return PrayerSchedule(
      id: id ?? this.id,
      prayerName: prayerName ?? this.prayerName,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabled: enabled ?? this.enabled,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'prayer_name': prayerName,
      'hour': hour,
      'minute': minute,
      'enabled': enabled ? 1 : 0,
      'duration_minutes': durationMinutes,
      'updated_at': updatedAt,
    };
  }

  factory PrayerSchedule.fromMap(Map<String, dynamic> map) {
    return PrayerSchedule(
      id: map['id'] as int?,
      prayerName: map['prayer_name'] as String,
      hour: map['hour'] as int,
      minute: map['minute'] as int,
      enabled: (map['enabled'] as int) == 1,
      durationMinutes: map['duration_minutes'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }

  /// Minutes from midnight for sorting / next-prayer logic.
  int get minutesFromMidnight => hour * 60 + minute;
}

/// Lightweight time holder without depending on Flutter in pure model tests.
class TimeOfDayCompat {
  final int hour;
  final int minute;
  const TimeOfDayCompat({required this.hour, required this.minute});
}
