import 'dart:convert';
import 'dart:math' as math;
import '../models/movement_thresholds.dart';

const int beltSensorChannelCount = 16;
const int beltSensorMaxValue = 4095;
const int fetalMovementThreshold = 3500;
const int fetalMovementThresholdWhileUserMoving = 4090;
const int fetalMovementNormalThreshold = 3800;
const int fetalMovementStrongThreshold = 4095;
const double userMotionGyroAxisThreshold = 245;

class BeltSensorSample {
  const BeltSensorSample({required this.values, this.motion});

  final List<int> values;
  final BeltMotionSample? motion;

  int get peak => values.fold<int>(0, math.max);
  bool get isUserMoving => motion?.isUserMoving ?? false;

  // 기존 코드 호환용 기본 기준
  int get activeFetalMovementThreshold => isUserMoving
      ? fetalMovementThresholdWhileUserMoving
      : fetalMovementThreshold;

  bool get isMovementActive => peak >= activeFetalMovementThreshold;

  // 사용자가 설정한 임계값 기준
  int activeFetalMovementThresholdFor(MovementThresholds thresholds) {
    final normalized = thresholds.normalized();

    // 사용자가 움직이는 중이면 더 강한 기준을 사용
    // 기존 fetalMovementThresholdWhileUserMoving = 4090 역할을
    // 사용자가 설정한 strongStart가 대신 맡음
    return isUserMoving ? normalized.strongStart : normalized.detectStart;
  }

  bool isMovementActiveFor(MovementThresholds thresholds) {
    return peak >= activeFetalMovementThresholdFor(thresholds);
  }
}

class BeltMotionSample {
  const BeltMotionSample({
    this.accX,
    this.accY,
    this.accZ,
    this.gyroX,
    this.gyroY,
    this.gyroZ,
  });

  final double? accX;
  final double? accY;
  final double? accZ;
  final double? gyroX;
  final double? gyroY;
  final double? gyroZ;

  double? get accelerationMagnitude => _magnitude(accX, accY, accZ);
  double? get gyroMagnitude => _magnitude(gyroX, gyroY, gyroZ);

  bool get isUserMoving {
    return _isGyroAxisMoving(gyroX) ||
        _isGyroAxisMoving(gyroY) ||
        _isGyroAxisMoving(gyroZ);
  }
}

class BeltMovementEvent {
  const BeltMovementEvent({
    required this.measuredAt,
    required this.intensity,
    required this.measuredDuringUserMotion,
  });

  final DateTime measuredAt;
  final int intensity;
  final bool measuredDuringUserMotion;

  bool get measuredDuringMotion => measuredDuringUserMotion;
}

class BeltMovementDetector {
  bool _active = false;

  BeltMovementEvent? addSample(
    BeltSensorSample sample,
    DateTime measuredAt, {
    MovementThresholds thresholds = MovementThresholds.defaults,
  }) {
    final normalized = thresholds.normalized();
    final peak = sample.peak;

    final threshold = sample.activeFetalMovementThresholdFor(normalized);
    final movementActive = peak >= threshold;

    if (movementActive) {
      if (_active) return null;

      _active = true;

      return BeltMovementEvent(
        measuredAt: measuredAt,
        intensity: peak.clamp(threshold, beltSensorMaxValue).toInt(),
        measuredDuringUserMotion: sample.isUserMoving,
      );
    }

    _active = false;
    return null;
  }

  void reset() {
    _active = false;
  }
}

BeltSensorSample? parseBeltSensorSample(dynamic message) {
  try {
    final data = jsonDecode(_extractJsonPayload(_messageToText(message)));
    if (data is! Map) return null;
    final values = <int>[];
    for (var i = 0; i < beltSensorChannelCount; i++) {
      final value = _parseChannelValue(data['c$i']);
      if (value == null) return null;
      values.add(value);
    }
    return BeltSensorSample(values: values, motion: _parseMotionSample(data));
  } catch (_) {
    return null;
  }
}

String _messageToText(dynamic message) {
  if (message is String) return message;
  if (message is List<int>) return utf8.decode(message, allowMalformed: true);
  return message.toString();
}

String _extractJsonPayload(String rawMessage) {
  final start = rawMessage.indexOf('{');
  final end = rawMessage.lastIndexOf('}');
  if (start == -1 || end <= start) return rawMessage;
  return rawMessage.substring(start, end + 1);
}

int? _parseChannelValue(Object? value) {
  final number = value is num ? value : num.tryParse(value?.toString() ?? '');
  if (number == null) return null;
  return number.round().clamp(0, beltSensorMaxValue);
}

BeltMotionSample? _parseMotionSample(Map<dynamic, dynamic> data) {
  final sample = BeltMotionSample(
    accX: _parseFlexibleDouble(data, const ['ax', 'accX', 'accelX']),
    accY: _parseFlexibleDouble(data, const ['ay', 'accY', 'accelY']),
    accZ: _parseFlexibleDouble(data, const ['az', 'accZ', 'accelZ']),
    gyroX: _parseFlexibleDouble(data, const ['gx', 'gyroX']),
    gyroY: _parseFlexibleDouble(data, const ['gy', 'gyroY']),
    gyroZ: _parseFlexibleDouble(data, const ['gz', 'gyroZ']),
  );
  return sample.accelerationMagnitude == null && sample.gyroMagnitude == null
      ? null
      : sample;
}

double? _parseFlexibleDouble(Map<dynamic, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key] ?? data[_upperFirst(key)];
    final number = value is num ? value : num.tryParse(value?.toString() ?? '');
    if (number != null) return number.toDouble();
  }
  return null;
}

String _upperFirst(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

double? _magnitude(double? x, double? y, double? z) {
  if (x == null && y == null && z == null) return null;
  final resolvedX = x ?? 0;
  final resolvedY = y ?? 0;
  final resolvedZ = z ?? 0;
  return math.sqrt(
    resolvedX * resolvedX + resolvedY * resolvedY + resolvedZ * resolvedZ,
  );
}

bool _isGyroAxisMoving(double? value) =>
    value != null && value.abs() >= userMotionGyroAxisThreshold;
