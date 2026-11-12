import 'package:flutter_test/flutter_test.dart';
import 'package:bandplan/features/songs/domain/song.dart';
import 'package:bandplan/features/songs/domain/song_document.dart';

void main() {
  group('Song legacy payload', () {
    test('reads common catalogue fields without rewriting lyrics', () {
      const lyrics = '[Куплет 1]\nEm       G\nТекст строки\nC [D] дальше';
      final song = Song.fromJson({
        'id': 'legacy-1',
        'title': 'Песня',
        'artist': 'Исполнитель',
        'key': 'Em',
        'bpm': 104,
        'duration': 225,
        'tags': ['рок', 'живое'],
        'fav': true,
        'lyrics': lyrics,
      });

      expect(song.id, 'legacy-1');
      expect(song.title, 'Песня');
      expect(song.artist, 'Исполнитель');
      expect(song.key, 'Em');
      expect(song.bpm, 104);
      expect(song.durationSeconds, 225);
      expect(song.tags, ['рок', 'живое']);
      expect(song.isFavorite, isTrue);
      expect(song.lyrics, lyrics);
      expect(song.lyricsColumns, 1);
    });

    test('keeps unknown chord and arrangement fields for round-trip', () {
      final payload = <String, dynamic>{
        'id': 'legacy-2',
        'title': 'Сложная песня',
        'lyrics': 'Am [C] текст',
        'chordAnchors': [
          {'line': 0, 'offset': 3, 'chord': 'Am'},
        ],
        'dynamics': {'instruments': ['vocal', 'guitar']},
        'customLegacyField': {'version': 7},
      };

      final song = Song.fromJson(payload);

      expect(song.toLegacyJson(), payload);
      expect(song.toLegacyJson()['chordAnchors'], payload['chordAnchors']);
      expect(song.toLegacyJson()['dynamics'], payload['dynamics']);
    });

    test('search text includes lyrics, artist and tags', () {
      final song = Song.fromJson({
        'id': 'legacy-3',
        'title': 'Ночь',
        'artist': 'Группа',
        'tags': ['баллада'],
        'lyrics': 'Свет в окне',
      });

      expect(song.searchableText, contains('группа'));
      expect(song.searchableText, contains('баллада'));
      expect(song.searchableText, contains('свет в окне'));
    });


    test('edits visible fields but preserves unknown chord and dynamics data', () {
      final song = Song.fromJson({
        'id': 'legacy-edit',
        'title': 'Старая версия',
        'artist': 'Исполнитель',
        'key': 'Am',
        'lyrics': 'Am      F\nТекст',
        'chordAnchors': [{'line': 0, 'offset': 0, 'chord': 'Am'}],
        'dynamics': {'sections': ['Куплет'], 'notes': {'guitar': 'тише'}},
        'legacyExtension': {'keep': true},
      });

      final edited = song.withEdits(
        title: 'Новая версия',
        artist: 'Другой исполнитель',
        key: 'C',
        bpm: 112,
        tags: ['live'],
        lyrics: 'C       G\nНовый текст',
      );

      expect(edited.title, 'Новая версия');
      expect(edited.artist, 'Другой исполнитель');
      expect(edited.key, 'C');
      expect(edited.bpm, 112);
      expect(edited.lyrics, 'C       G\nНовый текст');
      expect(edited.lyricsColumns, 1);
      expect(edited.toLegacyJson()['chordAnchors'], song.toLegacyJson()['chordAnchors']);
      expect(edited.toLegacyJson()['dynamics'], song.toLegacyJson()['dynamics']);
      expect(edited.toLegacyJson()['legacyExtension'], {'keep': true});
    });


    test('transposes inline and chord-only rows without changing section labels or spacing', () {
      final song = Song.fromJson({
        'id': 'transpose-1',
        'title': 'Тест',
        'key': 'Am',
        'lyrics': '[Куплет 1]\nAm       G\n[C]слово [D/F#]текст\n[Припев]',
        'chordAnchors': [{'line': 1, 'offset': 0, 'chord': 'Am'}],
        'dynamics': {'keep': true},
      });

      final raised = song.transposedBy(2);
      expect(raised.key, 'Bm');
      expect(raised.lyrics, '[Куплет 1]\nBm       A\n[D]слово [E/G#]текст\n[Припев]');
      expect(raised.toLegacyJson()['chordAnchors'], song.toLegacyJson()['chordAnchors']);
      expect(raised.toLegacyJson()['dynamics'], song.toLegacyJson()['dynamics']);
      expect(song.key, 'Am');
      expect(song.lyrics, '[Куплет 1]\nAm       G\n[C]слово [D/F#]текст\n[Припев]');
    });

    test('transposes flat chord roots while retaining chord qualities', () {
      final song = Song.fromJson({
        'id': 'transpose-2',
        'title': 'Тест',
        'key': 'Bb',
        'lyrics': '[Bbmaj7] [Gm7] [D/F]',
      });

      final raised = song.transposedBy(2);
      expect(raised.key, 'C');
      expect(raised.lyrics, '[Cmaj7] [Am7] [E/G]');
    });


    test('transposes altered extensions and slash bass notes', () {
      final song = Song.fromJson({
        'id': 'transpose-altered',
        'title': 'Тест',
        'key': 'F#m',
        'lyrics': '[Am7b5] [G7#5] [Cadd9/E] [D7sus4/A]',
      });

      final raised = song.transposedBy(2);
      expect(raised.key, 'G#m');
      expect(
        raised.lyrics,
        '[Bm7b5] [A7#5] [Dadd9/F#] [E7sus4/B]',
      );
      expect(song.key, 'F#m');
      expect(song.lyrics, '[Am7b5] [G7#5] [Cadd9/E] [D7sus4/A]');
    });

    test('supports downward and multi-octave transposition', () {
      final song = Song.fromJson({
        'id': 'transpose-down',
        'title': 'Тест',
        'key': 'Bb',
        'lyrics': 'Bb       F',
      });

      expect(song.transposedBy(-1).key, 'A');
      expect(song.transposedBy(-1).lyrics, 'A       E');
      expect(song.transposedBy(14).key, 'C');
      expect(song.transposedBy(14).lyrics, 'C       G');
    });

    test('rejects payloads without a legacy id', () {
      expect(
        () => Song.fromJson({'title': 'Без id'}),
        throwsFormatException,
      );
    });
  });

  group('SongDocument legacy parser', () {
    test('extracts inline chord anchors by lyric-text offset', () {
      final document = SongDocument.fromLegacyLyrics('До [Am]после [G]конец');

      expect(document.lines.single.lyricText, 'До после конец');
      expect(
        document.lines.single.anchors
            .map((anchor) => [anchor.wordIndex, anchor.characterOffset, anchor.chord]).toList(),
        [
          [1, 0, 'Am'],
          [2, 0, 'G'],
        ],
      );
    });


    test('keeps chord anchors stable when lyric spacing changes', () {
      final compact = SongDocument.fromLegacyLyrics('До [Am]после');
      final spaced = SongDocument.fromLegacyLyrics('До       [Am]после');

      expect(compact.lines.single.anchors.single.wordIndex, 1);
      expect(spaced.lines.single.anchors.single.wordIndex, 1);
      expect(compact.lines.single.anchors.single.characterOffset, 0);
      expect(spaced.lines.single.anchors.single.characterOffset, 0);
    });

    test('keeps section labels separate from chord anchors', () {
      final document = SongDocument.fromLegacyLyrics(
        '[Куплет 1]\n[Am]Первая строка\n[Припев]',
      );

      expect(document.lines[0].sectionLabel, 'Куплет 1');
      expect(document.lines[0].anchors, isEmpty);
      expect(document.lines[1].sectionLabel, isNull);
      expect(document.lines[1].anchors.single.chord, 'Am');
      expect(document.lines[2].sectionLabel, 'Припев');
    });

    test('inserts a chord at the cursor without manual spacing', () {
      expect(
        SongDocument.insertChordToken(
          source: 'До после',
          selectionStart: 3,
          selectionEnd: 3,
          chord: 'Am7',
        ),
        'До [Am7]после',
      );
    });

    test('replaces selected lyric text with a chord and normalizes reversed ranges', () {
      expect(
        SongDocument.insertChordToken(
          source: 'До этого слова',
          selectionStart: 9,
          selectionEnd: 3,
          chord: 'D/F#',
        ),
        'До [D/F#]слова',
      );
    });

    test('rejects invalid chord symbols instead of corrupting lyric markup', () {
      expect(
        () => SongDocument.insertChordToken(
          source: 'Текст',
          selectionStart: 0,
          selectionEnd: 0,
          chord: '[Am]',
        ),
        throwsArgumentError,
      );
    });

    test('round-trips original whitespace and line breaks exactly', () {
      const source = '[Куплет]\r\n[Am]Слова   строки\n\n[G]Финал  ';
      final document = SongDocument.fromLegacyLyrics(source);

      expect(document.toLegacyLyrics(), source);
    });
  });

}
