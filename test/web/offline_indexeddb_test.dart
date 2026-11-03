import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast_web/sembast_web.dart';

import 'package:bandplan/core/local/offline_store.dart';
import 'package:bandplan/core/local/offline_sync_engine.dart';

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

  test('IndexedDB outbox drains after reopen when connectivity returns', () async {
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
      operationId: 'pwa-reconnect-edit',
      ownerUserId: 'pwa-user',
      groupId: 'pwa-group',
      collection: 'group_songs',
      recordId: 'pwa-song',
      payload: {'id': 'pwa-song', 'title': 'Offline edit'},
    );
    await store.close();

    // WHY: Simulate a terminated PWA by reopening the durable IndexedDB
    // database before the sync engine is created.
    store = OfflineStore(
      await databaseFactoryWeb.openDatabase(databaseName),
    );
    addTearDown(() async {
      await store.close();
      await databaseFactoryWeb.deleteDatabase(databaseName);
    });

    final applied = <Map<String, Object?>>[];
    final engine = OfflineSyncEngine(
      store: store,
      currentUserId: () => 'pwa-user',
      // WHY: The adapter represents a successful remote acknowledgement;
      // live Supabase/RLS behavior is verified separately on real accounts.
      applyMutation: (mutation) async {
        applied.add(Map<String, Object?>.from(mutation));
      },
    );

    final report = await engine.syncPending(force: true);
    final pending = await store.readPendingMutations(ownerUserId: 'pwa-user');
    final cached = await store.readCachedRecords(
      ownerUserId: 'pwa-user',
      groupId: 'pwa-group',
      collection: 'group_songs',
    );

    expect(applied, hasLength(1));
    expect(applied.single['operationId'], 'pwa-reconnect-edit');
    expect(report.syncedCount, 1);
    expect(report.pendingCount, 0);
    expect(pending, isEmpty);
    expect(cached, hasLength(1));
    expect(cached.single['pendingSync'], isFalse);
    expect((cached.single['payload'] as Map)['title'], 'Offline edit');
  }, skip: !kIsWeb);
  test('IndexedDB retains a failed network retry and drains it after reopen', () async {
    await databaseFactoryWeb.deleteDatabase(databaseName);
    var store = OfflineStore(
      await databaseFactoryWeb.openDatabase(databaseName),
    );
    await store.saveAndQueue(
      operationId: 'pwa-network-retry',
      ownerUserId: 'pwa-user',
      groupId: 'pwa-group',
      collection: 'group_songs',
      recordId: 'pwa-song',
      payload: {'id': 'pwa-song', 'title': 'Offline edit'},
    );

    final offlineEngine = OfflineSyncEngine(
      store: store,
      currentUserId: () => 'pwa-user',
      applyMutation: (_) async => throw Exception('Failed to fetch'),
    );
    final offlineReport = await offlineEngine.syncPending(force: true);
    expect(offlineReport.pendingCount, 1);
    expect(offlineReport.failedCount, 0);
    final failedAttempt = (await store.readPendingMutations(
      ownerUserId: 'pwa-user',
    )).single;
    expect(failedAttempt['status'], 'pending');
    expect(failedAttempt['attemptCount'], 1);
    expect(failedAttempt['lastError'], contains('Failed to fetch'));
    await store.close();

    // WHY: Retry metadata must survive a real browser database reopen too;
    // reconnecting must not depend on the previous Dart process remaining alive.
    store = OfflineStore(
      await databaseFactoryWeb.openDatabase(databaseName),
    );
    addTearDown(() async {
      await store.close();
      await databaseFactoryWeb.deleteDatabase(databaseName);
    });

    final applied = <String>[];
    final onlineEngine = OfflineSyncEngine(
      store: store,
      currentUserId: () => 'pwa-user',
      applyMutation: (mutation) async {
        applied.add(mutation['operationId']! as String);
      },
    );
    final onlineReport = await onlineEngine.syncPending(force: true);
    final remaining = await store.readPendingMutations(ownerUserId: 'pwa-user');

    expect(applied, ['pwa-network-retry']);
    expect(onlineReport.syncedCount, 1);
    expect(onlineReport.pendingCount, 0);
    expect(remaining, isEmpty);
  }, skip: !kIsWeb);

}
