import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bandplan/features/songs/domain/song.dart';
import 'package:bandplan/features/stage/presentation/stage_mode_page.dart';

void main() {
  Song makeSong(String id, String title, String key, String lyrics) => Song.fromJson({
        'id': id,
        'title': title,
        'artist': 'Band',
        'key': key,
        'bpm': 96,
        'lyrics': lyrics,
      });

  testWidgets('shows song details and hides chord tokens while keeping section labels', (tester) async {
    final song = makeSong('song-1', 'Stage song', 'Am', '[Am]First line\n[Куплет]\nSecond line');
    await tester.pumpWidget(MaterialApp(home: StageModePage(song: song)));

    expect(find.text('Stage song'), findsOneWidget);
    expect(find.text('Am'), findsOneWidget);
    expect(find.text('96 BPM'), findsOneWidget);
    expect(find.text('[Am]First line\n[Куплет]\nSecond line'), findsOneWidget);

    await tester.tap(find.byTooltip('Скрыть аккорды'));
    await tester.pump();
    expect(find.text('First line\n[Куплет]\nSecond line'), findsOneWidget);
  });

  testWidgets('font and auto-scroll controls respond to user input', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: StageModePage(song: makeSong('song-1', 'Stage song', 'Am', 'Line'))));
    expect(find.text('30 px'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);

    await tester.tap(find.byTooltip('Увеличить текст'));
    await tester.pump();
    expect(find.text('32 px'), findsOneWidget);

    await tester.tap(find.byTooltip('Автопрокрутка'));
    await tester.pump();
    expect(find.byTooltip('Пауза'), findsOneWidget);
    await tester.tap(find.byTooltip('Пауза'));
    await tester.pump();
    expect(find.byTooltip('Автопрокрутка'), findsOneWidget);
  });

  testWidgets('navigates through setlist tracks with each track transpose and note', (tester) async {
    final first = makeSong('one', 'First track', 'Am', '[Am]first lyrics');
    final second = makeSong('two', 'Second track', 'C', '[C]second lyrics');
    await tester.pumpWidget(MaterialApp(
      home: StageModePage(
        song: first,
        queue: [
          StageModeTrack(song: first, semitones: 1, note: 'First note'),
          StageModeTrack(song: second, semitones: -2, note: 'Second note'),
        ],
      ),
    ));

    expect(find.text('A#m'), findsOneWidget);
    expect(find.text('First note'), findsOneWidget);
    expect(find.text('[A#m]first lyrics'), findsOneWidget);

    await tester.tap(find.byTooltip('Следующая песня'));
    await tester.pumpAndSettle();

    expect(find.text('Second track'), findsOneWidget);
    expect(find.text('A#'), findsOneWidget);
    expect(find.text('Second note'), findsOneWidget);
    expect(find.text('[A#]second lyrics'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);

    await tester.tap(find.byTooltip('Предыдущая песня'));
    await tester.pumpAndSettle();
    expect(find.text('First track'), findsOneWidget);
    expect(find.text('First note'), findsOneWidget);
  });
  testWidgets('keeps setlist navigation usable on a phone-sized screen', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final first = makeSong('one', 'First track', 'Am', 'First lyrics');
    final second = makeSong('two', 'Second track', 'C', 'Second lyrics');
    await tester.pumpWidget(MaterialApp(
      home: StageModePage(
        song: first,
        queue: [
          StageModeTrack(song: first),
          StageModeTrack(song: second),
        ],
      ),
    ));

    expect(find.text('Песня 1 из 2'), findsOneWidget);
    expect(find.byTooltip('Предыдущая песня'), findsOneWidget);
    expect(find.byTooltip('Следующая песня'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Следующая песня'));
    await tester.pumpAndSettle();

    expect(find.text('Second track'), findsOneWidget);
    expect(find.text('Песня 2 из 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
