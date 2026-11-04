import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast_web/sembast_web.dart';

import 'package:bandplan/core/local/offline_store.dart';
import 'package:bandplan/core/local/offline_sync_engine.dart';
import 'package:bandplan/features/events/domain/group_event.dart';
import 'package:bandplan/features/groups/domain/group_summary.dart';
import 'package:bandplan/features/setlists/domain/setlist.dart';
import 'package:bandplan/features/songs/domain/song.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bandplan/features/events/data/event_repository.dart';
import 'package:bandplan/features/setlists/data/setlist_repository.dart';
import 'package:bandplan/features/songs/data/song_repository.dart';

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


  test('IndexedDB preserves a two-device conflict and rebases keep-local after reopen', () async {
    await databaseFactoryWeb.deleteDatabase(databaseName);
    var store = OfflineStore(
      await databaseFactoryWeb.openDatabase(databaseName),
    );
    await store.cacheRemoteRecord(
      ownerUserId: 'pwa-user',
      groupId: 'pwa-group',
      collection: 'group_songs',
      recordId: 'pwa-song',
      payload: {'id': 'pwa-song', 'title': 'Original server version'},
    );
    await store.saveAndQueue(
      operationId: 'pwa-two-device-conflict',
      ownerUserId: 'pwa-user',
      groupId: 'pwa-group',
      collection: 'group_songs',
      recordId: 'pwa-song',
      payload: {'id': 'pwa-song', 'title': 'Device A offline edit'},
    );

    // WHY: Simulate device B changing the same song before device A reconnects.
    final conflictEngine = OfflineSyncEngine(
      store: store,
      currentUserId: () => 'pwa-user',
      applyMutation: (_) async => throw const OfflineMutationConflict(
        message: 'Song changed on another device.',
        remoteVersionExists: true,
        remotePayload: {'id': 'pwa-song', 'title': 'Device B server edit'},
      ),
    );
    final conflictReport = await conflictEngine.syncPending(force: true);
    expect(conflictReport.conflictCount, 1);
    expect(conflictReport.pendingCount, 1);
    await store.close();

    // WHY: Conflict details and both versions must survive PWA termination.
    store = OfflineStore(
      await databaseFactoryWeb.openDatabase(databaseName),
    );
    addTearDown(() async {
      await store.close();
      await databaseFactoryWeb.deleteDatabase(databaseName);
    });
    var pending = await store.readPendingMutations(ownerUserId: 'pwa-user');
    expect(pending.single['status'], 'conflict');
    expect((pending.single['payload'] as Map)['title'], 'Device A offline edit');
    expect((pending.single['remotePayload'] as Map)['title'], 'Device B server edit');

    await store.resolveConflictKeepLocal(
      operationId: 'pwa-two-device-conflict',
    );
    pending = await store.readPendingMutations(ownerUserId: 'pwa-user');
    expect(pending.single['status'], 'pending');
    expect((pending.single['basePayload'] as Map)['title'], 'Device B server edit');

    final applied = <Map<String, Object?>>[];
    final retryEngine = OfflineSyncEngine(
      store: store,
      currentUserId: () => 'pwa-user',
      applyMutation: (mutation) async {
        applied.add(Map<String, Object?>.from(mutation));
      },
    );
    final retryReport = await retryEngine.syncPending(force: true);
    expect(retryReport.syncedCount, 1);
    expect(retryReport.pendingCount, 0);
    expect(applied.single['basePayload'], {'id': 'pwa-song', 'title': 'Device B server edit'});
    expect(applied.single['payload'], {'id': 'pwa-song', 'title': 'Device A offline edit'});
  }, skip: !kIsWeb);


  test('IndexedDB restores all offline app datasets after a cold store reopen', () async {
    const databaseName = 'bandplan_offline_all_datasets_test';
    await databaseFactoryWeb.deleteDatabase(databaseName);
    var store = OfflineStore(
      await databaseFactoryWeb.openDatabase(databaseName),
    );

    // WHY: Seed the same account/group-scoped collections consumed by the
    // calendar, song library, setlists, and group switcher before termination.
    await store.cacheRemoteRecord(
      ownerUserId: 'offline-user',
      collection: 'my_groups',
      recordId: 'group-a',
      payload: {'id': 'group-a', 'name': 'Offline Band'},
    );
    await store.cacheRemoteRecord(
      ownerUserId: 'offline-user',
      collection: 'active_group',
      recordId: 'active',
      payload: {'group_id': 'group-a', 'group_name': 'Offline Band'},
    );
    await store.cacheRemoteRecord(
      ownerUserId: 'offline-user',
      groupId: 'group-a',
      collection: 'group_songs',
      recordId: 'song-a',
      payload: {'id': 'song-a', 'title': 'Cached song', 'lyrics': 'Offline lyrics'},
    );
    await store.cacheRemoteRecord(
      ownerUserId: 'offline-user',
      groupId: 'group-a',
      collection: 'group_events',
      recordId: 'event-a',
      payload: {'id': 'event-a', 'title': 'Cached rehearsal', 'date': '2026-11-05'},
    );
    await store.cacheRemoteRecord(
      ownerUserId: 'offline-user',
      groupId: 'group-a',
      collection: 'group_setlists',
      recordId: 'setlist-a',
      payload: {'id': 'setlist-a', 'name': 'Cached program', 'items': []},
    );
    await store.cacheRemoteRecord(
      ownerUserId: 'offline-user',
      collection: 'personal_songs',
      recordId: 'personal-song-a',
      payload: {'id': 'personal-song-a', 'title': 'Personal cached song'},
    );
    await store.close();

    // WHY: A new OfflineStore instance models a cold app restart; each dataset
    // must be readable without calling Supabase or depending on a live tab.
    store = OfflineStore(
      await databaseFactoryWeb.openDatabase(databaseName),
    );
    addTearDown(() async {
      await store.close();
      await databaseFactoryWeb.deleteDatabase(databaseName);
    });

    final groups = await store.readCachedRecords(
      ownerUserId: 'offline-user',
      collection: 'my_groups',
    );
    final activeGroup = await store.readCachedRecords(
      ownerUserId: 'offline-user',
      collection: 'active_group',
    );
    final songs = await store.readCachedRecords(
      ownerUserId: 'offline-user',
      groupId: 'group-a',
      collection: 'group_songs',
    );
    final events = await store.readCachedRecords(
      ownerUserId: 'offline-user',
      groupId: 'group-a',
      collection: 'group_events',
    );
    final setlists = await store.readCachedRecords(
      ownerUserId: 'offline-user',
      groupId: 'group-a',
      collection: 'group_setlists',
    );
    final personalSongs = await store.readCachedRecords(
      ownerUserId: 'offline-user',
      collection: 'personal_songs',
    );

    // WHY: A raw IndexedDB read is not enough: the actual feature models must
    // also accept the restored legacy payloads used by their screens.
    final restoredGroup = GroupSummary.fromJson(
      Map<String, dynamic>.from(groups.single['payload'] as Map),
    );
    final restoredSong = Song.fromJson(
      Map<String, dynamic>.from(songs.single['payload'] as Map),
    );
    final restoredEvent = GroupEvent.fromJson(
      Map<String, dynamic>.from(events.single['payload'] as Map),
    );
    final restoredSetlist = Setlist.fromJson(
      Map<String, dynamic>.from(setlists.single['payload'] as Map),
    );
    final restoredPersonalSong = Song.fromJson(
      Map<String, dynamic>.from(personalSongs.single['payload'] as Map),
    );

    expect(restoredGroup.id, 'group-a');
    expect(restoredGroup.name, 'Offline Band');
    expect((activeGroup.single['payload'] as Map)['group_id'], 'group-a');
    expect(restoredSong.title, 'Cached song');
    expect(restoredSong.lyrics, 'Offline lyrics');
    expect(restoredEvent.title, 'Cached rehearsal');
    expect(restoredSetlist.name, 'Cached program');
    expect(restoredPersonalSong.title, 'Personal cached song');
  }, skip: !kIsWeb);


  test('feature streams expose restored IndexedDB content before offline refresh', () async {
    const databaseName = 'bandplan_offline_feature_streams_test';
    await databaseFactoryWeb.deleteDatabase(databaseName);
    final store = OfflineStore(
      await databaseFactoryWeb.openDatabase(databaseName),
    );
    final client = SupabaseClient('http://127.0.0.1:1', 'offline-test-key');
    addTearDown(() async {
      await client.removeAllChannels();
      await store.close();
      await databaseFactoryWeb.deleteDatabase(databaseName);
    });

    // WHY: A cold offline relaunch must restore data through the same
    // repository streams consumed by the real songs, calendar and setlist UI.
    await store.cacheRemoteRecord(
      ownerUserId: 'offline-user',
      groupId: 'offline-group',
      collection: 'group_songs',
      recordId: 'song-stream',
      payload: {'id': 'song-stream', 'title': 'Offline stream song', 'lyrics': 'Local lyrics'},
    );
    await store.cacheRemoteRecord(
      ownerUserId: 'offline-user',
      groupId: 'offline-group',
      collection: 'group_events',
      recordId: 'event-stream',
      payload: {'id': 'event-stream', 'title': 'Offline stream rehearsal', 'date': '2026-11-05'},
    );
    await store.cacheRemoteRecord(
      ownerUserId: 'offline-user',
      groupId: 'offline-group',
      collection: 'group_setlists',
      recordId: 'setlist-stream',
      payload: {'id': 'setlist-stream', 'name': 'Offline stream setlist', 'items': []},
    );

    // WHY: Port 1 deliberately refuses network requests. The stream must still
    // emit its durable local snapshot and suppress only this transport failure.
    final songs = await SongRepository(client, offlineStore: store)
        .watchGroupSongs('offline-user', 'offline-group')
        .first
        .timeout(const Duration(seconds: 5));
    final events = await EventRepository(client, offlineStore: store)
        .watchGroupEvents('offline-user', 'offline-group')
        .first
        .timeout(const Duration(seconds: 5));
    final setlists = await SetlistRepository(client, offlineStore: store)
        .watchGroupSetlists('offline-user', 'offline-group')
        .first
        .timeout(const Duration(seconds: 5));

    expect(songs.map((song) => song.title), ['Offline stream song']);
    expect(songs.single.lyrics, 'Local lyrics');
    expect(events.map((event) => event.title), ['Offline stream rehearsal']);
    expect(setlists.map((setlist) => setlist.name), ['Offline stream setlist']);
  }, skip: !kIsWeb);

}
