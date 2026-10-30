import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/prayer_schedule.dart';

/// Local SQLite database with versioning and migrations.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'salah_silent.db';
  static const _dbVersion = 2;

  Database? _db;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createPrayerSchedules(db);
    await _createSilentSessions(db);
    await _seedPrayers(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createSilentSessions(db);
    }
  }

  Future<void> _createPrayerSchedules(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS prayer_schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        prayer_name TEXT UNIQUE NOT NULL,
        hour INTEGER NOT NULL,
        minute INTEGER NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        duration_minutes INTEGER NOT NULL DEFAULT 10,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_prayer_schedules_name
      ON prayer_schedules (prayer_name)
    ''');
  }

  Future<void> _createSilentSessions(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS silent_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_uuid TEXT,
        prayer_name TEXT NOT NULL,
        start_epoch INTEGER NOT NULL,
        end_epoch INTEGER NOT NULL,
        previous_ringer_mode INTEGER,
        previous_dnd_filter INTEGER,
        applied_ringer_mode INTEGER,
        session_status TEXT NOT NULL,
        restoration_status TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _seedPrayers(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final name in PrayerSchedule.orderedNames) {
      final example = PrayerSchedule.exampleDefaults[name]!;
      batch.insert('prayer_schedules', {
        'prayer_name': name,
        'hour': example.$1,
        'minute': example.$2,
        'enabled': 1,
        'duration_minutes': 10,
        'updated_at': now,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    final db = _db;
    if (db != null && db.isOpen) {
      await db.close();
      _db = null;
    }
  }
}
