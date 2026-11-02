import 'package:flutter_test/flutter_test.dart';
import 'package:bandplan/features/profile/data/profile_repository.dart';

void main() {
  group('AccountProfile.fromJson', () {
    test('parses profile fields and trims empty roles', () {
      final profile = AccountProfile.fromJson({
        'user_id': 'user-1',
        'display_name': 'Alex',
        'roles': ['Вокал', ' гитара ', ''],
      });

      expect(profile.userId, 'user-1');
      expect(profile.displayName, 'Alex');
      expect(profile.roles, ['Вокал', 'гитара']);
    });

    test('uses empty roles when legacy data is not an array', () {
      final profile = AccountProfile.fromJson({
        'user_id': 'user-2',
        'display_name': 'Sam',
        'roles': 'Вокал',
      });

      expect(profile.roles, isEmpty);
    });

    test('handles missing nullable fields', () {
      final profile = AccountProfile.fromJson({'user_id': 'user-3'});

      expect(profile.displayName, isEmpty);
      expect(profile.roles, isEmpty);
    });
  });
}
