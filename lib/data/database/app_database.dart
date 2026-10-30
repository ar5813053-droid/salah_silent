import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/prayer_schedule.dart';

/// Local SQLite database with versioning and migrations.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'salah_silent.db';
  static const _dbVersion = 1;

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
    await db.execute('''
      CREATE TABLE prayer_schedules (
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
      CREATE INDEX idx_prayer_schedules_name
      ON prayer_schedules (prayer_name)
    ''');

    // Seed example defaults (clearly example times, not real local times).
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

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here.
    // Example:
    // if (oldVersion < 2) { await db.execute('ALTER TABLE ...'); }
  }

  Future<void> close() async {
    final db = _db;
    if (db != null && db.isOpen) {
      await db.close();
      _db = null;
    }
  }
}
