import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local/offline_providers.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository?>((ref) {
  if (!SupabaseBootstrap.isInitialized) return null;
  return ProfileRepository(Supabase.instance.client);
});

final myProfileProvider = FutureProvider<AccountProfile>((ref) async {
  if (!SupabaseBootstrap.isInitialized) {
    throw StateError('Supabase is not configured.');
  }
  final store = await ref.watch(offlineStoreProvider.future);
  final repository = ProfileRepository(
    Supabase.instance.client,
    offlineStore: store,
  );
  return repository.getMyProfile();
});
