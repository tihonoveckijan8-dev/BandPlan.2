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

  Stream<List<Setlist>> watchGroupSetlists(String userId, String groupId) async* {
    final cached = await _readCachedSetlists(userId, groupId);
    yield cached;
    try {
      final remote = await getGroupSetlists(groupId);
      await _cacheSetlists(userId, groupId, remote);
      yield await _readCachedSetlists(userId, groupId);
    } catch (error) {
      if (!isOfflineNetworkError(error) || cached.isEmpty) rethrow;
    }
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
    await store.saveAndQueue(
      operationId: _operationId(user.id, setlist.id), ownerUserId: user.id,
      groupId: groupId, collection: 'group_setlists', recordId: setlist.id,
      payload: Map<String, Object?>.from(setlist.toLegacyJson()),
    );
    return _syncEngine?.syncPending(force: true, retryFailed: true) ?? const SyncReport(pendingCount: 1);
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
    return _syncEngine?.syncPending(force: true) ?? const SyncReport(pendingCount: 1);
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
