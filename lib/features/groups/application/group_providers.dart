import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../data/group_repository.dart';

final groupRepositoryProvider = Provider<GroupRepository?>((ref) {
  if (!SupabaseBootstrap.isInitialized) return null;
  return GroupRepository(Supabase.instance.client);
});

final myGroupsProvider = FutureProvider<dynamic>((ref) {
  final repository = ref.watch(groupRepositoryProvider);
  if (repository == null) {
    throw StateError('Supabase is not configured.');
  }
  return repository.getMyGroups();
});
