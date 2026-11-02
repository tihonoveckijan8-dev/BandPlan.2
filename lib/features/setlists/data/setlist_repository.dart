import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/setlist.dart';

/// Group setlists use the verified bandplan_setlists JSONB table contract.
class SetlistRepository {
  const SetlistRepository(this._client);

  final SupabaseClient _client;

  Future<List<Setlist>> getGroupSetlists(String groupId) async {
    final rows = await _client
        .from('bandplan_setlists')
        .select('data')
        .eq('group_id', groupId);

    return rows
        .map((row) => row['data'])
        .whereType<Map>()
        .map((data) => Setlist.fromJson(Map<String, dynamic>.from(data)))
        .toList(growable: false);
  }

  Future<void> saveGroupSetlist(String groupId, Setlist setlist) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Требуется авторизация.');

    // WHY: confirm the upsert returned the saved record before closing the editor.
    await _client
        .from('bandplan_setlists')
        .upsert(
          {
            'group_id': groupId,
            'id': setlist.id,
            'data': setlist.toLegacyJson(),
            'updated_by': user.id,
          },
          onConflict: 'group_id,id',
        )
        .select('id')
        .single();
  }

  Future<void> deleteGroupSetlist(String groupId, String setlistId) async {
    // WHY: don't report a successful removal when no row was actually deleted.
    final deleted = await _client
        .from('bandplan_setlists')
        .delete()
        .eq('group_id', groupId)
        .eq('id', setlistId)
        .select('id');
    if (deleted.isEmpty) {
      throw StateError('Сет-лист не найден или нет прав на его удаление.');
    }
  }
}
