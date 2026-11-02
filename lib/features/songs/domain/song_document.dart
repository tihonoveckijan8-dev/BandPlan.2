/// Structured, read-only view of legacy song lyrics.
///
/// Legacy storage remains the source of truth until structured editing can be
/// round-tripped against real production records. Chord offsets are measured
/// in lyric text (with chord tokens removed), never in visual whitespace.
class SongDocument {
  SongDocument._(this.source, this.lines);

  factory SongDocument.fromLegacyLyrics(String source) {
    final lines = source
        .split('\n')
        .map(SongDocumentLine._parse)
        .toList(growable: false);
    return SongDocument._(source, lines);
  }

  /// Exact original payload, including whitespace and line endings.
  final String source;

  final List<SongDocumentLine> lines;

  /// Returns the original representation unchanged for safe legacy storage.
  String toLegacyLyrics() => source;
}

class SongDocumentLine {
  SongDocumentLine._({
    required this.source,
    required this.lyricText,
    required this.anchors,
    required this.sectionLabel,
  });

  factory SongDocumentLine._parse(String source) {
    final matches = RegExp(r'\[([^\]\r\n]+)\]').allMatches(source);
    final text = StringBuffer();
    final anchors = <SongChordAnchor>[];
    var sourceOffset = 0;
    var lyricOffset = 0;

    for (final match in matches) {
      final before = source.substring(sourceOffset, match.start);
      text.write(before);
      lyricOffset += before.length;

      final token = match.group(1)!;
      if (_isChord(token)) {
        anchors.add(SongChordAnchor(
          offset: lyricOffset,
          chord: token,
        ));
      } else {
        // Section labels and unknown bracketed text remain ordinary text.
        text.write(match.group(0)!);
        lyricOffset += match.group(0)!.length;
      }
      sourceOffset = match.end;
    }

    final tail = source.substring(sourceOffset);
    text.write(tail);

    final trimmed = source.trim();
    final sectionMatch = RegExp(r'^\[([^\]\r\n]+)\]$').firstMatch(trimmed);
    final sectionToken = sectionMatch?.group(1);
    final sectionLabel = sectionToken != null && !_isChord(sectionToken)
        ? sectionToken
        : null;

    return SongDocumentLine._(
      source: source,
      lyricText: text.toString(),
      anchors: List.unmodifiable(anchors),
      sectionLabel: sectionLabel,
    );
  }

  final String source;
  final String lyricText;
  final List<SongChordAnchor> anchors;
  final String? sectionLabel;

  static bool _isChord(String value) => RegExp(
        r'^[A-G](?:#|b)?(?:maj|min|m|M|dim|aug|sus[24]?|add\d+|no\d+|omit\d+|\d+|[b#]\d+|ø|°|\+|-)*(?:/[A-G](?:#|b)?)?$',
      ).hasMatch(value);
}

class SongChordAnchor {
  const SongChordAnchor({required this.offset, required this.chord});

  /// Character offset in lyric text after inline chord tokens are removed.
  final int offset;
  final String chord;
}
