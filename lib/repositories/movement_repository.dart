import '../data/local_database.dart';
import '../models/fetal_movement_record.dart';

class MovementRepository {
  MovementRepository({LocalDatabase? database})
    : _database = database ?? LocalDatabase.instance;

  final LocalDatabase _database;

  Future<int> addRecord({
    required String userId,
    required DateTime measuredAt,
    required int intensity,
    bool measuredDuringUserMotion = false,
  }) async {
    final db = await _database.database;
    final record = FetalMovementRecord(
      userId: userId,
      measuredAt: measuredAt,
      intensity: intensity < 1 ? 1 : intensity,
      measuredDuringUserMotion: measuredDuringUserMotion,
    );
    return db.insert('fetal_movement_records', record.toMap());
  }

  Future<List<FetalMovementRecord>> findRecords({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'fetal_movement_records',
      where: 'user_id = ? AND measured_at >= ? AND measured_at < ?',
      whereArgs: [
        userId,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
      orderBy: 'measured_at ASC',
    );
    return rows.map(FetalMovementRecord.fromMap).toList();
  }

  Future<int> countRecords({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final records = await findRecords(userId: userId, start: start, end: end);
    return records.length;
  }

  Future<int> addDeviceSession({
    required String userId,
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    if (!endedAt.isAfter(startedAt)) return 0;
    final db = await _database.database;
    return db.insert('device_usage_sessions', {
      'user_id': userId,
      'started_at': startedAt.millisecondsSinceEpoch,
      'ended_at': endedAt.millisecondsSinceEpoch,
    });
  }

  Future<List<DeviceUsageSession>> findDeviceSessions({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'device_usage_sessions',
      where: 'user_id = ? AND started_at < ? AND ended_at > ?',
      whereArgs: [
        userId,
        end.millisecondsSinceEpoch,
        start.millisecondsSinceEpoch,
      ],
      orderBy: 'started_at ASC',
    );
    return rows.map(DeviceUsageSession.fromMap).toList();
  }
}

class DeviceUsageSession {
  const DeviceUsageSession({
    this.id,
    required this.userId,
    required this.startedAt,
    required this.endedAt,
  });

  final int? id;
  final String userId;
  final DateTime startedAt;
  final DateTime endedAt;

  factory DeviceUsageSession.fromMap(Map<String, Object?> map) {
    return DeviceUsageSession(
      id: map['id'] as int?,
      userId: map['user_id']! as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['started_at']! as int),
      endedAt: DateTime.fromMillisecondsSinceEpoch(map['ended_at']! as int),
    );
  }
}
