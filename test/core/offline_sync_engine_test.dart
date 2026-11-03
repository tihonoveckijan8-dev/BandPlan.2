import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:bandplan/core/local/offline_store.dart';
import 'package:bandplan/core/local/offline_sync_engine.dart';

void main() {
  late OfflineStore store;
  var databaseId = 0;

  setUp(() async {
    final database = await databaseFactoryMemory.openDatabase(
      'offline-sync-test-${databaseId++}',
    );
    store = OfflineStore(database);
  });

  tearDown(() async => store.close());

  Future<void> enqueue(String id) => store.saveAndQueue(
        operationId: id,
        ownerUserId: 'user-a',
        groupId: 'group-a',
        collection: 'group_songs',
        recordId: id,
        payload: {'id': id, 'title': id},
      );

  test('acknowledges a mutation only after the remote handler succeeds', () async {
    await enqueue('song-1');
    final engine = OfflineSyncEngine(
      store: store,
      currentUserId: () => 'user-a',
      applyMutation: (_) async {},
    );
    final report = await engine.syncPending();
    expect(report.syncedCount, 1);
    expect(report.pendingCount, 0);
    expect(await store.readPendingMutations(ownerUserId: 'user-a'), isEmpty);
  });

  test('retains a mutation after a transport failure', () async {
    await enqueue('song-1');
    final engine = OfflineSyncEngine(
      store: store,
      currentUserId: () => 'user-a',
      applyMutation: (_) async => throw Exception('Failed to fetch'),
    );
    final report = await engine.syncPending();
    final pending = await store.readPendingMutations(ownerUserId: 'user-a');
    expect(report.pendingCount, 1);
    expect(report.failedCount, 0);
    expect(pending.single['status'], 'pending');
    expect(pending.single['attemptCount'], 1);
  });

  test('preserves local data when Supabase permanently rejects a mutation', () async {
    await enqueue('song-1');
    final engine = OfflineSyncEngine(
      store: store,
      currentUserId: () => 'user-a',
      applyMutation: (_) async => throw StateError('RLS rejected the write'),
    );
    final report = await engine.syncPending();
    final cached = await store.readCachedRecords(
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'group_songs',
    );
    final pending = await store.readPendingMutations(ownerUserId: 'user-a');
    expect(report.failedCount, 1);
    expect(report.pendingCount, 1);
    expect(pending.single['status'], 'failed');
    expect((cached.single['payload'] as Map)['title'], 'song-1');
  });

  test('does not send one account queue while another account is active', () async {
    await enqueue('song-1');
    var applied = false;
    final engine = OfflineSyncEngine(
      store: store,
      currentUserId: () => 'user-b',
      applyMutation: (_) async => applied = true,
    );
    final report = await engine.syncPending();
    expect(applied, isFalse);
    expect(report.pendingCount, 0);
    expect(await store.readPendingMutations(ownerUserId: 'user-a'), hasLength(1));
  });

  test('allows explicit retry after a permanent rejection is corrected', () async {
    await enqueue('song-1');
    await store.recordFailure(operationId: 'song-1', error: 'temporary policy issue');
    final engine = OfflineSyncEngine(
      store: store,
      currentUserId: () => 'user-a',
      applyMutation: (_) async {},
    );
    final report = await engine.syncPending(retryFailed: true);
    expect(report.syncedCount, 1);
    expect(report.pendingCount, 0);
  });

  test('preserves FIFO order across multiple local edits', () async {
    await enqueue('song-1');
    await enqueue('song-2');
    final applied = <String>[];
    final engine = OfflineSyncEngine(
      store: store,
      currentUserId: () => 'user-a',
      applyMutation: (mutation) async => applied.add(mutation['recordId']! as String),
    );
    final report = await engine.syncPending();
    expect(applied, ['song-1', 'song-2']);
    expect(report.pendingCount, 0);
  });
}
