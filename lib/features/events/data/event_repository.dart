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

  Stream<List<GroupEvent>> watchGroupEvents(String userId, String groupId) async* {
    final cached = await _readCachedEvents(userId, groupId);
    yield cached;
    try {
      final remote = await getGroupEvents(groupId);
      await _cacheEvents(userId, groupId, remote);
      yield await _readCachedEvents(userId, groupId);
    } catch (error) {
      if (!isOfflineNetworkError(error) || cached.isEmpty) rethrow;
    }
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
    return _syncEngine?.syncPending(force: true, retryFailed: true) ?? const SyncReport(pendingCount: 1);
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
    return _syncEngine?.syncPending(force: true, retryFailed: true) ?? const SyncReport(pendingCount: 1);
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
