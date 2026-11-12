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

  /// Splits the logical lyrics into editable, contiguous columns.
  /// Break positions are line counts before the next column; no marker is
  /// inserted into the lyrics, so chord tokens and line content stay lossless.
  static List<String> splitIntoColumns(
    String source, {
    int columns = 1,
    List<int> columnBreaks = const [],
  }) {
    final count = columns.clamp(1, 3).toInt();
    if (count == 1) return [source];

    final lines = source.split('\n');
    List<int> breaks;
    var validStoredBreaks = columnBreaks.length == count - 1 &&
        columnBreaks.every((value) => value >= 0 && value <= lines.length);
    for (var i = 1; i < columnBreaks.length; i++) {
      if (columnBreaks[i] < columnBreaks[i - 1]) {
        validStoredBreaks = false;
      }
    }
    breaks = validStoredBreaks
        ? List<int>.of(columnBreaks)
        : _balancedBreaks(lines.length, count);

    final result = <String>[];
    var start = 0;
    for (final end in [...breaks, lines.length]) {
      result.add(lines.sublist(start, end).join('\n'));
      start = end;
    }
    return result;
  }

  /// Stores column boundaries separately from lyrics as line offsets.
  static List<int> columnBreaksFor(List<String> columns) {
    if (columns.length <= 1 || columns.every((column) => column.isEmpty)) {
      return const [];
    }
    var offset = 0;
    final breaks = <int>[];
    for (var i = 0; i < columns.length - 1; i++) {
      offset += columns[i].split('\n').length;
      breaks.add(offset);
    }
    return breaks;
  }

  static String joinColumns(List<String> columns) =>
      columns.every((column) => column.isEmpty) ? '' : columns.join('\n');

  static List<int> _balancedBreaks(int lineCount, int columnCount) {
    final base = lineCount ~/ columnCount;
    final remainder = lineCount % columnCount;
    final breaks = <int>[];
    var offset = 0;
    for (var i = 0; i < columnCount - 1; i++) {
      offset += base + (i < remainder ? 1 : 0);
      breaks.add(offset);
    }
    return breaks;
  }

  static bool isChordSymbol(String value) => SongDocumentLine.isChordSymbol(value);

  /// Finds standalone legacy section-marker lines without treating chord tokens as sections.
  static List<int> sectionLineIndices(String source) {
    final lines = source.split('\\n');
    return [
      for (var i = 0; i < lines.length; i++)
        if (RegExp(r'^\\s*\\[[^\\]\\r\\n]+\\]\\s*
  /// WHY: this keeps chord placement tied to the cursor/syllable, not to manually
  /// estimated spaces that change between fonts and screen sizes.
  static String insertChordToken({
    required String source,
    required int selectionStart,
    required int selectionEnd,
    required String chord,
  }) {
    final normalizedChord = chord.trim();
    if (!isChordSymbol(normalizedChord)) {
      throw ArgumentError.value(chord, 'chord', 'Invalid chord symbol');
    }
    final lower = (selectionStart < selectionEnd ? selectionStart : selectionEnd)
        .clamp(0, source.length).toInt();
    final upper = (selectionStart > selectionEnd ? selectionStart : selectionEnd)
        .clamp(0, source.length);
    return source.replaceRange(lower, upper, '[$normalizedChord]');
  }
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

    for (final match in matches) {
      final before = source.substring(sourceOffset, match.start);
      text.write(before);
      final token = match.group(1)!;
      if (isChordSymbol(token)) {
        final position = _wordPosition(text.toString());
        anchors.add(SongChordAnchor(
          wordIndex: position.$1,
          characterOffset: position.$2,
          chord: token,
        ));
      } else {
        // Section labels and unknown bracketed text remain ordinary text.
        text.write(match.group(0)!);
      }
      sourceOffset = match.end;
    }

    final tail = source.substring(sourceOffset);
    text.write(tail);

    final trimmed = source.trim();
    final sectionMatch = RegExp(r'^\[([^\]\r\n]+)\]$').firstMatch(trimmed);
    final sectionToken = sectionMatch?.group(1);
    final sectionLabel = sectionToken != null && !isChordSymbol(sectionToken)
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

  static (int, int) _wordPosition(String text) {
    final words = RegExp(r'\S+').allMatches(text).toList(growable: false);
    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      if (text.length <= word.end) {
        return (i, text.length - word.start);
      }
    }
    return (words.length, 0);
  }

  static bool isChordSymbol(String value) => RegExp(
        r'^[A-G](?:#|b)?(?:maj|min|m|M|dim|aug|sus[24]?|add\d+|no\d+|omit\d+|\d+|[b#]\d+|ø|°|\+|-)*(?:/[A-G](?:#|b)?)?$',
      ).hasMatch(value);
}

class SongChordAnchor {
  const SongChordAnchor({
    required this.wordIndex,
    required this.characterOffset,
    required this.chord,
  });

  /// Index of the lyric word preceding this chord, ignoring whitespace width.
  final int wordIndex;

  /// Character offset inside that word (zero when anchored between words).
  final int characterOffset;
  final String chord;
}
).hasMatch(lines[i]) &&
            !isChordSymbol(lines[i].trim().substring(1, lines[i].trim().length - 1)))
          i,
    ];
  }

  static String renameSection(String source, int sectionIndex, String label) {
    final lines = source.split('\\n');
    final starts = sectionLineIndices(source);
    if (sectionIndex < 0 || sectionIndex >= starts.length) return source;
    final clean = label.trim();
    if (clean.isEmpty || clean.contains(']') || clean.contains('\\n')) return source;
    lines[starts[sectionIndex]] = '[$clean]';
    return lines.join('\\n');
  }

  static String removeSection(String source, int sectionIndex) {
    final lines = source.split('\\n');
    final starts = sectionLineIndices(source);
    if (sectionIndex < 0 || sectionIndex >= starts.length) return source;
    final start = starts[sectionIndex];
    final end = sectionIndex + 1 < starts.length ? starts[sectionIndex + 1] : lines.length;
    lines.removeRange(start, end);
    return lines.join('\\n');
  }

  static String duplicateSection(String source, int sectionIndex) {
    final lines = source.split('\\n');
    final starts = sectionLineIndices(source);
    if (sectionIndex < 0 || sectionIndex >= starts.length) return source;
    final start = starts[sectionIndex];
    final end = sectionIndex + 1 < starts.length ? starts[sectionIndex + 1] : lines.length;
    lines.insertAll(end, lines.sublist(start, end));
    return lines.join('\\n');
  }

  static String moveSection(String source, int sectionIndex, int delta) {
    if (delta != -1 && delta != 1) return source;
    final lines = source.split('\\n');
    final starts = sectionLineIndices(source);
    final target = sectionIndex + delta;
    if (sectionIndex < 0 || sectionIndex >= starts.length ||
        target < 0 || target >= starts.length) return source;
    final ranges = <List<int>>[];
    for (var i = 0; i < starts.length; i++) {
      ranges.add([starts[i], i + 1 < starts.length ? starts[i + 1] : lines.length]);
    }
    final first = ranges[sectionIndex];
    final second = ranges[target];
    if (delta < 0) {
      final before = lines.sublist(second[0], first[0]);
      final current = lines.sublist(first[0], first[1]);
      lines.replaceRange(second[0], first[1], [...current, ...before]);
    } else {
      final current = lines.sublist(first[0], first[1]);
      final after = lines.sublist(second[0], second[1]);
      lines.replaceRange(first[0], second[1], [...after, ...current]);
    }
    return lines.join('\\n');
  }

  /// Inserts a legacy chord token at the selected lyric position.
  /// WHY: this keeps chord placement tied to the cursor/syllable, not to manually
  /// estimated spaces that change between fonts and screen sizes.
  static String insertChordToken({
    required String source,
    required int selectionStart,
    required int selectionEnd,
    required String chord,
  }) {
    final normalizedChord = chord.trim();
    if (!isChordSymbol(normalizedChord)) {
      throw ArgumentError.value(chord, 'chord', 'Invalid chord symbol');
    }
    final lower = (selectionStart < selectionEnd ? selectionStart : selectionEnd)
        .clamp(0, source.length).toInt();
    final upper = (selectionStart > selectionEnd ? selectionStart : selectionEnd)
        .clamp(0, source.length);
    return source.replaceRange(lower, upper, '[$normalizedChord]');
  }
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

    for (final match in matches) {
      final before = source.substring(sourceOffset, match.start);
      text.write(before);
      final token = match.group(1)!;
      if (isChordSymbol(token)) {
        final position = _wordPosition(text.toString());
        anchors.add(SongChordAnchor(
          wordIndex: position.$1,
          characterOffset: position.$2,
          chord: token,
        ));
      } else {
        // Section labels and unknown bracketed text remain ordinary text.
        text.write(match.group(0)!);
      }
      sourceOffset = match.end;
    }

    final tail = source.substring(sourceOffset);
    text.write(tail);

    final trimmed = source.trim();
    final sectionMatch = RegExp(r'^\[([^\]\r\n]+)\]$').firstMatch(trimmed);
    final sectionToken = sectionMatch?.group(1);
    final sectionLabel = sectionToken != null && !isChordSymbol(sectionToken)
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

  static (int, int) _wordPosition(String text) {
    final words = RegExp(r'\S+').allMatches(text).toList(growable: false);
    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      if (text.length <= word.end) {
        return (i, text.length - word.start);
      }
    }
    return (words.length, 0);
  }

  static bool isChordSymbol(String value) => RegExp(
        r'^[A-G](?:#|b)?(?:maj|min|m|M|dim|aug|sus[24]?|add\d+|no\d+|omit\d+|\d+|[b#]\d+|ø|°|\+|-)*(?:/[A-G](?:#|b)?)?$',
      ).hasMatch(value);
}

class SongChordAnchor {
  const SongChordAnchor({
    required this.wordIndex,
    required this.characterOffset,
    required this.chord,
  });

  /// Index of the lyric word preceding this chord, ignoring whitespace width.
  final int wordIndex;

  /// Character offset inside that word (zero when anchored between words).
  final int characterOffset;
  final String chord;
}
