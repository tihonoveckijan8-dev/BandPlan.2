import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bandplan/features/songs/domain/song.dart';
import 'package:bandplan/features/stage/presentation/stage_mode_page.dart';

Finder lyricText(String value) => find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText().contains(value),
    );

double? _firstExplicitFontSize(InlineSpan span) {
  if (span is! TextSpan) return null;
  if (span.style?.fontSize != null) return span.style!.fontSize;
  for (final child in span.children ?? const <InlineSpan>[]) {
    final size = _firstExplicitFontSize(child);
    if (size != null) return size;
  }
  return null;
}

void main() {
  Song makeSong(String id, String title, String lyrics, {int columns = 1}) =>
      Song.fromJson({
        'id': id,
        'title': title,
        'artist': 'Band',
        'key': 'Am',
        'bpm': 96,
        'lyrics': lyrics,
        'lyricsColumns': columns,
      });

  testWidgets('stage mode is immersive text-only with pinch zoom', (tester) async {
    final song = makeSong('song-1', 'Stage song', '[Am]First line\n[Куплет]\nSecond line');
    await tester.pumpWidget(MaterialApp(home: StageModePage(song: song)));

    expect(lyricText('First'), findsOneWidget);
    expect(lyricText('line'), findsWidgets);
    expect(find.text('Куплет'), findsOneWidget);
    expect(find.text('Stage song'), findsNothing);
    expect(find.text('96 BPM'), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byTooltip('Автопрокрутка'), findsNothing);
    expect(find.byTooltip('Увеличить текст'), findsNothing);
    expect(find.byTooltip('Скрыть аккорды'), findsNothing);
  });

  testWidgets('renders song in configured columns', (tester) async {
    final song = makeSong('columns', 'Columns', 'Line one\nLine two\nLine three\nLine four',
        columns: 2);
    await tester.pumpWidget(MaterialApp(home: StageModePage(song: song)));

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(lyricText('Line'), findsNWidgets(4));
    expect(lyricText('one'), findsOneWidget);
    expect(lyricText('four'), findsOneWidget);
  });

  testWidgets('navigates through setlist tracks using only previous and next', (tester) async {
    final first = makeSong('one', 'First track', '[Am]first lyrics');
    final second = makeSong('two', 'Second track', '[C]second lyrics');
    await tester.pumpWidget(MaterialApp(
      home: StageModePage(
        song: first,
        queue: [
          StageModeTrack(song: first, semitones: 1, note: 'First note'),
          StageModeTrack(song: second, semitones: -2, note: 'Second note'),
        ],
      ),
    ));

    expect(find.byTooltip('Предыдущая песня'), findsOneWidget);
    expect(find.byTooltip('Следующая песня'), findsOneWidget);
    expect(find.text('First note'), findsNothing);

    await tester.tap(find.byTooltip('Следующая песня'));
    await tester.pumpAndSettle();
    expect(lyricText('second'), findsOneWidget);
    expect(find.text('Second track'), findsNothing);

    await tester.tap(find.byTooltip('Предыдущая песня'));
    await tester.pumpAndSettle();
    expect(lyricText('first'), findsOneWidget);
  });

  testWidgets('shows an explicit exit control and returns to the previous page', (tester) async {
    final song = makeSong('exit', 'Exit test', 'All lyrics');
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => StageModePage(song: song)),
              ),
              child: const Text('Open stage'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open stage'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Выйти из режима сцены'), findsOneWidget);

    await tester.tap(find.byTooltip('Выйти из режима сцены'));
    await tester.pumpAndSettle();
    expect(find.text('Open stage'), findsOneWidget);
    expect(find.byType(StageModePage), findsNothing);
  });

  testWidgets('keeps a long lyric phrase fully visible without horizontal panning', (tester) async {
    const longLine =
        'ОченьдлиннаястрокаКотораяДолжнаПолностьюПомещатьсяНаЭкранеБезПрокрутки';
    final song = makeSong('long-line', 'Long line', longLine);

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: StageModePage(song: song)));

    expect(find.byType(FittedBox), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    final fitted = tester.widget<FittedBox>(find.byType(FittedBox));
    expect(fitted.fit, BoxFit.scaleDown);

    final rendered = tester.widget<RichText>(lyricText(longLine));
    expect(rendered.softWrap, isFalse);
    expect(rendered.maxLines, 1);
    expect(rendered.text.toPlainText(), longLine);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adapts stage typography for phone and desktop widths', (tester) async {
    final song = makeSong('responsive', 'Responsive', 'Responsive lyric line');

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: StageModePage(song: song)));
    var richText = tester.widget<RichText>(lyricText('Responsive'));
    expect(_firstExplicitFontSize(richText.text), 28);

    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpWidget(MaterialApp(home: StageModePage(song: song)));
    richText = tester.widget<RichText>(lyricText('Responsive'));
    expect(_firstExplicitFontSize(richText.text), 34);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stage mode works on a phone-sized screen', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final first = makeSong('one', 'First track', 'First lyrics');
    final second = makeSong('two', 'Second track', 'Second lyrics');
    await tester.pumpWidget(MaterialApp(
      home: StageModePage(
        song: first,
        queue: [StageModeTrack(song: first), StageModeTrack(song: second)],
      ),
    ));

    expect(lyricText('First'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Следующая песня'));
    await tester.pumpAndSettle();
    expect(lyricText('Second'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
