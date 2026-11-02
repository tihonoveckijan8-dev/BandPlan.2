import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../groups/application/group_providers.dart';
import '../data/event_repository.dart';
import '../domain/group_event.dart';

final eventRepositoryProvider = Provider<EventRepository?>((ref) {
  if (!SupabaseBootstrap.isInitialized) return null;
  return EventRepository(Supabase.instance.client);
});

final groupEventsProvider = FutureProvider<List<GroupEvent>>((ref) async {
  final group = await ref.watch(activeGroupProvider.future);
  if (group == null) return const [];
  final repository = ref.watch(eventRepositoryProvider);
  if (repository == null) throw StateError('Supabase is not configured.');
  return repository.getGroupEvents(group.id);
});
