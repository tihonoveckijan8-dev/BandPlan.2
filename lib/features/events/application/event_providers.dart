import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local/offline_providers.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../groups/application/group_providers.dart';
import '../data/event_repository.dart';
import '../domain/group_event.dart';

final eventRepositoryProvider = Provider<EventRepository?>((ref) {
  if (!SupabaseBootstrap.isInitialized) return null;
  return EventRepository(Supabase.instance.client);
});

final groupEventsProvider = StreamProvider<List<GroupEvent>>((ref) async* {
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
  final repository = EventRepository(client, offlineStore: store);
  yield* repository.watchGroupEvents(userId, group.id);
});
