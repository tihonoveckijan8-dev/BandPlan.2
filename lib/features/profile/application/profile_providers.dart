import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository?>((ref) {
  if (!SupabaseBootstrap.isInitialized) return null;
  return ProfileRepository(Supabase.instance.client);
});

final myProfileProvider = FutureProvider<AccountProfile>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  if (repository == null) {
    throw StateError('Supabase is not configured.');
  }
  return repository.getMyProfile();
});
