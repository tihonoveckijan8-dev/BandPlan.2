import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local/offline_providers.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../groups/application/group_providers.dart';
import '../data/song_repository.dart';
import '../domain/song.dart';

final songRepositoryProvider = FutureProvider<SongRepository>((ref) async {
  if (!SupabaseBootstrap.isInitialized) throw StateError('Supabase is not configured.');
  final store = await ref.watch(offlineStoreProvider.future);
  final syncEngine = await ref.watch(offlineSyncEngineProvider.future);
  return SongRepository(Supabase.instance.client, offlineStore: store, syncEngine: syncEngine);
});

final groupSongsProvider = StreamProvider<List<Song>>((ref) async* {
  final group = await ref.watch(activeGroupProvider.future);
  if (group == null) { yield const []; return; }
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) throw StateError('Требуется авторизация.');
  final repository = await ref.watch(songRepositoryProvider.future);
  yield* repository.watchGroupSongs(userId, group.id);
});

final personalSongsProvider = StreamProvider<List<Song>>((ref) async* {
  if (!SupabaseBootstrap.isInitialized) throw StateError('Supabase is not configured.');
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) throw StateError('Требуется авторизация.');
  final repository = await ref.watch(songRepositoryProvider.future);
  yield* repository.watchPersonalSongs(userId);
});
