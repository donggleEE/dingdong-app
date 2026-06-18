class MovementThresholds {
  const MovementThresholds({
    required this.detectStart,
    required this.mediumStart,
    required this.strongStart,
  });

  final int detectStart;
  final int mediumStart;
  final int strongStart;

  static const defaults = MovementThresholds(
    detectStart: 3500,
    mediumStart: 3800,
    strongStart: 4090,
  );

  Map<String, dynamic> toJson() => {
    'detectStart': detectStart,
    'mediumStart': mediumStart,
    'strongStart': strongStart,
  };

  factory MovementThresholds.fromJson(Map<String, dynamic> json) {
    return MovementThresholds(
      detectStart: (json['detectStart'] as num?)?.round() ?? 3500,
      mediumStart: (json['mediumStart'] as num?)?.round() ?? 3800,
      strongStart: (json['strongStart'] as num?)?.round() ?? 4090,
    ).normalized();
  }

  MovementThresholds normalized() {
    final d = detectStart.clamp(0, 4095);
    final m = mediumStart.clamp(d + 1, 4095);
    final s = strongStart.clamp(m + 1, 4095);

    return MovementThresholds(detectStart: d, mediumStart: m, strongStart: s);
  }

  bool get isValid =>
      detectStart >= 0 &&
      detectStart < mediumStart &&
      mediumStart < strongStart &&
      strongStart <= 4095;
}

class MovementThresholdChange {
  const MovementThresholdChange({
    required this.changedAt,
    required this.thresholds,
  });

  final DateTime changedAt;
  final MovementThresholds thresholds;

  Map<String, dynamic> toJson() => {
    'changedAt': changedAt.millisecondsSinceEpoch,
    'thresholds': thresholds.toJson(),
  };

  factory MovementThresholdChange.fromJson(Map<String, dynamic> json) {
    return MovementThresholdChange(
      changedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['changedAt'] as num?)?.round() ?? 0,
      ),
      thresholds: MovementThresholds.fromJson(
        Map<String, dynamic>.from(json['thresholds'] as Map? ?? const {}),
      ),
    );
  }
}
