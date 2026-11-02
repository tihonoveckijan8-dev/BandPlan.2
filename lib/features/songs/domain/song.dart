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
        bpm = _integer(raw['bpm']),
        durationSeconds = _integer(raw['duration']),
        tags = _stringList(raw['tags']),
        isFavorite = raw['fav'] == true;

  final Map<String, dynamic> raw;
  final String id;
  final String title;
  final String artist;
  final String key;
  final String lyrics;
  final int? bpm;
  final int? durationSeconds;
  final List<String> tags;
  final bool isFavorite;

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
  }) {
    return Song._({
      ...raw,
      'title': title,
      'artist': artist,
      'key': key,
      'bpm': bpm,
      'tags': tags,
      'lyrics': lyrics,
    });
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

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
