import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bandplan/features/songs/presentation/song_lyrics_view.dart';

void main() {
  testWidgets('preserves all lyric characters and wraps a long line', (tester) async {
    const lyrics =
        'ОченьдлиннаястрокаБезПробеловКотораяДолжнаПереноситься  и   сохранять пробелы';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 180,
              child: SongLyricsView(lyrics: lyrics),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final rendered = tester.widget<Text>(find.byType(Text).first);
    expect((rendered.textSpan as TextSpan).toPlainText(), lyrics);
    expect(tester.getSize(find.byType(Text).first).width, lessThanOrEqualTo(180));
  });
}
