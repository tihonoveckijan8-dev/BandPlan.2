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
      if (cached == null || cached.isEmpty) rethrow;
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
      if (cached == null || cached.isEmpty) rethrow;
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
    final response = await _client.rpc(
      'bandplan_join_group',
      params: {
        'p_code': inviteCode,
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
