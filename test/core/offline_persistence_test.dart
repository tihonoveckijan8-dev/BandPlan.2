import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:bandplan/core/local/offline_store.dart';
import 'package:bandplan/core/local/offline_sync_engine.dart';

void main() {
  late Directory directory;
  late String databasePath;
  OfflineStore? store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bandplan-offline-');
    databasePath = '${directory.path}/bandplan_offline_test.db';
  });

  tearDown(() async {
    await store?.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('outbox and local edit survive closing and reopening the database', () async {
    store = OfflineStore(await databaseFactoryIo.openDatabase(databasePath));
    await store!.cacheRemoteRecord(
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'group_songs',
      recordId: 'song-1',
      payload: {'id': 'song-1', 'title': 'Server title'},
    );
    await store!.saveAndQueue(
      operationId: 'restart-edit-1',
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'group_songs',
      recordId: 'song-1',
      payload: {'id': 'song-1', 'title': 'Local title'},
    );

    await store!.close();
    store = OfflineStore(await databaseFactoryIo.openDatabase(databasePath));

    final cached = await store!.readCachedRecords(
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'group_songs',
    );
    final pending = await store!.readPendingMutations(ownerUserId: 'user-a');

    expect(cached, hasLength(1));
    expect((cached.single['payload'] as Map)['title'], 'Local title');
    expect(cached.single['pendingSync'], isTrue);
    expect(pending, hasLength(1));
    expect(pending.single['operationId'], 'restart-edit-1');
    expect((pending.single['basePayload'] as Map)['title'], 'Server title');
    expect(pending.single['baseVersionCaptured'], isTrue);

    final applied = <Map<String, Object?>>[];
    final engine = OfflineSyncEngine(
      store: store!,
      currentUserId: () => 'user-a',
      applyMutation: (mutation) async => applied.add(mutation),
    );
    final report = await engine.syncPending(force: true);

    expect(report.syncedCount, 1);
    expect(report.pendingCount, 0);
    expect(applied.single['operationId'], 'restart-edit-1');
    expect(await store!.readPendingMutations(ownerUserId: 'user-a'), isEmpty);
    final afterSync = await store!.readCachedRecords(
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'group_songs',
    );
    expect(afterSync.single['pendingSync'], isFalse);
    expect((afterSync.single['payload'] as Map)['title'], 'Local title');
  });

  test('offline delete tombstone survives restart and blocks snapshot resurrection', () async {
    store = OfflineStore(await databaseFactoryIo.openDatabase(databasePath));
    await store!.cacheRemoteRecord(
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'group_events',
      recordId: 'event-1',
      payload: {'id': 'event-1', 'title': 'Rehearsal'},
    );
    await store!.saveAndQueue(
      operationId: 'restart-delete-1',
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'group_events',
      recordId: 'event-1',
      payload: {'id': 'event-1'},
      operation: 'delete',
    );

    await store!.close();
    store = OfflineStore(await databaseFactoryIo.openDatabase(databasePath));
    await store!.replaceRemoteRecords(
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'group_events',
      records: [
        {'recordId': 'event-1', 'payload': {'id': 'event-1', 'title': 'Old server event'}},
      ],
    );

    expect(
      await store!.readCachedRecords(
        ownerUserId: 'user-a',
        groupId: 'group-a',
        collection: 'group_events',
      ),
      isEmpty,
    );
    final pending = await store!.readPendingMutations(ownerUserId: 'user-a');
    expect(pending, hasLength(1));
    expect(pending.single['operation'], 'delete');
    expect(pending.single['status'], 'pending');
  });
}
