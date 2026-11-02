import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bandplan/features/songs/domain/song.dart';
import 'package:bandplan/features/stage/presentation/stage_mode_page.dart';

void main() {
  Song makeSong() => Song.fromJson({
        'id': 'song-1',
        'title': 'Stage song',
        'artist': 'Band',
        'key': 'Am',
        'bpm': 96,
        'lyrics': '[Am]First line\n[Куплет]\nSecond line',
      });

  testWidgets('shows song details and hides chord tokens while keeping section labels', (tester) async {
    await tester.pumpWidget(MaterialApp(home: StageModePage(song: makeSong())));

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

    await tester.pumpWidget(MaterialApp(home: StageModePage(song: makeSong())));
    expect(find.text('30 px'), findsOneWidget);
    expect(find.text('Автопрокрутка'), findsOneWidget);

    await tester.tap(find.byTooltip('Увеличить текст'));
    await tester.pump();
    expect(find.text('32 px'), findsOneWidget);

    await tester.tap(find.text('Автопрокрутка'));
    await tester.pump();
    expect(find.text('Пауза'), findsOneWidget);

    await tester.tap(find.text('Пауза'));
    await tester.pump();
    expect(find.text('Автопрокрутка'), findsOneWidget);
  });
}
