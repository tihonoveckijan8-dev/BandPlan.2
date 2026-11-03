import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'offline_store.dart';

/// Shared persistent database for local-first repositories.
final offlineStoreProvider = FutureProvider<OfflineStore>((ref) async {
  final store = await OfflineStore.open();
  ref.onDispose(() => unawaited(store.close()));
  return store;
});
