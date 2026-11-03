import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:bandplan/core/local/offline_store.dart';

void main() {
  late OfflineStore store;
  var testDatabaseId = 0;

  setUp(() async {
    // WHY: The memory factory keeps named databases alive across test cases.
    // Give every test its own database so outbox records cannot leak between tests.
    final database = await databaseFactoryMemory.openDatabase(
      'offline-store-test-${testDatabaseId++}',
    );
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

  test('queued edits retain the first server baseline across repeated edits', () async {
    await store.cacheRemoteRecord(
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
      recordId: 'song-1',
      payload: {'title': 'Server baseline', 'tempo': 120},
    );

    await store.saveAndQueue(
      operationId: 'edit-1',
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
      recordId: 'song-1',
      payload: {'title': 'First local edit', 'tempo': 120},
    );
    await store.saveAndQueue(
      operationId: 'edit-2',
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
      recordId: 'song-1',
      payload: {'title': 'Second local edit', 'tempo': 125},
    );

    final pending = await store.readPendingMutations(ownerUserId: 'user-a');
    expect(pending, hasLength(2));
    for (final mutation in pending) {
      expect(mutation['baseVersionCaptured'], isTrue);
      expect(
        (mutation['basePayload'] as Map)['title'],
        'Server baseline',
      );
      expect((mutation['basePayload'] as Map)['tempo'], 120);
    }
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

  test('queued delete is hidden and cannot be resurrected by remote refresh', () async {
    await store.cacheRemoteRecord(
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
      recordId: 'song-1',
      payload: {'title': 'Song'},
    );
    await store.saveAndQueue(
      operationId: 'delete-1',
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
      recordId: 'song-1',
      payload: const {},
      operation: 'delete',
    );
    await store.cacheRemoteRecord(
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
      recordId: 'song-1',
      payload: {'title': 'Stale server row'},
    );

    final cached = await store.readCachedRecords(
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
    );
    expect(cached, isEmpty);
    expect(await store.readPendingMutations(ownerUserId: 'user-a'), hasLength(1));
  });

  test('acknowledging an older edit keeps a newer edit pending', () async {
    await store.saveAndQueue(
      operationId: 'edit-1',
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
      recordId: 'song-1',
      payload: {'title': 'First edit'},
    );
    await store.saveAndQueue(
      operationId: 'edit-2',
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
      recordId: 'song-1',
      payload: {'title': 'Second edit'},
    );

    await store.acknowledgeMutation('edit-1');

    final cached = await store.readCachedRecords(
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
    );
    expect(cached.single['pendingSync'], isTrue);
    expect((cached.single['payload'] as Map)['title'], 'Second edit');
    expect(await store.readPendingMutations(ownerUserId: 'user-a'), hasLength(1));
  });

  test('remote snapshot removes stale clean rows but preserves pending edits', () async {
    await store.cacheRemoteRecord(
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
      recordId: 'stale-song',
      payload: {'title': 'Stale'},
    );
    await store.saveAndQueue(
      operationId: 'pending-song',
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
      recordId: 'pending-song',
      payload: {'title': 'Local pending'},
    );

    await store.replaceRemoteRecords(
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
      records: [
        {
          'recordId': 'fresh-song',
          'payload': {'id': 'fresh-song', 'title': 'Fresh'},
        },
      ],
    );

    final cached = await store.readCachedRecords(
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
    );
    final ids = cached.map((row) => row['recordId']).toSet();
    expect(ids, containsAll(['fresh-song', 'pending-song']));
    expect(ids, isNot(contains('stale-song')));
    expect(
      cached.singleWhere((row) => row['recordId'] == 'pending-song')['pendingSync'],
      isTrue,
    );
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
  test('acknowledgement advances the next queued edit baseline', () async {
    await store.cacheRemoteRecord(
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
      recordId: 'song-1',
      payload: {'title': 'Server version'},
    );
    await store.saveAndQueue(
      operationId: 'edit-1',
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
      recordId: 'song-1',
      payload: {'title': 'First local version'},
    );
    await store.saveAndQueue(
      operationId: 'edit-2',
      ownerUserId: 'user-a',
      groupId: 'group-a',
      collection: 'songs',
      recordId: 'song-1',
      payload: {'title': 'Second local version'},
    );

    await store.acknowledgeMutation('edit-1');

    final pending = await store.readPendingMutations(ownerUserId: 'user-a');
    expect(pending, hasLength(1));
    expect(pending.single['operationId'], 'edit-2');
    expect(
      (pending.single['basePayload'] as Map)['title'],
      'First local version',
    );
    expect(pending.single['baseVersionCaptured'], isTrue);
  });

}
