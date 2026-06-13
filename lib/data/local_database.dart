import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  Database? _database;

  Future<Database> get database async {
    final current = _database;
    if (current != null) return current;
    final dbPath = await getDatabasesPath();
    return _database = await openDatabase(
      path.join(dbPath, 'ding_dong.db'),
      version: 3,
      onCreate: (db, version) async {
        await _createMovementTable(db);
        await _createDeviceSessionTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createDeviceSessionTable(db);
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE fetal_movement_records '
            'ADD COLUMN measured_during_user_motion INTEGER NOT NULL DEFAULT 0',
          );
        }
      },
    );
  }

  Future<void> _createMovementTable(Database db) async {
    await db.execute('''
          CREATE TABLE fetal_movement_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            measured_at INTEGER NOT NULL,
            intensity INTEGER NOT NULL,
            measured_during_user_motion INTEGER NOT NULL DEFAULT 0
          )
        ''');
    await db.execute('''
          CREATE INDEX idx_fetal_movement_user_time
          ON fetal_movement_records (user_id, measured_at)
        ''');
  }

  Future<void> _createDeviceSessionTable(Database db) async {
    await db.execute('''
          CREATE TABLE device_usage_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            started_at INTEGER NOT NULL,
            ended_at INTEGER NOT NULL
          )
        ''');
    await db.execute('''
          CREATE INDEX idx_device_usage_user_time
          ON device_usage_sessions (user_id, started_at, ended_at)
        ''');
  }
}
