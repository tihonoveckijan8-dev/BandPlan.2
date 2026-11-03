import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local/network_error.dart';
import '../../../core/local/offline_store.dart';
import '../../../core/local/offline_sync_engine.dart';
import '../domain/group_event.dart';

class EventRepository {
  const EventRepository(this._client, {OfflineStore? offlineStore, OfflineSyncEngine? syncEngine})
      : _offlineStore = offlineStore, _syncEngine = syncEngine;
  final SupabaseClient _client;
  final OfflineStore? _offlineStore;
  final OfflineSyncEngine? _syncEngine;

  Future<List<GroupEvent>> getGroupEvents(String groupId) async {
    final rows = await _client.from('bandplan_events').select('data').eq('group_id', groupId);
    return rows.map((row) => row['data']).whereType<Map>()
        .map((data) => GroupEvent.fromJson(Map<String, dynamic>.from(data))).toList(growable: false);
  }

  /// Refreshes the event snapshot for startup cache warmup.
  Future<void> refreshAndCacheGroupEvents(String userId, String groupId) async {
    final remote = await getGroupEvents(groupId);
    await _cacheEvents(userId, groupId, remote);
  }

  Stream<List<GroupEvent>> watchGroupEvents(String userId, String groupId) {
    late final StreamController<List<GroupEvent>> controller;
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
          final remote = await getGroupEvents(groupId);
          await _cacheEvents(userId, groupId, remote);
          if (!controller.isClosed) {
            controller.add(await _readCachedEvents(userId, groupId));
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

    controller = StreamController<List<GroupEvent>>(
      onListen: () async {
        try {
          if (_offlineStore != null) {
            controller.add(await _readCachedEvents(userId, groupId));
          }
        } catch (error, stackTrace) {
          controller.addError(error, stackTrace);
        }

        // WHY: Realtime is an invalidation signal only. Re-fetching a complete
        // snapshot keeps RLS and repository parsing authoritative, while the
        // local store protects unsynced rows and delete tombstones.
        channel = _client
            .channel('bandplan:group_events:$userId:$groupId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'bandplan_events',
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

  Future<SyncReport> saveGroupEvent(String groupId, GroupEvent event) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Требуется авторизация.');
    final store = _offlineStore;
    if (store == null) {
      await _client.from('bandplan_events').upsert({
        'group_id': groupId, 'id': event.id, 'data': event.toLegacyJson(), 'updated_by': user.id,
      }, onConflict: 'group_id,id').select('id').single();
      return const SyncReport();
    }
    await store.saveAndQueue(
      operationId: _operationId(user.id, event.id), ownerUserId: user.id,
      groupId: groupId, collection: 'group_events', recordId: event.id,
      payload: Map<String, Object?>.from(event.toLegacyJson()),
    );
    return _syncEngine?.syncPending(force: true) ?? const SyncReport(pendingCount: 1);
  }

  Future<SyncReport> deleteGroupEvent(String groupId, String eventId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Требуется авторизация.');
    final store = _offlineStore;
    if (store == null) {
      final deleted = await _client.from('bandplan_events').delete()
          .eq('group_id', groupId).eq('id', eventId).select('id');
      if (deleted.isEmpty) throw StateError('Событие не найдено или нет прав на его удаление.');
      return const SyncReport();
    }
    await store.saveAndQueue(
      operationId: _operationId(user.id, eventId, suffix: 'delete'),
      ownerUserId: user.id, groupId: groupId, collection: 'group_events',
      recordId: eventId, payload: const {}, operation: 'delete',
    );
    return _syncEngine?.syncPending(force: true) ?? const SyncReport(pendingCount: 1);
  }

  Future<List<GroupEvent>> _readCachedEvents(String userId, String groupId) async {
    final rows = await _offlineStore?.readCachedRecords(
      ownerUserId: userId, collection: 'group_events', groupId: groupId,
    );
    return (rows ?? const []).map((row) => row['payload']).whereType<Map>()
        .map((payload) => GroupEvent.fromJson(Map<String, dynamic>.from(payload))).toList(growable: false);
  }

  Future<void> _cacheEvents(String userId, String groupId, List<GroupEvent> events) async {
    await _offlineStore?.replaceRemoteRecords(
      ownerUserId: userId, collection: 'group_events', groupId: groupId,
      records: events.map((event) => <String, Object?>{
        'recordId': event.id, 'payload': event.toLegacyJson(),
      }).toList(growable: false),
    );
  }

  String _operationId(String userId, String id, {String suffix = 'upsert'}) =>
      '${userId}:group_events:${id}:${suffix}:${DateTime.now().microsecondsSinceEpoch}';
}
