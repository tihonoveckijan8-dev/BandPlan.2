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
      if (operation == 'delete') {
        await _cache.record(cacheKey).delete(transaction);
      } else {
        await _cache.record(cacheKey).put(transaction, {
          'ownerUserId': ownerUserId,
          'groupId': groupId,
          'collection': collection,
          'recordId': recordId,
          'payload': payload,
          'updatedAt': now,
          'pendingSync': true,
        });
      }

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
        'createdAt': now,
        'attemptCount': 0,
        'lastError': null,
      });
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
        'lastAttemptAt': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  /// Call only after Supabase has positively acknowledged this operation.
  Future<void> acknowledgeMutation(String operationId) async {
    await _database.transaction((transaction) async {
      final queued = await _outbox.record(operationId).get(transaction);
      if (queued == null) return;
      await _outbox.record(operationId).delete(transaction);

      if (queued['operation'] == 'delete') return;
      final cacheKey = _cacheKey(
        queued['ownerUserId']! as String,
        queued['groupId'] as String?,
        queued['collection']! as String,
        queued['recordId']! as String,
      );
      final cached = await _cache.record(cacheKey).get(transaction);
      if (cached == null) return;
      await _cache.record(cacheKey).put(transaction, {
        ...cached,
        'pendingSync': false,
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
