import 'dart:math' as math;
import 'dart:typed_data';

/// Pure-Dart PCM16 pitch detector, shared later by guitar and violin tuners.
class PitchDetector {
  const PitchDetector({this.sampleRate = 44100});
  final int sampleRate;

  double? detect(Uint8List pcm) {
    final count = pcm.length ~/ 2;
    if (count < 2048) return null;
    final x = Float64List(count);
    var mean = 0.0;
    for (var i = 0; i < count; i++) {
      final raw = pcm[2 * i] | (pcm[2 * i + 1] << 8);
      final sample = raw >= 32768 ? raw - 65536 : raw;
      x[i] = sample / 32768.0;
      mean += x[i];
    }
    mean /= count;
    var energy = 0.0;
    for (var i = 0; i < count; i++) {
      x[i] -= mean;
      energy += x[i] * x[i];
    }
    if (math.sqrt(energy / count) < 0.008) return null;

    final minLag = (sampleRate / 700).floor().clamp(2, count ~/ 4).toInt();
    final maxLag = (sampleRate / 65).ceil().clamp(minLag + 2, count ~/ 2).toInt();
    final scores = Float64List(maxLag + 1);
    for (var lag = minLag; lag <= maxLag; lag++) {
      var dot = 0.0, a = 0.0, b = 0.0;
      for (var i = 0; i < count - lag; i++) {
        final left = x[i], right = x[i + lag];
        dot += left * right;
        a += left * left;
        b += right * right;
      }
      final norm = math.sqrt(a * b);
      scores[lag] = norm == 0 ? 0 : dot / norm;
    }

    var best = -1, bestScore = 0.0;
    for (var lag = minLag + 1; lag < maxLag; lag++) {
      if (scores[lag] >= scores[lag - 1] &&
          scores[lag] > scores[lag + 1] &&
          scores[lag] > 0.72) {
        best = lag;
        bestScore = scores[lag];
        break;
      }
      if (scores[lag] > bestScore) {
        best = lag;
        bestScore = scores[lag];
      }
    }
    if (best < 0 || bestScore < 0.72) return null;
    final denominator = scores[best - 1] - 2 * scores[best] + scores[best + 1];
    final shift = denominator.abs() < 1e-9
        ? 0.0
        : (0.5 * (scores[best - 1] - scores[best + 1]) / denominator)
            .clamp(-0.5, 0.5);
    return sampleRate / (best + shift);
  }
}

/// Median-based pitch smoothing to ignore brief octave/noise jumps.
/// Reset it when the input goes silent or the selected string changes.
class PitchStabilizer {
  PitchStabilizer({this.windowSize = 5}) : assert(windowSize > 0);
  final int windowSize;
  final List<double> _samples = [];

  double? add(double? frequency) {
    if (frequency == null || !frequency.isFinite || frequency <= 0) {
      reset();
      return null;
    }
    _samples.add(frequency);
    if (_samples.length > windowSize) _samples.removeAt(0);
    final sorted = List<double>.of(_samples)..sort();
    return sorted[sorted.length ~/ 2];
  }

  void reset() => _samples.clear();
}
