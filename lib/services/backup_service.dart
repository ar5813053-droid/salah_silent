import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repositories/prayer_repository.dart';
import 'native_alarm_service.dart';

/// Local JSON backup of schedules + prefs. File share via share string copy.
class BackupService {
  BackupService._();
  static final instance = BackupService._();

  Future<String> exportJson() async {
    final schedules = await PrayerRepository().getAll();
    final prefs = await SharedPreferences.getInstance();
    final notif = await NativeAlarmService.instance.getNotificationPrefs();
    final map = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'schedules': schedules.map((s) => s.toMap()).toList(),
      'defaultDurationMinutes': prefs.getInt('default_duration_minutes') ?? 10,
      'notificationPrefs': notif,
      'stats': {
        'sessions': prefs.getInt('stats_sessions') ?? 0,
        'minutes': prefs.getInt('stats_minutes') ?? 0,
        'restores': prefs.getInt('stats_restores') ?? 0,
        'skipped': prefs.getInt('stats_skipped') ?? 0,
      },
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Validates and applies schedule + preference restore.
  Future<String> restoreFromJson(String raw) async {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['version'] != 1) return 'Unsupported backup version';
      final list = map['schedules'] as List?;
      if (list == null) return 'Missing schedules';
      final repo = PrayerRepository();
      for (final item in list) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final name = m['prayer_name'] as String?;
        if (name == null) continue;
        final existing = await repo.getByName(name);
        if (existing == null) continue;
        await repo.update(existing.copyWith(
          hour: m['hour'] as int? ?? existing.hour,
          minute: m['minute'] as int? ?? existing.minute,
          enabled: (m['enabled'] as int? ?? 1) == 1,
          durationMinutes: m['duration_minutes'] as int? ?? existing.durationMinutes,
        ));
      }
      final prefs = await SharedPreferences.getInstance();
      final def = map['defaultDurationMinutes'];
      if (def is int) await prefs.setInt('default_duration_minutes', def);
      final notif = map['notificationPrefs'];
      if (notif is Map) {
        await NativeAlarmService.instance.setNotificationPrefs({
          'silentActivated': notif['silentActivated'] != false,
          'callDuringSalah': notif['callDuringSalah'] != false,
          'sessionRestore': notif['sessionRestore'] != false,
          'permissionWarning': notif['permissionWarning'] != false,
        });
      }
      return 'ok';
    } catch (e) {
      debugPrint('restore error: $e');
      return 'Invalid backup data';
    }
  }
}
