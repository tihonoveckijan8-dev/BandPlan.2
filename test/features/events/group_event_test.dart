import 'package:flutter_test/flutter_test.dart';
import 'package:bandplan/features/events/domain/group_event.dart';

void main() {
  test('reads legacy event fields and preserves unknown payload fields', () {
    final event = GroupEvent.fromJson({
      'id': 'event-1',
      'title': 'Sunday service',
      'date': '2026-11-08',
      'time': '10:00',
      'setlistId': 'setlist-1',
      'customField': {'keep': true},
    });

    expect(event.id, 'event-1');
    expect(event.title, 'Sunday service');
    expect(event.setlistId, 'setlist-1');
    expect(event.toLegacyJson()['customField'], {'keep': true});
  });

  test('rejects event payloads without an id', () {
    expect(() => GroupEvent.fromJson({'title': 'Missing id'}), throwsFormatException);
  });
}
