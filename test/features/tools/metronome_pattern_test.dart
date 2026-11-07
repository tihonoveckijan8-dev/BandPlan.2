import 'package:flutter_test/flutter_test.dart';
import 'package:bandplan/features/tools/domain/metronome_pattern.dart';

void main() {
  group('MetronomePattern', () {
    test('starts with the first beat accented', () {
      final pattern = MetronomePattern.commonTime(4, 4);
      expect(pattern.isAccented(0), isTrue);
      expect(pattern.isAccented(1), isFalse);
    });

    test('toggles individual accents without mutating the original', () {
      final original = MetronomePattern.commonTime(3, 4);
      final changed = original.toggleAccent(2);
      expect(changed.isAccented(2), isTrue);
      expect(original.isAccented(2), isFalse);
      expect(changed.toggleAccent(0).isAccented(0), isFalse);
    });

    test('keeps beat duration tied to BPM', () {
      expect(MetronomePattern.commonTime(6, 8)
          .beatDuration(120).inMilliseconds, 500);
    });

    test('ignores accent indexes outside the bar', () {
      final pattern = MetronomePattern.commonTime(4, 4);
      expect(identical(pattern, pattern.toggleAccent(4)), isTrue);
    });
  });
}
