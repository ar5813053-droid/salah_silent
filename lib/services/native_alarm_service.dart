import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../data/models/prayer_schedule.dart';

/// Flutter ↔ Kotlin bridge for exact prayer alarms (Milestone 2).
class NativeAlarmService {
  NativeAlarmService._();
  static final NativeAlarmService instance = NativeAlarmService._();

  static const _method = MethodChannel('com.salahsilent.app/native');
  static const _events = EventChannel('com.salahsilent.app/alarm_events');

  StreamSubscription? _eventSub;
  final _alarmFiredController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onAlarmFired => _alarmFiredController.stream;

  void startListening() {
    _eventSub?.cancel();
    _eventSub = _events.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          _alarmFiredController.add(Map<String, dynamic>.from(event));
        }
      },
      onError: (e) => debugPrint('[SalahSilent/Alarm] event error: $e'),
    );
  }

  void dispose() {
    _eventSub?.cancel();
    _alarmFiredController.close();
  }

  Future<bool> canScheduleExactAlarms() async {
    try {
      final v = await _method.invokeMethod<bool>('canScheduleExactAlarms');
      return v ?? false;
    } on PlatformException catch (e) {
      debugPrint('[SalahSilent/Alarm] canScheduleExactAlarms: $e');
      return false;
    }
  }

  Future<void> openExactAlarmSettings() async {
    try {
      await _method.invokeMethod('openExactAlarmSettings');
    } on PlatformException catch (e) {
      debugPrint('[SalahSilent/Alarm] openExactAlarmSettings: $e');
    }
  }

  List<Map<String, dynamic>> _toPayload(List<PrayerSchedule> schedules) {
    return schedules
        .map((s) => {
              'prayerName': s.prayerName,
              'hour': s.hour,
              'minute': s.minute,
              'enabled': s.enabled,
            })
        .toList();
  }

  Future<Map<String, dynamic>> scheduleAll(List<PrayerSchedule> schedules) async {
    try {
      final result = await _method.invokeMethod(
        'scheduleAllPrayers',
        _toPayload(schedules),
      );
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      debugPrint('[SalahSilent/Alarm] scheduleAll: $e');
      return {'lastError': e.message, 'exactAlarmGranted': false};
    }
  }

  Future<Map<String, dynamic>> cancelAll() async {
    try {
      final result = await _method.invokeMethod('cancelAllPrayers');
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      return {'lastError': e.message};
    }
  }

  Future<Map<String, dynamic>> updateOne(PrayerSchedule s) async {
    try {
      final result = await _method.invokeMethod('updatePrayerAlarm', {
        'prayerName': s.prayerName,
        'hour': s.hour,
        'minute': s.minute,
        'enabled': s.enabled,
      });
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      return {'lastError': e.message};
    }
  }

  Future<Map<String, dynamic>> getStatus() async {
    try {
      final result = await _method.invokeMethod('getSchedulingStatus');
      return Map<String, dynamic>.from(result as Map? ?? {});
    } on PlatformException catch (e) {
      return {'lastError': e.message};
    }
  }

  Future<Map<String, dynamic>?> getNextScheduled() async {
    try {
      final result = await _method.invokeMethod('getNextScheduledAlarm');
      if (result == null) return null;
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      debugPrint('[SalahSilent/Alarm] getNextScheduled: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> refresh(List<PrayerSchedule> schedules) {
    return scheduleAll(schedules);
  }
}
