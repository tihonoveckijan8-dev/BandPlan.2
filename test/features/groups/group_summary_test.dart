import 'package:flutter_test/flutter_test.dart';
import 'package:bandplan/features/groups/domain/group_summary.dart';

void main() {
  group('GroupSummary.fromJson', () {
    test('parses the current group RPC field names', () {
      final group = GroupSummary.fromJson({
        'group_id': 'group-1',
        'group_name': 'Sunday Band',
        'owner_id': 'user-1',
        'joined_at': '2026-10-01T12:30:00Z',
        'role': 'owner',
      });

      expect(group.id, 'group-1');
      expect(group.name, 'Sunday Band');
      expect(group.ownerId, 'user-1');
      expect(group.joinedAt, DateTime.parse('2026-10-01T12:30:00Z'));
      expect(group.isOwner, isTrue);
    });

    test('accepts legacy id and name field names', () {
      final group = GroupSummary.fromJson({
        'id': 'legacy-group',
        'name': 'Legacy Band',
        'role': 'member',
      });

      expect(group.id, 'legacy-group');
      expect(group.name, 'Legacy Band');
      expect(group.isOwner, isFalse);
      expect(group.joinedAt, isNull);
    });

    test('rejects a response without a group id or name', () {
      expect(
        () => GroupSummary.fromJson({'group_id': 'group-1'}),
        throwsFormatException,
      );
      expect(
        () => GroupSummary.fromJson({'group_name': 'No id'}),
        throwsFormatException,
      );
    });

    test('does not treat malformed optional joined_at as a valid date', () {
      final group = GroupSummary.fromJson({
        'group_id': 'group-1',
        'group_name': 'Sunday Band',
        'joined_at': 'not-a-date',
      });

      expect(group.joinedAt, isNull);
    });
  });
}
