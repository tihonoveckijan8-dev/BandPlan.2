import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/group_event.dart';

/// Reads the existing group event JSONB records without rewriting their payload.
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
}
