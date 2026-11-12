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
    final words = RegExp(r'\\S+').allMatches(line.lyricText).toList();
    if (words.isEmpty) {
      return SizedBox(height: (textStyle?.fontSize ?? 16) * 1.5);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          for (var index = 0; index < words.length; index++)
            _SongLyricsWord(
              word: words[index].group(0)!,
              anchors: line.anchors
                  .where((anchor) => anchor.wordIndex == index)
                  .toList(growable: false),
              textStyle: textStyle,
            ),
        ],
      ),
    );
  }
}

class _SongLyricsWord extends StatelessWidget {
  const _SongLyricsWord({
    required this.word,
    required this.anchors,
    this.textStyle,
  });

  final String word;
  final List<SongChordAnchor> anchors;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    if (anchors.isEmpty) return Text(word, style: textStyle);
    final ordered = [...anchors]
      ..sort((a, b) => a.characterOffset.compareTo(b.characterOffset));
    final pieces = <Widget>[];
    var offset = 0;
    for (final anchor in ordered) {
      final position = anchor.characterOffset.clamp(offset, word.length).toInt();
      if (position > offset) {
        pieces.add(_SongLyricsPiece(
          text: word.substring(offset, position),
          style: textStyle,
        ));
      }
      pieces.add(_SongLyricsPiece(
        text: word.substring(position, position),
        chord: anchor.chord,
        style: textStyle,
      ));
      offset = position;
    }
    if (offset < word.length) {
      pieces.add(_SongLyricsPiece(
        text: word.substring(offset),
        style: textStyle,
      ));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: pieces,
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
