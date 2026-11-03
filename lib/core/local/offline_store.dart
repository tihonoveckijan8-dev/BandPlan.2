import 'package:sembast/sembast.dart';

import 'local_database_factory.dart';

/// A durable, account-scoped local cache and outbox.
///
/// This is infrastructure only: feature repositories are migrated in a later
/// milestone after their legacy payload and conflict semantics are verified.
class OfflineStore {
  OfflineStore(this._database);

  final Database _database;

  static final _cache = stringMapStoreFactory.store('cached_records');
  static final _outbox = stringMapStoreFactory.store('pending_mutations');

  static Future<OfflineStore> open() async =>
      OfflineStore(await openBandPlanLocalDatabase());

  /// Writes a local record and its matching remote mutation atomically.
  ///
  /// The caller supplies a stable operation ID so retrying the same enqueue
  /// request cannot create duplicate outbox entries.
  Future<void> saveAndQueue({
    required String operationId,
    required String ownerUserId,
    required String collection,
    required String recordId,
    required Map<String, Object?> payload,
    String? groupId,
    String operation = 'upsert',
  }) async {
    _validateScope(ownerUserId, collection, recordId);
    if (operationId.trim().isEmpty) {
      throw ArgumentError.value(operationId, 'operationId', 'Must not be empty.');
    }
    if (operation != 'upsert' && operation != 'delete') {
      throw ArgumentError.value(operation, 'operation', 'Must be upsert or delete.');
    }

    final cacheKey = _cacheKey(ownerUserId, groupId, collection, recordId);
    final now = DateTime.now().toUtc().toIso8601String();

    await _database.transaction((transaction) async {
      // WHY: The first queued edit must retain the last known server snapshot.
      // Later edits to the same record reuse that original baseline rather
      // than treating an intermediate local edit as the server version.
      final queuedForRecord = await _outbox.find(
        transaction,
        finder: Finder(
          filter: Filter.and([
            Filter.equals('ownerUserId', ownerUserId),
            Filter.equals('groupId', groupId),
            Filter.equals('collection', collection),
            Filter.equals('recordId', recordId),
          ]),
          sortOrders: [SortOrder('createdAt')],
        ),
      );
      final firstQueued = queuedForRecord.isEmpty
          ? null
          : queuedForRecord.first.value;
      final cachedBeforeEdit = await _cache.record(cacheKey).get(transaction);
      final baseVersionCaptured =
          firstQueued?['baseVersionCaptured'] == true ||
          (firstQueued == null && cachedBeforeEdit?['pendingSync'] != true);
      final basePayload = firstQueued != null
          ? firstQueued['basePayload']
          : (baseVersionCaptured && cachedBeforeEdit?['isDeleted'] != true
              ? cachedBeforeEdit?['payload']
              : null);

      // WHY: Keep a tombstone for queued deletes. A later remote refresh must
      // not resurrect the row before Supabase acknowledges the deletion.
      await _cache.record(cacheKey).put(transaction, {
        'ownerUserId': ownerUserId,
        'groupId': groupId,
        'collection': collection,
        'recordId': recordId,
        'payload': payload,
        'updatedAt': now,
        'pendingSync': true,
        'isDeleted': operation == 'delete',
      });

      // WHY: Cache mutation and outbox insertion share one transaction. A crash
      // cannot leave a local edit visible without a durable sync instruction.
      await _outbox.record(operationId).put(transaction, {
        'operationId': operationId,
        'ownerUserId': ownerUserId,
        'groupId': groupId,
        'collection': collection,
        'recordId': recordId,
        'operation': operation,
        'payload': payload,
        // WHY: Store the original server baseline with every queued operation
        // so sync can detect edits made by another device before applying ours.
        'basePayload': basePayload,
        'baseVersionCaptured': baseVersionCaptured,
        'createdAt': now,
        'attemptCount': 0,
        'lastError': null,
        'status': 'pending',
      });
    });
  }

  /// Reconciles a complete remote snapshot while protecting dirty local rows.
  Future<void> replaceRemoteRecords({
    required String ownerUserId,
    required String collection,
    required List<Map<String, Object?>> records,
    String? groupId,
  }) async {
    _validateScope(ownerUserId, collection, 'snapshot');
    final payloads = <String, Map<String, Object?>>{};
    for (final item in records) {
      final recordId = item['recordId']?.toString().trim() ?? '';
      final payload = item['payload'];
      if (recordId.isEmpty || payload is! Map) {
        throw ArgumentError('Every remote record needs a recordId and map payload.');
      }
      payloads[recordId] = Map<String, Object?>.from(payload);
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((transaction) async {
      final existing = await _cache.find(
        transaction,
        finder: Finder(
          filter: Filter.and([
            Filter.equals('ownerUserId', ownerUserId),
            Filter.equals('groupId', groupId),
            Filter.equals('collection', collection),
          ]),
        ),
      );

      for (final snapshot in existing) {
        final value = snapshot.value;
        final recordId = value['recordId']?.toString() ?? '';
        if (value['pendingSync'] == true || payloads.containsKey(recordId)) continue;
        await _cache.record(snapshot.key).delete(transaction);
      }

      for (final entry in payloads.entries) {
        final key = _cacheKey(ownerUserId, groupId, collection, entry.key);
        final previous = await _cache.record(key).get(transaction);
        if (previous?['pendingSync'] == true) continue;
        await _cache.record(key).put(transaction, {
          'ownerUserId': ownerUserId,
          'groupId': groupId,
          'collection': collection,
          'recordId': entry.key,
          'payload': entry.value,
          'updatedAt': now,
          'pendingSync': false,
        });
      }
    });
  }

  /// Stores a confirmed server snapshot without changing an existing dirty row.
  Future<void> cacheRemoteRecord({
    required String ownerUserId,
    required String collection,
    required String recordId,
    required Map<String, Object?> payload,
    String? groupId,
  }) async {
    _validateScope(ownerUserId, collection, recordId);
    final key = _cacheKey(ownerUserId, groupId, collection, recordId);

    await _database.transaction((transaction) async {
      final existing = await _cache.record(key).get(transaction);
      if (existing?['pendingSync'] == true) return;
      await _cache.record(key).put(transaction, {
        'ownerUserId': ownerUserId,
        'groupId': groupId,
        'collection': collection,
        'recordId': recordId,
        'payload': payload,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'pendingSync': false,
      });
    });
  }

  Future<List<Map<String, Object?>>> readCachedRecords({
    required String ownerUserId,
    required String collection,
    String? groupId,
  }) async {
    _validateScope(ownerUserId, collection, 'scope');
    final snapshots = await _cache.find(
      _database,
      finder: Finder(
        filter: Filter.and([
          Filter.equals('ownerUserId', ownerUserId),
          Filter.equals('groupId', groupId),
          Filter.equals('collection', collection),
        ]),
        sortOrders: [SortOrder('recordId')],
      ),
    );
    return snapshots
        .where((snapshot) => snapshot.value['isDeleted'] != true)
        .map((snapshot) => Map<String, Object?>.from(snapshot.value))
        .toList(growable: false);
  }

  Future<List<Map<String, Object?>>> readPendingMutations({
    required String ownerUserId,
  }) async {
    if (ownerUserId.trim().isEmpty) {
      throw ArgumentError.value(ownerUserId, 'ownerUserId', 'Must not be empty.');
    }
    final snapshots = await _outbox.find(
      _database,
      finder: Finder(
        filter: Filter.equals('ownerUserId', ownerUserId),
        sortOrders: [SortOrder('createdAt')],
      ),
    );
    return snapshots
        .map((snapshot) => Map<String, Object?>.from(snapshot.value))
        .toList(growable: false);
  }

  Future<void> recordRetry({
    required String operationId,
    required String error,
  }) async {
    await _database.transaction((transaction) async {
      final record = _outbox.record(operationId);
      final current = await record.get(transaction);
      if (current == null) return;
      await record.put(transaction, {
        ...current,
        'attemptCount': ((current['attemptCount'] as num?)?.toInt() ?? 0) + 1,
        'lastError': error,
        'status': 'pending',
        'lastAttemptAt': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  Future<void> recordFailure({
    required String operationId,
    required String error,
  }) async {
    await _database.transaction((transaction) async {
      final record = _outbox.record(operationId);
      final current = await record.get(transaction);
      if (current == null) return;
      await record.put(transaction, {
        ...current,
        'attemptCount': ((current['attemptCount'] as num?)?.toInt() ?? 0) + 1,
        'lastError': error,
        'status': 'failed',
        'lastAttemptAt': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  /// Explicitly re-enables server-rejected mutations after the user retries.
  Future<void> retryFailedMutations({required String ownerUserId}) async {
    await _database.transaction((transaction) async {
      final failed = await _outbox.find(
        transaction,
        finder: Finder(
          filter: Filter.and([
            Filter.equals('ownerUserId', ownerUserId),
            Filter.equals('status', 'failed'),
          ]),
        ),
      );
      for (final snapshot in failed) {
        await _outbox.record(snapshot.key).put(transaction, {
          ...snapshot.value,
          'status': 'pending',
          'lastError': null,
        });
      }
    });
  }

  /// Call only after Supabase has positively acknowledged this operation.
  Future<void> acknowledgeMutation(String operationId) async {
    await _database.transaction((transaction) async {
      final queued = await _outbox.record(operationId).get(transaction);
      if (queued == null) return;
      await _outbox.record(operationId).delete(transaction);

      final ownerUserId = queued['ownerUserId']! as String;
      final groupId = queued['groupId'] as String?;
      final collection = queued['collection']! as String;
      final recordId = queued['recordId']! as String;
      final cacheKey = _cacheKey(ownerUserId, groupId, collection, recordId);
      final otherMutations = await _outbox.find(
        transaction,
        finder: Finder(
          filter: Filter.equals('ownerUserId', ownerUserId),
        ),
      );
      final hasOtherPendingMutation = otherMutations.any((snapshot) {
        final value = snapshot.value;
        return value['groupId'] == groupId &&
            value['collection'] == collection &&
            value['recordId'] == recordId;
      });
      final cached = await _cache.record(cacheKey).get(transaction);
      if (cached == null) return;

      if (cached['isDeleted'] == true && !hasOtherPendingMutation) {
        await _cache.record(cacheKey).delete(transaction);
        return;
      }

      // WHY: Acknowledging an older operation must not mark a newer local edit
      // as synced. The remaining outbox entry still owns this dirty cache row.
      await _cache.record(cacheKey).put(transaction, {
        ...cached,
        'pendingSync': hasOtherPendingMutation,
      });
    });
  }

  Future<void> close() => _database.close();

  static String _cacheKey(
    String ownerUserId,
    String? groupId,
    String collection,
    String recordId,
  ) => '$ownerUserId::${groupId ?? '_personal'}::$collection::$recordId';

  static void _validateScope(
    String ownerUserId,
    String collection,
    String recordId,
  ) {
    if (ownerUserId.trim().isEmpty ||
        collection.trim().isEmpty ||
        recordId.trim().isEmpty) {
      throw ArgumentError('Offline cache scope and record identifiers must not be empty.');
    }
  }
}
