/// Musical pulse configuration for the metronome.
class MetronomePattern {
  const MetronomePattern({
    required this.beatsPerBar,
    required this.denominator,
    required this.accentedBeats,
  });

  final int beatsPerBar;
  final int denominator;
  final Set<int> accentedBeats;

  factory MetronomePattern.commonTime(int beats, int denominator) =>
      MetronomePattern(
        beatsPerBar: beats,
        denominator: denominator,
        accentedBeats: {0},
      );

  bool isAccented(int beatIndex) => accentedBeats.contains(beatIndex);

  /// BPM follows the displayed beat unit (e.g. eighth notes in 6/8).
  Duration beatDuration(int bpm) =>
      Duration(microseconds: (60000000 / bpm).round());

  MetronomePattern toggleAccent(int beatIndex) {
    if (beatIndex < 0 || beatIndex >= beatsPerBar) return this;
    final next = Set<int>.of(accentedBeats);
    if (!next.add(beatIndex)) next.remove(beatIndex);
    return MetronomePattern(
      beatsPerBar: beatsPerBar,
      denominator: denominator,
      accentedBeats: next,
    );
  }
}
