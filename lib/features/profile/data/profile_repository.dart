import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local/network_error.dart';
import '../../../core/local/offline_store.dart';

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

  Map<String, Object?> toJson() => {
        'user_id': userId,
        'display_name': displayName,
        'roles': roles,
      };
}

class ProfileRepository {
  const ProfileRepository(this._client, {OfflineStore? offlineStore})
      : _offlineStore = offlineStore;

  final SupabaseClient _client;
  final OfflineStore? _offlineStore;

  Future<AccountProfile> getMyProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Требуется авторизация.');

    try {
      final row = await _client
          .from('bandplan_accounts')
          .select('user_id, display_name, roles')
          .eq('user_id', user.id)
          .maybeSingle();

      final profile = row == null
          ? AccountProfile(
              userId: user.id,
              displayName: user.email?.split('@').first ?? '',
              roles: const [],
            )
          : AccountProfile.fromJson(row);
      await _cacheProfile(profile);
      return profile;
    } catch (error) {
      if (!isOfflineNetworkError(error)) rethrow;
      final cached = await _offlineStore?.readCachedRecords(
        ownerUserId: user.id,
        collection: 'profile',
      );
      if (cached == null || cached.isEmpty || cached.first['payload'] is! Map) {
        rethrow;
      }
      return AccountProfile.fromJson(
        Map<String, dynamic>.from(cached.first['payload'] as Map),
      );
    }
  }

  Future<void> saveMyProfile({
    required String displayName,
    required List<String> roles,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Требуется авторизация.');

    final payload = {
      'user_id': user.id,
      'display_name': displayName.trim(),
      'roles': roles,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _client.from('bandplan_accounts').upsert(
      payload,
      onConflict: 'user_id',
    );

    // WHY: only cache profile edits after the existing Supabase write succeeds.
    await _offlineStore?.cacheRemoteRecord(
      ownerUserId: user.id,
      collection: 'profile',
      recordId: 'profile',
      payload: {
        'user_id': user.id,
        'display_name': displayName.trim(),
        'roles': roles,
      },
    );
  }

  Future<void> _cacheProfile(AccountProfile profile) async {
    await _offlineStore?.cacheRemoteRecord(
      ownerUserId: profile.userId,
      collection: 'profile',
      recordId: 'profile',
      payload: profile.toJson(),
    );
  }
}
