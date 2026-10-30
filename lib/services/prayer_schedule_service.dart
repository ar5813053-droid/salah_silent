import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/prayer_schedule.dart';
import '../data/repositories/prayer_repository.dart';
import 'native_alarm_service.dart';

/// Application service: schedules + next-prayer logic + global default duration.
class PrayerScheduleService extends ChangeNotifier {
  PrayerScheduleService({PrayerRepository? repository})
      : _repository = repository ?? PrayerRepository();

  final PrayerRepository _repository;

  static const _prefsDefaultDurationKey = 'default_duration_minutes';
  static const int defaultDurationFallback = 10;
  static const List<int> presetDurations = [5, 10, 15, 20, 30, 45, 60];

  List<PrayerSchedule> _schedules = [];
  int _defaultDurationMinutes = defaultDurationFallback;
  bool _loading = true;
  String? _error;

  List<PrayerSchedule> get schedules => List.unmodifiable(_schedules);
  int get defaultDurationMinutes => _defaultDurationMinutes;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> init() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      _defaultDurationMinutes =
          prefs.getInt(_prefsDefaultDurationKey) ?? defaultDurationFallback;
      _schedules = await _repository.getAll();
      _error = null;
      await _syncNativeAlarms();
    } catch (e, st) {
      _error = 'Failed to load prayer schedules.';
      debugPrint('PrayerScheduleService.init error: $e\n$st');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setDefaultDuration(int minutes) async {
    final validated = _validateDuration(minutes);
    _defaultDurationMinutes = validated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsDefaultDurationKey, validated);
    notifyListeners();
  }

  Future<void> setEnabled(String prayerName, bool enabled) async {
    await _repository.updateEnabled(prayerName, enabled);
    await _reload();
  }

  Future<void> setTime(String prayerName, int hour, int minute) async {
    final h = hour.clamp(0, 23);
    final m = minute.clamp(0, 59);
    await _repository.updateTime(prayerName, h, m);
    await _reload();
  }

  Future<void> setDuration(String prayerName, int minutes) async {
    final validated = _validateDuration(minutes);
    await _repository.updateDuration(prayerName, validated);
    await _reload();
  }

  Future<void> resetSchedules() async {
    await _repository.resetToDefaults(
      defaultDurationMinutes: _defaultDurationMinutes,
    );
    await _reload();
  }

  Future<void> _reload() async {
    try {
      _schedules = await _repository.getAll();
      _error = null;
      await _syncNativeAlarms();
    } catch (e) {
      _error = 'Failed to refresh schedules.';
      debugPrint('PrayerScheduleService._reload error: $e');
    }
    notifyListeners();
  }

  /// Push current SQLite schedules to native AlarmManager.
  Future<Map<String, dynamic>> _syncNativeAlarms() async {
    try {
      return await NativeAlarmService.instance.refresh(_schedules);
    } catch (e) {
      debugPrint('[SalahSilent/Alarm] sync failed: $e');
      return {};
    }
  }

  /// Explicit refresh for Settings UI.
  Future<Map<String, dynamic>> refreshNativeAlarms() async {
    _schedules = await _repository.getAll();
    final status = await _syncNativeAlarms();
    notifyListeners();
    return status;
  }

  int _validateDuration(int minutes) {
    if (minutes < 1) return 1;
    if (minutes > 180) return 180; // hard cap 3 hours
    return minutes;
  }

  // ─── Next prayer / countdown ───────────────────────────────────────────

  /// Schedules relevant for a calendar day (Jumu'ah replaces Dhuhr on Friday).
  List<PrayerSchedule> schedulesForDay(DateTime day) {
    final names = PrayerSchedule.namesForWeekday(day.weekday);
    return _schedules.where((s) => names.contains(s.prayerName)).toList();
  }

  /// Next enabled prayer occurrence (today or tomorrow), weekday-aware.
  NextPrayerInfo? get nextPrayer {
    final now = DateTime.now();
    PrayerSchedule? best;
    var bestAt = DateTime(2100);

    for (var dayOffset = 0; dayOffset < 8; dayOffset++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));
      final names = PrayerSchedule.namesForWeekday(day.weekday);
      for (final s in _schedules) {
        if (!s.enabled) continue;
        if (!names.contains(s.prayerName)) continue;
        var candidate = DateTime(day.year, day.month, day.day, s.hour, s.minute);
        if (candidate.isBefore(now) || candidate.isAtSameMomentAs(now)) continue;
        if (candidate.isBefore(bestAt)) {
          bestAt = candidate;
          best = s;
        }
      }
      if (best != null && dayOffset == 0) {
        // Found something today; still scan in case nothing — loop continues fine
      }
    }

    if (best == null) return null;
    return NextPrayerInfo(schedule: best, occurrence: bestAt);
  }

  Duration? remainingUntilNext() {
    final next = nextPrayer;
    if (next == null) return null;
    final diff = next.occurrence.difference(DateTime.now());
    if (diff.isNegative) return Duration.zero;
    return diff;
  }
}

class NextPrayerInfo {
  final PrayerSchedule schedule;
  final DateTime occurrence;

  const NextPrayerInfo({
    required this.schedule,
    required this.occurrence,
  });

  bool get isTomorrow {
    final now = DateTime.now();
    return occurrence.year != now.year ||
        occurrence.month != now.month ||
        occurrence.day != now.day;
  }
}
