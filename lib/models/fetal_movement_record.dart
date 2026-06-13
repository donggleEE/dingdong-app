class FetalMovementRecord {
  const FetalMovementRecord({
    this.id,
    required this.userId,
    required this.measuredAt,
    required this.intensity,
    this.measuredDuringUserMotion = false,
  });

  final int? id;
  final String userId;
  final DateTime measuredAt;
  final int intensity;
  final bool measuredDuringUserMotion;

  bool get measuredDuringMotion => measuredDuringUserMotion;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'measured_at': measuredAt.millisecondsSinceEpoch,
      'intensity': intensity,
      'measured_during_user_motion': measuredDuringUserMotion ? 1 : 0,
    };
  }

  factory FetalMovementRecord.fromMap(Map<String, Object?> map) {
    return FetalMovementRecord(
      id: map['id'] as int?,
      userId: map['user_id']! as String,
      measuredAt: DateTime.fromMillisecondsSinceEpoch(
        map['measured_at']! as int,
      ),
      intensity: map['intensity']! as int,
      measuredDuringUserMotion:
          (map['measured_during_user_motion'] as int? ?? 0) == 1,
    );
  }
}
