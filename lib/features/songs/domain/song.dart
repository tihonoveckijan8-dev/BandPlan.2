/// A lossless view of a legacy BandPlan song JSON document.
///
/// The original payload is retained so future editing/sync can round-trip
/// fields that this first catalogue screen does not understand yet.
class Song {
  Song._(this.raw)
      : id = _string(raw['id']),
        title = _string(raw['title']),
        artist = _string(raw['artist']),
        key = _string(raw['key']),
        lyrics = _string(raw['lyrics']),
        lyricsColumns = (_integer(raw['lyricsColumns']) ?? 1).clamp(1, 3),
        bpm = _integer(raw['bpm']),
        durationSeconds = _integer(raw['duration']),
        tags = _stringList(raw['tags']),
        isFavorite = raw['fav'] == true,\n        lyricsColumns = (_integer(raw['lyricsColumns']) ?? 1).clamp(1, 3).toInt(),\n        lyricsColumnBreaks = _integerList(raw['lyricsColumnBreaks']);

  final Map<String, dynamic> raw;
  final String id;
  final String title;
  final String artist;
  final String key;
  final String lyrics;
  /// Number of Word-like reading columns used for this song.
  final int lyricsColumns;
  final int? bpm;
  final int? durationSeconds;
  final List<String> tags;
  final bool isFavorite;\n  final int lyricsColumns;\n  final List<int> lyricsColumnBreaks;

  factory Song.fromJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    if (_string(copy['id']).isEmpty) {
      throw const FormatException('Song payload is missing its id.');
    }
    return Song._(copy);
  }

  /// Creates an edited view while retaining legacy fields this UI does not know.
  Song withEdits({
    required String title,
    required String artist,
    required String key,
    required int? bpm,
    required List<String> tags,
    required String lyrics,
    int? lyricsColumns,
  }) {
    return Song._({
      ...raw,
      'title': title,
      'artist': artist,
      'key': key,
      'bpm': bpm,
      'tags': tags,
      'lyrics': lyrics,
      'lyricsColumns': (lyricsColumns ?? this.lyricsColumns).clamp(1, 3),
    });
  }

  /// Returns a temporary transposed view without changing the stored song.
  /// Inline chord tokens and chord-only rows are transformed in place; every
  /// other character (including line breaks and spacing) is retained.
  Song transposedBy(int semitones) {
    if (semitones == 0) return this;
    final transposedLyrics = lyrics
        .split('\n')
        .map((line) => _transposeLyricsLine(line, semitones))
        .join('\n');
    final transposedKey = _transposeChord(key, semitones) ?? key;
    return Song._({...raw, 'key': transposedKey, 'lyrics': transposedLyrics});
  }

  static String _transposeLyricsLine(String line, int semitones) {
    // Legacy section labels such as [Куплет] are deliberately left untouched.
    final withInlineChords = line.replaceAllMapped(
      RegExp(r'\[([^\r\n\]]+)\]'),
      (match) {
        final chord = _transposeChord(match.group(1)!, semitones);
        return chord == null ? match.group(0)! : '[$chord]';
      },
    );
    final tokens = RegExp(r'\S+').allMatches(withInlineChords).toList();
    if (tokens.isEmpty ||
        tokens.any((match) => _transposeChord(match.group(0)!, semitones) == null)) {
      return withInlineChords;
    }
    // Chord-only rows (for example "Am       G") are common in legacy songs.
    return withInlineChords.replaceAllMapped(
      RegExp(r'\S+'),
      (match) => _transposeChord(match.group(0)!, semitones)!,
    );
  }

  static String? _transposeChord(String value, int semitones) {
    final match = RegExp(
      r'^([A-G](?:#|b)?)(?:(?:maj|min|m|M|dim|aug|sus[24]?|add\d+|no\d+|omit\d+|\d+|[b#]\d+|ø|°|\+|-)*)(?:/([A-G](?:#|b)?))?$'
    ).firstMatch(value);
    if (match == null) return null;
    final root = _transposeNote(match.group(1)!, semitones);
    final slash = match.group(2);
    final suffixStart = match.group(1)!.length;
    final suffixEnd = slash == null ? value.length : value.lastIndexOf('/');
    final suffix = value.substring(suffixStart, suffixEnd);
    return root + suffix + (slash == null ? '' : '/' + _transposeNote(slash, semitones));
  }

  static String _transposeNote(String note, int semitones) {
    const sharpNotes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    const flatNotes = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'];
    const pitch = {
      'C': 0, 'B#': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3,
      'E': 4, 'Fb': 4, 'E#': 5, 'F': 5, 'F#': 6, 'Gb': 6, 'G': 7,
      'G#': 8, 'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11, 'Cb': 11,
    };
    final value = pitch[note];
    if (value == null) return note;
    final normalized = (value + semitones) % 12;
    final index = (normalized + 12) % 12;
    return note.contains('b') ? flatNotes[index] : sharpNotes[index];
  }

  /// Returns the unchanged legacy payload, including unknown fields.
  Map<String, dynamic> toLegacyJson() => Map<String, dynamic>.from(raw);

  String get searchableText =>
      '$title $artist ${tags.join(' ')} $lyrics'.toLowerCase();

  static String _string(Object? value) => value?.toString().trim() ?? '';

  static int? _integer(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static List<int> _integerList(Object? value) {\n    if (value is! List) return const [];\n    return value.map((item) => item is int ? item : item is num ? item.toInt() : int.tryParse(item?.toString() ?? '')).whereType<int>().toList(growable: false);\n  }\n\n  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}