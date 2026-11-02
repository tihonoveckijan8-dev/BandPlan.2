import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../groups/application/group_providers.dart';
import '../data/setlist_repository.dart';
import '../domain/setlist.dart';

final setlistRepositoryProvider = Provider<SetlistRepository?>((ref) {
  if (!SupabaseBootstrap.isInitialized) return null;
  return SetlistRepository(Supabase.instance.client);
});

final groupSetlistsProvider = FutureProvider<List<Setlist>>((ref) async {
  final group = await ref.watch(activeGroupProvider.future);
  if (group == null) return const [];
  final repository = ref.watch(setlistRepositoryProvider);
  if (repository == null) throw StateError('Supabase is not configured.');
  return repository.getGroupSetlists(group.id);
});
