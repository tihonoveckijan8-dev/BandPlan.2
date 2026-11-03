import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:bandplan/core/local/offline_store.dart';

void main() {
  late OfflineStore store;

  setUp(() async {
    final database = await databaseFactoryMemory.openDatabase('offline-store-test');
    store = OfflineStore(database);
  });

  tearDown(() async {
    await store.close();
  });

  test('cache is isolated by account and group', () async {
    await store.cacheRemoteRecord(
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
      recordId: 'song-1',
      payload: {'title': 'Song A'},
    );

    final sameScope = await store.readCachedRecords(
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
    );
    final otherGroup = await store.readCachedRecords(
      ownerUserId: 'user-a',
      groupId: 'group-b',
      collection: 'songs',
    );
    final otherAccount = await store.readCachedRecords(
      ownerUserId: 'user-b',
      groupId: 'group-a',
      collection: 'songs',
    );

    expect(sameScope, hasLength(1));
    expect(otherGroup, isEmpty);
    expect(otherAccount, isEmpty);
  });

  test('local edit and outbox entry are persisted together', () async {
    await store.saveAndQueue(
      operationId: 'op-1',
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
      recordId: 'song-1',
      payload: {'title': 'Edited song'},
    );

    final cached = await store.readCachedRecords(
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
    );
    final pending = await store.readPendingMutations(ownerUserId: 'user-a');

    expect(cached.single['pendingSync'], isTrue);
    expect(pending, hasLength(1));
    expect(pending.single['operationId'], 'op-1');
  });

  test('remote refresh cannot overwrite a pending local edit', () async {
    await store.saveAndQueue(
      operationId: 'op-1',
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
      recordId: 'song-1',
      payload: {'title': 'Local edit'},
    );
    await store.cacheRemoteRecord(
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
      recordId: 'song-1',
      payload: {'title': 'Stale server value'},
    );

    final cached = await store.readCachedRecords(
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
    );

    expect((cached.single['payload'] as Map)['title'], 'Local edit');
  });

  test('acknowledgement clears pending state only after server confirmation', () async {
    await store.saveAndQueue(
      operationId: 'op-1',
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
      recordId: 'song-1',
      payload: {'title': 'Local edit'},
    );

    await store.acknowledgeMutation('op-1');

    final cached = await store.readCachedRecords(
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
    );
    final pending = await store.readPendingMutations(ownerUserId: 'user-a');

    expect(cached.single['pendingSync'], isFalse);
    expect(pending, isEmpty);
  });
}
