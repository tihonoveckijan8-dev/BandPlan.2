import 'package:flutter_test/flutter_test.dart';
import 'package:bandplan/features/setlists/domain/setlist.dart';

void main() {
  group('Setlist', () {
    test('keeps unknown setlist and item fields when edited', () {
      final setlist = Setlist.fromJson({
        'id': 'sl-1',
        'name': 'Old name',
        'note': 'Note',
        'eventId': 'event-old',
        'customFlag': true,
        'items': [
          {'id': 'item-1', 'songId': 'song-1', 'shift': -2, 'note': 'Intro', 'customItem': 42},
        ],
      });

      final edited = setlist.withEdits(
        name: 'New name',
        note: 'Updated',
        items: [setlist.items.single.withEdits(shift: 1)],
        eventId: 'event-new',
      );

      expect(edited.toLegacyJson()['customFlag'], isTrue);
      expect(edited.eventId, 'event-new');
      final item = (edited.toLegacyJson()['items'] as List).single as Map;
      expect(item['customItem'], 42);
      expect(item['shift'], 1);
      expect(item['note'], 'Intro');
    });

    test('preserves existing event link when eventId is omitted from partial edit', () {
      final setlist = Setlist.fromJson({
        'id': 'sl-linked',
        'name': 'Program',
        'eventId': 'event-keep',
        'items': [{'id': 'item-1', 'songId': 'song-1'}],
      });

      final edited = setlist.withEdits(
        name: 'Renamed program',
        note: 'Updated note',
        items: setlist.items,
      );

      expect(edited.eventId, 'event-keep');
      expect(edited.toLegacyJson()['eventId'], 'event-keep');
    });

    test('clears event link only when an empty eventId is explicitly passed', () {
      final setlist = Setlist.fromJson({
        'id': 'sl-unlink',
        'name': 'Program',
        'eventId': 'event-old',
      });

      final edited = setlist.withEdits(
        name: setlist.name,
        note: setlist.note,
        items: setlist.items,
        eventId: '',
      );

      expect(edited.eventId, isEmpty);
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
