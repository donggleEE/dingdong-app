import 'package:ding_dong_app/services/belt_message_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

void main() {
  test('ESP32 16 channel JSON creates a belt sensor sample', () {
    final sample = parseBeltSensorSample(
      '{"c0":0,"c1":1,"c2":2,"c3":3,"c4":4,"c5":5,"c6":6,"c7":7,'
      '"c8":8,"c9":9,"c10":10,"c11":11,"c12":12,"c13":13,"c14":14,"c15":4095}',
    );

    expect(sample, isNotNull);
    expect(sample!.values, hasLength(16));
    expect(sample.peak, 4095);
    expect(sample.isMovementActive, isTrue);
  });

  test('sensor values are clamped to ADC range', () {
    final sample = parseBeltSensorSample(
      '{"c0":-1,"c1":0,"c2":0,"c3":0,"c4":0,"c5":0,"c6":0,"c7":0,'
      '"c8":0,"c9":0,"c10":0,"c11":0,"c12":0,"c13":0,"c14":0,"c15":5000}',
    );

    expect(sample, isNotNull);
    expect(sample!.values.first, 0);
    expect(sample.values.last, 4095);
  });

  test('sensor JSON can be extracted from labeled or byte messages', () {
    const json =
        '{"c0":4074,"c1":0,"c2":0,"c3":0,"c4":0,"c5":0,"c6":0,"c7":0,'
        '"c8":0,"c9":0,"c10":0,"c11":0,"c12":0,"c13":0,"c14":0,"c15":0}';

    final labeledSample = parseBeltSensorSample('Live API:\n$json');
    final byteSample = parseBeltSensorSample(utf8.encode(json));

    expect(labeledSample, isNotNull);
    expect(labeledSample!.peak, 4074);
    expect(byteSample, isNotNull);
    expect(byteSample!.peak, 4074);
  });

  test('IMU aliases are parsed and user motion raises active threshold', () {
    final sample = parseBeltSensorSample(
      '{"c0":4090,"c1":0,"c2":0,"c3":0,"c4":0,"c5":0,"c6":0,"c7":0,'
      '"c8":0,"c9":0,"c10":0,"c11":0,"c12":0,"c13":0,"c14":0,"c15":0,'
      '"accX":0.1,"accY":0.2,"accZ":1.6,"gyroX":245,"gyroY":0,"gyroZ":5}',
    );

    expect(sample, isNotNull);
    expect(sample!.motion, isNotNull);
    expect(sample.isUserMoving, isTrue);
    expect(sample.activeFetalMovementThreshold, 4090);
    expect(sample.isMovementActive, isFalse);
  });

  test('short IMU keys can trigger user motion by gyro axis threshold', () {
    final sample = parseBeltSensorSample(
      '{"c0":4091,"c1":0,"c2":0,"c3":0,"c4":0,"c5":0,"c6":0,"c7":0,'
      '"c8":0,"c9":0,"c10":0,"c11":0,"c12":0,"c13":0,"c14":0,"c15":0,'
      '"ax":0,"ay":0,"az":1,"gx":244,"gy":-245,"gz":0}',
    );

    expect(sample, isNotNull);
    expect(sample!.isUserMoving, isTrue);
    expect(sample.isMovementActive, isTrue);
  });

  test('movement is recorded once when threshold is first crossed', () {
    final detector = BeltMovementDetector();
    final startedAt = DateTime(2026, 6, 9, 10);

    expect(detector.addSample(_sampleWithPeak(3500), startedAt), isNull);

    final firstEvent = detector.addSample(
      _sampleWithPeak(3501),
      startedAt.add(const Duration(milliseconds: 100)),
    );
    expect(firstEvent, isNotNull);
    expect(
      firstEvent!.measuredAt,
      startedAt.add(const Duration(milliseconds: 100)),
    );
    expect(firstEvent.intensity, 3501);
    expect(firstEvent.measuredDuringUserMotion, isFalse);

    expect(
      detector.addSample(
        _sampleWithPeak(3800),
        startedAt.add(const Duration(milliseconds: 250)),
      ),
      isNull,
    );
    expect(
      detector.addSample(
        _sampleWithPeak(3600),
        startedAt.add(const Duration(milliseconds: 500)),
      ),
      isNull,
    );

    expect(
      detector.addSample(
        _sampleWithPeak(3500),
        startedAt.add(const Duration(milliseconds: 750)),
      ),
      isNull,
    );

    final nextEvent = detector.addSample(
      _sampleWithPeak(4095),
      startedAt.add(const Duration(milliseconds: 1000)),
    );
    expect(nextEvent, isNotNull);
    expect(nextEvent!.intensity, 4095);
  });

  test('user motion raises movement threshold to 4090', () {
    final detector = BeltMovementDetector();
    final startedAt = DateTime(2026, 6, 10, 10);
    final movingSampleBelowRaisedThreshold = BeltSensorSample(
      values: [4090, ...List<int>.filled(15, 0)],
      motion: const BeltMotionSample(gyroX: 245),
    );

    expect(
      detector.addSample(movingSampleBelowRaisedThreshold, startedAt),
      isNull,
    );

    final movingSampleAboveRaisedThreshold = BeltSensorSample(
      values: [4091, ...List<int>.filled(15, 0)],
      motion: const BeltMotionSample(gyroX: 245),
    );
    final event = detector.addSample(
      movingSampleAboveRaisedThreshold,
      startedAt.add(const Duration(milliseconds: 100)),
    );

    expect(event, isNotNull);
    expect(event!.intensity, 4091);
    expect(event.measuredDuringMotion, isTrue);
  });

  test(
    'movement during user motion is recorded only above raised threshold',
    () {
      final detector = BeltMovementDetector();
      final startedAt = DateTime(2026, 6, 9, 10);

      expect(
        detector.addSample(
          _sampleWithPeak(
            4090,
            motion: const BeltMotionSample(gyroX: -245, gyroY: 0, gyroZ: 0),
          ),
          startedAt,
        ),
        isNull,
      );

      final event = detector.addSample(
        _sampleWithPeak(
          4095,
          motion: const BeltMotionSample(gyroX: -245, gyroY: 0, gyroZ: 0),
        ),
        startedAt.add(const Duration(milliseconds: 200)),
      );

      expect(event, isNotNull);
      expect(event!.intensity, 4095);
      expect(event.measuredDuringUserMotion, isTrue);
    },
  );

  test('invalid messages are ignored', () {
    expect(parseBeltSensorSample('not-json'), isNull);
    expect(parseBeltSensorSample('{"c0":0}'), isNull);
  });
}

BeltSensorSample _sampleWithPeak(int peak, {BeltMotionSample? motion}) {
  return BeltSensorSample(
    values: [peak, ...List<int>.filled(15, 0)],
    motion: motion,
  );
}
