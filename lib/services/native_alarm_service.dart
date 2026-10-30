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
              'durationMinutes': s.durationMinutes,
            })
        .toList();
  }

  Future<Map<String, dynamic>> startSilentSession({
    required String prayerName,
    required int durationMinutes,
  }) async {
    try {
      final result = await _method.invokeMethod('startSilentSession', {
        'prayerName': prayerName,
        'durationMinutes': durationMinutes,
      });
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      return {'ok': false, 'error': e.message};
    }
  }

  Future<Map<String, dynamic>> cancelSilentSession() async {
    try {
      final result = await _method.invokeMethod('cancelSilentSession');
      return Map<String, dynamic>.from(result as Map? ?? {});
    } on PlatformException catch (e) {
      return {'ok': false, 'error': e.message};
    }
  }

  Future<Map<String, dynamic>> getSilentSessionStatus() async {
    try {
      final result = await _method.invokeMethod('getSilentSessionStatus');
      return Map<String, dynamic>.from(result as Map? ?? {});
    } on PlatformException catch (e) {
      return {'active': false, 'error': e.message};
    }
  }

  Future<bool> isSilentModeActive() async {
    try {
      return await _method.invokeMethod<bool>('isSilentModeActive') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> checkNotificationPolicyAccess() async {
    try {
      return await _method.invokeMethod<bool>('checkNotificationPolicyAccess') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openNotificationPolicySettings() async {
    try {
      await _method.invokeMethod('openNotificationPolicySettings');
    } on PlatformException catch (e) {
      debugPrint('[SalahSilent/Silent] openNotificationPolicySettings: $e');
    }
  }

  Future<Map<String, dynamic>> reconcileSilentSession() async {
    try {
      final result = await _method.invokeMethod('reconcileSilentSession');
      return Map<String, dynamic>.from(result as Map? ?? {});
    } on PlatformException catch (e) {
      return {'ok': false, 'error': e.message};
    }
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
        'durationMinutes': s.durationMinutes,
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


  Future<Map<String, dynamic>> getPermissionStatuses() async {
    try {
      final result = await _method.invokeMethod('getPermissionStatuses');
      return Map<String, dynamic>.from(result as Map? ?? {});
    } on PlatformException catch (e) {
      debugPrint('[SalahSilent/Permissions] getPermissionStatuses: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> openNotificationListenerSettings() async {
    try {
      final result = await _method.invokeMethod('openNotificationListenerSettings');
      return Map<String, dynamic>.from(result as Map? ?? {});
    } on PlatformException catch (e) {
      return {'opened': false, 'error': e.message};
    }
  }

  Future<Map<String, dynamic>> openAppNotificationSettings() async {
    try {
      final result = await _method.invokeMethod('openAppNotificationSettings');
      return Map<String, dynamic>.from(result as Map? ?? {});
    } on PlatformException catch (e) {
      return {'opened': false, 'error': e.message};
    }
  }

  Future<Map<String, dynamic>> openBatterySettings() async {
    try {
      final result = await _method.invokeMethod('openBatterySettings');
      return Map<String, dynamic>.from(result as Map? ?? {});
    } on PlatformException catch (e) {
      return {'opened': false, 'error': e.message};
    }
  }

  Future<Map<String, dynamic>> openAppDetailsSettings() async {
    try {
      final result = await _method.invokeMethod('openAppDetailsSettings');
      return Map<String, dynamic>.from(result as Map? ?? {});
    } on PlatformException catch (e) {
      return {'opened': false, 'error': e.message};
    }
  }

  Future<Map<String, dynamic>> getDeviceManufacturerInfo() async {
    try {
      final result = await _method.invokeMethod('getDeviceManufacturerInfo');
      return Map<String, dynamic>.from(result as Map? ?? {});
    } on PlatformException catch (e) {
      return {'error': e.message};
    }
  }

  Future<Map<String, dynamic>> getReadinessSummary() async {
    final all = await getPermissionStatuses();
    final r = all['readiness'];
    if (r is Map) return Map<String, dynamic>.from(r);
    return {};
  }

}
