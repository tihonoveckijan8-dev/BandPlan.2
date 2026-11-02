import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bandplan/features/setlists/domain/setlist.dart';
import 'package:bandplan/features/setlists/presentation/setlist_run_page.dart';
import 'package:bandplan/features/songs/domain/song.dart';

void main() {
  testWidgets('executes songs in order and applies item shift without changing source song', (tester) async {
    final setlist = Setlist.fromJson({
      'id': 'set-1',
      'name': 'Sunday set',
      'items': [
        {'id': 'item-1', 'songId': 'song-1', 'shift': 1, 'note': 'Start after intro'},
        {'id': 'item-2', 'songId': 'song-2', 'shift': 0, 'note': ''},
      ],
    });
    final firstSong = Song.fromJson({
      'id': 'song-1',
      'title': 'First song',
      'key': 'Am',
      'lyrics': '[Am]First line',
    });
    final secondSong = Song.fromJson({
      'id': 'song-2',
      'title': 'Second song',
      'key': 'C',
      'lyrics': 'Second lyrics',
    });

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => SetlistRunPage(
                    setlist: setlist,
                    songs: [firstSong, secondSong],
                  ),
                ),
              ),
              child: const Text('Open setlist'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open setlist'));
    await tester.pumpAndSettle();

    expect(find.text('First song'), findsOneWidget);
    expect(find.text('Тональность: A#m'), findsOneWidget);
    expect(find.text('Start after intro'), findsOneWidget);
    expect(find.text('[A#m]First line'), findsOneWidget);
    expect(firstSong.key, 'Am');
    expect(firstSong.lyrics, '[Am]First line');

    await tester.tap(find.text('Следующая'));
    await tester.pumpAndSettle();

    expect(find.text('Second song'), findsOneWidget);
    expect(find.text('Second lyrics'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.tap(find.text('Завершить'));
    await tester.pumpAndSettle();
    expect(find.text('Open setlist'), findsOneWidget);
  });

  testWidgets('shows a clear fallback when a referenced song is missing', (tester) async {
    final setlist = Setlist.fromJson({
      'id': 'set-missing',
      'name': 'Missing song set',
      'items': [{'id': 'item-1', 'songId': 'deleted-song'}],
    });

    await tester.pumpWidget(MaterialApp(
      home: SetlistRunPage(setlist: setlist, songs: const []),
    ));

    expect(find.text('Песня не найдена'), findsOneWidget);
    expect(find.text('Эта песня больше не доступна в репертуаре группы.'), findsOneWidget);
  });

  testWidgets('opens stage mode on the selected track when earlier setlist songs are missing', (tester) async {
    final setlist = Setlist.fromJson({
      'id': 'set-gap',
      'name': 'Set with missing song',
      'items': [
        {'id': 'item-1', 'songId': 'song-1'},
        {'id': 'item-missing', 'songId': 'deleted-song'},
        {'id': 'item-2', 'songId': 'song-2'},
        {'id': 'item-3', 'songId': 'song-3'},
      ],
    });
    Song makeSong(String id, String title) => Song.fromJson({
          'id': id,
          'title': title,
          'key': 'C',
          'lyrics': '$title lyrics',
        });

    await tester.pumpWidget(MaterialApp(
      home: SetlistRunPage(
        setlist: setlist,
        songs: [
          makeSong('song-1', 'First song'),
          makeSong('song-2', 'Selected song'),
          makeSong('song-3', 'Following song'),
        ],
      ),
    ));

    await tester.tap(find.text('Следующая'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Следующая'));
    await tester.pumpAndSettle();

    expect(find.text('Selected song'), findsOneWidget);
    await tester.tap(find.byTooltip('Сценический режим'));
    await tester.pumpAndSettle();

    expect(find.text('Selected'), findsOneWidget);
    expect(find.text('song'), findsWidgets);
    expect(find.text('lyrics'), findsOneWidget);
    expect(find.text('Following'), findsNothing);
  });

}
