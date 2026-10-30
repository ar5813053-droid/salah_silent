import '../database/app_database.dart';
import '../models/prayer_schedule.dart';

/// Data access for prayer_schedules table. Uses parameterized queries only.
class PrayerRepository {
  PrayerRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<PrayerSchedule>> getAll() async {
    final db = await _database.database;
    final rows = await db.query(
      'prayer_schedules',
      orderBy: 'id ASC',
    );
    final list = rows.map(PrayerSchedule.fromMap).toList();

    // Ensure canonical order Fajr → Isha
    list.sort((a, b) {
      final ai = PrayerSchedule.orderedNames.indexOf(a.prayerName);
      final bi = PrayerSchedule.orderedNames.indexOf(b.prayerName);
      return ai.compareTo(bi);
    });
    return list;
  }

  Future<PrayerSchedule?> getByName(String prayerName) async {
    final db = await _database.database;
    final rows = await db.query(
      'prayer_schedules',
      where: 'prayer_name = ?',
      whereArgs: [prayerName],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PrayerSchedule.fromMap(rows.first);
  }

  Future<void> update(PrayerSchedule schedule) async {
    final db = await _database.database;
    final map = schedule.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ).toMap();
    map.remove('id');

    final count = await db.update(
      'prayer_schedules',
      map,
      where: 'prayer_name = ?',
      whereArgs: [schedule.prayerName],
    );

    if (count == 0) {
      // Should not happen after seed, but recover safely.
      await db.insert('prayer_schedules', {
        ...map,
        'prayer_name': schedule.prayerName,
      });
    }
  }

  Future<void> updateTime(String prayerName, int hour, int minute) async {
    final existing = await getByName(prayerName);
    if (existing == null) return;
    await update(existing.copyWith(hour: hour, minute: minute));
  }

  Future<void> updateEnabled(String prayerName, bool enabled) async {
    final existing = await getByName(prayerName);
    if (existing == null) return;
    await update(existing.copyWith(enabled: enabled));
  }

  Future<void> updateDuration(String prayerName, int durationMinutes) async {
    final existing = await getByName(prayerName);
    if (existing == null) return;
    await update(existing.copyWith(durationMinutes: durationMinutes));
  }

  /// Restores example default times/durations/enabled for all five prayers.
  /// Does not touch any other tables.
  Future<void> resetToDefaults({int defaultDurationMinutes = 10}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = await _database.database;

    for (final name in PrayerSchedule.orderedNames) {
      final example = PrayerSchedule.exampleDefaults[name]!;
      await db.update(
        'prayer_schedules',
        {
          'hour': example.$1,
          'minute': example.$2,
          'enabled': 1,
          'duration_minutes': defaultDurationMinutes,
          'updated_at': now,
        },
        where: 'prayer_name = ?',
        whereArgs: [name],
      );
    }
  }
}
