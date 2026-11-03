import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local/offline_providers.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../groups/application/group_providers.dart';
import '../data/song_repository.dart';
import '../domain/song.dart';

final songRepositoryProvider = Provider<SongRepository?>((ref) {
  if (!SupabaseBootstrap.isInitialized) return null;
  return SongRepository(Supabase.instance.client);
});

final groupSongsProvider = StreamProvider<List<Song>>((ref) async* {
  final group = await ref.watch(activeGroupProvider.future);
  if (group == null) {
    yield const [];
    return;
  }
  if (!SupabaseBootstrap.isInitialized) {
    throw StateError('Supabase is not configured.');
  }
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) throw StateError('Требуется авторизация.');
  final store = await ref.watch(offlineStoreProvider.future);
  final repository = SongRepository(client, offlineStore: store);
  yield* repository.watchGroupSongs(userId, group.id);
});

final personalSongsProvider = StreamProvider<List<Song>>((ref) async* {
  if (!SupabaseBootstrap.isInitialized) {
    throw StateError('Supabase is not configured.');
  }
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) throw StateError('Требуется авторизация.');
  final store = await ref.watch(offlineStoreProvider.future);
  final repository = SongRepository(client, offlineStore: store);
  yield* repository.watchPersonalSongs(userId);
});
