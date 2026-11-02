import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin adapter over the existing BandPlan group RPC contract.
class GroupRepository {
  const GroupRepository(this._client);

  final SupabaseClient _client;

  Future<dynamic> getMyGroups() => _client.rpc('bandplan_get_my_groups');

  Future<dynamic> getMyGroup() => _client.rpc('bandplan_get_my_group');

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
