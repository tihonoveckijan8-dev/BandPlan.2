import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/group_event.dart';

/// Uses the verified JSONB contract and preserves unknown legacy payload fields.
class EventRepository {
  const EventRepository(this._client);
  final SupabaseClient _client;
  Future<List<GroupEvent>> getGroupEvents(String groupId) async {
    final rows = await _client.from('bandplan_events').select('data').eq('group_id', groupId);
    return rows.map((row) => row['data']).whereType<Map>()
      .map((data) => GroupEvent.fromJson(Map<String, dynamic>.from(data))).toList(growable: false);
  }
  Future<void> saveGroupEvent(String groupId, GroupEvent event) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Требуется авторизация.');
    await _client.from('bandplan_events').upsert({
      'group_id': groupId, 'id': event.id, 'data': event.toLegacyJson(), 'updated_by': user.id,
    }, onConflict: 'group_id,id');
  }
  Future<void> deleteGroupEvent(String groupId, String eventId) async {
    await _client.from('bandplan_events').delete().eq('group_id', groupId).eq('id', eventId);
  }
}