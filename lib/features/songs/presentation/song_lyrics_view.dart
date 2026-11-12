import 'package:flutter/material.dart';

import '../domain/song_document.dart';

/// WHY: one renderer keeps chord-to-word positioning identical in song details
/// and stage mode while leaving the legacy stored lyrics untouched.
class SongLyricsView extends StatelessWidget {
  const SongLyricsView({
    super.key,
    required this.lyrics,
    this.textStyle,
    this.chordStyle,
    this.columns = 1,
    this.columnBreaks = const [],
  });

  final String lyrics;
  final TextStyle? textStyle;
  final TextStyle? chordStyle;
  final int columns;
  final List<int> columnBreaks;

  @override
  Widget build(BuildContext context) {
    final columnSources = SongDocument.splitIntoColumns(
      lyrics,
      columns: columns,
      columnBreaks: columnBreaks,
    );
    final content = columnSources.length == 1
        ? _SongLyricsColumn(source: columnSources.single, textStyle: textStyle, chordStyle: chordStyle)
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < columnSources.length; index++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == columnSources.length - 1 ? 0 : 28,
                    ),
                    child: _SongLyricsColumn(
                      source: columnSources[index],
                      textStyle: textStyle,
                      chordStyle: chordStyle,
                    ),
                  ),
                ),
            ],
          );
    return SelectionArea(child: content);
  }
}

class _SongLyricsColumn extends StatelessWidget {
  const _SongLyricsColumn({required this.source, this.textStyle, this.chordStyle});

  final String source;
  final TextStyle? textStyle;
  final TextStyle? chordStyle;

  @override
  Widget build(BuildContext context) {
    final document = SongDocument.fromLegacyLyrics(source);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in document.lines)
          if (line.sectionLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 8),
              child: Text(
                line.sectionLabel!,
                style: textStyle?.copyWith(fontWeight: FontWeight.w700),
              ),
            )
          else
            _SongLyricsLine(line: line, textStyle: textStyle, chordStyle: chordStyle),
      ],
    );
  }
}

class _SongLyricsLine extends StatelessWidget {
  const _SongLyricsLine({required this.line, this.textStyle, this.chordStyle});

  final SongDocumentLine line;
  final TextStyle? textStyle;
  final TextStyle? chordStyle;

  @override
  Widget build(BuildContext context) {
    if (line.lyricText.isEmpty) {
      return SizedBox(height: (textStyle?.fontSize ?? 16) * 1.5);
    }
    final words = RegExp(r'\S+').allMatches(line.lyricText).toList();
    final anchors = line.anchors.map((anchor) {
      final word = anchor.wordIndex < words.length
          ? words[anchor.wordIndex]
          : null;
      final position = word == null
          ? line.lyricText.length
          : word.start +
              anchor.characterOffset.clamp(0, word.end - word.start).toInt();
      return (anchor: anchor, position: position);
    }).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final spans = <InlineSpan>[];
    var offset = 0;

    for (final item in anchors) {
      final anchor = item.anchor;
      final position = item.position.clamp(offset, line.lyricText.length).toInt();
      if (position > offset) {
        spans.add(TextSpan(
          text: line.lyricText.substring(offset, position),
          style: textStyle,
        ));
      }
      // WHY: WidgetSpan keeps chord labels attached to their exact lyric
      // character while Text handles natural wrapping and preserves spaces.
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.aboveBaseline,
        baseline: TextBaseline.alphabetic,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Text(
            anchor.chord,
            style: chordStyle ?? textStyle?.copyWith(
              fontSize: (textStyle?.fontSize ?? 16) * 0.72,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ));
      offset = position;
    }

    if (offset < line.lyricText.length) {
      spans.add(TextSpan(
        text: line.lyricText.substring(offset),
        style: textStyle,
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      // WHY: stage mode must show the complete musical phrase at once.
      // Scale only oversized rows down to the available width instead of
      // forcing performers to pan horizontally or splitting the phrase.
      child: SizedBox(
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(children: spans, style: textStyle),
            softWrap: false,
            maxLines: 1,
            overflow: TextOverflow.visible,
          ),
        ),
      ),
    );
  }
}
