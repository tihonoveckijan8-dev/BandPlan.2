import 'package:flutter_test/flutter_test.dart';
import 'package:bandplan/features/setlists/domain/setlist.dart';

void main() {
  group('Setlist', () {
    test('keeps unknown setlist and item fields when edited', () {
      final setlist = Setlist.fromJson({
        'id': 'sl-1',
        'name': 'Old name',
        'note': 'Note',
        'customFlag': true,
        'items': [
          {'id': 'item-1', 'songId': 'song-1', 'shift': -2, 'note': 'Intro', 'customItem': 42},
        ],
      });

      final edited = setlist.withEdits(
        name: 'New name',
        note: 'Updated',
        items: [setlist.items.single.withEdits(shift: 1)],
      );

      expect(edited.toLegacyJson()['customFlag'], isTrue);
      final item = (edited.toLegacyJson()['items'] as List).single as Map;
      expect(item['customItem'], 42);
      expect(item['shift'], 1);
      expect(item['note'], 'Intro');
    });

    test('preserves item order and unresolved song references', () {
      final setlist = Setlist.fromJson({
        'id': 'sl-2',
        'items': [
          {'id': 'a', 'songId': 'missing-song'},
          {'id': 'b', 'songId': 'song-b'},
        ],
      });
      final edited = setlist.withEdits(
        name: 'Program',
        note: '',
        items: [setlist.items[1], setlist.items[0]],
      );

      final items = edited.toLegacyJson()['items'] as List;
      expect((items[0] as Map)['songId'], 'song-b');
      expect((items[1] as Map)['songId'], 'missing-song');
    });

    test('requires a setlist id', () {
      expect(() => Setlist.fromJson({'name': 'No id'}), throwsFormatException);
    });
  });
}
