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

  test('nearest standard string follows the closest pitch', () {
    const targets = [82.4069, 110.0, 146.8324, 195.9977, 246.9417, 329.6276];
    int nearest(double hz) {
      var index = 0;
      var distance = double.infinity;
      for (var i = 0; i < targets.length; i++) {
        final cents = (1200 * math.log(hz / targets[i]) / math.ln2).abs();
        if (cents < distance) { distance = cents; index = i; }
      }
      return index;
    }
    expect(nearest(110.8), 1);
    expect(nearest(82.5), 0);
    expect(nearest(329.0), 5);
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
