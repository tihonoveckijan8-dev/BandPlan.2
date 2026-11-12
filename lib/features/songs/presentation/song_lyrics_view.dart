import 'package:flutter/material.dart';

import '../domain/song_document.dart';

/// WHY: one renderer keeps chord-to-word positioning identical in song details
/// and stage mode while leaving the legacy stored lyrics untouched.
class SongLyricsView extends StatelessWidget {
  const SongLyricsView({
    super.key,
    required this.lyrics,
    this.textStyle,
    this.columns = 1,
    this.columnBreaks = const [],
  });

  final String lyrics;
  final TextStyle? textStyle;
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
        ? _SongLyricsColumn(source: columnSources.single, textStyle: textStyle)
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
                    ),
                  ),
                ),
            ],
          );
    return SelectionArea(child: content);
  }
}

class _SongLyricsColumn extends StatelessWidget {
  const _SongLyricsColumn({required this.source, this.textStyle});

  final String source;
  final TextStyle? textStyle;

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
            _SongLyricsLine(line: line, textStyle: textStyle),
      ],
    );
  }
}

class _SongLyricsLine extends StatelessWidget {
  const _SongLyricsLine({required this.line, this.textStyle});

  final SongDocumentLine line;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final anchors = [...line.anchors]
      ..sort((a, b) => a.characterOffset.compareTo(b.characterOffset));
    final spans = <InlineSpan>[];
    var offset = 0;

    for (final anchor in anchors) {
      final position = anchor.characterOffset
          .clamp(offset, line.lyricText.length)
          .toInt();
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
            style: textStyle?.copyWith(
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
      child: Text.rich(
        TextSpan(children: spans, style: textStyle),
        softWrap: true,
        maxLines: null,
        overflow: TextOverflow.visible,
      ),
    );
  }
}

class _SongLyricsPiece extends StatelessWidget {
  const _SongLyricsPiece({required this.text, required this.style, this.chord});

  final String text;
  final String? chord;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chord != null)
            Text(
              chord!,
              style: style?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          Text(text, style: style),
        ],
      );
}
