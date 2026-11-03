import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast_web/sembast_web.dart';

import 'package:bandplan/core/local/offline_store.dart';

void main() {
  const databaseName = 'bandplan_offline_pwa_persistence_test';

  test('IndexedDB keeps cached edits and outbox after database reopen', () async {
    await databaseFactoryWeb.deleteDatabase(databaseName);
    var store = OfflineStore(
      await databaseFactoryWeb.openDatabase(databaseName),
    );

    await store.cacheRemoteRecord(
      ownerUserId: 'pwa-user',
      groupId: 'pwa-group',
      collection: 'group_songs',
      recordId: 'pwa-song',
      payload: {'id': 'pwa-song', 'title': 'Server version'},
    );
    await store.saveAndQueue(
      operationId: 'pwa-restart-edit',
      ownerUserId: 'pwa-user',
      groupId: 'pwa-group',
      collection: 'group_songs',
      recordId: 'pwa-song',
      payload: {'id': 'pwa-song', 'title': 'Offline edit'},
    );
    await store.close();

    // WHY: Reopening the same named browser database exercises IndexedDB,
    // rather than Sembast's in-memory test factory.
    store = OfflineStore(
      await databaseFactoryWeb.openDatabase(databaseName),
    );
    addTearDown(() async {
      await store.close();
      await databaseFactoryWeb.deleteDatabase(databaseName);
    });

    final cached = await store.readCachedRecords(
      ownerUserId: 'pwa-user',
      groupId: 'pwa-group',
      collection: 'group_songs',
    );
    final pending = await store.readPendingMutations(ownerUserId: 'pwa-user');

    expect(cached, hasLength(1));
    expect((cached.single['payload'] as Map)['title'], 'Offline edit');
    expect(cached.single['pendingSync'], isTrue);
    expect(pending, hasLength(1));
    expect(pending.single['operationId'], 'pwa-restart-edit');
    expect((pending.single['basePayload'] as Map)['title'], 'Server version');
  }, skip: !kIsWeb);
}
