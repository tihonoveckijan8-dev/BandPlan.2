import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local/network_error.dart';
import '../../../core/local/offline_store.dart';
import '../../../core/local/offline_sync_engine.dart';
import '../../../core/local/user_state_repository.dart';

class AccountProfile {
  const AccountProfile({
    required this.userId,
    required this.displayName,
    required this.roles,
    this.updatedAt,
  });
  final String userId;
  final String displayName;
  final List<String> roles;
  final String? updatedAt;

  factory AccountProfile.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'];
    final roles = rawRoles is List
        ? rawRoles.map((role) => role.toString().trim()).where((role) => role.isNotEmpty).toList(growable: false)
        : const <String>[];
    return AccountProfile(
      userId: json['user_id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      roles: roles,
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, Object?> toJson() => {
        'user_id': userId,
        'display_name': displayName,
        'roles': roles,
        if (updatedAt != null) 'updated_at': updatedAt,
      };
}

class ProfileRepository {
  const ProfileRepository(this._client, {OfflineStore? offlineStore, OfflineSyncEngine? syncEngine})
      : _offlineStore = offlineStore, _syncEngine = syncEngine;
  final SupabaseClient _client;
  final OfflineStore? _offlineStore;
  final OfflineSyncEngine? _syncEngine;

  Future<AccountProfile> getMyProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Требуется авторизация.');
    try {
      final row = await _client.from('bandplan_accounts')
          .select('user_id, display_name, roles, updated_at').eq('user_id', user.id).maybeSingle();
      final account = row == null
          ? AccountProfile(userId: user.id, displayName: user.email?.split('@').first ?? '', roles: const [])
          : AccountProfile.fromJson(row);

      // WHY: bandplan_accounts is intentionally read-only for authenticated
      // clients. Personal edits live in the owner's existing private state row.
      final state = await _stateRepository().readState();
      final rawProfile = state['profile'];
      final personal = rawProfile is Map
          ? Map<String, Object?>.from(rawProfile)
          : <String, Object?>{};
      final rawRoles = personal['roles'];
      final personalRoles = rawRoles is List
          ? rawRoles.map((role) => role.toString().trim()).where((role) => role.isNotEmpty).toList(growable: false)
          : (personal['role']?.toString().trim().isNotEmpty == true
              ? <String>[personal['role'].toString().trim()]
              : account.roles);
      final personalName = personal['name']?.toString().trim();
      final profile = AccountProfile(
        userId: user.id,
        displayName: personalName == null || personalName.isEmpty
            ? account.displayName
            : personalName,
        roles: personalRoles,
        updatedAt: row?['updated_at']?.toString(),
      );
      await _cacheProfile(profile);
      return profile;
    } catch (error) {
      if (!isOfflineNetworkError(error)) rethrow;
      final cached = await _offlineStore?.readCachedRecords(ownerUserId: user.id, collection: 'profile');
      if (cached == null || cached.isEmpty || cached.first['payload'] is! Map) rethrow;
      return AccountProfile.fromJson(Map<String, dynamic>.from(cached.first['payload'] as Map));
    }
  }

  /// Caches a profile only when the account row is confirmed by Supabase.
  Future<void> refreshAndCacheConfirmedProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final row = await _client.from('bandplan_accounts')
        .select('user_id, display_name, roles, updated_at')
        .eq('user_id', user.id)
        .maybeSingle();
    // WHY: A synthetic empty profile for a new account must not be mistaken
    // for proof that onboarding has already been completed while offline.
    if (row == null) return;
    await _cacheProfile(AccountProfile.fromJson(row));
  }

  Future<SyncReport> saveMyProfile({required String displayName, required List<String> roles}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Требуется авторизация.');

    final stateRepository = _stateRepository();
    final state = await stateRepository.readState();
    final rawProfile = state['profile'];
    final personal = rawProfile is Map
        ? Map<String, Object?>.from(rawProfile)
        : <String, Object?>{};
    // WHY: Merge only the edited fields; legacy profile keys such as
    // defaultParticipation and unknown future values must survive.
    personal['name'] = displayName.trim();
    personal['roles'] = roles;
    if (roles.isEmpty) {
      personal.remove('role');
    } else {
      personal['role'] = roles.first;
    }
    state['profile'] = personal;

    final report = await stateRepository.saveState(state);
    await _cacheProfile(AccountProfile(
      userId: user.id,
      displayName: displayName.trim(),
      roles: roles,
    ));
    return report;
  }

  UserStateRepository _stateRepository() {
    final store = _offlineStore;
    final syncEngine = _syncEngine;
    if (store == null || syncEngine == null) {
      throw StateError('Хранилище профиля не инициализировано.');
    }
    return UserStateRepository(
      client: _client,
      store: store,
      syncEngine: syncEngine,
    );
  }

  Future<void> _cacheProfile(AccountProfile profile) async {
    await _offlineStore?.cacheRemoteRecord(
      ownerUserId: profile.userId, collection: 'profile', recordId: 'profile', payload: profile.toJson(),
    );
  }
}
