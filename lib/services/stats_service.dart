import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight local counters (no fake data). Incremented from UI on known events.
class StatsService {
  StatsService._();
  static final instance = StatsService._();

  static const _kSessions = 'stats_sessions';
  static const _kMinutes = 'stats_minutes';
  static const _kRestores = 'stats_restores';
  static const _kSkipped = 'stats_skipped';

  Future<Map<String, int>> snapshot() async {
    final p = await SharedPreferences.getInstance();
    return {
      'sessions': p.getInt(_kSessions) ?? 0,
      'minutes': p.getInt(_kMinutes) ?? 0,
      'restores': p.getInt(_kRestores) ?? 0,
      'skipped': p.getInt(_kSkipped) ?? 0,
    };
  }

  Future<void> recordSession(int durationMinutes) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kSessions, (p.getInt(_kSessions) ?? 0) + 1);
    await p.setInt(_kMinutes, (p.getInt(_kMinutes) ?? 0) + durationMinutes);
  }

  Future<void> recordRestore({required bool skipped}) async {
    final p = await SharedPreferences.getInstance();
    if (skipped) {
      await p.setInt(_kSkipped, (p.getInt(_kSkipped) ?? 0) + 1);
    } else {
      await p.setInt(_kRestores, (p.getInt(_kRestores) ?? 0) + 1);
    }
  }
}
