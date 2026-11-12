import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local/network_error.dart';
import '../../../core/local/offline_store.dart';
import '../../../core/local/offline_sync_engine.dart';
import '../domain/song.dart';

class SongRepository {
  const SongRepository(this._client, {OfflineStore? offlineStore, OfflineSyncEngine? syncEngine})
      : _offlineStore = offlineStore, _syncEngine = syncEngine;
  final SupabaseClient _client;
  final OfflineStore? _offlineStore;
  final OfflineSyncEngine? _syncEngine;

  Future<List<Song>> getGroupSongs(String groupId) async {
    final rows = await _client.from('bandplan_songs').select('data').eq('group_id', groupId);
    return rows.map((row) => row['data']).whereType<Map>()
        .map((data) => Song.fromJson(Map<String, dynamic>.from(data))).toList(growable: false);
  }

  Stream<List<Song>> watchGroupSongs(String userId, String groupId) {
    late final StreamController<List<Song>> controller;
    RealtimeChannel? channel;
    var refreshing = false;
    var refreshAgain = false;
    var hasConnectedOnce = false;

    Future<void> refresh() async {
      if (refreshing) {
        refreshAgain = true;
        return;
      }
      refreshing = true;
      try {
        do {
          refreshAgain = false;
          final remote = await getGroupSongs(groupId);
          await _cacheSongs(userId, 'group_songs', remote, groupId);
          if (!controller.isClosed) {
            controller.add(await _readCachedSongs(userId, 'group_songs', groupId));
          }
        } while (refreshAgain && !controller.isClosed);
      } catch (error, stackTrace) {
        // WHY: keep the last confirmed local snapshot visible during transport
        // failures; surface authorization/schema errors instead of hiding them.
        if (!isOfflineNetworkError(error) && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      } finally {
        refreshing = false;
      }
    }

    controller = StreamController<List<Song>>(
      onListen: () async {
        try {
          if (_offlineStore != null) {
            controller.add(await _readCachedSongs(userId, 'group_songs', groupId));
          }
        } catch (error, stackTrace) {
          controller.addError(error, stackTrace);
        }

        // WHY: Realtime is an invalidation signal only. Re-fetching a complete
        // snapshot keeps RLS and repository parsing authoritative, while the
        // local store protects unsynced rows and delete tombstones.
        channel = _client
            .channel('bandplan:group_songs:$userId:$groupId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'bandplan_songs',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'group_id',
                value: groupId,
              ),
              callback: (_) => unawaited(refresh()),
            )
            .subscribe((status, error) {
              if (status == RealtimeSubscribeStatus.subscribed) {
                // WHY: Realtime may reconnect after a network interruption.
                // Refresh a full snapshot after reconnection so changes missed
                // while disconnected are not left stale on this device.
                if (hasConnectedOnce) unawaited(refresh());
                hasConnectedOnce = true;
              }
            });

        await refresh();
      },
      onCancel: () async {
        final activeChannel = channel;
        channel = null;
        if (activeChannel != null) {
          await _client.removeChannel(activeChannel);
        }
      },
    );
    return controller.stream;
  }

  Future<SyncReport> saveGroupSong(String groupId, Song song) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Требуется авторизация.');
    final store = _offlineStore;
    if (store == null) {
      await _client.from('bandplan_songs').upsert({
        'group_id': groupId, 'id': song.id, 'data': song.toLegacyJson(), 'updated_by': user.id,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'group_id,id').select('id').single();
      return const SyncReport();
    }
    await store.saveAndQueue(
      operationId: '${user.id}:group_songs:${song.id}:${DateTime.now().microsecondsSinceEpoch}',
      ownerUserId: user.id, groupId: groupId, collection: 'group_songs',
      recordId: song.id, payload: Map<String, Object?>.from(song.toLegacyJson()),
    );
    // WHY: the latest song edit retries earlier failed outbox writes.
    return _syncEngine?.syncPending(force: true, retryFailed: true) ?? const SyncReport(pendingCount: 1);
  }

  Future<List<Song>> getPersonalSongs() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Требуется авторизация.');
    final row = await _client.from('bandplan_user_state').select('state')
        .eq('user_id', user.id).maybeSingle();
    final state = row?['state'];
    if (state is! Map || state['personalSongs'] is! List) return const [];
    return (state['personalSongs'] as List).whereType<Map>()
        .map((data) => Song.fromJson(Map<String, dynamic>.from(data))).toList(growable: false);
  }

  /// Refreshes the group-song snapshot for startup cache warmup.
  Future<void> refreshAndCacheGroupSongs(String userId, String groupId) async {
    final remote = await getGroupSongs(groupId);
    await _cacheSongs(userId, 'group_songs', remote, groupId);
  }

  /// Refreshes personal songs even when the user has not opened the Songs tab yet.
  Future<void> refreshAndCachePersonalSongs(String userId) async {
    final remote = await getPersonalSongs();
    await _cacheSongs(userId, 'personal_songs', remote, null);
  }

  Stream<List<Song>> watchPersonalSongs(String userId) async* {
    final cached = await _readCachedSongs(userId, 'personal_songs', null);
    yield cached;
    try {
      final remote = await getPersonalSongs();
      await _cacheSongs(userId, 'personal_songs', remote, null);
      yield await _readCachedSongs(userId, 'personal_songs', null);
    } catch (error) {
      // WHY: an empty personal-song cache is a valid empty state, not a reason
      // to fail the screen while offline; the cached snapshot was already emitted.
      if (!isOfflineNetworkError(error)) rethrow;
    }
  }

  Future<List<Song>> _readCachedSongs(String userId, String collection, String? groupId) async {
    final rows = await _offlineStore?.readCachedRecords(
      ownerUserId: userId, collection: collection, groupId: groupId,
    );
    return (rows ?? const []).map((row) => row['payload']).whereType<Map>()
        .map((payload) => Song.fromJson(Map<String, dynamic>.from(payload))).toList(growable: false);
  }

  Future<void> _cacheSongs(String userId, String collection, List<Song> songs, String? groupId) async {
    await _offlineStore?.replaceRemoteRecords(
      ownerUserId: userId, collection: collection, groupId: groupId,
      records: songs.map((song) => <String, Object?>{
        'recordId': song.id, 'payload': song.toLegacyJson(),
      }).toList(growable: false),
    );
  }
}
