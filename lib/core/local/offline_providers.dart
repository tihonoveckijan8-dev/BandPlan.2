import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'offline_store.dart';
import 'offline_sync_engine.dart';
import 'supabase_offline_mutation_handler.dart';

/// Shared persistent database for local-first repositories.
final offlineStoreProvider = FutureProvider<OfflineStore>((ref) async {
  final store = await OfflineStore.open();
  ref.onDispose(() => unawaited(store.close()));
  return store;
});

/// One sequential outbox processor per app container.
final offlineSyncEngineProvider = FutureProvider<OfflineSyncEngine>((ref) async {
  final store = await ref.watch(offlineStoreProvider.future);
  final client = Supabase.instance.client;
  final handler = SupabaseOfflineMutationHandler(client);
  return OfflineSyncEngine(
    store: store,
    currentUserId: () => client.auth.currentUser?.id,
    applyMutation: handler.call,
  );
});


/// Current account's durable outbox state for the profile's sync controls.
final offlineQueueStatusProvider = FutureProvider<SyncReport>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return const SyncReport();
  final store = await ref.watch(offlineStoreProvider.future);
  final mutations = await store.readPendingMutations(ownerUserId: user.id);
  return SyncReport(
    pendingCount: mutations.length,
    failedCount: mutations.where((item) => item['status'] == 'failed').length,
    conflictCount: mutations.where((item) => item['status'] == 'conflict').length,
    // WHY: expose the actual server rejection instead of an unexplained sync error.
    lastError: mutations.reversed
        .map((item) => item['lastError']?.toString())
        .firstWhere((value) => value?.isNotEmpty == true, orElse: () => null),
  );
});

/// Current account's unresolved server/device conflicts for profile actions.
final offlineConflictsProvider =
    FutureProvider<List<Map<String, Object?>>>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return const [];
  final store = await ref.watch(offlineStoreProvider.future);
  final mutations = await store.readPendingMutations(ownerUserId: user.id);
  return mutations
      .where((item) => item['status'] == 'conflict')
      .toList(growable: false);
});
