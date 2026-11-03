import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local/offline_providers.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../data/profile_repository.dart';

final profileRepositoryProvider = FutureProvider<ProfileRepository>((ref) async {
  if (!SupabaseBootstrap.isInitialized) throw StateError('Supabase is not configured.');
  final store = await ref.watch(offlineStoreProvider.future);
  final syncEngine = await ref.watch(offlineSyncEngineProvider.future);
  return ProfileRepository(Supabase.instance.client, offlineStore: store, syncEngine: syncEngine);
});

final myProfileProvider = FutureProvider<AccountProfile>((ref) async {
  final repository = await ref.watch(profileRepositoryProvider.future);
  return repository.getMyProfile();
});
