import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local/network_error.dart';
import '../../../core/local/offline_store.dart';
import '../../../core/local/offline_sync_engine.dart';
import '../domain/setlist.dart';

class SetlistRepository {
  const SetlistRepository(this._client, {OfflineStore? offlineStore, OfflineSyncEngine? syncEngine})
      : _offlineStore = offlineStore, _syncEngine = syncEngine;
  final SupabaseClient _client;
  final OfflineStore? _offlineStore;
  final OfflineSyncEngine? _syncEngine;

  Future<List<Setlist>> getGroupSetlists(String groupId) async {
    final rows = await _client.from('bandplan_setlists').select('data').eq('group_id', groupId);
    return rows.map((row) => row['data']).whereType<Map>()
        .map((data) => Setlist.fromJson(Map<String, dynamic>.from(data))).toList(growable: false);
  }

  /// Refreshes the setlist snapshot for startup cache warmup.
  Future<void> refreshAndCacheGroupSetlists(String userId, String groupId) async {
    final remote = await getGroupSetlists(groupId);
    await _cacheSetlists(userId, groupId, remote);
  }

  Stream<List<Setlist>> watchGroupSetlists(String userId, String groupId) {
    late final StreamController<List<Setlist>> controller;
    RealtimeChannel? channel;
    var refreshing = false;
    var refreshAgain = false;

    Future<void> refresh() async {
      if (refreshing) {
        refreshAgain = true;
        return;
      }
      refreshing = true;
      try {
        do {
          refreshAgain = false;
          final remote = await getGroupSetlists(groupId);
          await _cacheSetlists(userId, groupId, remote);
          if (!controller.isClosed) {
            controller.add(await _readCachedSetlists(userId, groupId));
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

    controller = StreamController<List<Setlist>>(
      onListen: () async {
        try {
          if (_offlineStore != null) {
            controller.add(await _readCachedSetlists(userId, groupId));
          }
        } catch (error, stackTrace) {
          controller.addError(error, stackTrace);
        }

        // WHY: Realtime is an invalidation signal only. Re-fetching a complete
        // snapshot keeps RLS and repository parsing authoritative, while the
        // local store protects unsynced rows and delete tombstones.
        channel = _client
            .channel('bandplan:group_setlists:$userId:$groupId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'bandplan_setlists',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'group_id',
                value: groupId,
              ),
              callback: (_) => unawaited(refresh()),
            )
            .subscribe();

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

  Future<SyncReport> saveGroupSetlist(String groupId, Setlist setlist) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Требуется авторизация.');
    final store = _offlineStore;
    if (store == null) {
      await _client.from('bandplan_setlists').upsert({
        'group_id': groupId, 'id': setlist.id, 'data': setlist.toLegacyJson(), 'updated_by': user.id,
      }, onConflict: 'group_id,id').select('id').single();
      return const SyncReport();
    }
    final operationId = _operationId(user.id, setlist.id);
    await store.saveAndQueue(
      operationId: operationId, ownerUserId: user.id,
      groupId: groupId, collection: 'group_setlists', recordId: setlist.id,
      payload: Map<String, Object?>.from(setlist.toLegacyJson()),
    );
    // WHY: unrelated failed records must not make this setlist look unsaved.
    return _syncEngine?.syncMutation(
          operationId: operationId,
          force: true,
          retryFailed: true,
        ) ??
        const SyncReport(pendingCount: 1);
  }

  Future<SyncReport> deleteGroupSetlist(String groupId, String setlistId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Требуется авторизация.');
    final store = _offlineStore;
    if (store == null) {
      final deleted = await _client.from('bandplan_setlists').delete()
          .eq('group_id', groupId).eq('id', setlistId).select('id');
      if (deleted.isEmpty) throw StateError('Сет-лист не найден или нет прав на его удаление.');
      return const SyncReport();
    }
    await store.saveAndQueue(
      operationId: _operationId(user.id, setlistId, suffix: 'delete'),
      ownerUserId: user.id, groupId: groupId, collection: 'group_setlists',
      recordId: setlistId, payload: const {}, operation: 'delete',
    );
    // WHY: each setlist mutation retries earlier failed outbox writes.
    return _syncEngine?.syncPending(force: true, retryFailed: true) ?? const SyncReport(pendingCount: 1);
  }

  Future<List<Setlist>> _readCachedSetlists(String userId, String groupId) async {
    final rows = await _offlineStore?.readCachedRecords(
      ownerUserId: userId, collection: 'group_setlists', groupId: groupId,
    );
    return (rows ?? const []).map((row) => row['payload']).whereType<Map>()
        .map((payload) => Setlist.fromJson(Map<String, dynamic>.from(payload))).toList(growable: false);
  }

  Future<void> _cacheSetlists(String userId, String groupId, List<Setlist> setlists) async {
    await _offlineStore?.replaceRemoteRecords(
      ownerUserId: userId, collection: 'group_setlists', groupId: groupId,
      records: setlists.map((setlist) => <String, Object?>{
        'recordId': setlist.id, 'payload': setlist.toLegacyJson(),
      }).toList(growable: false),
    );
  }

  String _operationId(String userId, String id, {String suffix = 'upsert'}) =>
      '${userId}:group_setlists:${id}:${suffix}:${DateTime.now().microsecondsSinceEpoch}';
}
