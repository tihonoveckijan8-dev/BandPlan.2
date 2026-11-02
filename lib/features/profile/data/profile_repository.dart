import 'package:supabase_flutter/supabase_flutter.dart';

class AccountProfile {
  const AccountProfile({
    required this.userId,
    required this.displayName,
    required this.roles,
  });

  final String userId;
  final String displayName;
  final List<String> roles;

  factory AccountProfile.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'];
    // WHY: tolerate malformed legacy JSON without breaking the whole profile screen.
    final roles = rawRoles is List
        ? rawRoles
            .map((role) => role.toString().trim())
            .where((role) => role.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    return AccountProfile(
      userId: json['user_id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      roles: roles,
    );
  }
}

class ProfileRepository {
  const ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<AccountProfile> getMyProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Требуется авторизация.');

    final row = await _client
        .from('bandplan_accounts')
        .select('user_id, display_name, roles')
        .eq('user_id', user.id)
        .maybeSingle();

    if (row == null) {
      return AccountProfile(
        userId: user.id,
        displayName: user.email?.split('@').first ?? '',
        roles: const [],
      );
    }

    return AccountProfile.fromJson(row);
  }

  Future<void> saveMyProfile({
    required String displayName,
    required List<String> roles,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Требуется авторизация.');

    await _client.from('bandplan_accounts').upsert({
      'user_id': user.id,
      'display_name': displayName.trim(),
      'roles': roles,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }
}
