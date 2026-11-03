import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local/network_error.dart';
import '../../../core/local/offline_store.dart';
import '../domain/song.dart';

/// Reads existing BandPlan song records without converting their JSON payloads.
class SongRepository {
  const SongRepository(this._client, {OfflineStore? offlineStore})
      : _offlineStore = offlineStore;

  final SupabaseClient _client;
  final OfflineStore? _offlineStore;

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

  /// Emits cached songs immediately, then reconciles them with the server.
  Stream<List<Song>> watchGroupSongs(String userId, String groupId) async* {
    final cached = await _readCachedSongs(userId, 'group_songs', groupId);
    yield cached;
    try {
      final remote = await getGroupSongs(groupId);
      await _cacheSongs(userId, 'group_songs', remote, groupId);
      yield remote;
    } catch (error) {
      if (!isOfflineNetworkError(error) || cached.isEmpty) rethrow;
    }
  }

  /// Writes one group song using the existing RLS-protected table contract.
  /// The original JSON payload is retained, including chord/dynamics metadata.
  Future<void> saveGroupSong(String groupId, Song song) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Требуется авторизация.');

    // WHY: request the saved row so RLS/permission failures cannot look like a successful save.
    await _client
        .from('bandplan_songs')
        .upsert(
          {
            'group_id': groupId,
            'id': song.id,
            'data': song.toLegacyJson(),
            'updated_by': user.id,
          },
          onConflict: 'group_id,id',
        )
        .select('id')
        .single();
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

  Stream<List<Song>> watchPersonalSongs(String userId) async* {
    final cached = await _readCachedSongs(userId, 'personal_songs', null);
    yield cached;
    try {
      final remote = await getPersonalSongs();
      await _cacheSongs(userId, 'personal_songs', remote, null);
      yield remote;
    } catch (error) {
      if (!isOfflineNetworkError(error) || cached.isEmpty) rethrow;
    }
  }

  Future<List<Song>> _readCachedSongs(
    String userId,
    String collection,
    String? groupId,
  ) async {
    final store = _offlineStore;
    if (store == null) return const [];
    final rows = await store.readCachedRecords(
      ownerUserId: userId,
      collection: collection,
      groupId: groupId,
    );
    return rows
        .map((row) => row['payload'])
        .whereType<Map>()
        .map((payload) => Song.fromJson(Map<String, dynamic>.from(payload)))
        .toList(growable: false);
  }

  Future<void> _cacheSongs(
    String userId,
    String collection,
    List<Song> songs,
    String? groupId,
  ) async {
    await _offlineStore?.replaceRemoteRecords(
      ownerUserId: userId,
      collection: collection,
      groupId: groupId,
      records: songs
          .map((song) => <String, Object?>{
                'recordId': song.id,
                'payload': song.toLegacyJson(),
              })
          .toList(growable: false),
    );
  }
}
