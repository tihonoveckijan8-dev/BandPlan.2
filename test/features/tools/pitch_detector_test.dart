import 'dart:math' as math;
import 'dart:typed_data';

import 'package:bandplan/features/tools/domain/pitch_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const detector = PitchDetector(sampleRate: 44100);

  test('detects a clean A2 reference tone', () {
    const rate = 44100, count = 4096, hz = 110.0;
    final pcm = Uint8List(count * 2);
    final data = ByteData.sublistView(pcm);
    for (var i = 0; i < count; i++) {
      final sample = math.sin(2 * math.pi * hz * i / rate) * 0.5;
      data.setInt16(i * 2, (sample * 32767).round(), Endian.little);
    }
    final detected = detector.detect(pcm);
    expect(detected, isNotNull);
    expect(detected!, closeTo(hz, 1.5));
  });

  test('median smoothing rejects a single octave jump', () {
    final smoother = PitchStabilizer(windowSize: 5);
    expect(smoother.add(110), 110);
    expect(smoother.add(111), 110);
    expect(smoother.add(220), 111);
    expect(smoother.add(109), 111);
    expect(smoother.add(110), 110);
  });

  test('resets smoothing after silence', () {
    final smoother = PitchStabilizer();
    smoother.add(110);
    smoother.add(111);
    expect(smoother.add(null), isNull);
    expect(smoother.add(220), 220);
  });

  test('ignores silence instead of displaying a false note', () {
    expect(detector.detect(Uint8List(8192)), isNull);
  });
}
