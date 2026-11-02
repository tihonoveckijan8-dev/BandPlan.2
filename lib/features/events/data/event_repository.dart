import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/group_event.dart';

/// Uses the verified JSONB contract and preserves unknown legacy payload fields.
class EventRepository {
  const EventRepository(this._client);

  final SupabaseClient _client;

  Future<List<GroupEvent>> getGroupEvents(String groupId) async {
    final rows = await _client
        .from('bandplan_events')
        .select('data')
        .eq('group_id', groupId);

    return rows
        .map((row) => row['data'])
        .whereType<Map>()
        .map((data) => GroupEvent.fromJson(Map<String, dynamic>.from(data)))
        .toList(growable: false);
  }

  Future<void> saveGroupEvent(String groupId, GroupEvent event) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Требуется авторизация.');

    // WHY: require the persisted row so a blocked write is reported to the editor.
    await _client
        .from('bandplan_events')
        .upsert(
          {
            'group_id': groupId,
            'id': event.id,
            'data': event.toLegacyJson(),
            'updated_by': user.id,
          },
          onConflict: 'group_id,id',
        )
        .select('id')
        .single();
  }

  Future<void> deleteGroupEvent(String groupId, String eventId) async {
    // WHY: an empty delete result means the event was not removed (for example, RLS denied it).
    final deleted = await _client
        .from('bandplan_events')
        .delete()
        .eq('group_id', groupId)
        .eq('id', eventId)
        .select('id');
    if (deleted.isEmpty) {
      throw StateError('Событие не найдено или нет прав на его удаление.');
    }
  }
}
