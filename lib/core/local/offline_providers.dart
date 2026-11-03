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
  const handler = SupabaseOfflineMutationHandler;
  return OfflineSyncEngine(
    store: store,
    currentUserId: () => client.auth.currentUser?.id,
    applyMutation: handler(client).call,
  );
});
