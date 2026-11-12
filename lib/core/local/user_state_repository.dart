import 'package:supabase_flutter/supabase_flutter.dart';

import 'network_error.dart';
import 'offline_store.dart';
import 'offline_sync_engine.dart';

/// Reads and writes the authenticated user's existing private JSON state row.
/// The repository deliberately merges at the feature layer so unknown legacy
/// profile/settings keys survive every update.
class UserStateRepository {
  const UserStateRepository({
    required SupabaseClient client,
    required OfflineStore store,
    required OfflineSyncEngine syncEngine,
  }) : _client = client,
       _store = store,
       _syncEngine = syncEngine;

  final SupabaseClient _client;
  final OfflineStore _store;
  final OfflineSyncEngine _syncEngine;

  Future<Map<String, Object?>> readState() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Требуется авторизация.');

    // WHY: a dirty local row may contain edits that are not on the server yet.
    // Prefer it until the outbox acknowledges those edits.
    final cached = await _store.readCachedRecords(
      ownerUserId: user.id,
      collection: 'user_state',
    );
    if (cached.isNotEmpty && cached.first['pendingSync'] == true) {
      return _stateFromPayload(cached.first['payload']);
    }

    try {
      final row = await _client
          .from('bandplan_user_state')
          .select('user_id,state,updated_at')
          .eq('user_id', user.id)
          .maybeSingle();
      if (row == null) {
        // WHY: If a previously cached row disappeared remotely, retain its
        // contents locally; the compare-and-swap sync path will surface a
        // deletion conflict instead of silently recreating or discarding it.
        final previous = cached.isEmpty ? null : cached.first['payload'];
        return previous is Map
            ? _stateFromPayload(previous['state'])
            : const <String, Object?>{};
      }

      final payload = Map<String, Object?>.from(row);
      await _store.cacheRemoteRecord(
        ownerUserId: user.id,
        collection: 'user_state',
        recordId: 'state',
        payload: payload,
      );
      return _stateFromPayload(payload['state']);
    } catch (error) {
      if (!isOfflineNetworkError(error)) rethrow;
      final fallback = cached.isEmpty ? null : cached.first['payload'];
      if (fallback is Map) return _stateFromPayload(fallback['state']);
      // WHY: brand-new accounts can still use local defaults while offline.
      return const <String, Object?>{};
    }
  }

  Future<SyncReport> saveState(Map<String, Object?> state) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Требуется авторизация.');

    final payload = <String, Object?>{
      'user_id': user.id,
      'state': state,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _store.saveAndQueue(
      operationId: '${user.id}:user-state:${DateTime.now().microsecondsSinceEpoch}',
      ownerUserId: user.id,
      collection: 'user_state',
      recordId: 'state',
      payload: payload,
    );
    // WHY: a corrected later profile/settings edit can unblock an older failed write.
    return _syncEngine.syncPending(force: true, retryFailed: true);
  }

  Map<String, Object?> _stateFromPayload(Object? raw) {
    if (raw is! Map) return const <String, Object?>{};
    return Map<String, Object?>.from(raw);
  }
}
