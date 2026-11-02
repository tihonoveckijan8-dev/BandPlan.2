import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/song.dart';

/// Reads existing BandPlan song records without converting their JSON payloads.
class SongRepository {
  const SongRepository(this._client);

  final SupabaseClient _client;

  Future<List<Song>> getGroupSongs(String groupId) async {
    final rows = await _client
        .from('bandplan_songs')
        .select('data')
        .eq('group_id', groupId);

    return rows
        .map((row) => row['data'])
        .whereType<Map>()
        .map((data) => Song.fromJson(Map<String, dynamic>.from(data)))
        .toList(growable: false);
  }

  Future<List<Song>> getPersonalSongs() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Требуется авторизация.');

    final row = await _client
        .from('bandplan_user_state')
        .select('state')
        .eq('user_id', user.id)
        .maybeSingle();

    final state = row?['state'];
    if (state is! Map) return const [];
    final songs = state['personalSongs'];
    if (songs is! List) return const [];

    return songs
        .whereType<Map>()
        .map((data) => Song.fromJson(Map<String, dynamic>.from(data)))
        .toList(growable: false);
  }
}
