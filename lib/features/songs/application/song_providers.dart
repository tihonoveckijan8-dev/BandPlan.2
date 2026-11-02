import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../groups/application/group_providers.dart';
import '../data/song_repository.dart';
import '../domain/song.dart';

final songRepositoryProvider = Provider<SongRepository?>((ref) {
  if (!SupabaseBootstrap.isInitialized) return null;
  return SongRepository(Supabase.instance.client);
});

final groupSongsProvider = FutureProvider<List<Song>>((ref) async {
  final group = await ref.watch(activeGroupProvider.future);
  if (group == null) return const [];

  final repository = ref.watch(songRepositoryProvider);
  if (repository == null) throw StateError('Supabase is not configured.');
  return repository.getGroupSongs(group.id);
});

final personalSongsProvider = FutureProvider<List<Song>>((ref) async {
  final repository = ref.watch(songRepositoryProvider);
  if (repository == null) throw StateError('Supabase is not configured.');
  return repository.getPersonalSongs();
});
