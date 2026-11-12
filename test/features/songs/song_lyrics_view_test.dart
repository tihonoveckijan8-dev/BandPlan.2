import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bandplan/features/songs/presentation/song_lyrics_view.dart';

void main() {
  testWidgets('keeps a complete lyric row visible without horizontal scrolling', (tester) async {
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
    expect(find.byType(FittedBox), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);

    final fitted = tester.widget<FittedBox>(find.byType(FittedBox));
    expect(fitted.fit, BoxFit.scaleDown);
    expect(fitted.alignment, Alignment.centerLeft);

    final rendered = tester.widget<Text>(find.byType(Text).first);
    expect(rendered.softWrap, isFalse);
    expect(rendered.maxLines, 1);
    expect((rendered.textSpan as TextSpan).toPlainText(), lyrics);
    expect(
      tester.getSize(find.byType(FittedBox)).width,
      lessThanOrEqualTo(180),
    );
  });
}
