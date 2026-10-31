import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin adapter over the existing BandPlan group RPC contract.
///
/// RPC responses are kept dynamic here because the legacy functions return
/// JSON whose exact envelope varies by operation. Parsing belongs in models.
class GroupRepository {
  const GroupRepository(this._client);

  final SupabaseClient _client;

  Future<dynamic> getMyGroups() =>
      _client.rpc('bandplan_get_my_groups');

  Future<dynamic> getMyGroup() =>
      _client.rpc('bandplan_get_my_group');

  Future<void> setActiveGroup(String groupId) async {
    await _client.rpc(
      'bandplan_set_active_group',
      params: {'p_group_id': groupId},
    );
  }

  Future<dynamic> createGroup({
    required String name,
    required String displayName,
    required List<String> roles,
  }) {
    return _client.rpc(
      'bandplan_create_group',
      params: {
        'p_name': name,
        'p_display_name': displayName,
        'p_roles': roles,
      },
    );
  }

  Future<dynamic> joinGroup({
    required String inviteCode,
    required String displayName,
    required List<String> roles,
  }) {
    return _client.rpc(
      'bandplan_join_group',
      params: {
        'p_code': inviteCode,
        'p_display_name': displayName,
        'p_roles': roles,
      },
    );
  }

  /// This RPC may create a group and invite when the user has no group.
  /// Call only after an explicit user action to obtain an invite.
  Future<dynamic> getOrCreateInviteCode() =>
      _client.rpc('bandplan_get_invite_code');

  Future<void> leaveGroup(String groupId) async {
    await _client.rpc(
      'bandplan_leave_group',
      params: {'p_group_id': groupId},
    );
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
}
