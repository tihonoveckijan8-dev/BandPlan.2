import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local/network_error.dart';
import '../../../core/local/offline_store.dart';

/// Thin adapter over the existing BandPlan group RPC contract.
class GroupRepository {
  const GroupRepository(this._client, {OfflineStore? offlineStore})
      : _offlineStore = offlineStore;

  final SupabaseClient _client;
  final OfflineStore? _offlineStore;

  Future<dynamic> getMyGroups() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Требуется авторизация.');
    try {
      final response = await _client.rpc('bandplan_get_my_groups');
      await _cacheGroups(user.id, response);
      return response;
    } catch (error) {
      if (!isOfflineNetworkError(error)) rethrow;
      final cached = await _offlineStore?.readCachedRecords(
        ownerUserId: user.id,
        collection: 'my_groups',
      );
      // WHY: a missing first-run cache must not turn offline app entry into an error.
      if (cached == null || cached.isEmpty) return const <Map<String, dynamic>>[];
      return cached
          .map((row) => row['payload'])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }
  }

  Future<dynamic> getMyGroup() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Требуется авторизация.');
    try {
      final response = await _client.rpc('bandplan_get_my_group');
      final row = response is List
          ? (response.isEmpty ? null : response.first)
          : response;
      final id = row is Map
          ? (row['group_id'] ?? row['id'])?.toString().trim() ?? ''
          : '';
      await _offlineStore?.replaceRemoteRecords(
        ownerUserId: user.id,
        collection: 'active_group',
        records: id.isEmpty
            ? const []
            : [
                {
                  'recordId': 'active',
                  'payload': Map<String, Object?>.from(row as Map),
                },
              ],
      );
      return response;
    } catch (error) {
      if (!isOfflineNetworkError(error)) rethrow;
      final cached = await _offlineStore?.readCachedRecords(
        ownerUserId: user.id,
        collection: 'active_group',
      );
      // WHY: an account with no cached group should still reach the empty calendar
      // and profile screens; lack of a group is not an app-startup failure.
      if (cached == null || cached.isEmpty) return null;
      return cached.first['payload'];
    }
  }

  Future<void> _cacheGroups(String userId, dynamic response) async {
    if (response is! List) return;
    final records = <Map<String, Object?>>[];
    for (final item in response.whereType<Map>()) {
      final id = (item['group_id'] ?? item['id'])?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      records.add({
        'recordId': id,
        'payload': Map<String, Object?>.from(item),
      });
    }
    await _offlineStore?.replaceRemoteRecords(
      ownerUserId: userId,
      collection: 'my_groups',
      records: records,
    );
  }

  /// Returns the current roster using the canonical membership table.
  /// Profile fields are fetched separately because account directory access is
  /// restricted to members and the membership table stores only user IDs.
  Future<List<Map<String, dynamic>>> getGroupMembers({
    required String groupId,
    String? ownerId,
  }) async {
    final memberships = await _client
        .from('bandplan_group_members')
        .select('user_id, joined_at')
        .eq('group_id', groupId)
        .order('joined_at');

    final rows = List<Map<String, dynamic>>.from(memberships);
    if (rows.isEmpty) return const <Map<String, dynamic>>[];

    final userIds = rows
        .map((row) => row['user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (userIds.isEmpty) return const <Map<String, dynamic>>[];

    final accounts = await _client
        .from('bandplan_accounts')
        .select('user_id, display_name, roles')
        .inFilter('user_id', userIds);
    final accountById = <String, Map<String, dynamic>>{
      for (final account in accounts)
        account['user_id'].toString(): Map<String, dynamic>.from(account),
    };

    return rows.map((membership) {
      final userId = membership['user_id']?.toString() ?? '';
      final account = accountById[userId] ?? const <String, dynamic>{};
      final rawRoles = account['roles'];
      final roles = rawRoles is List
          ? rawRoles.map((role) => role.toString()).toList(growable: false)
          : const <String>[];
      return <String, dynamic>{
        'user_id': userId,
        'display_name': (account['display_name'] ?? '').toString().trim(),
        'roles': roles,
        'joined_at': membership['joined_at'],
        'is_owner': ownerId != null && userId == ownerId,
      };
    }).toList(growable: false);
  }

  Future<void> setActiveGroup(String groupId) async {
    final result = await _client.rpc(
      'bandplan_set_active_group',
      params: {'p_group_id': groupId},
    );
    if (result?.toString() != groupId) {
      throw StateError('Сервер не подтвердил выбор активной группы.');
    }
  }

  Future<void> createGroup({
    required String name,
    required String displayName,
    required List<String> roles,
  }) async {
    final response = await _client.rpc(
      'bandplan_create_group',
      params: {
        'p_name': name,
        'p_display_name': displayName,
        'p_roles': roles,
      },
    );
    _requireGroupRow(response, 'создания группы');
  }

  Future<void> joinGroup({
    required String inviteCode,
    required String displayName,
    required List<String> roles,
  }) async {
    final normalizedCode = inviteCode.trim().toUpperCase();
    final response = await _client.rpc(
      'bandplan_join_group',
      params: {
        'p_code': normalizedCode,
        'p_display_name': displayName,
        'p_roles': roles,
      },
    );
    _requireGroupRow(response, 'вступления в группу');
  }

  /// This RPC may create a group and invite when the user has no group.
  /// Call only after an explicit user action to obtain an invite.
  Future<dynamic> getOrCreateInviteCode() =>
      _client.rpc('bandplan_get_invite_code');

  Future<void> leaveGroup(String groupId) async {
    final response = await _client.rpc(
      'bandplan_leave_group',
      params: {'p_group_id': groupId},
    );
    _requireGroupRow(response, 'выхода из группы');
  }

  Future<void> renameGroup({
    required String groupId,
    required String name,
  }) async {
    await _client.rpc(
      'bandplan_rename_group',
      params: {
        'p_name': name,
        'p_group_id': groupId,
      },
    );
  }

  Map<String, dynamic> _requireGroupRow(dynamic response, String operation) {
    final row = response is List
        ? (response.isEmpty ? null : response.first)
        : response;
    if (row is! Map ||
        (row['group_id'] ?? row['id'])?.toString().trim().isNotEmpty != true) {
      // WHY: a void/empty RPC response must not be mistaken for a completed group action.
      throw FormatException('Сервер не подтвердил $operation.');
    }
    return Map<String, dynamic>.from(row);
  }
}
