import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bandplan/features/songs/presentation/song_lyrics_view.dart';

void main() {
  testWidgets('keeps each lyric row intact and scrollable horizontally', (tester) async {
    const lyrics =
        'ОченьдлиннаястрокаБезПробеловКотораяДолжнаОстатьсяЦелой  и   сохранять пробелы';

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
    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView).first,
    );
    expect(scrollView.scrollDirection, Axis.horizontal);

    final rendered = tester.widget<Text>(find.byType(Text).first);
    expect(rendered.softWrap, isFalse);
    expect(rendered.maxLines, 1);
    expect((rendered.textSpan as TextSpan).toPlainText(), lyrics);
    expect(
      tester.getSize(find.byType(SingleChildScrollView).first).width,
      lessThanOrEqualTo(180),
    );
  });
}
